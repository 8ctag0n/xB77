---
pageClass: is-legacy-page
---
# Branch Plan: Noir + Demo Wiring (Aligned to README)

## Goal
Wire the existing Noir badge proof to the private order flow in the gateway and deliver demo scripts + logs, aligned with the README Phase 2 integration scope.

## What Already Exists
- Circuit: `circuits/agent_badge`
- Proof scripts: `sdk/scripts/generate_badge_proof.ts`, `scripts/sunspot.sh`
- JS test: `sdk/test_badge.mjs`

## Work to Do (Scope)
1) Extend circuit inputs (public):
   - `order_id` (public) and optional `nullifier`.
2) Update proof generation:
   - Include `order_id` in inputs.
   - Emit outputs compatible with `verify_badge` gateway instruction.
3) Wire scripts:
   - Update `sdk/scripts/generate_badge_proof.ts` to include `order_id`.
   - Ensure output artifacts include `order_id` mapping.
4) Demo flow:
   - Script to call `verify_badge` then `submit_private_order` (Phase 2: The Gateway).
   - Public vs god-mode output logging.
5) Docs:
   - Add README snippet for running Noir proof with `order_id` and localnet helpers.

## Out of Scope
- New gateway logic or contract changes beyond proof input wiring.
- Changes to Arcium C-SPL, Light SDK, or UI work in `./web`.
- New narrative or phase changes in README beyond this branch.

## Success Criteria
- Proof pipeline runs with `order_id` as public input and stays compatible with `verify_badge`.
- Gateway accepts the proof and allows `submit_private_order` (Phase 2 expectation).
- Demo script produces public result + private logs (god-mode) without breaking existing test flow.
- README includes a minimal how-to aligned with localnet helper commands.
