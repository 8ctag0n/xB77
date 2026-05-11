# 🔁 HANDOFF — Frontend Realistic Wiring

> **Worktree**: `/home/exp1/Desktop/xB77/worktree/docs-v2`
> **Branch**: `feat/dapp-public-split` @ `9bf5618`
> **Parallel sibling**: `/home/exp1/Desktop/xB77/worktree/gateway-realdata` (`feat/gateway-realdata`) — backend producer
> **Contract (source of truth)**: `docs/api-contract-v1.md` (tracked, both sides see it)
> **Estimated effort**: 4–5 hours
> **Created at**: 2026-05-11 session close — fresh session expected to pick this up

---

## State at session close

Webapp deluxe shipped, ready for real wiring:

✅ 2-entry split (`index.html` + `app.html`) with cross-doc fade transitions
✅ Theme system (warm-paper light + Obsidian dark + bottom-right toggle, hybrid OS-pref)
✅ ASCII boot screen (first visit on landing, theme-respect, skippable)
✅ Layered surface tokens, zebra tables, drawer striping, sharp-edge widgets
✅ `/pitch` slide deck (scroll-snap + keyboard nav + dot nav + progress bar)
✅ Pitch moved to Docs sidebar related-links (out of horizontal nav)
✅ SDK Zig/TS/Rust merged from `merge/onchain-deluxe`
✅ API contract v1 committed at `docs/api-contract-v1.md`

Tag for rollback: `pre-sdk-wasm-deluxe-2026-05-11` (lives on `feat/docs-vitepress`).

## Mission for this worktree

Consume `docs/api-contract-v1.md` from the frontend side. Wire every stub-button in the dApp to real signed actions over the gateway. Replace `DataSource` mocks with real reads.

## What to build (from contract §8 checklist)

- [ ] **Keystore flow** in `webapp_deploy/assets/src/dapp-wallet.jsx`:
  - "Connect" button opens password modal.
  - Two paths: "Generate new keystore" (calls SDK `keystore.seal`) and "Import existing" (file input with sealed blob, calls `keystore.unseal`).
  - Sealed blob persists in `localStorage.xb77_keystore`. Private key lives only in component state for the session.
  - First-session flow auto-calls `register_agent` after keystore is ready.
- [ ] **`Wallet → Claim credits`** wired to `POST /api/v1/actions/claim_credits`.
- [ ] **`Pipelines → Run pipeline`** wired to `POST /api/v1/actions/submit_order`. On success, append to tx log via lifted state.
- [ ] **`Agents → Deploy agent`** wired to `POST /api/v1/actions/register_agent` (creates a child agent under the connected one).
- [ ] **`DataSource.networkPulse`** swap mock branch for `GET /api/v1/network/pulse`.
- [ ] **`DataSource.agents`** swap for `GET /api/v1/agents/fleet`.
- [ ] **`DataSource.pipelinesRecent`** swap for `GET /api/v1/pipelines/recent`.
- [ ] **Rate-limit debug strip** (bottom-right, dev-only, behind a `?debug=1` flag): show `Tier · Remaining · Reset` from `X-RateLimit-*` headers.
- [ ] **429 toast**: catch rate-limit responses, show a small toast "Rate limited — retry in Xs", reading `Retry-After` header.

## SDK import path (after merge)

The TS wrapper is at `sdk/ts/src/index.ts` and needs `bun run build` (via `sdk/ts/package.json`) to produce `sdk/ts/dist/`. For the webapp:

```bash
cd sdk/ts
bun install
bun run copy-wasm   # copies xb77_core.wasm next to dist
bun run build       # produces dist/index.js
```

Then vendor it into `webapp_deploy/assets/vendor/`:

```bash
cp -r sdk/ts/dist/* webapp_deploy/assets/vendor/xb77-sdk/
cp sdk/ts/wasm/xb77_core.wasm webapp_deploy/assets/vendor/xb77-sdk/
```

Add a `<script type="module" src="assets/vendor/xb77-sdk/index.js">` to both HTMLs. (Adjust path to match what `tsc` actually emits.)

## Mock-first development (no backend dependency)

Until the gateway worktree publishes a preview URL, point `window.XB77_GATEWAY` at the local SDK mock:

```bash
cd sdk/ts
bun run dev/mock-gateway.ts   # spins up the mock on :8787
```

The webapp talks to `http://127.0.0.1:8787` exactly as it would to the real gateway. The contract guarantees byte-identical shapes.

## Build sequence (suggested)

1. Vendor the SDK TS wrapper into the webapp. Smoke test in browser console: `await window.XB77.load()` resolves.
2. Implement keystore modal in `dapp-wallet.jsx`. Use `var(--bg-elevated)` + `var(--accent)` for the password input. Generate/import paths.
3. Wire `register_agent` on first keystore unlock. Save returned `agent_id` to `localStorage.xb77_agent_id`.
4. Wire `Claim credits` → `claim_credits` action. On success, animate the credits card from old → new total.
5. Wire `Run pipeline` → `submit_order`. Lift `txLog` state to `PipelinesView`; new orders prepend.
6. Wire `Deploy agent` → `register_agent` (child). Add the new agent to the visible list.
7. Replace `DataSource.networkPulse` mock with real fetch + 3s interval.
8. Replace `DataSource.agents` and `DataSource.pipelinesRecent`.
9. Add the rate-limit debug strip and the 429 toast.
10. Test against `mock-gateway.ts` end-to-end.
11. Once gateway-realdata has a preview URL, swap `window.XB77_GATEWAY` and re-test.

## Sync points with gateway worktree

- **Only shared artifact**: `docs/api-contract-v1.md`.
- If a contract change is needed, edit the file in this worktree, commit, push to the other side. Backend session sees the new contract before re-implementing.
- **Preview URL handoff**: gateway worktree publishes via `wrangler deploy`; you receive a URL string. Update one constant in `index.html` + `app.html`:
  ```html
  <script>window.XB77_GATEWAY = "https://xb77-gateway.<account>.workers.dev";</script>
  ```

## Risk register

- **CORS** — Gateway must respond with `Access-Control-Allow-Origin: *` (contract §1.4 requires this). If browser blocks, the contract was violated, not your code.
- **Idempotency** — `submit_order` and `claim_credits` are dangerous to retry without `idempotency_key`. Always set one in the SDK call.
- **Keystore UX** — first-time user with no keystore needs the "Generate new" path. Don't force "Import" only.
- **Pre-React paint** — keep boot.js and theme.js as the first two scripts in `<head>` regardless of SDK wiring.
- **Bundle size** — vendoring the SDK adds ~50KB. Worth it; don't try to inline.

## Local server status

The `python3 -m http.server 8080` background process (id `bamh1fiis`) from this session **must be killed** before opening a fresh session. Run:

```bash
kill $(lsof -ti :8080)
# or:
ps aux | grep "python3 -m http.server" | grep -v grep | awk '{print $2}' | xargs kill
```

## Frase de arranque sugerida

> "Vengo a labura el frontend realistic wiring en `feat/dapp-public-split`. Leé `HANDOFF-NEXT-SESSION.md` y el contract `docs/api-contract-v1.md` (§8 es el MUST-implement). Arrancamos por el step 1 del build sequence: vendor del SDK TS al webapp."
