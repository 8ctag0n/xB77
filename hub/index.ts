import index from './index.html';

type AgentRecord = {
  id: string;
  mcpUrl: string;
  capabilities: string[];
  pubkey?: string;
  version?: string;
  metadata?: Record<string, unknown>;
  registeredAt: number;
  lastSeen: number;
};

const PORT = Number(Bun.env.PORT ?? 7777);
const HUB_TOKEN = Bun.env.HUB_TOKEN;
const STALE_AFTER_MS = 45_000;
const registry = new Map<string, AgentRecord>();

function jsonResponse(payload: unknown, status: number = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: {
      'content-type': 'application/json',
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET,POST,OPTIONS',
      'access-control-allow-headers': 'content-type,x-hub-token',
    },
  });
}

function unauthorized() {
  return jsonResponse({ ok: false, error: 'unauthorized' }, 401);
}

function requireAuth(req: Request) {
  if (!HUB_TOKEN) {
    return true;
  }
  return req.headers.get('x-hub-token') === HUB_TOKEN;
}

async function readJson(req: Request) {
  try {
    return await req.json();
  } catch {
    return null;
  }
}

function normalizeAgent(payload: any) {
  const id = payload?.agent_id ?? payload?.agentId;
  const mcpUrl = payload?.mcp_url ?? payload?.mcpUrl;
  if (!id || !mcpUrl) {
    throw new Error('agent_id and mcp_url are required');
  }
  const capabilities = Array.isArray(payload?.capabilities)
    ? payload.capabilities.map((item: string) => item.trim()).filter(Boolean)
    : [];
  return {
    id: String(id),
    mcpUrl: String(mcpUrl),
    capabilities,
    pubkey: payload?.pubkey ? String(payload.pubkey) : undefined,
    version: payload?.version ? String(payload.version) : undefined,
    metadata: payload?.metadata ?? undefined,
  };
}

function buildPublicAgent(record: AgentRecord) {
  const now = Date.now();
  const age = now - record.lastSeen;
  return {
    id: record.id,
    mcpUrl: record.mcpUrl,
    capabilities: record.capabilities,
    pubkey: record.pubkey,
    version: record.version,
    metadata: record.metadata,
    registeredAt: record.registeredAt,
    lastSeen: record.lastSeen,
    lastSeenAgeMs: age,
    status: age < STALE_AFTER_MS ? 'online' : 'stale',
  };
}

const server = Bun.serve({
  port: PORT,
  routes: {
    '/': index,
    '/register': {
      POST: async (req) => {
        if (!requireAuth(req)) {
          return unauthorized();
        }
        const payload = await readJson(req);
        if (!payload) {
          return jsonResponse({ ok: false, error: 'invalid_json' }, 400);
        }
        try {
          const normalized = normalizeAgent(payload);
          const now = Date.now();
          const record: AgentRecord = {
            ...normalized,
            registeredAt: registry.get(normalized.id)?.registeredAt ?? now,
            lastSeen: now,
          };
          registry.set(normalized.id, record);
          return jsonResponse({ ok: true, agent: buildPublicAgent(record) });
        } catch (error: any) {
          return jsonResponse({ ok: false, error: error.message }, 400);
        }
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/heartbeat': {
      POST: async (req) => {
        if (!requireAuth(req)) {
          return unauthorized();
        }
        const payload = await readJson(req);
        if (!payload) {
          return jsonResponse({ ok: false, error: 'invalid_json' }, 400);
        }
        const id = payload?.agent_id ?? payload?.agentId;
        if (!id || !registry.has(String(id))) {
          return jsonResponse({ ok: false, error: 'unknown_agent' }, 404);
        }
        const record = registry.get(String(id))!;
        record.lastSeen = Date.now();
        if (payload?.metadata) {
          record.metadata = payload.metadata;
        }
        registry.set(record.id, record);
        return jsonResponse({ ok: true, agent: buildPublicAgent(record) });
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/agents': {
      GET: () => {
        const agents = Array.from(registry.values()).map(buildPublicAgent);
        return jsonResponse({ ok: true, agents });
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/agent/:id': {
      GET: (req) => {
        const record = registry.get(req.params.id);
        if (!record) {
          return jsonResponse({ ok: false, error: 'unknown_agent' }, 404);
        }
        return jsonResponse({ ok: true, agent: buildPublicAgent(record) });
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/agent/:id/tool': {
      POST: async (req) => {
        if (!requireAuth(req)) {
          return unauthorized();
        }
        const record = registry.get(req.params.id);
        if (!record) {
          return jsonResponse({ ok: false, error: 'unknown_agent' }, 404);
        }
        const payload = await readJson(req);
        if (!payload) {
          return jsonResponse({ ok: false, error: 'invalid_json' }, 400);
        }
        try {
          const response = await fetch(record.mcpUrl, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(payload),
          });
          const text = await response.text();
          const data = (() => {
            try {
              return JSON.parse(text);
            } catch {
              return text;
            }
          })();
          return jsonResponse({ ok: response.ok, status: response.status, data });
        } catch (error: any) {
          return jsonResponse({ ok: false, error: error.message }, 502);
        }
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
  },
});

console.log(`MiniHub listening on http://localhost:${server.port}`);
