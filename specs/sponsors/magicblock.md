# Spec — MagicBlock PER live (Sovereign HFT Rail)

> **Sponsor**: MagicBlock
> **Track**: Main hackathon (Colosseum Frontier)
> **Repo branch to target**: `sponsor/magicblock` (cut from `feat/dapp-public-split`)

## Why this spec exists

`core/chain/magicblock.zig` (175 lines) is a half-built `MagicBlockSDK`
shell with `Session`, `EphemeralTx`, and PER (Private Ephemeral Rollup)
types — but every CLI flow that touches it (`submit_order`,
`claim_credits`, `merchant`) currently fails into the `"ShadowWire
initialization failed: InvalidResponse. Using standard rails."`
fallback path. The integration is **structural but not live**.

This spec makes PER sessions actually open against MagicBlock's hosted
infrastructure (devnet sequencer), produce real session IDs, and serve
the existing narrative (*"sub-millisecond settlement"* in `README.md`).

## What "done" means

- `xb77 magicblock {start,status,close}` CLI subcommands open / inspect /
  close real PER sessions against MagicBlock's devnet sequencer
- The session ID printed by `xb77 magicblock start` is observable on
  MagicBlock's explorer (or via their RPC for verification)
- Webapp shows an active session in the dApp shell (badge + countdown to
  expiry)
- Existing `[MAGIC]` logs in the CLI gateway flow stop saying *"failed,
  using standard rails"* and instead show *"PER session active: <id>"*
- `scripts/smoke_magicblock.sh` proves the lifecycle end-to-end

## Required reading

1. **MagicBlock docs**: https://docs.magicblock.gg
2. **Their Solana program ID** (delegation / commit / etc): find in their
   docs — this is what we delegate accounts TO
3. **Devnet sequencer URL**: find in their docs — this is what
   `MagicBlockSDK.sequencer_url` should be set to
4. **`core/chain/magicblock.zig`** — read the full file. Inventory what's
   stubbed vs what's implemented. The struct shapes (`Session`,
   `EphemeralTx`) are the contract you're implementing against
5. **`core/chain/solana.zig`** (referenced as `solana_mod`) — see what
   the existing Solana client can do; PER sessions need normal Solana txs
   to bootstrap (delegate-account instruction)
6. **`core/kernel/context.zig`** + **`core/kernel/engine.zig`** — see how
   `magicblock.zig` is consumed today and where the `[MAGIC]` log lines
   originate (so you know what success looks like)
7. **`scripts/demo_frontier.sh`** — has explicit `[SWARM] ... MagicBlock
   transfer` lines; these should land as real sessions after this spec
8. **`gateway/main.zig`** — gateway side references magicblock; may need
   nothing changed, may need read

## Implementation plan

### 1. Discovery (no code yet)

The agent MUST first determine:

- **Devnet sequencer endpoint URL** (typical form
  `https://devnet.magicblock.app` or similar; verify in their docs)
- **Their Solana program ID for delegation** (8-byte pubkey, base58)
- **The delegation-instruction format** (which accounts must be passed,
  what discriminator the instruction uses, what data the program expects)
- **Session lifecycle endpoints**: how to open a session (instruction or
  HTTP?), how to query state, how to close cleanly
- **Authentication model**: do they pin gateway keys? Or is the
  delegation-instruction signature enough?

These answers live in their docs / their github (search
`github.com/magicblocklabs`). The agent records these in this spec
inline (replacing the placeholders below) once verified, so the next
reader has the contract pinned.

**Findings template** (fill in then commit):
```
DEVNET_SEQUENCER_URL = "https://devnet.magicblock.app"
DELEGATION_PROGRAM_ID = "DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh"
SESSION_DURATION_DEFAULT = "3600 seconds"
AUTH_MODEL = "Delegation-instruction signature"
EXPLORER_URL_FOR_SESSION = "https://explorer.magicblock.gg/session/"
```

### 2. CLI: `xb77 magicblock <sub>`

Create `cli/commands/magicblock.zig` (sibling to `gateway.zig` which we
already shipped):

```
xb77 magicblock start [--duration <sec>] [--lock-amount <lamports>]
  → opens a PER session; prints session_id + expiry + sequencer pubkey
  → on success, writes the session file to $profile/magicblock_session

xb77 magicblock status
  → reads the session file; queries sequencer for liveness; prints state

xb77 magicblock close
  → submits the close-session instruction; clears the session file

xb77 magicblock probe
  → developer aid: GET <sequencer>/_meta to confirm reachability
```

