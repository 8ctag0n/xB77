# 🔁 HANDOFF — Close the bidirectional demo (webapp ↔ CLI ↔ gateway)

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/docs-v2`
> **Branch**: `feat/dapp-public-split` @ `ef039e3`
> **Scope**: LOCAL demo closure only. Sponsors moved to `specs/sponsors/` for remote execution.
> **Estimated effort**: 2.5–3h focused

## State at session close

| Component | State |
|---|---|
| Mock-gateway (wire 1.1) | ✅ `sdk/ts/dev/mock-gateway.ts` — VERIFY_SIGS toggle, CORS, RL headers, full endpoint coverage |
| Real gateway (CF Worker) | ✅ Merged via `feat/gateway-realdata` — `gateway/worker/src/index.js` (865 lines) |
| SDK wire 1.1 (Zig/TS/Rust) | ✅ Byte-identical, 67 tests green |
| CLI `xb77 gateway *` | ✅ **Real Ed25519 sigs** against mock, e2e script green (see `scripts/e2e_cli_gateway.sh`) |
| Webapp checklist §8 | ✅ Modal, pill, actions, wallet polling, rate-limit strip, 429 toast |
| **Webapp signing** | ❌ **STUB** — `signEnvelope` returns `"ed25519:stub..."`. Works against mock with `VERIFY_SIGS=0` only. Fails against real gateway. |
| **Webapp keystore** | ❌ **STUB** — `_ksRandHex(32)` for pubkey, base64 placeholder for seal |
| Sponsor specs (QVAC/MagicBlock/SNS) | ✅ Committed at `specs/sponsors/*` — remote execution, not local |

## Commits this session (in order)

```
ef039e3  docs(specs): sponsor integration specs for remote execution
8189714  feat(cli): gateway subcommand — wire-1.1 e2e from CLI
548c4e7  merge: bring in feat/gateway-realdata (wire schema 1.1 + real gateway)
18d429b  feat(webapp,mock): wire wallet to real data + contract-v1 mock-gateway
3b80042  feat(webapp): wire dApp to contract v1 §8 — stub-signed end-to-end
```

## Mission for the next session

Migrate the webapp from stub crypto to real Web Crypto Ed25519 so both
sides of the demo (CLI and webapp) speak wire schema 1.1 end-to-end
against the same gateway with `XB77_VERIFY_SIGS=1`. Then build the
bidirectional cross-visibility demo orchestrator.

## What still works without doing anything

Tonight you can already demo this much:

```bash
# Boot mock with sigs OFF (default)
cd sdk/ts && bun run dev/mock-gateway.ts --port 8787 &

# CLI uses real sigs, mock accepts them anyway
./zig-out/bin/xb77 gateway register --intent merchant
./zig-out/bin/xb77 gateway order --side buy --amount 100 --price 10000

# Webapp uses stub sigs, mock also accepts them
cd webapp_deploy && ./build.sh && python3 -m http.server 8080 &
# Open http://127.0.0.1:8080/app.html → modal generate → buttons work
```

Both sides hit the same gateway, in-memory state is shared, so an order
submitted from CLI shows up in webapp's pipelines list (10s poll) and
vice versa. **That's the demo.** It just isn't crypto-real on the webapp
side yet.

## What needs doing (7 tasks)

### [1] Real keystore (Web Crypto Ed25519)

**File to create**: `webapp_deploy/assets/src/lib/keystore.js`

Single vanilla JS module attached to `window.XB77Keystore`. Public API:

```
XB77Keystore.generate(password)   → {pubkeyHex, agentId, sealedBlob, sessionReady}
XB77Keystore.import(blob, password) → {pubkeyHex, agentId, sealedBlob, sessionReady}
XB77Keystore.loadFromStorage(password) → reads localStorage, calls import
XB77Keystore.signCanonical(canonicalBytes) → Uint8Array(64)
XB77Keystore.currentPubkey() → hex string or null
XB77Keystore.currentAgentId() → "ag_" + sha256(pubkey)[:9] hex
XB77Keystore.lock() → clears in-memory session key
```

Implementation:
- `crypto.subtle.generateKey({name:"Ed25519"}, true, ["sign","verify"])`
- `crypto.subtle.exportKey("raw", publicKey)` → 32B pubkey
- `crypto.subtle.exportKey("pkcs8", privateKey)` → DER bytes
- Seal: PBKDF2 from password (100k iters, SHA-256, 32B output salt) → AES-GCM key → encrypt PKCS8 → base64 JSON blob `{v:1, pubkey, salt, iv, ct}`
- Private key in session: re-import as **non-extractable** so it can only sign, never leaks
- `agent_id = "ag_" + hex(sha256(pubkey_bytes)[:9])` — use `crypto.subtle.digest("SHA-256", ...)`

### [2] Migrate `dapp-actions.js` to wire 1.1

**File**: `webapp_deploy/assets/src/lib/dapp-actions.js`

Replace `signEnvelope()` with:

```js
async function signEnvelope(action, payload) {
  const actionByte = { submit_order: 0x01, register_agent: 0x02, claim_credits: 0x03, query_pulse: 0x04 }[action];
  const tsMs = Date.now();
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const payloadBytes = new TextEncoder().encode(payload);  // payload is now a string, not object

  // canonical: action(1) || ts_be_u64(8) || nonce(12) || payload
  const canonical = new Uint8Array(1 + 8 + 12 + payloadBytes.length);
  canonical[0] = actionByte;
  new DataView(canonical.buffer).setBigUint64(1, BigInt(tsMs), false);  // big-endian
  canonical.set(nonce, 9);
  canonical.set(payloadBytes, 21);

  const sig = await XB77Keystore.signCanonical(canonical);
  const pubkeyHex = XB77Keystore.currentPubkey();

  return {
    headers: {
      "Content-Type": "application/json",
      "X-API-Version": "v1",
      "X-Xb77-Pubkey": pubkeyHex,
      "X-Xb77-Timestamp": String(tsMs),
      "X-Xb77-Nonce": toHex(nonce),
      "X-Xb77-Signature": toHex(sig),
    },
    body: payload,  // raw JSON string
  };
}
```

Replace `callAction()` to:
- Compute `{headers, body}` via the new signEnvelope
- For `register_agent`, headers may include `X-Xb77-Pubkey` but no signature — the mock accepts this. Or include all headers (mock ignores sig for register_agent bootstrap).
- `fetch(gateway + path, { method: "POST", headers, body })` with body as **raw JSON string**, not wrapped
- Response: parse `body.data` (no more `gateway_sig` in body — it's in `X-Xb77-Gateway-Signature` header)
- Optionally verify the response signature using `crypto.subtle.verify` and a cached gateway pubkey from `GET /_meta`

**Reference**: `cli/commands/gateway.zig` does this exact pattern — the SDK in `core/sdk/sdk.zig` (`buildSignedRequest` / `verifyResponse`) is the Zig version. The webapp's JS version must produce byte-identical canonical bytes.

### [3] Drop `agent_id` from outgoing payloads + derive locally

Per contract §1.1: server derives `agent_id` from the verified pubkey. Webapp should:

- Stop including `agent_id` in any action payload (it was in older stub versions of submitOrder etc.)
- Compute `agent_id` locally for UI display via `XB77Keystore.currentAgentId()`
- `ConnectionPill` in `app-tabs.jsx` already shows truncated `agent_id`; just point it at `XB77Keystore.currentAgentId()`

### [4] Modal uses real keystore

**File**: `webapp_deploy/assets/src/dapp-keystore-modal.jsx`

Replace `_ksRandHex(32)` with `await XB77Keystore.generate(password)` for the generate path; `await XB77Keystore.import(blob, password)` for import. Result includes the real `pubkeyHex` and `agentId`.

Persist the `sealedBlob` to `localStorage.xb77_keystore` (the keystore module can own that side-effect).

### [5] Smoke webapp with `VERIFY_SIGS=1`

```bash
cd sdk/ts && XB77_VERIFY_SIGS=1 bun run dev/mock-gateway.ts --port 8787 &
cd webapp_deploy && ./build.sh && python3 -m http.server 8080 &
# Open http://127.0.0.1:8080/app.html
# Modal: Generate, password "demo", confirm
# Expected: agent_id is ag_XXXX (real sha256-derived)
# Click "+ NEW" in pipelines → expect 200 OK, not 401
# Mock-gateway logs MUST NOT show "invalid_signature"
```

If `XB77_VERIFY_SIGS=1` rejects the webapp request, the canonical bytes are wrong somewhere. Compare byte-for-byte against `cli/commands/gateway.zig`'s output (use the SDK test fixtures in `core/sdk/sdk.zig` as the source of truth).

### [6] Cross-visibility test script

**File to create**: `scripts/demo_e2e.sh`

```bash
#!/usr/bin/env bash
# 1. Boot mock-gateway with VERIFY_SIGS=1
# 2. Open webapp in default browser (xdg-open / open)
# 3. Drive CLI: register agent A, submit order from A
# 4. Show CLI 'gateway reads recent' includes the order
# 5. Print URL to webapp pipelines view; tester verifies same order shows there
# 6. Webapp: user clicks + NEW AGENT (registers child B)
# 7. CLI 'gateway reads fleet' shows both A and B
# 8. Cleanup
```

The test is **semi-manual**: CLI side asserts via `grep`, webapp side prints
the URL and waits for human nod (`read -p "Verified in browser? [y/N]"`).
For an automated version, use Playwright/Puppeteer.

### [7] Commit + `DEMO.md`

Single commit. `DEMO.md` with:
- 5-min pitch flow (which buttons in which order, what to say)
- Architecture diagram (CLI + webapp + gateway, all wire 1.1)
- Cross-visibility narrative ("same gateway, both clients see each other")
- Failure modes + recovery (gateway down, sig mismatch, etc)

## Reference points for the migration

- **CLI gateway impl** (canonical reference): `cli/commands/gateway.zig`
- **SDK Zig** (canonical bytes algorithm): `core/sdk/sdk.zig`
- **Worker** (verification side): `gateway/worker/src/index.js` line ~67 onwards
- **Mock-gateway** (same algorithm in TS): `sdk/ts/dev/mock-gateway.ts` `canonicalRequest` function
- **Contract** (the spec): `docs/api-contract-v1.md` §1.1

## How to verify "byte-identical"

A simple TS unit test should hash the SDK Zig output and the webapp JS
output of `signEnvelope` for a fixed `(action, ts, nonce, payload)` and
assert equal canonical bytes. Use the SDK test fixture
`{action: submit_order, ts: 1700000000000, nonce: a1b2..., payload:
{"symbol":"SOL/USDC","amount":1000}}` from `core/sdk/sdk.zig` line 181.

## Gotchas

- **DataView setBigUint64** needs `BigInt(tsMs)` — number type doesn't fit
- **Endian**: big-endian per contract. `setBigUint64(offset, value, false)` (false = big-endian; default is little)
- **Headers case**: HTTP headers are case-insensitive on read but **the mock-gateway uses the canonical-case names** (`X-Xb77-Pubkey` not `x-xb77-pubkey`). Browser `fetch` lowercases sent headers automatically — the server reads them case-insensitively so this should be fine. Verify against mock log if 401 occurs
- **Web Crypto Ed25519 browser support**: Chrome 137+, Safari 17+, Firefox 130+. Older Chromium-based browsers (Electron old versions) may fail. **Assume Chrome for the demo** and document
- **localStorage in privacy mode**: keystore persistence may fail; surface a friendly error
- **Mock-gateway response signature**: the mock signs responses with a per-boot Ed25519 keypair. The webapp can `GET /_meta` once to fetch the gateway pubkey if it wants to verify response signatures. **Strictly optional for demo — skip if it adds friction**

## Sponsors (parallel, remote)

Three specs ready at `specs/sponsors/`:

- **`qvac.md`** — Tether QVAC ($10k side track) — needs cloud GPU
- **`magicblock.md`** — MagicBlock PER live — devnet, no GPU
- **`sns.md`** — Bonfida SNS / AllDomains — devnet, no GPU

These execute on a separate agent / environment. Each spec is
self-contained. Branches: `sponsor/qvac`, `sponsor/magicblock`,
`sponsor/sns`. Merge them back into `feat/dapp-public-split` when green.

**Do not attempt sponsor work in this local session** — the user's local
PC needs resources for the demo stack.

## Local server state at session close

Both bg processes from this session were killed (`:8080` http.server,
`:8787` mock-gateway). Confirm with `ss -ltn | grep -E ":(8080|8787)"`.
Untracked `HANDOFF-NEXT-SESSION.local.md` is personal scratch — leave it.

## Frase de arranque

> "Vengo a migrar el webapp a wire 1.1 real. Leé `HANDOFF-NEXT-SESSION.md`
> y el contract `docs/api-contract-v1.md` §1.1. Arrancamos por
> `webapp_deploy/assets/src/lib/keystore.js` — el módulo Web Crypto
> Ed25519 que mencioné en la sección [1]."
