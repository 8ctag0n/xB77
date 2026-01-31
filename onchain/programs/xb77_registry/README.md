# xb77_registry (Merchant Registry)

Lightweight on-chain registry for merchants and catalogs. No Anchor.

## Accounts

**MerchantAccount**
- `merchant_id` (Vec<u8>, max 64)
- `owner` (Pubkey)
- `catalog_count` (u32)
- `created_at`, `updated_at` (u64)
- `bump` (u8)

**CatalogAccount**
- `merchant_id` (Vec<u8>)
- `catalog_id` (u64)
- `category` (u8)
- `catalog_url` (Vec<u8>, max 256)
- `metadata_hash` (Option<[u8;32]>)
- `active` (bool)
- `updated_at` (u64)
- `bump` (u8)

## PDA Seeds

- Merchant: `["merchant", merchant_id]`
- Catalog: `["catalog", merchant_id, catalog_id]`

## Instructions

1) `InitMerchant(merchant_id)`
2) `AddCatalog(merchant_id, catalog_id, category, catalog_url, metadata_hash?)`
3) `UpdateCatalog(merchant_id, catalog_id, category?, catalog_url?, metadata_hash?, active?)`
4) `DeactivateCatalog(merchant_id, catalog_id)`

## Notes

- Registry reads are done via RPC/Helius in a different branch.
- Catalog URLs should point to signed JSON payloads.
