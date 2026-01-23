# xB77 Merchant Hub

A dual-mode interface serving as both a **Commercial Terminal** for merchants and a **Control Plane** for the autonomous agent.

## Modes

1.  **Merchant Terminal:**
    - POS-like interface for listing products and accepting payments.
    - Strategy Selector (Privacy Cash vs Starpay).
    - Real-time sales activity feed.

2.  **Control Plane (MiniHub):**
    - Technical dashboard to register and monitor MCP agents.
    - Tool dispatcher and process manager.

## Run

```bash
bun --hot hub/index.ts
```

Visit `http://localhost:7777`.

## Usage Flow

1.  **Start the Hub:** Run the command above.
2.  **Start an Agent:** In a separate terminal, run `MCP_HTTP_PORT=7001 bun run mcp/src/http.ts`.
3.  **Connect:** Go to the **Control Plane** tab in the Hub. Register the agent (`http://localhost:7001/tool`).
4.  **Transact:** Switch to the **Terminal** tab. Select a strategy and click "Buy Now" on any product. The Hub will dispatch `agent.pay` commands to the connected agent.

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
