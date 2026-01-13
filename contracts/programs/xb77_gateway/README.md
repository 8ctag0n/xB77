## xb77_gateway

Gateway program responsibilities:
- Verify the Noir proof (agent authorization).
- If valid, execute a confidential transfer via Arcium C-SPL.
- Record an encrypted receipt via Light Protocol.

Planned instruction flow:
1) `verify_badge`: verify proof + inputs (agent, root, index).
2) `execute_confidential_transfer`: CPI into C-SPL to move funds.
3) `record_receipt`: write compressed receipt via Light SDK/CPI.

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
- `verify_badge`: `[payer signer, gateway_state]`

Tests (Mollusk):
1) `cargo build-sbf` from `contracts/` to produce `target/deploy/xb77_gateway.so`.
2) `cargo test -p xb77_gateway` to run the Mollusk suite.
