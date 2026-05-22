# Quickstart — xB77 end-to-end local

Run the full signed-action lifecycle in under 60 seconds. No Cloudflare,
no Solana, no Fly. For prod deploy see `DEPLOY.md`.

## Prerequisites

- `zig` (master), `bun` (>=1.3), `curl`, `jq` (optional)
- Linux/macOS shell

## Single-command smoke

```bash
scripts/e2e_cli_gateway.sh
```

That script:

1. Runs `zig build` (produces `zig-out/bin/xb77`)
2. Boots the mock gateway on `:8787` with `XB77_VERIFY_SIGS=1` (real Ed25519 verification)
3. Spawns a fresh profile, initializes the keystore
4. Runs `register_agent` → `submit_order` → `claim_credits` → `query_pulse` (all signed)
5. Runs the 4 read endpoints (`pulse`, `fleet`, `recent`, `wallet`)
6. Asserts each response signature verifies
7. Asserts the gateway log shows zero signature rejections
8. Cleans up the mock + tempdir

Exits 0 on full success.

## Manual exploration

After `zig build`, drive the CLI directly:

```bash
# Boot gateway
cd sdk/ts
XB77_VERIFY_SIGS=1 bun run dev/mock-gateway.ts --port 8787 &

# Init agent
cd /tmp && mkdir -p agent && cd agent
XB77_PASSWORD=hi xb77 spawn demo
XB77_PASSWORD=hi xb77 -p demo init

# Talk to gateway
export XB77_GATEWAY=http://127.0.0.1:8787
export XB77_PASSWORD=hi
xb77 -p demo gateway meta
xb77 -p demo gateway register --intent merchant
xb77 -p demo gateway order --side buy --amount 1000 --price 10000
xb77 -p demo gateway claim --proof_tx demo
xb77 -p demo gateway pulse
xb77 -p demo gateway reads fleet
```

## Pointing at a real gateway

```bash
export XB77_GATEWAY=https://gateway.xb77.io
export XB77_GATEWAY_PUBKEY=<64-hex-chars>  # or omit to fetch from /_meta
```

Same commands work. Only constraint: the gateway must speak contract
v1 / wire schema 1.1 (`docs/api-contract-v1.md`).

## Knobs

| Env | Default | Purpose |
|---|---|---|
| `XB77_GATEWAY` | `http://127.0.0.1:8787` | Base URL the CLI POSTs to |
| `XB77_GATEWAY_PUBKEY` | (auto from `/_meta`) | Pin for response signature verify |
| `XB77_PASSWORD` | (prompt) | Unlock the keystore non-interactively |
| `XB77_VERIFY_SIGS` (mock only) | `0` | Set `1` to enforce Ed25519 verify on the mock |

## Forcing a 429 to test client backoff

```bash
curl -i "http://127.0.0.1:8787/api/v1/network/pulse?force429=1"
# returns 429 with Retry-After: 5
```
