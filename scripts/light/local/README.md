# Light local (WIP)

Minimal scaffold for a local Light stack (compression API + prover wrapper).
This is a placeholder to iterate quickly with Bun.

## Goal
- Provide local endpoints compatible with `@lightprotocol/stateless.js`:
  - Compression API (JSON-RPC) on `LIGHT_COMPRESSION_RPC_URL`
  - Prover API (HTTP) on `LIGHT_PROVER_RPC_URL`

## Env
- `LIGHT_RPC_URL` (Solana RPC)
- `LIGHT_COMPRESSION_RPC_URL` (default: http://127.0.0.1:8784)
- `LIGHT_PROVER_RPC_URL` (default: http://127.0.0.1:3001)
- `LIGHT_UPSTREAM_COMPRESSION_URL` (optional proxy target)
- `LIGHT_UPSTREAM_PROVER_URL` (optional proxy target)

## Run
- `bun scripts/light/local/light-server.ts`

## Status
- Light server exposes both compression JSON-RPC (8784) y prover (/prove 3001) con fixtures mínimas. Revísalo y reemplaza proof/account logic si necesitás más realismo.

## Extracted assets from Light repo
- `scripts/light/local/accounts/`: pre-configured state/address tree accounts from `light-protocol/cli/accounts`.
- `scripts/light/local/prover-compose.yml`: docker-compose for the prover service (copied from `light-protocol/prover/server/docker-compose.yml`).
- `scripts/light/local/prover-README.md`: instructions to build/run the prover container.

## Next steps
1. Use `scripts/light/local/accounts` as the genesis accounts when launching a light validator (can drop into `solana-test-validator --account-dir`).
2. Start `bun scripts/light/local/light-server.ts` and point los envs a `http://127.0.0.1:8784`/`:3001`.
3. (Opcional) usa `scripts/light/local/accounts/` para inicializar el validator con `--account-dir`.
