## xb77_gateway

Gateway program responsibilities:
- Verify the Noir proof (agent authorization).
- If valid, execute a confidential transfer via Arcium C-SPL.
- Record an encrypted receipt via Light Protocol.

Planned instruction flow:
1) `verify_badge`: verify proof + inputs (agent, root, index).
2) `submit_private_order`: submit order payload for private execution.
3) `execute_confidential_transfer`: CPI into C-SPL to move funds.
4) `record_receipt`: write compressed receipt via Light SDK/CPI.

Account sketch (to refine):
- `payer`: funds tx fees.
- `gateway_state`: PDA with config (roots, authorities).
- `vault`: C-SPL account.
- `recipient`: destination (C-SPL or wrapper).
- `audit_pda`: Light compressed receipt.

Serialization: `wincode` (bincode-compatible) for instruction/state layouts.

Current account order (minimal):
- `init_gateway`: `[payer signer, gateway_state (PDA), system_program]`
- `update_gateway`: `[admin signer, gateway_state]`
- `verify_badge`: `[payer signer, gateway_state, zk_verifier_program]`
- `submit_private_order`: `[payer signer, gateway_state, nullifier_pda, system_program]`

Tests (Mollusk):
1) `cargo build-sbf --manifest-path contracts/programs/xb77_gateway/Cargo.toml` to produce `contracts/target/deploy/xb77_gateway.so`.
2) `cargo test --manifest-path contracts/programs/xb77_gateway/Cargo.toml --test gateway` to run the Mollusk suite.

Notes:
- Nullifier anti-replay is tracked via a PDA per nullifier; exploring Light compressed state for storage optimization.
- End-to-end demo scripts should be run separately (verify then submit), not chained in one command.
