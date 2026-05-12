# 🔁 HANDOFF — Sovereign onchain CLOSED, what's next

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/docs-v2`
> **Branch**: `feat/dapp-public-split` @ `a4e41d5`
> **Status**: Webapp + CLI both submit real Solana tx onchain via IDL.
> **Local stack**: bootable in one shot via `scripts/full_local_stack.sh --keep-up`.

## What's real now (no mocks anywhere on the critical path)

| Layer | Status |
|---|---|
| Web Crypto Ed25519 keystore (webapp) | ✅ AES-GCM at rest, non-extractable session key |
| Wire 1.1 (canonical bytes, header-bound sigs) | ✅ byte-identical webapp ↔ CLI ↔ CF Worker |
| Mock-gateway (`sdk/ts/dev/mock-gateway.ts`) | ✅ VERIFY_SIGS=1 — kept for `demo_e2e.sh` |
| Real gateway (`gateway/worker/src/index.js`, wrangler dev) | ✅ verifies wire-1.1 sigs, reads validator state |
| Solana validator (`xb77-validator` podman container) | ✅ 4 programs deployed (`xb77_core/_compression/_zk_verifier/_gateway`) |
| Webapp onchain stack (`webapp_deploy/assets/src/lib/`) | ✅ wincode + base58 + idl-client + solana-rpc + solana-tx |
| **Webapp anchorState onchain** | ✅ `Compression: Transition Verified via Poseidon BN254` |
| CLI Zig onchain stack (`core/onchain/`) | ✅ wincode + idl_client + solana_rpc + solana_tx — byte-identical to JS |
| **CLI `xb77 gateway anchor`** | ✅ same program log as webapp |
| `scripts/full_local_stack.sh` | ✅ idempotent, --reset/--teardown/--no-wrangler/--validator-only flags |
| `DEMO.md` | ✅ no-mocks variant front and center |

## What's still mock-ish or missing

| # | Gap | Effort | Why it matters |
|---|---|---|---|
| 1 | `submit_order` is only worker-memory; should hit `xb77_gateway.SubmitPrivateOrder` onchain | 2-3h | Needs PDA derivation (gatewayState, orderbookPda, nullifierPda). The most visible "still not real" path. |
| 2 | `xb77 serve` daemon + znode-server in the stack | 2-3h | Removes the "agent only acts on demand" feel; makes the dApp see live continuous activity. |
| 3 | ZK proof gen (Noir + bb container) → `xb77_zk_verifier` chunked upload | 3-4h | Real ZK story closes; today the verifier program is deployed but idle. |
| 4 | `xb77_registry` (merchants) integrated into the dApp UI | 1-2h | Low — the dApp doesn't have a merchants tab. Could be a future PR. |
| 5 | Receipts program (Light Protocol compressed receipts) | 2-3h | Low — separable demo, can ship without. |

## What's explicitly OUT OF SCOPE locally

- Sponsors (QVAC / MagicBlock / SNS) — remote at `specs/sponsors/*.md`.
- Deploy to devnet/mainnet — held until `submit_order` onchain (gap #1) closes.
- CF Pages prod deploy — same.

## How to retake this branch

```bash
cd /home/exp1/Desktop/xB77/worktree/docs-v2
git log --oneline -6           # confirm a4e41d5 is HEAD
scripts/full_local_stack.sh --keep-up   # boots everything

# Then either:
#  - test webapp at http://127.0.0.1:8080/app.html (Chrome 137+)
#  - test CLI from repo root:
#      export XB77_PASSWORD=demo-pw
#      ./zig-out/bin/xb77 spawn myagent
#      ./zig-out/bin/xb77 -p myagent init
#      ./zig-out/bin/xb77 -p myagent gateway register --intent merchant
#      ./zig-out/bin/xb77 -p myagent gateway anchor   # ← lands tx onchain
```

## Test commands

```bash
bun test webapp_deploy/test/              # 50/50 webapp tests
zig build test                            # 37/38 Zig (app_test pre-existing fail)
scripts/full_local_stack.sh --reset --keep-up   # full smoke from scratch
```

## Suggested next sessions

**Session A — Close gap #1 (submit_order onchain)**:
   Trace the SubmitPrivateOrder accounts in `onchain/programs/xb77_gateway/src/instruction.rs`,
   compute the gatewayState PDA (seed: `GATEWAY_STATE_SEED`), orderbookPda + nullifierPda.
   Init the gatewayState via `InitGateway` first (one-time admin tx). Then wire
   webapp + CLI to use IDL `SubmitPrivateOrder`.

**Session B — Agent lifecycle**:
   Boot `xb77-agent-demo` container running `xb77 serve` continuously. Wire
   znode-server to subscribe to the validator and feed events to the worker's
   `/pipelines/recent`. Demo: leave the stack running, watch the dApp see live
   activity from the daemon.

**Session C — ZK end-to-end**:
   Use `xb77-zk` container to nargo-prove + bb-prove. Upload chunked proof via
   `zk-upload-e2e` style flow → `xb77_zk_verifier` returns verdict GREEN onchain.
   Webapp shows the GREEN verdict in a new "Proofs" tab.

**Session D — Merge + devnet**:
   Once gaps #1-3 close, merge `feat/dapp-public-split` to `bedrock`. Redeploy
   programs to devnet. Switch wrangler `ZNODE_RPC_URL` to devnet. Webapp + CLI
   work against a real public chain.

## Frase de arranque sugerida

> "Vengo del cierre sovereign-onchain en feat/dapp-public-split (HEAD `a4e41d5`).
> Webapp y CLI ambos mandan tx onchain via IDL byte-identical. Leé este HANDOFF
> + memory. Próximo gap más visible: [elegir A/B/C/D arriba]."
