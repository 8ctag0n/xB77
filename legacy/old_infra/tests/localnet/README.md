# Localnet E2E tests

These tests run against a real local validator and use the **generated SDK instructions**.
They assume a fresh localnet (gateway config is initialized once). If you reuse a ledger
with a different gateway config, reset the ledger or start a new validator.

## Run

```bash
# If validator already running
./tests/localnet/run.sh

# If you want the runner to start the validator
START_VALIDATOR=1 ./tests/localnet/run.sh
```

## Requirements

- Programs deployed (core, gateway, registry, receipts, test_utils)
- `.localnet/program_ids.env` populated
- `sdk/target/agent_badge.meta.json` + proof artifacts generated (`make proof-badge`)
- Optional: deploy the real verifier and set `XB77_USE_REAL_VERIFIER=true`
  (reads `.localnet/verifier_program_id.txt`)
- For Light Protocol-backed receipt tests:
  - Light services running (RPC, compression, prover)
  - `LIGHT_RPC_URL`, `LIGHT_COMPRESSION_RPC_URL`, `LIGHT_PROVER_RPC_URL` set

## Coverage

- Registry lifecycle (merchant + catalog)
- Gateway init + submit order
- verify_badge (CPI verifier via test_utils + ShadowWire binding)
- resolve_private_order (verify_badge in same tx)
- execute_confidential_transfer (CPI passthrough)
- record_receipt (CPI passthrough)
- receipts program direct record_receipt (Light)
- Core init + register + credit + request payment (smoke)
- Negative flows: missing verify_badge, empty instruction payloads
- SDK live: agent.pay against localnet + Light receipts (requires Light services)
