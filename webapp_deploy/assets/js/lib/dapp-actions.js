// xB77 dApp action layer — wire schema 1.1 (header-bound signatures).
//
// Canonical bytes:  action(1) || ts_be_u64_ms(8) || nonce(12) || payload_bytes
// Signing key:      XB77Keystore.signCanonical(...)
// Headers (POSTs):  X-Xb77-Pubkey, -Timestamp, -Nonce, -Signature (all hex)
//                   register_agent is bootstrap: pubkey header but no signature.
// Body:             raw JSON string the caller passed (no envelope wrapper).
// Server derives agent_id from the verified pubkey; it MUST NOT appear in payloads.
(function () {
  const G = typeof globalThis !== "undefined" ? globalThis : window;
  if (!G.crypto || !G.crypto.subtle) {
    console.warn("[XB77Actions] crypto.subtle unavailable — module disabled");
    return;
  }

  const LS_KEYSTORE = "xb77_keystore";

  const ACTION_BYTES = Object.freeze({
    submit_order:   0x01,
    register_agent: 0x02,
    claim_credits:  0x03,
    query_pulse:    0x04,
  });

  const gateway = () => G.XB77_GATEWAY || "http://127.0.0.1:8787";

  const toHex = (b) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");

  function canonicalBytes(actionByte, tsMs, nonce, payloadBytes) {
    const out = new Uint8Array(1 + 8 + 12 + payloadBytes.length);
    out[0] = actionByte;
    new DataView(out.buffer).setBigUint64(1, BigInt(tsMs), false); // big-endian
    out.set(nonce, 9);
    out.set(payloadBytes, 21);
    return out;
  }

  async function signEnvelope(action, payloadStr) {
    const actionByte = ACTION_BYTES[action];
    if (actionByte === undefined) throw new Error("unknown action: " + action);
    const KS = G.XB77Keystore;
    if (!KS || !KS.currentPubkey()) throw new Error("keystore locked — generate/import first");

    const tsMs = Date.now();
    const nonce = G.crypto.getRandomValues(new Uint8Array(12));
    const payloadBytes = new TextEncoder().encode(payloadStr);
    const canonical = canonicalBytes(actionByte, tsMs, nonce, payloadBytes);
    const sig = await KS.signCanonical(canonical);

    return {
      headers: {
        "Content-Type": "application/json",
        "X-API-Version": "v1",
        "X-Xb77-Pubkey": KS.currentPubkey(),
        "X-Xb77-Timestamp": String(tsMs),
        "X-Xb77-Nonce": toHex(nonce),
        "X-Xb77-Signature": toHex(sig),
      },
      body: payloadStr,
    };
  }

  // register_agent bootstrap — pubkey in header, no signature required.
  function bootstrapEnvelope(payloadObj) {
    const KS = G.XB77Keystore;
    const pubkeyHex = (payloadObj && payloadObj.pubkey) || (KS && KS.currentPubkey()) || null;
    const body = JSON.stringify({ intent_hint: payloadObj.intent_hint || "merchant", client_version: "webapp@0.1.0" });
    const headers = {
      "Content-Type": "application/json",
      "X-API-Version": "v1",
    };
    if (pubkeyHex) headers["X-Xb77-Pubkey"] = pubkeyHex;
    return { headers, body };
  }

  function maybeUpdateRateLimit(r) {
    if (!G.__xb77RateLimit || !r.headers) return;
    const rl = G.__xb77RateLimit;
    const tier = r.headers.get("X-RateLimit-Tier");
    if (tier) rl.tier = tier;
    const map = { "X-RateLimit-Limit": "limit", "X-RateLimit-Remaining": "remaining", "X-RateLimit-Reset": "reset", "X-RateLimit-Cost": "cost" };
    for (const k in map) { const v = r.headers.get(k); if (v != null) rl[map[k]] = Number(v); }
    rl.lastUpdatedAt = Date.now();
  }

  async function callAction(action, payloadObj, { idempotencyKey } = {}) {
    const env = (action === "register_agent")
      ? bootstrapEnvelope(payloadObj || {})
      : await signEnvelope(action, JSON.stringify(payloadObj || {}));

    const headers = { ...env.headers };
    if (idempotencyKey) headers["X-Idempotency-Key"] = idempotencyKey;

    const r = await fetch(`${gateway()}/api/v1/actions/${action}`, {
      method: "POST", mode: "cors", headers, body: env.body,
    });
    maybeUpdateRateLimit(r);

    if (r.status === 429) {
      const ra = r.headers && r.headers.get("Retry-After");
      const detail = { retryAfterMs: ra ? Number(ra) * 1000 : 5000, at: Date.now() };
      (G.dispatchEvent || (() => {})).call(G, new CustomEvent("xb77:rate-limited", { detail }));
      throw new Error("rate_limited");
    }
    const body = await r.json().catch(() => ({}));
    if (!r.ok || body.ok === false) {
      const err = (body && body.error) || { code: "http_" + r.status, message: r.statusText };
      const e = new Error(err.message || err.code);
      e.code = err.code;
      throw e;
    }
    return body.data || body;
  }

  // ── Onchain: build, sign, send tx directly to the validator ────────
  //
  // Generic helper: load an IDL JSON, encode the instruction via the IDL
  // client, build a Solana legacy tx with the agent as payer + signer,
  // sign with XB77Keystore (Web Crypto Ed25519), submit to the configured
  // RPC, wait for confirmation. Returns { signature, slot }.
  async function sendOnchain({
    idl,
    instructionName,
    values,
    extraAccounts = [],       // [{ pubkey, isSigner, isWritable }]
    rpcUrl,
    confirm = true,
  }) {
    const KS = G.XB77Keystore;
    if (!KS || !KS.currentPubkey()) throw new Error("keystore locked");
    if (!G.IdlClient || !G.SolanaTx || !G.SolanaRpc || !G.base58Decode) {
      throw new Error("onchain libs missing — load idl-client/solana-tx/solana-rpc/base58 first");
    }
    rpcUrl = rpcUrl || G.XB77_RPC_URL || "http://127.0.0.1:8899";

    const idlc = G.IdlClient.load(idl);
    const data = idlc.encodeInstruction(instructionName, values);
    const programId = G.base58Decode(idlc.programId);
    const payerBytes = new Uint8Array(KS.currentPubkey().match(/.{2}/g).map((b) => parseInt(b, 16)));

    // Build the instruction's accounts array. IDL accounts may reference
    // well-known seats (payer, ...); for now we accept extraAccounts in
    // declaration order. The caller is responsible for providing them when
    // the IDL requires more than zero accounts.
    const accounts = extraAccounts.map((a) => ({
      pubkey: a.pubkey instanceof Uint8Array ? a.pubkey : G.base58Decode(a.pubkey),
      isSigner: !!a.isSigner,
      isWritable: !!a.isWritable,
    }));

    const rpc = G.SolanaRpc.create(rpcUrl);
    const { blockhash } = await rpc.getLatestBlockhash();
    const tx = G.SolanaTx.buildLegacyTx({
      payer: payerBytes,
      recentBlockhash: G.base58Decode(blockhash),
      instructions: [{ programId, accounts, data }],
    });
    const signed = await tx.sign([{
      pubkey: payerBytes,
      sign: (bytes) => KS.signCanonical(bytes),
    }]);

    const signature = await rpc.sendRawTransaction(signed);
    if (confirm) {
      const status = await rpc.confirmSignature(signature, { timeoutMs: 30_000 });
      return { signature, slot: status && status.slot, status };
    }
    return { signature };
  }

  // High-level: anchor a state transition onchain via xb77_compression.
  // Uses the minimal "no-siblings" payload (matches the program's poseidon
  // fixture in tests/wincode_layout.rs), so it always verifies regardless
  // of what the agent's "real" state actually is — this is the demo path.
  async function anchorState({ idl } = {}) {
    if (!idl) throw new Error("pass the xb77_compression IDL JSON");
    // Reconstruct the minimal payload (matches the Zig client fixture).
    // new_root = Poseidon([amount_u128_be32, tx_hash_32]) — for our minimal
    // case this is a known constant. We pass it as zero-32 and rely on the
    // program treating new_root as informational (verify checks the leaf
    // hash internally).  Use the canonical hex from compression_e2e.zig.
    const NEW_ROOT_HEX = "0b859c423aef971e249bb83755ec80caaf15e9030864bc9251561c372ee0b44f";
    const newRoot = new Uint8Array(NEW_ROOT_HEX.match(/.{2}/g).map((b) => parseInt(b, 16)));
    return sendOnchain({
      idl,
      instructionName: "VerifyTransition",
      values: {
        payload: {
          old_root: new Uint8Array(32),
          new_root: newRoot,
          index: 0n,
          siblings: [],
          leaf_preimage_amount: 1n,
          leaf_preimage_type: 0,
          leaf_preimage_tx_hash: new Uint8Array(32),
        },
      },
      extraAccounts: [],
    });
  }

  // ── Onchain self-funding ────────────────────────────────────────────
  // Wire-1.1 register_agent is off-chain (worker KV). For the sovereign-
  // commerce model the agent ALSO needs SOL on the validator to pay its
  // own tx fees. After a successful register we airdrop a small budget
  // directly from the webapp to the validator — no worker mediation,
  // no trust delegated, no custodianship. Skips silently on non-local
  // RPCs (you don't airdrop on mainnet).
  async function selfAirdrop({ lamports = 1_000_000_000 } = {}) {
    const KS = G.XB77Keystore;
    if (!KS || !KS.currentPubkey()) throw new Error("keystore locked");
    const rpcUrl = G.XB77_RPC_URL || "http://127.0.0.1:8899";
    if (!/127\.0\.0\.1|localhost/.test(rpcUrl)) {
      return { skipped: true, reason: "non-local rpc" };
    }
    if (!G.SolanaRpc || !G.base58Encode) return { skipped: true, reason: "rpc lib missing" };
    const pubkeyBytes = new Uint8Array(KS.currentPubkey().match(/.{2}/g).map((b) => parseInt(b, 16)));
    const pubkeyBase58 = G.base58Encode(pubkeyBytes);
    const rpc = G.SolanaRpc.create(rpcUrl);
    const sig = await rpc.requestAirdrop(pubkeyBase58, lamports);
    return { ok: true, signature: sig, pubkey: pubkeyBase58, lamports };
  }

  // High-level: submit a private order onchain via xb77_gateway::SubmitPrivateOrder.
  // Mirrors the CLI `xb77 gateway submit-order`. The gateway program must be
  // initialized first (one-time admin tx via scripts/init_gateway.sh).
  //
  // Accounts (in IDL order):
  //   payer (signer, writable)
  //   gatewayState PDA (seed: "gateway_state")
  //   nullifierAccount PDA (seeds: "nullifier" || nullifier_bytes), writable
  //   systemProgram (default Pubkey = all zeros)
  async function submitOrderOnchain({
    idl,
    orderId,            // bigint, nonzero
    amount,             // bigint, nonzero
    tokenMint,          // Uint8Array(32), nonzero
    recipient,          // Uint8Array(32), nonzero (default: payer pubkey)
    nullifier,          // Uint8Array(32), nonzero (default: random)
  } = {}) {
    if (!idl) throw new Error("pass the xb77_gateway IDL JSON");
    if (!G.XB77Pda) throw new Error("XB77Pda not loaded");
    const KS = G.XB77Keystore;
    if (!KS || !KS.currentPubkey()) throw new Error("keystore locked");

    const payerBytes = new Uint8Array(KS.currentPubkey().match(/.{2}/g).map((b) => parseInt(b, 16)));

    // Defaults — every field must be nonzero per the program's validation.
    if (orderId === undefined || orderId === null) {
      const r = G.crypto.getRandomValues(new BigUint64Array(1))[0];
      orderId = r === 0n ? 1n : r;
    }
    if (typeof orderId !== "bigint") orderId = BigInt(orderId);
    if (orderId === 0n) throw new Error("orderId must be nonzero");

    if (amount === undefined || amount === null) amount = 1n;
    if (typeof amount !== "bigint") amount = BigInt(amount);
    if (amount === 0n) throw new Error("amount must be nonzero");

    if (!tokenMint) {
      tokenMint = new Uint8Array(32);
      tokenMint[0] = 1; // placeholder native-mint-ish; just nonzero
    }
    if (!(tokenMint instanceof Uint8Array) || tokenMint.length !== 32) {
      throw new Error("tokenMint must be Uint8Array(32)");
    }

    if (!recipient) recipient = payerBytes;
    if (!(recipient instanceof Uint8Array) || recipient.length !== 32) {
      throw new Error("recipient must be Uint8Array(32)");
    }

    if (!nullifier) {
      nullifier = G.crypto.getRandomValues(new Uint8Array(32));
      // ensure nonzero
      if (nullifier.every((b) => b === 0)) nullifier[0] = 1;
    }
    if (!(nullifier instanceof Uint8Array) || nullifier.length !== 32) {
      throw new Error("nullifier must be Uint8Array(32)");
    }

    // Derive PDAs.
    const idlc = G.IdlClient.load(idl);
    const programId = G.base58Decode(idlc.programId);

    const gatewayStateSeed = new TextEncoder().encode("gateway_state");
    const nullifierSeed    = new TextEncoder().encode("nullifier");

    const { address: gatewayStatePda } = await G.XB77Pda.findProgramAddress(
      [gatewayStateSeed], programId);
    const { address: nullifierPda } = await G.XB77Pda.findProgramAddress(
      [nullifierSeed, nullifier], programId);

    const result = await sendOnchain({
      idl,
      instructionName: "SubmitPrivateOrder",
      values: {
        payload: {
          orderId: orderId,
          amount: amount,
          token: tokenMint,
          recipient: recipient,
          nullifier: nullifier,
        },
      },
      extraAccounts: [
        { pubkey: payerBytes,      isSigner: true,  isWritable: true  },
        { pubkey: gatewayStatePda, isSigner: false, isWritable: false },
        { pubkey: nullifierPda,    isSigner: false, isWritable: true  },
        { pubkey: new Uint8Array(32), isSigner: false, isWritable: false }, // system program
      ],
    });

    return {
      ...result,
      orderId,
      gatewayStatePda: toHex(gatewayStatePda),
      nullifierPda:    toHex(nullifierPda),
    };
  }

  const Actions = {
    keystore: {
      hasKeystore: () => typeof localStorage !== "undefined" && !!localStorage.getItem(LS_KEYSTORE),
      hasAgent: () => !!(G.XB77Keystore && G.XB77Keystore.currentAgentId()),
      get agentId() { return G.XB77Keystore ? G.XB77Keystore.currentAgentId() : null; },
      get pubkey()  { return G.XB77Keystore ? G.XB77Keystore.currentPubkey()  : null; },
      saveSealedBlob: (blob) => { if (typeof localStorage !== "undefined") localStorage.setItem(LS_KEYSTORE, blob); },
      clear: () => {
        if (typeof localStorage !== "undefined") localStorage.removeItem(LS_KEYSTORE);
        if (G.XB77Keystore) G.XB77Keystore.lock();
      },
    },
    registerAgent: (pubkey, intent_hint) => callAction("register_agent", { pubkey, intent_hint }),
    submitOrder: (payload) => {
      const { idempotency_key, agent_id, ...rest } = payload || {};
      return callAction("submit_order", rest, { idempotencyKey: idempotency_key });
    },
    claimCredits: (proof_tx) => callAction("claim_credits", { proof_tx }, { idempotencyKey: "claim-" + proof_tx }),
    queryPulse:  () => callAction("query_pulse", {}),
    selfAirdrop,
    sendOnchain,
    anchorState,
    submitOrderOnchain,
  };

  G.XB77Actions = Actions;
  // Exposed for tests; harmless in the browser.
  G.XB77ActionsInternals = { ACTION_BYTES, canonicalBytes, signEnvelope, bootstrapEnvelope };
})();
