# xB77 — Sovereign Commerce Demo

**Tagline.** Two clients (a CLI and a browser dApp) speak the exact same
protocol stack against one local Solana validator. State is shared
end-to-end, and writes leave a real onchain footprint: agents pay their
own fees, programs verify state transitions in Poseidon, and the gateway
never holds a key on behalf of anyone.

Two layers, both real:
1. **Wire 1.1** — header-bound Ed25519 over canonical bytes, off-chain
   coordination layer (worker for rate limiting, aggregation, dashboards).
2. **Onchain** — the agent's keystore IS its Solana wallet. The webapp
   builds wincode-serialized instruction data via IDL, signs the legacy
   Solana tx with the same Ed25519 keystore, and submits direct to the
   validator. No mock-gateway. No worker mediating writes. No relayer
   custody.

## 5-minute pitch flow (no-mocks variant)

Boot first: `scripts/full_local_stack.sh --keep-up` — gives you validator
(podman container) + 4 programs deployed + CF Worker (wrangler dev) +
webapp served.

| # | What you do | What you say |
|---|---|---|
| 1 | `podman ps` shows `xb77-validator` running on :8899 | "Real Solana validator. Local podman container. 4 programs deployed onchain." |
| 2 | Open `http://127.0.0.1:8080/app.html` in Chrome, click **Connect → Generate new** | "Web Crypto Ed25519. PKCS8 sealed with AES-GCM. Private key never leaves the browser. Same keypair is the agent's Solana wallet — sovereign." |
| 3 | Wait for "agent registered" — console shows self-airdrop sig | "Agent automatically funded with 1 SOL on the validator so it can pay its own onchain fees. No relayer." |
| 4 | Click **ANCHOR ⛓** in Pipelines header | "Webapp builds the wincode payload, encodes the instruction via IDL, builds a Solana legacy tx, signs with the keystore, sends direct to the validator. No worker mediation. Browser → chain in one hop." |
| 5 | `solana logs` shows `Compression: Transition Verified via Poseidon BN254` | "Program ran Poseidon BN254 onchain. Compute units consumed. Fee debited from the agent's wallet. Verifiable in any block explorer." |
| 6 | Show `getTransaction <sig>` from the webapp's console | "Same agent_id from the wire-1.1 layer. Same key. Two surfaces: off-chain coordination (worker) and on-chain settlement (program). One identity." |

## Architecture

```
            ┌──────────────┐               ┌──────────────────┐
            │ CLI (xb77)   │               │ Webapp dApp      │
            │ Zig binary   │               │ Vanilla JS       │
            │  - keystore  │               │  XB77Keystore    │
            │  - wire 1.1  │               │  XB77Actions     │
            │  - tx Zig    │               │  IdlClient       │
            └──────┬───┬───┘               │  SolanaTx + RPC  │
                   │   │                   └───┬──────┬───────┘
       wire 1.1 ──►│   │                       │      │
                   ▼   │                       ▼      │ onchain
        ┌──────────────┴──┐                          │  (direct)
        │ wrangler dev    │                          │
        │ (CF Worker)     │   wire 1.1 ──────────────┘
        │  - verify sigs  │                          │
        │  - aggregate    │                          │
        └────────┬────────┘                          ▼
                 │  reads (getTransaction, etc.)
                 ▼                          ┌──────────────┐
       ┌──────────────────┐   sendTransaction │  validator  │
       │  xb77-validator  │◄──────────────────│  (podman)   │
       │  (podman)        │                   │  :8899      │
       │  - programs:     │                   └──────────────┘
       │    core          │
       │    compression   │
       │    zk_verifier   │
       │    gateway       │
       └──────────────────┘

Wire-1.1 canonical bytes (off-chain, shared by webapp + CLI):
  action(1) || ts_be_u64_ms(8) || nonce(12) || payload_bytes

Onchain encoding (wincode, mirrors the program's wincode::deserialize):
  enum disc u32 LE || struct fields in declaration order
  Vec<T> = u64 LE len || items
  [u8;N] = N bytes inline
```

