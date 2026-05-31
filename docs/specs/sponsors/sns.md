# Spec — SNS / AllDomains resolve + register

> **Sponsor**: Solana Name Service (Bonfida) / AllDomains
> **Track**: Main hackathon (Colosseum Frontier)
> **Repo branch**: `post-frontier-enhancement`

## Status — post-frontier SNS end-to-end pass (commits `29086ec`, `a13ea9d`)

What landed in F6 + SNS end-to-end pass after the original spec was written:

- **Native PDA derivation in Zig**: `core/security/identity.zig:resolveSnsNative` matches Bonfida mainnet byte-for-byte. Validated by `zig build sns-test` against live mainnet RPC + Bonfida API (the side-by-side MATCH stamp in the demo video).
- **Worker reverse-lookup endpoint**: `GET /api/v1/sns/reverse?pubkey=<base58>` in `gateway/worker/src/index.js`:
  - Tries Bonfida's `/v2/user/favorite-domain/<wallet>` first (canonical primary)
  - Falls back to `/v2/user/domains/<wallet>[0]`
  - Cached in BUCKETS KV (1h TTL, positive + negative). No retry-storm hammering.
- **Browser helper**: `apps/web/assets/src/lib/sns-reverse.js` exposes `window.XB77SnsReverseLookup(pubkey)` → `<name>.sol | null`. sessionStorage cache (1h TTL).
- **ConnectionPill swap (F6)**: `apps/web/assets/src/app-tabs.jsx:ConnectionPill` now listens for `xb77:domain-resolved` and swaps `ag_xxx…` for `<name>.sol` in lime with glow. `dapp-actions.js:identity.resolveFavoriteDomain` orchestrates the lookup post-`xb77:connected` and dispatches the event when a name lands.

Result: when a judge visits `/app` and connects via keystore, the ConnectionPill upgrades from `ag_77b9e2…` to `<theirname>.sol` automatically — what F6 wired structurally, this pass made functional.

Honest delta: the **register** flow (mint a fresh `.sol` from the dApp) is still pending — current scope is read-only (resolve + reverse). Spec for the register-via-unsigned-tx flow is documented further down.

---

## Why this spec exists

xB77 prints `<agent_name>.xb77 / .sol` in `xb77 status` output and the
webapp connection pill shows `ag_xxx` — neither is backed by a real
SNS lookup. We have *one* piece of working code already:
`scripts/verify_sns.ts` (22 lines) correctly derives the SNS PDA for a
domain using `namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ` (Bonfida) and
`58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx` (root). That's the seed.

This spec turns that 22-line proof-of-concept into:

- `xb77 sns resolve <name>.sol|<name>.xb77` — pubkey lookup
- `xb77 sns reverse <pubkey>` — find favorite domain
- `xb77 sns register <name>.xb77` — register a name during demo
- Webapp connection pill replaces `ag_xxx…` with `<name>.xb77` when the
  connected agent's pubkey has a registered favorite

## What "done" means

- `xb77 sns resolve <real-bonfida-domain>.sol` returns the correct pubkey
  against devnet or mainnet RPC
- `xb77 sns register demo.xb77` (during the live pitch) successfully
  registers a name owned by the agent's pubkey — verifiable on the
  AllDomains explorer
- Webapp `ConnectionPill` shows `● demo.xb77` instead of `● ag_abc…`
  after registration (refreshes on the `xb77:connected` event)
- `scripts/smoke_sns.sh` validates resolve + reverse-lookup

## Required reading

1. **Bonfida SNS GitHub**: https://github.com/Bonfida/sns-sdk
2. **AllDomains docs**: https://docs.alldomains.id (or via their
   GitHub) — they own custom TLDs like `.xb77` (if reserved); if not
   reserved, register against `.sol` or use a TLD the team owns
3. **`scripts/verify_sns.ts`** — the 22-line existing PoC. Read it; this
   is the algorithm
4. **`cli/commands/identity.zig`** — has `identity claim/resolve`
   subcommands today that go to `gateway.xb77.io/identity/claim` (legacy
   stub). Replace with real SNS calls
5. **`apps/web/assets/src/app-tabs.jsx`** — `ConnectionPill`
   component is where the display swap happens
6. **`apps/web/assets/src/lib/dapp-actions.js`** — exposes
   `XB77Actions.keystore`; the resolve happens after `xb77:connected`
   event fires, using the persisted pubkey

## Implementation plan

### 1. TS service for SNS calls

Create `services/sns/`:

```
services/sns/
├── resolve.ts           # resolve(name) → pubkey
├── reverse.ts           # reverse(pubkey) → favorite domain name | null
├── register.ts          # register(name, owner_kp, payer_kp) → tx_sig
├── server.ts            # tiny HTTP shim on :8089 for webapp consumption
└── package.json         # @bonfida/spl-name-service + @solana/web3.js pinned
```

**HTTP contract** (used by both CLI and webapp):

