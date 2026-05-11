# xB77 Devnet Deluxe Demo

End-to-end demo running real Solana devnet transactions, orchestrating three podman
containers (agent, solana CLI, zk toolchain).

## Prerequisites

1. **podman** installed.
2. **Zig** toolchain (binaries built: `zig build`).
3. **Container images** (build once):
   ```bash
   podman build -f infra/Containerfile.solana_slim -t xb77-solana .
   podman build -f infra/Containerfile.agent       -t xb77-agent  .
   podman build -f infra/Containerfile.zk          -t xb77-zk     .
   ```
4. **Payer wallet** with at least 6 SOL on devnet:
   ```bash
   podman run --rm -v /tmp:/tmp:Z xb77-solana \
     solana-keygen new --no-bip39-passphrase --outfile /tmp/xb77_payer.json --force
   PUBKEY=$(podman run --rm -v /tmp:/tmp:Z xb77-solana \
     solana-keygen pubkey /tmp/xb77_payer.json)
   for i in 1 2 3; do
     podman run --rm xb77-solana solana airdrop 2 "$PUBKEY" --url devnet
   done
   ```
5. **On-chain programs** built (`.so` files):
   ```bash
   for p in xb77_core xb77_gateway xb77_compression xb77_registry xb77_zk_verifier; do
     (cd onchain/programs/$p && cargo build-sbf)
   done
   ```

## Run

Autopilot (no input required):

```bash
./scripts/demo_deluxe.sh
```

Interactive (pause between each step — good for live presentation):

```bash
./scripts/demo_deluxe.sh --runner
```

Per-step keys: `r` run · `s` skip · `a` auto from here · `c` show command · `q` quit.

Other flags:

- `--cluster devnet` (default — competition requires devnet)
- `--payer /path/to/keypair.json` (default `/tmp/xb77_payer.json`)
- `--dry-run` (print commands without executing — useful to preview the plan)

## What it does

| Step | Action |
|---:|---|
| 0 | Balance check + idempotent program deploy (5 programs) |
| 1 | xb77 agent daemon up (background container) |
| 2 | AWP order matching via znode-e2e |
| 3 | Sovereign state anchor on devnet (tx sig printed) |
| 4 | Generate ZK proof (nargo + bb in xb77-zk container) |
| 5 | Chunked proof upload + verifier verdict GREEN on devnet (tx sig printed) |
| 6 | Tail `solana logs` of verifier program for 10 seconds |
| 7 | In-process health check (`zig build test --summary all`) |

Every onchain action prints an `explorer.solana.com` URL so the judge can verify.

## Troubleshooting

- **`Insufficient balance`**: airdrop manually (the script never touches the faucet automatically).
- **`Missing podman image`**: build it with the command shown in the error message.
- **`agent socket did not appear within 10s`**: `podman logs xb77-agent-demo` to inspect.
- **Devnet 429 / outage**: retry; the script is idempotent (programs already deployed are skipped).
- **`Missing artifact for <program>`**: the `.so` was not built. Run the build loop in the Prerequisites section.
