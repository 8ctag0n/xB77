## Programs roadmap

Order of implementation:
1) `xb77_gateway` (Solana program): verify Noir proof, then call C-SPL and Light.
2) C-SPL vault integration (Arcium).
3) Light Protocol audit receipt integration.

Notes:
- The gateway is the orchestrator; C-SPL and Light are invoked after proof verification.