- `GET  /healthz` → `{ ok: true, rpc: "<rpc_url>", cluster: "devnet|mainnet-beta" }`
- `GET  /resolve?name=<name>.sol` → `{ name, owner: "<pubkey>", class, parent }` or 404
- `GET  /reverse?pubkey=<pk>` → `{ pubkey, favorite: "<name>" | null }`
- `POST /register` body `{ name: "demo.xb77", owner_pubkey: "<pk>", space: 1000 }`
  → `{ tx_sig, registered_name, owner }` — payer is the service itself
  (devnet SOL airdrop) OR returns an unsigned tx for the CLI to sign

**Choose the unsigned-tx path** so the agent's keypair stays in its
profile; the service is stateless and never holds keys.

### 2. CLI: `xb77 sns <sub>`

`cli/commands/sns.zig`:

```
xb77 sns resolve <name>          # name.sol / name.xb77
xb77 sns reverse                 # uses connected agent pubkey by default
xb77 sns reverse <pubkey>        # explicit
xb77 sns register <name>         # register name owned by the agent
xb77 sns set-favorite <name>     # mark a name as the favorite (for reverse)
```

Each command calls into `services/sns/` via HTTP (mirrors how the
gateway command works), then displays the result.

For `register` and `set-favorite`, the service returns an unsigned tx
(base64), the CLI signs with the keypair from `ctx.vaults.ops.sol_kp`,
then submits via `core.chain.solana.SolanaClient.sendTransaction`.

### 3. Webapp integration

In `apps/web/assets/src/lib/dapp-actions.js`:

- Add `XB77Actions.sns.resolve(name)`, `XB77Actions.sns.reverseFor(pubkey)`
- After `xb77:connected` event, call `reverseFor(pubkey)` once; if a
  favorite domain exists, dispatch a new event `xb77:domain-resolved`
  with `{name}` detail

In `apps/web/assets/src/app-tabs.jsx` `ConnectionPill`:

- Listen for `xb77:domain-resolved`
- Replace the truncated `ag_xxx…` display with the resolved name when present
- Hover tooltip still shows the agent_id

### 4. Devnet vs mainnet decision

**Default to devnet** for demos:

- Faucet SOL is free
- Bonfida programs are deployed on devnet (verify the program IDs match)
- The risk of accidental real-money registrations during demo == zero

Document an env var `XB77_SNS_CLUSTER=devnet|mainnet-beta` for the
`services/sns/` service.

**Important**: AllDomains TLDs (.xb77 specifically) might only exist on
mainnet. The agent must verify which TLDs are devnet-reachable. If
`.xb77` is mainnet-only, use `.sol` for the demo or register a devnet
`.xb77` if AllDomains supports it.

### 5. Bonus: dApp avatar from SNS record

If time permits, read the SNS record's profile picture URL (Bonfida
record format) and display it in the webapp wallet header as the agent
avatar. Pure visual polish, +5 demo quality.

### 6. Deliverables checklist

- [ ] `services/sns/` runs locally on :8089
- [ ] `cli/commands/sns.zig` with 5 subcommands wired through `services/sns/`
- [ ] `xb77 sns resolve bonfida.sol` returns the real owner pubkey
- [ ] `xb77 sns register demo.xb77` registers on chosen cluster
- [ ] Webapp `ConnectionPill` shows the resolved name when present
- [ ] `scripts/smoke_sns.sh` passes (resolve + reverse + register cycle)
- [ ] `README.md` has a *"Sponsor: SNS / AllDomains"* section
- [ ] Commit on `sponsor/sns` branch with subject
      `feat(sns): resolve + register — sovereign identity on Solana`

### 7. Cost / time budget

- No cloud needed; runs against public devnet RPC
- ~3-4 hours code if Bonfida SDK matches the version in their docs
- ~1 hour extra if AllDomains TLD discovery is squirrelly

**Open questions the agent must resolve**

1. **Is `.xb77` a real TLD on AllDomains?** AllDomains supports custom TLDs; `.xb77` is a conceptual TLD for the demo. If not available on devnet, we use `.sol` or register `agent.sol`.
2. **Bonfida SDK version**: `@bonfida/spl-name-service` v3.0.21 is current.
3. **RPC choice for devnet**: `https://api.devnet.solana.com` or Helius devnet.
4. **Naming collision**: Use `demo-${timestamp}.xb77` for uniqueness.

## What this spec must NOT do

- Don't use a hard-coded mainnet payer keypair anywhere
- Don't return the agent's keypair from the service. The service is
  stateless; it returns unsigned txs and the CLI signs locally
- Don't pretend `.xb77` works on devnet if AllDomains says otherwise.
  Honesty wins demo quality

## Reference

- Bonfida SNS SDK: https://github.com/Bonfida/sns-sdk
- AllDomains: https://docs.alldomains.id
- Existing PoC: `scripts/verify_sns.ts`
- xB77 narrative tie-in: `xb77 status` and webapp connection pill;
  identity printed as `<name>.xb77 / .sol`
