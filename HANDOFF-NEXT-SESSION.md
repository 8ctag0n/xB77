# 🔁 HANDOFF — Migrate webapp to wire schema 1.1

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/docs-v2`
> **Branch**: `feat/dapp-public-split` (post-merge `feat/gateway-realdata` 2026-05-11)
> **Estimated effort**: 2–3h focused
> **Contract**: `docs/api-contract-v1.md` (wire schema 1.1)

## What happened (TL;DR)

Two parallel worktrees merged:

- **Frontend** (this side) shipped checklist §8 end-to-end with stub crypto: keystore modal, action layer, all DataSource swaps, rate-limit strip + 429 toast, wallet polling real balances/transactions.
- **Gateway** (`feat/gateway-realdata`) shipped a real Cloudflare Worker (`gateway/worker/src/index.js`, 865 lines), 22 worker tests, and the SDK propagated to wire 1.1 in Zig/TS/Rust (67 tests green).

**The wire protocol changed underneath us**. The contract bumped from JSON envelope → header-bound signatures. The webapp stub still produces the old envelope, so action POSTs will fail against the real gateway and against the post-merge mock when `XB77_VERIFY_SIGS=1`.

## What still works as-is

- **GET reads** (`/api/v1/network/pulse`, `/agents/fleet`, `/pipelines/recent`, `/wallet/balances`, `/wallet/transactions`) — unsigned, shape unchanged.
- **DataSource layer** (live → cached → snapshot) with normalizers, polling, captured `X-RateLimit-*` headers.
- **Debug strip** (`?debug=1`), **429 toast** (window event `xb77:rate-limited`).
- **Modal UI**, **connection pill**, all UI components.
- **`mock-gateway.ts`** (post-merge): default `VERIFY_SIGS=false`, so the stub signer can still hit it. Real Ed25519 verification enables with `XB77_VERIFY_SIGS=1`.

## What needs migration (concrete checklist)

All in `webapp_deploy/assets/src/lib/dapp-actions.js`:

### 1. Replace `signEnvelope()` with wire-1.1 signing

Current: returns `{agent_id, ts, nonce, action, payload, signature: "ed25519:stub..."}` as the JSON body.

Needs to:
- Produce binary canonical bytes: `action_byte(1) ‖ ts_be_u64_ms(8) ‖ nonce(12) ‖ payload_json_bytes`
- Real Ed25519 sign with the keystore's private key
- Return `{headers, body}` where `headers` is `{X-Xb77-Pubkey, X-Xb77-Timestamp, X-Xb77-Nonce, X-Xb77-Signature}` (all hex) and `body` is the raw payload JSON string

Action bytes: `0x01` submit_order · `0x02` register_agent · `0x03` claim_credits · `0x04` query_pulse.

### 2. Rewrite `callAction(action, payload)`

Current: POST JSON `{envelope...}`. Needs to:
- Compute headers + raw body via the new `signEnvelope`
- `fetch(gateway + path, { method: "POST", headers, body })` — `body` is raw `payload_json`, **not** wrapped
- Parse response per contract §1.2: body is `{ok: true, data}` (no `gateway_sig` in body — it's in header `X-Xb77-Gateway-Signature` over canonical of action+ts+body_bytes)
- On `ok: false`: throw with `error.code`/`error.message`

### 3. Drop `agent_id` from outgoing payloads

Per contract §1.1: server derives `agent_id = "ag_" + hex(sha256(pubkey)[:9])` from the verified pubkey. The webapp must stop sending it in payloads. The local `agentId` in keystore is computed the same way for UI display (sha256 the 32B pubkey, slice 9 bytes, hex-encode).

### 4. Real keystore (Web Crypto API)

Current: pubkey is random hex, seal/unseal are base64 placeholders.

Needs:
- `crypto.subtle.generateKey("Ed25519", true, ["sign", "verify"])` on Generate
- Export pubkey to raw → 32B → hex (this is what server sees as `X-Xb77-Pubkey`)
- Export private to PKCS#8 → encrypt with password-derived key (PBKDF2 + AES-GCM) → base64 → store as `xb77_keystore`
- Import path: decrypt blob with password, re-import the keypair into Web Crypto

The two patterns to copy: see `gateway/worker/src/index.js` for verification-side canonical bytes; see `sdk/ts/src/index.ts` for the client-side signing example with `crypto.subtle.sign`.

## How to run

```bash
# Webapp + serve
cd webapp_deploy && ./build.sh && python3 -m http.server 8080 &

# Mock gateway (default: signature verification OFF for incremental migration)
cd sdk/ts && bun run dev/mock-gateway.ts --port 8787 &

# Once webapp produces real signatures, flip on enforcement:
XB77_VERIFY_SIGS=1 bun run dev/mock-gateway.ts --port 8787
```

When the real gateway worker is reachable, swap `window.XB77_GATEWAY` in `app.html` to the worker URL and the same client should work without changes.

## Suggested migration order

1. Real keystore (Web Crypto Ed25519 keypair). Verify with `console.log` that pubkey is 64-char hex.
2. Real `signEnvelope` returning `{headers, body}`. Unit-test against a fixture from `sdk/ts/src/index.ts`.
3. Rewrite `callAction` to send headers + raw body. Smoke each action against the post-merge mock with `XB77_VERIFY_SIGS=0` first.
4. Flip `XB77_VERIFY_SIGS=1`. Fix anything that didn't sign correctly.
5. Validate `agent_id` shows the new sha256-derived form (18 hex chars from 9 bytes).
6. End-to-end click-through: modal generate → register_agent → claim_credits → submit_order → fleet shows the new child.

## Open deltas (low priority, post-migration)

- **Allocations** panel in Wallet still placeholder (contract doesn't expose per-child agent breakdown). Derive from `/api/v1/agents/fleet` filtering by parent agent when contract gains a parent_id field.
- **Pipelines/Agents list seeds** still decorate `volume/privacy/pnl/governance/risk` — contract doesn't expose these. Either extend contract or accept they're UI flavor only.
- **`scripts/e2e_local.sh`** points at `dev/mock-gateway-legacy.ts` (the pre-v1 fixture for the SDK e2e). When the SDK migrates its e2e to wire 1.1 against the real mock, delete the legacy file.

## Risk register

- **Pubkey leak via console** — Web Crypto keypair lives in component state. Don't `console.log` the private key. Default to non-extractable for the private side; only extract when sealing.
- **Storage XSS** — sealed blob in localStorage protects against passive disclosure but not against XSS that runs in the page. Out of scope for hackathon; document it.
- **Clock skew** — gateway rejects `|now - ts| > 30s`. If the user's clock is wildly off, every action fails with `clock_skew`. Surface the error code in the toast.

## Frase de arranque

> "Vengo a migrar la webapp al wire schema 1.1. Leé `HANDOFF-NEXT-SESSION.md` y el contract `docs/api-contract-v1.md` §1.1. Arrancamos por el keystore real con Web Crypto Ed25519."
