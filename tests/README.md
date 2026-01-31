# Tests

This project uses a hybrid test layout:
- Existing tests stay where they are (so toolchains keep working).
- New localnet/E2E tests live under `tests/localnet/`.
- This folder provides **centralized runners** and a single entry point.

## Quick start

```bash
# SDK unit tests (Bun)
./tests/sdk/run.sh

# Program tests (Rust / Mollusk)
./tests/programs/run.sh

# Localnet E2E (validator + JS scripts)
./tests/localnet/run.sh

# Run everything
./tests/run_all.sh
```

## Layers

- **SDK unit tests**: `sdk/tests/*.test.ts` (run via `bun test` in `sdk/`).
- **Program tests**: `onchain/programs/*/tests/*.rs` (run via `cargo test`).
- **Localnet E2E**: `tests/localnet/` (JS tests that hit a real local validator).

## Localnet notes

- `tests/localnet/run.sh` can optionally start the validator for you.
- If you already have a validator running, set `START_VALIDATOR=0` (default).
- Make sure `.localnet/program_ids.env` is populated if required by scripts.
- For full coverage, deploy all programs (including `xb77_test_utils`) with `scripts/localnet/deploy-all.sh`.
