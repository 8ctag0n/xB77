# WEEK PLAN S7: THE SOVEREIGN SWAP
**Goal:** Pivot from 3rd party protocols to the native ZDK.

## Tasks
- [ ] Fix Receipts CPI bug (P0) -> Call to Light Protocol.
- [ ] Replace `PrivacyCashAdapter` with `ZyberShieldAdapter`.
- [ ] Update Agent logic to use ZDK-provided compliance checks.
- [ ] Test the "Mobile-Served" notification flow for agent approvals.

## Success Criteria
- **Simple:** xB77 compiles and runs using `@zyberlink/zdk` as a dependency.
- **Ambicious:** xB77 handles its first private transaction 100% via the ZyberLink infrastructure on Devnet.
- [ ] **Fix CPI stack depth/account limit (P0):** Debug receipt minting to Light Protocol.
