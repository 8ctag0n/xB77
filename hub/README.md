# MiniHub (Owner Control Plane)

Local hub that registers MCP agents, dispatches tool calls, and optionally spawns CLI agents.

## Run

```bash
bun --hot hub/index.ts
```

Visit `http://localhost:7777`.

## Observability panel

The Hub can pull live state via MCP tool calls. To enable this, run the MCP server
in HTTP mode and register the agent with the `/tool` endpoint.

```bash
MCP_HTTP_PORT=7001 bun run src/http.ts
```

Then register the agent with `mcp_url` set to `http://localhost:7001/tool`.

## Environment

- `PORT`: Hub port (default: `7777`).
- `HUB_TOKEN`: Optional token for auth (set in UI header).
- `HUB_ALLOW_SPAWN`: `true` to enable `/spawn` and process controls.

## Endpoints

- `POST /register` → register an agent (http or stdio).
- `POST /heartbeat` → update agent status.
- `GET /agents` → list agents.
- `POST /agent/:id/tool` → proxy tool call (http only).
- `POST /spawn` → spawn a CLI MCP process (requires `HUB_ALLOW_SPAWN=true`).
- `GET /processes` → list spawned processes.
- `POST /process/:id/stop` → stop a spawned process.

## Agent Registration Payload

```json
{
  "agent_id": "agent-alpha",
  "mcp_url": "http://localhost:7001/tool",
  "transport": "http",
  "capabilities": ["agent.pay", "agent.status"],
  "pubkey": "base58..."
}
```

## Spawn Payload

```json
{
  "agent_id": "agent-alpha",
  "command": "bun",
  "args": ["run", "mcp/src/index.ts"],
  "cwd": "/path/to/repo",
  "env": {
    "XB77_KEYPAIR_PATH": "/path/to/keypair.json",
    "XB77_OFFLINE": "true"
  }
}
```
