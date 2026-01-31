import type { AgentContext } from './agent_tools.ts';
import { buildAgentContext, handleToolCall, listTools } from './agent_tools.ts';

const PORT = Number(Bun.env.MCP_HTTP_PORT ?? 7001);

function jsonResponse(payload: unknown, status: number = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: {
      'content-type': 'application/json',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET,POST,OPTIONS',
      'access-control-allow-headers': 'content-type',
    },
  });
}

async function readJson(req: Request) {
  try {
    return await req.json();
  } catch {
    return null;
  }
}

let context: AgentContext;
try {
  context = await buildAgentContext();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[xb77-mcp] http startup failed: ${message}`);
  process.exit(1);
}

const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    if (req.method === 'OPTIONS') {
      return jsonResponse({ ok: true });
    }
    const url = new URL(req.url);
    if (req.method === 'GET' && url.pathname === '/health') {
      return jsonResponse({ ok: true, status: 'ok' });
    }
    if (req.method === 'GET' && url.pathname === '/tools') {
      return jsonResponse({ ok: true, tools: listTools() });
    }
    if (req.method === 'POST' && url.pathname === '/tool') {
      const payload = await readJson(req);
      if (!payload) {
        return jsonResponse({ ok: false, error: 'invalid_json' }, 400);
      }
      const name = payload?.name;
      const args = payload?.arguments;
      if (!name || typeof name !== 'string') {
        return jsonResponse({ ok: false, error: 'missing_tool_name' }, 400);
      }
      const response = await handleToolCall(context, name, args ?? {});
      return jsonResponse(response);
    }
    return jsonResponse({ ok: false, error: 'not_found' }, 404);
  },
});

console.log(`xb77 MCP HTTP listening on http://localhost:${server.port}`);