Use the existing keypair from `ctx.vaults.ops.sol_kp` (we have wire-1.1
working — same pattern). HTTP layer is `core.mesh.http.HttpClient` (which
has `postWithHeaders` we added for the gateway track).

### 3. Wire into existing `MagicBlockSDK`

The CLI commands should call into `core/chain/magicblock.zig`'s existing
types. The agent's job is to:

- Fill in the unimplemented methods on `MagicBlockSDK` (likely:
  `openSession(authority, duration, lock_amount) !Session`,
  `closeSession(session) !void`, `queryState(session) !SessionState`)
- Make those methods talk to the discovered sequencer URL + program ID
- Replace the *"ShadowWire initialization failed"* path in `commerce/pay.zig`
  and `kernel/engine.zig` with the real call

### 4. Webapp widget

Add a small **Session** indicator to the dApp shell (sibling to the
connection pill we already built):

- Shows `⚡ PER <session_id_short> · 12m 34s` when active
- Click → opens a panel with details: full session ID, lock amount,
  expiry, sequencer pubkey, link to explorer
- When no session: dim pill *"⚡ No PER session"* with a button to call
  `xb77 magicblock start` (or trigger via the gateway action that opens
  one — depends on the API discovered in step 1)

### 5. Demo orchestrator integration

Update `scripts/demo_e2e.sh` (or `scripts/hackathon_demo_v2.sh` which
already has the `sponsor()` function) to:

1. `xb77 magicblock start` near the top of the flow
2. Show the session ID with `sponsor MagicBlock "live PER session opened"`
3. Run a `submit_order` that, in its CLI output, references the active session
4. Close the session at the end with `xb77 magicblock close`

### 6. Deliverables checklist

- [ ] `cli/commands/magicblock.zig` with 4 subcommands
- [ ] `core/chain/magicblock.zig` extended: `openSession` /
      `closeSession` / `queryState` implemented
- [ ] `commerce/pay.zig` + `kernel/engine.zig` no longer fall to
      `"standard rails"` — they use the active session
- [ ] Webapp Session pill + panel in `webapp_deploy/assets/src/`
- [ ] `scripts/smoke_magicblock.sh` opens / queries / closes a session
- [ ] `README.md` has a *"Sponsor: MagicBlock"* section with screenshot /
      asciinema of a live session
- [ ] Pinned constants (sequencer URL, program ID) committed in this spec
- [ ] Commit on `sponsor/magicblock` branch with subject
      `feat(magicblock): PER live — sovereign HFT rail on devnet`

### 7. Cost / time budget

- No cloud GPU needed
- Devnet SOL airdrop (free; rate-limited)
- ~4 hours of code if the API discovery in step 1 goes smoothly; +2
  hours if the auth model surprises (delegation instruction edge cases)

## Open questions the agent must resolve

1. **Is the session creation an on-chain Solana instruction, an off-chain
   HTTP call to the sequencer, or both?** (most likely "both": on-chain
   delegation + off-chain session lifecycle)
2. **Lock-amount semantics**: is it actual SOL escrowed or a virtual
   collateral commitment? Affects which account we sign / what's
   recoverable
3. **Session reuse**: if `xb77 magicblock start` is called while a
   session is active, do we error or reuse? **Default: error, suggest
   `close` first**
4. **Devnet faucet for SOL**: confirm Sol airdrop on devnet works for
   testing (it does, but rate-limited; have backup means)
5. **MagicBlock fee structure on devnet**: is there a per-session fee?
   Document if so

## What this spec must NOT do

- Don't try to run a local MagicBlock sequencer. Their infrastructure is
  hosted; pointing at their devnet endpoint is the right move and matches
  how a real merchant would integrate
- Don't hard-code mainnet endpoints. Stay on devnet for the demo;
  document the env var for mainnet (`XB77_MAGICBLOCK_URL` etc) for
  future deploy
- Don't strip the existing `[MAGIC]` log style — extend it; the demo
  script grep-matches on those tags

## Reference

- MagicBlock docs: https://docs.magicblock.gg
- MagicBlock GitHub: https://github.com/magicblocklabs
- xB77 narrative tie-in: `README.md` *"HFT Rail: MagicBlock ephemeral
  rollups for sub-millisecond payment settlement"*
- Existing code anchor: `core/chain/magicblock.zig`
