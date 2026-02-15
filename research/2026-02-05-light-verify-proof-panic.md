# Research: Light Protocol `verify_proof` V2 Panic on Devnet (Helius)

## Executive Summary
Public Light Protocol docs indicate that **validity proofs must align with the exact address tree + queue accounts** used in the on-chain instruction. If the proof is generated for one tree/queue pair but the instruction supplies a different pair, verification can fail and may manifest as a panic in `verify_proof`. citeturn0search1turn3search0  
In your logs, the proof’s `treeInfos` returned by Helius shows **`queue == tree`**, while the instruction uses a **different queue**. That mismatch is the most plausible root cause given the official guidance on proof/TreeInfo alignment. citeturn0search1turn3search0

## Key Findings

### 1) Proofs must match the tree + queue accounts used by the instruction
The Light client guide shows that the proof is generated using a `TreeInfo` (tree + queue), and those same accounts are packed into the instruction. This implies a strict consistency requirement between proof inputs and instruction accounts. citeturn0search1turn3search0

### 2) Devnet uses Helius RPC and publishes shared public tree/queue addresses
The devnet addresses page lists program IDs and the public tree/queue accounts for shared trees, and recommends Helius RPC as the devnet endpoint. citeturn0search0turn1search0  
If you use a different tree/queue pair than the documented devnet public pair, you risk proof/account mismatch.

### 3) The docs show examples where `queue == tree`
The client guide includes example usage where the queue is the same as the tree when requesting a validity proof. citeturn3search0  
This aligns with what Helius returns in `treeInfos` (queue == tree) in your logs.

## Most Likely Root Cause (Evidence-Based)
- **Mismatch between proof `treeInfos` and instruction accounts**, specifically queue mismatch:
  - Proof from Helius: `queue == tree`.
  - Instruction: `queue != tree` (batch queue).
  - Docs require these to match. citeturn0search1turn3search0

## Recommended Next Experiments (Low-Risk)
1) **Use the same tree+queue that comes from the proof inputs**  
   Don’t override queue to a different account if Helius returns `queue == tree`. This directly follows the Light docs’ guidance. citeturn0search1turn3search0

2) **Cross-check with documented Devnet public tree/queue**  
   If you intend to use the shared public trees, confirm you’re using the documented devnet addresses. citeturn0search0turn1search0

3) **Fallback to V1 on devnet**  
   If V2 continues to panic, attempt a V1 path using the documented proof flow (per client guide), which is the most stable reference path in public docs. citeturn0search1turn3search0

## Method & Iterations
### Search round 1 (web)
- Light Protocol devnet addresses
- Light client guide for validity proofs
- Light error cheatsheet

### Gap analysis
- No public doc found for `getValidityProofV2` details or Helius-specific V2 behavior.
- No direct issue in public sources describing the exact panic.

## Sources
- Light Protocol Devnet addresses: https://docs.lightprotocol.com/developers/devnet-addresses citeturn0search0turn1search0
- Light Protocol Client Guide (validity proof usage + account packing): https://www.zkcompression.com/client-library/client-guide citeturn0search1turn3search0
- Light Protocol Error Cheatsheet: https://www.zkcompression.com/resources/error-cheatsheet citeturn0search3

