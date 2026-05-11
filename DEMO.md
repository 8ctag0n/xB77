# xB77 — Bidirectional Demo

**Tagline.** Two clients (a CLI and a browser dApp) speak the exact same
wire schema 1.1 against one gateway. State is shared end-to-end: an order
submitted from the CLI shows up in the webapp's pipelines view, and an
agent registered from the webapp appears in the CLI's fleet listing.

The crypto is real on both sides — Ed25519 signatures over canonical
bytes, verified by the gateway with `XB77_VERIFY_SIGS=1`.

## 5-minute pitch flow

| # | What you do | What you say |
|---|---|---|
| 1 | `scripts/demo_e2e.sh` boots gateway + webapp + builds CLI | "One gateway. Two clients. Same wire schema." |
| 2 | CLI registers `agent_a`, submits a buy order | "CLI is signing every request — real Ed25519." |
| 3 | Open `http://127.0.0.1:8080/app.html` → Pipelines tab | "Webapp polls the same gateway. There's the CLI's order." |
| 4 | In the webapp click **Connect → Generate new** | "Web Crypto Ed25519. PKCS8 sealed with AES-GCM at rest. Private key never leaves the browser." |
| 5 | Run `xb77 gateway reads fleet` from the CLI | "And the CLI sees the webapp's new agent. Bidirectional." |
| 6 | Show the gateway log: zero `invalid_signature` lines | "Every byte verified. Single contract. No envelopes, no agent-id-in-payload, no stubs." |

## Architecture

```
            ┌──────────────┐
            │ CLI (xb77)   │  Zig binary, real Ed25519, wire 1.1
            │ profile-keyed│
            └──────┬───────┘
                   │  POST /api/v1/actions/*
                   │  X-Xb77-{Pubkey,Timestamp,Nonce,Signature}
                   │  body = raw payload JSON (no envelope)
                   ▼
        ┌──────────────────────┐
        │ mock-gateway (Bun)   │  VERIFY_SIGS=1
        │ in-memory shared state│  derives agent_id from pubkey
        └──────────┬───────────┘
                   ▲
                   │  GET /api/v1/pipelines/recent (10s poll)
                   │  POST same headers, same canonical bytes
                   │
            ┌──────┴───────┐
            │ Webapp dApp  │  Vanilla JS + Web Crypto Ed25519
            │  XB77Keystore│  PBKDF2 + AES-GCM sealed blob in localStorage
            │  XB77Actions │  wire 1.1 canonical bytes
            └──────────────┘

Canonical bytes (both clients produce identical output):
  action(1) || ts_be_u64_ms(8) || nonce(12) || payload_bytes
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
# One-shot (boots gateway + webapp + CLI, walks you through the flow)
scripts/demo_e2e.sh

# Manual mode (if you want to drive it yourself)
cd sdk/ts && XB77_VERIFY_SIGS=1 bun run dev/mock-gateway.ts --port 8787 &
cd webapp_deploy && ./build.sh && python3 -m http.server 8080 &
zig build
# Then:
#  - CLI: ./zig-out/bin/xb77 gateway register --intent merchant && \
#         ./zig-out/bin/xb77 gateway order --side buy --amount 100 --price 10000
#  - Webapp: open http://127.0.0.1:8080/app.html → Connect → Generate
```

## What's NOT in the demo (out of scope)

- Real Solana onchain settlement (the mock gateway is in-memory only;
  the real CF Worker gateway speaks the same wire and is merged but
  not wired into this demo)
- Sponsor integrations (QVAC / MagicBlock / SNS) — see `specs/sponsors/`
- Response signature verification on the webapp side (mock signs
  responses; webapp could `GET /_meta` to fetch the gateway pubkey
  and verify — strictly optional, skipped for demo simplicity)
- Multi-device keystore sync — the sealed blob lives in
  `localStorage.xb77_keystore` on one browser; export/import via the
  modal's import path
