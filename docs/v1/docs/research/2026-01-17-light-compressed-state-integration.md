---
pageClass: is-legacy-page
---
# Light zkCompression Integration for xb77_gateway (Local Sources)

## Executive summary
This report summarizes how to integrate Light Protocol's zkCompression compressed state into the `xb77_gateway` flow based on local sources `light_basics.txt` and `light_example.txt`. The core requirement is to use Light's Rust SDK (`light-sdk`) to create or update compressed accounts via CPI to the Light System Program using client-provided validity proofs and compressed account metadata. The recommended integration is: keep the gateway as the main program, add a Light-compressed receipt state update in `ResolvePrivateOrder`, and only introduce a separate escrow program if you need independent ownership, settlement logic, or third-party composition that must be isolated from the gateway program.

## Key findings

### 1) Light compressed state is updated via CPI with client-supplied proofs and metas
- Compressed accounts are stored off-chain; only hashes and Merkle tree updates are on-chain.
- Updates follow a UTXO-style flow: consume old hash, produce new hash; no in-place overwrite.
- Programs create/update compressed state via CPI to the Light System Program, providing:
  - `ValidityProof` (client fetched)
  - `CompressedAccountMeta` (tree + index + address metadata)
  - Light System Program + Account Compression Program + state tree accounts (passed in remaining accounts)

Evidence: `light_basics.txt` (sections “On-Chain Program Development” and “Update a Compressed Account”), `light_example.txt` (native Rust example: `LightSystemProgramCpi::new_cpi(...).with_light_account(...).invoke(...)`).

### 2) Light SDK primitives used in Rust programs
- `LightAccount::<T>::new_init(...)` for create, `LightAccount::<T>::new_mut(...)` for update.
- `LightDiscriminator` required for compressed account structs; serialization is Borsh.
- `CpiAccounts::new(...)` groups signer + remaining accounts for the Light CPI.

Evidence: `light_example.txt` (native Rust snippet). `light_basics.txt` (dependencies and account struct requirements).

### 3) Required program IDs and accounts are runtime data, not hardcoded
- The Light System Program and Account Compression Program IDs must be available to the program.
- The gateway should store Light program IDs in `GatewayConfig` (already added) and validate them.

Evidence: `light_basics.txt` (table listing Light System Program and Account Compression Program involvement) and `light_example.txt` (Light CPI uses remaining accounts including trees).

### 4) “Escrow-style” program is optional; it depends on ownership and composition needs
- If the gateway owns the compressed state, an extra escrow program is not required.
- A separate escrow program makes sense when:
  - multiple independent actors need to compose around the same compressed state,
  - you want a distinct authority or upgrade policy,
  - you want to decouple settlement from gateway logic.

Evidence: Derived from Light’s model (compressed state is program-specific via `LightDiscriminator` and program ID usage) in `light_example.txt` and typical Solana composition patterns.

## Proposed integration (mapped to xb77_gateway)

### A) Define compressed receipt state
Define a compressed struct for a receipt commitment and minimal metadata. Only use hashes/commitments to preserve privacy.

- Example (conceptual):
  - `owner: Pubkey` (gateway or auditor)
  - `order_commitment: [u8; 32]`
  - `receipt_hash: [u8; 32]`
  - `orderbook_root: [u8; 32]`

This should be a compressed account with `LightDiscriminator` and Borsh serialization. Use `order_commitment` and `receipt_hash` so no sensitive plaintext is emitted.

### B) Update `ResolvePrivateOrder` to CPI into Light
Current code already computes `receipt_hash = keccak(domain || order_commitment || receipt_leaf_hash)` and updates `orderbook_root`. To integrate Light:

- Accept `ValidityProof` + `CompressedAccountMeta` and `PackedAddressTreeInfo` (for create) or just `CompressedAccountMeta` (for update) in the instruction payload.
- Build a `LightAccount` wrapper and call `LightSystemProgramCpi::new_cpi(...)`.
- Use `CpiAccounts::new(signer, remaining_accounts, light_cpi_signer)`.

Account order expectations (high-level):
1. signer (payer)
2. gateway state
3. instructions sysvar
4. Light System Program
5. Account Compression Program
6. State tree account(s)
7. Address tree account(s)
8. (optional) Light noop program if used for logging

The exact ordering depends on Light’s SDK API; the key is to pass the required accounts in `remaining_accounts` per the Light SDK.

### C) Use client-side SDK to fetch proofs and metas
Client (or off-chain agent) needs to provide:
- `ValidityProof`
- `CompressedAccountMeta`
- Address tree info if creating new compressed accounts

Evidence: `light_basics.txt` and `light_example.txt` mention these are fetched client-side (`getValidityProof()` and account metas).

## Open questions / uncertainties
- Which exact Light program IDs and account ordering are required for the current SDK version in use (e.g., `light-sdk = 0.16.0`)? The local docs describe the concept, but not the concrete account list per instruction for a production setup.
- Should receipts be a single compressed account per order or a tree of receipts per market? This impacts address derivation and index usage.
- Whether to store `orderbook_root` in the compressed account or keep it in `GatewayConfig` and only anchor it with compressed receipts.

## Method and iterations
- No external web searches due to gemini quota exhaustion.
- Sources used are local files:
  - `light_basics.txt`
  - `light_example.txt`

## Source list
- `light_basics.txt`
- `light_example.txt`

