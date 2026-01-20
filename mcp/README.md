# xb77 MCP (Agent-local)

Local MCP server that wraps the xb77 SDK for a single agent runtime.

## Run

```bash
bun install --cwd ../sdk
bun install
bun run src/index.ts
```

## Environment

- `XB77_KEYPAIR_JSON`: JSON array of 64 bytes for the agent keypair.
- `XB77_KEYPAIR_PATH`: Path to a JSON file with the 64-byte array.
- `XB77_DEBUG`: `true` to enable ShadowWire debug.
- `XB77_TOKEN_DEFAULT`: Default token for balance/state (default: `USD1`).
- `XB77_OFFLINE`: `true` to avoid network calls and simulate payments.
- `XB77_PAYMENT_MODE`: `mock` (default) or `live` to enable live ShadowWire calls.
- `XB77_PAYMENT_PROVIDER`: `shadowwire` (default) or `privacy_cash`.
- `XB77_BALANCES_JSON`: JSON object of token balances for offline mode (e.g. `{"USD1": 2500}`).

If both keypair vars are set, `XB77_KEYPAIR_JSON` takes precedence.

## Portable run

```bash
./run.sh
```

## Smoke test (offline)

```bash
bun run smoke
```

## Demo flow (offline)

```bash
bun run demo
```

## Error format

Tools return errors as JSON:

```json
{
  "error": {
    "message": "Missing or invalid recipient."
  }
}
```

## Prompt examples

- "Check the agent balance in USD1."
- "Pay 50 USD1 to <RECIPIENT> as internal transfer."
- "Show the latest receipt and summarize it."

## Client configs (examples)

Use the MCP stdio command entry your client expects, and point it at the MCP entry file.
Replace the `command`, `args`, or path as needed for your environment.

### Claude Desktop (MCP)

```json
{
  "name": "xb77-agent-mcp",
  "command": "bun",
  "args": ["run", "/path/to/repo/mcp/src/index.ts"],
  "env": {
    "XB77_KEYPAIR_PATH": "/path/to/solana-keypair.json",
    "XB77_DEBUG": "true",
    "XB77_TOKEN_DEFAULT": "USD1"
  }
}
```

### Gemini (MCP)

```json
{
  "name": "xb77-agent-mcp",
  "command": "bun",
  "args": ["run", "/path/to/repo/mcp/src/index.ts"],
  "env": {
    "XB77_KEYPAIR_PATH": "/path/to/solana-keypair.json",
    "XB77_TOKEN_DEFAULT": "USD1"
  }
}
```

### Codex (MCP)

```json
{
  "name": "xb77-agent-mcp",
  "command": "bun",
  "args": ["run", "/path/to/repo/mcp/src/index.ts"],
  "env": {
    "XB77_KEYPAIR_PATH": "/path/to/solana-keypair.json"
  }
}
```

### OpenCode (MCP)

```json
{
  "name": "xb77-agent-mcp",
  "command": "bun",
  "args": ["run", "/path/to/repo/mcp/src/index.ts"],
  "env": {
    "XB77_KEYPAIR_PATH": "/path/to/solana-keypair.json"
  }
}
```
