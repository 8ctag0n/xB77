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
- `resolve_private_order`: `[payer signer, gateway_state, instructions_sysvar, receipt_program, ...receipt_remaining_accounts]`

Receipt CPI account order (for `resolve_private_order` when `receipt_instruction_data` is set):
1) `payer` (signer, writable as provided)
2) `gateway_state` (writable)
3) `instructions_sysvar`
4) `receipt_program`
5) `receipt_remaining_accounts` in the exact order produced by:
   - `PackedAccounts.newWithSystemAccounts(SystemAccountMetaConfig.new(receipt_program_id))`
   - then `insertOrGet(address_tree)`, `insertOrGet(address_queue)`, `insertOrGet(output_state_tree)`

The `PackedAccounts` system accounts order is:
1) Light System Program
2) Light CPI signer (PDA for `receipt_program_id`)
3) Light registered program PDA
4) Light noop program
5) Light account compression authority
6) Light account compression program
7) `receipt_program_id`
8) System Program
9) (optional) CPI context

CLI note: `xb77_gateway_cli resolve` accepts `--receipt-accounts` as a JSON array of
`{ pubkey, is_signer, is_writable }` matching the order above.

Tests (Mollusk):
1) `cargo build-sbf --manifest-path contracts/programs/xb77_gateway/Cargo.toml` to produce `contracts/target/deploy/xb77_gateway.so`.
2) `cargo test --manifest-path contracts/programs/xb77_gateway/Cargo.toml --test gateway` to run the Mollusk suite.

Notes:
- Nullifier anti-replay is tracked via a PDA per nullifier; exploring Light compressed state for storage optimization.
- End-to-end demo scripts should be run separately (verify then submit), not chained in one command.
