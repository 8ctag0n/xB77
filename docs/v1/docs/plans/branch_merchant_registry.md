---
pageClass: is-legacy-page
---
# Branch Plan: Merchant Registry (On-chain Catalogs)

## Objective
Enable on-chain merchant discovery via a lightweight registry and catalog accounts, so agents and the hub can list all merchants and filter catalogs by category using Helius RPC.

## Scope
- New program `xb77_registry` (preferred) or minimal module inside `xb77_gateway`.
- Merchant account + Catalog account model (one merchant, many catalogs).
- Instructions to create/update merchants and catalogs.
- SDK helper stubs or interfaces for registry reads (no RPC wiring in this branch).
- UI plan for the hub to list merchants and show catalogs.

## Out of Scope
- Payment execution logic.
- Checkout and receipt flows.
- Full merchant onboarding UX.
- Helius RPC integration (handled in Infra/Observability branch).

## Data Model
**Merchant Account**
- `merchant_id` (string or bytes)
- `owner_pubkey` (Pubkey)
- `catalog_count` (u32)
- `created_at` (u64)
- `updated_at` (u64)

**Catalog Account**
- `merchant_id` (string or bytes)
- `catalog_id` (u64)
- `category` (u8)
- `catalog_url` (string)
- `metadata_hash` (bytes32, optional)
- `updated_at` (u64)

## PDA Seeds
- Merchant: `["merchant", merchant_id]`
- Catalog: `["catalog", merchant_id, catalog_id]`

## Instructions
1) `init_merchant(merchant_id)`
2) `add_catalog(merchant_id, catalog_id, category, catalog_url, metadata_hash?)`
3) `update_catalog(merchant_id, catalog_id, category?, catalog_url?, metadata_hash?)`
4) `deactivate_catalog(merchant_id, catalog_id)` (optional)

## Hub Integration (Deferred)
- Hub should consume registry data via SDK helper interfaces.
- Helius RPC wiring and caching live in Infra/Observability branch.

## SDK Integration
- Add `registry` helpers: `listMerchants`, `listCatalogs`, `listCatalogsByCategory`.
- Return stable types for UI consumption.

## Deliverables
- On-chain registry program + deploy script (devnet).
- Hub registry fetch + UI list.
- SDK helpers + docs.

## Dependencies
- Program ID allocation.
- Helius RPC endpoint.
- Decision: `xb77_registry` vs `xb77_gateway` extension.

## Risks
- Account size limits for string fields.
- Helius query latency for large registries.

## Fallback
- Store catalog_url off-chain and keep only hash on-chain.

## Breakpoints
- BP1: Merchant account created on devnet.
- BP2: Catalog account created and fetched via Helius.
- BP3: Hub UI lists merchants + catalogs with category filter.
