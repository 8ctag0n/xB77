# Helius RPC Setup (Infra)

This repo expects a reliable RPC endpoint for devnet demos. Use Helius if available.

## Environment Variables

- `XB77_RPC_URL`: Full RPC URL to use (overrides everything).
- `XB77_HELIUS_API_KEY`: Helius API key for devnet/mainnet RPC.
- `XB77_HELIUS_NETWORK`: `devnet` (default) or `mainnet`.
- `XB77_CU_LIMIT`: Optional compute unit limit for smoke tests.
- `XB77_CU_PRICE`: Optional compute unit price (micro-lamports) for priority fees.

Example (devnet):

```
export XB77_HELIUS_API_KEY="YOUR_KEY"
export XB77_HELIUS_NETWORK="devnet"
```

## Smoke Test Script

Use the SDK script to send a minimal transfer through Helius:

```
bun run sdk/scripts/helius_rpc_smoke.ts --airdrop-sol 1 --lamports 1
```

Options:
- `--rpc`: Explicit RPC URL.
- `--keypair`: Path to a Solana keypair JSON file.
- `--keypair-json`: Inline JSON array for the keypair.
- `--to`: Recipient address (defaults to self).
- `--lamports`: Transfer amount.
- `--cu-limit`: Compute unit limit.
- `--cu-price`: Compute unit price (micro-lamports).
- `--airdrop-sol`: Request a devnet airdrop first.

If you use the MCP server, keep `XB77_KEYPAIR_PATH` or `XB77_KEYPAIR_JSON` set so
the same keypair works across flows.
