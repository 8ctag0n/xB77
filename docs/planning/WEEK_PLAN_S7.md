# WEEK PLAN S7: OPERATION SYNAPSE ⚡

**Status:** Infrastructure ready. Core purified. Vision locked.
**Goal:** Transition to Reactive HFT-Latency Commerce.

## 🏁 Starting Point (Start here next session)
1. **[Z-Node Glue]**: Connect `znode/parser.zig` with `core/engine.zig` via Unix Sockets.
2. **[Risk Recon]**: Implement the first rule in `core/audit.zig` (e.g., Block if recipient has received from known mixers).
3. **[Infra Tax]**: Add the 11% facilitation fee instruction to `core/tx.zig`.
4. **[Edge Ready]**: Run `zig build -Dtarget=wasm32-wasi` and fix any WASM-incompatible code.

## 🛠️ Technical Debt / Small Tasks
- [ ] Fix `sendResponse` in `mcp/server.zig` to handle `id: null` better.
- [ ] Add `std.debug` logs to the Z-Node Parser to see raw bytes flow.
- [ ] Implement `recordSpend` with persistent storage (SQLite or Flat File).

## 🚀 The "Big Wins"
- **Reactive Pulse:** First time the agent wakes up because of a slot event without polling.
- **ZK-Factura:** Generate a Noir proof of a compliant payment.
- **Merchant Hub:** Deploy the first `/.well-known/xb77.json` for a test business.

## Success Metrics
- Binary Size: < 500 KB (ReleaseSmall).
- Memory Usage: < 10 MB in operation.
- Latency: < 50ms (Event to Decision).