## Cross-visibility narrative

The point of the demo is that the two clients are **interchangeable
peers**, not "frontend and backend." The CLI is not a privileged
operator; the webapp is not a thin view. Both speak the same protocol,
both hold their own keystore, both register/sign/submit the same way.
The gateway just verifies and shares state.

This is why the demo flips direction mid-flow: CLI writes → webapp reads,
then webapp writes → CLI reads. Symmetric. No bridge code, no
out-of-band trust.

## Failure modes + recovery

| Symptom | Likely cause | Fix |
|---|---|---|
| Webapp modal: `invalid_password` on import | Wrong password for the sealed blob | Generate a new agent instead |
| Webapp: `wire 1.1 mismatch` / 401 from gateway | Canonical bytes diverged (timestamp endian, nonce length, payload encoding) | Compare against `sdk/ts/dev/mock-gateway.ts` `canonicalRequest`; unit test `webapp_deploy/test/dapp-actions.test.js` covers this |
| Demo script hangs at "Do you see agent A's order?" | Webapp pipelines poll is 10s; you clicked too fast | Wait, refresh, look at the Pipelines tab |
| `xb77 gateway reads fleet` returns only the seeded agents | Webapp registration failed silently — check browser devtools console | Re-run the modal "Generate new" path; check `localStorage.xb77_keystore` was written |
| Gateway log shows `invalid_signature` | One of the clients drifted from wire 1.1 | Run `bun test webapp_deploy/test/` — `signEnvelope returns headers + raw-JSON body and a verifiable Ed25519 signature` is the canonical-bytes regression test |
| Demo script: `mock-gateway did not come up` | Port 8787 in use | `XB77_GATEWAY_PORT=8788 scripts/demo_e2e.sh` |
| Webapp blank in Firefox <130 / Safari <17 | Web Crypto Ed25519 not supported | Use Chrome 137+; document this as a known constraint |

## Browser support

Web Crypto Ed25519 requires:
- Chrome 137+
- Safari 17+
- Firefox 130+

Older Chromium-based browsers (some Electron versions) will fail at
`crypto.subtle.generateKey({name:"Ed25519"}, ...)`. The demo assumes
Chrome and surfaces a console warning if `crypto.subtle` is missing.

## Running the demo

```bash
# No-mocks variant — real validator + real worker + real webapp.
# Boots everything via podman, runs an onchain smoke at the end.
scripts/full_local_stack.sh --keep-up

# Mock-gateway variant (lighter, no container, no programs deployed)
scripts/demo_e2e.sh                # walks you through bidirectional CLI ↔ webapp

# Manual no-mocks mode:
podman run -d --name xb77-validator --network host xb77-solana
# (deploy programs once — see scripts/full_local_stack.sh phase 3)
cd gateway/worker && bunx wrangler@latest dev --local --port 8787 &
cd webapp_deploy && ./build.sh && python3 -m http.server 8080 &
zig build
# Then:
#  - Webapp: open http://127.0.0.1:8080/app.html → Connect → Generate
#  - Click ANCHOR ⛓  →  tx onchain, signature shown in pipelines header
```

## What's NOT in the demo (out of scope)

- Real devnet/mainnet — everything is local (podman validator). The
  worker's `ZNODE_RPC_URL` is configurable; switching to devnet is a
  config change but the programs need redeploy.
- CLI parity with webapp's IDL-driven onchain — in progress (`feat/zig-onchain-parity`
  if dispatched, see HANDOFF for status). The webapp does it; CLI today
  only does the wire-1.1 leg via `xb77 gateway *`.
- Sponsor integrations (QVAC / MagicBlock / SNS) — see `specs/sponsors/`,
  executed remotely.
- Response signature verification on the webapp side (worker signs
  responses; webapp could `GET /_meta` and verify — strictly optional,
  skipped for demo simplicity).
- Multi-device keystore sync — the sealed blob lives in
  `localStorage.xb77_keystore` on one browser; export/import via the
  modal's import path.
