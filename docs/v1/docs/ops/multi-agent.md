---
pageClass: is-legacy-page
---
# Multi-Agent Deployment (Hub + MCP)

1. **Each agent must have its own runtime context.**
   - `MCP_HTTP_PORT`: override the HTTP port before running `bun run mcp/src/http.ts` (e.g. `MCP_HTTP_PORT=7001` for agent-A, `MCP_HTTP_PORT=7002` for agent-B).
   - `XB77_KEYPAIR_PATH` / `XB77_KEYPAIR_JSON`: point to a dedicated keypair for each agent so `PrivacyAgent` instances stay isolated.
   - `XB77_DB_PATH`: default is `xb77_agent_<agentPubkey>.db` (auto-derived from the keypair). Set explicitly when you want to control the file name, e.g. `XB77_DB_PATH=./data/agent-alpha.db`.

2. **Run the Hub with spawn/registry enabled.**
   - Start the Hub (`bun --hot hub/index.ts`) and optionally set `HUB_ALLOW_SPAWN=`true`` if you want the Hub to launch agents.
   - Register each agent via `POST /register` (or allow auto-registration from `mcp/src/http.ts`). Example payload:
     ```json
     {
       "agent_id": "agent-alpha",
       "mcp_url": "http://localhost:7001/tool",
       "transport": "http",
       "capabilities": ["agent.pay","agent.status"],
       "pubkey": "<agent-public-key>"
     }
     ```
   - After registration the Hub shows status in the Control Plane tab under **Agents**.

3. **Sample workflow for two agents.**
   | Agent | Command | Keypair env | Port | DB path |
   | --- | --- | --- | --- | --- |
   | agent-alpha | `MCP_HTTP_PORT=7001 XB77_DB_PATH=./data/agent-alpha.db XB77_KEYPAIR_PATH=./keys/alpha.json bun run mcp/src/http.ts` | `./keys/alpha.json` | 7001 | `./data/agent-alpha.db` |
   | agent-bravo | `MCP_HTTP_PORT=7002 XB77_DB_PATH=./data/agent-bravo.db XB77_KEYPAIR_PATH=./keys/bravo.json bun run mcp/src/http.ts` | `./keys/bravo.json` | 7002 | `./data/agent-bravo.db` |

4. **Listeners / Governance.**
   - Point agents at the same listener (`XB77_LISTENER_URL`) so governance/reports stay centralized.
   - If multiple listeners are needed, set `XB77_LISTENER_URL` per agent to keep governance queues separate.
   - Use the listener’s `/governance/requests?agent_id=<agent>` endpoint to pull only the approvals for a given agent; requests now TTL after 5 minutes so the store does not grow forever.

5. **Verification steps**
   - After starting each agent, call `GET /agents` on the Hub to confirm statuses.
   - Use the Hub **Control Plane** tab to issue `agent.pay` calls or request `agent.receipts.latest`.
   - Check each agent’s SQLite file to ensure receipts are namespaced (files should contain `<agentId>` in the name unless overridden).

Keeping the port, keypair, and DB path per agent guarantees the Control Plane can scale beyond a single mock runtime and avoids collisions when you bring the stack to devnet or the hackathon demo stage.
