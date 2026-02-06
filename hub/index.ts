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
  transport: 'http' | 'stdio';
};

type ProcessRecord = {
  id: string;
  agentId: string;
  command: string;
  args: string[];
  cwd?: string;
  env?: Record<string, string>;
  pid: number;
  startedAt: number;
  status: 'running' | 'stopped';
  exitCode?: number;
};

const PORT = Number(Bun.env.PORT ?? 7777);
const HUB_TOKEN = Bun.env.HUB_TOKEN;
const ALLOW_SPAWN = Bun.env.HUB_ALLOW_SPAWN === 'true';
const STALE_AFTER_MS = 45_000;
const registry = new Map<string, AgentRecord>();
const processes = new Map<string, ProcessRecord>();
const spawnedPids = new Set<number>();

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
  const transport = payload?.transport === 'stdio' ? 'stdio' : 'http';
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
    transport,
  };
}

function upsertAgent(payload: any) {
  const normalized = normalizeAgent(payload);
  const now = Date.now();
  const record: AgentRecord = {
    ...normalized,
    registeredAt: registry.get(normalized.id)?.registeredAt ?? now,
    lastSeen: now,
  };
  registry.set(normalized.id, record);
  return record;
}

function spawnProcess(params: {
  agentId: string;
  command: string;
  args?: string[];
  cwd?: string;
  env?: Record<string, string>;
  capabilities?: string[];
  registerAgent?: boolean;
  transport?: 'http' | 'stdio';
  mcpUrl?: string;
}) {
  const id = `${params.agentId}-${Date.now()}`;
  const proc = Bun.spawn({
    cmd: [params.command, ...(params.args ?? [])],
    cwd: params.cwd,
    env: params.env,
    stdout: 'pipe',
    stderr: 'pipe',
  });

  const record: ProcessRecord = {
    id,
    agentId: params.agentId,
    command: params.command,
    args: params.args ?? [],
    cwd: params.cwd,
    env: params.env,
    pid: proc.pid,
    startedAt: Date.now(),
    status: 'running',
  };
  processes.set(id, record);
  spawnedPids.add(proc.pid);

  if (params.registerAgent) {
    const now = Date.now();
    registry.set(params.agentId, {
      id: params.agentId,
      mcpUrl:
        params.mcpUrl ??
        `http://localhost:${params.env?.MCP_HTTP_PORT ?? '7001'}/tool`,
      capabilities: params.capabilities ?? [],
      registeredAt: registry.get(params.agentId)?.registeredAt ?? now,
      lastSeen: now,
      transport: params.transport ?? 'http',
    });
  }

  proc.exited.then((exitCode) => {
    const stored = processes.get(id);
    if (stored) {
      stored.status = 'stopped';
      stored.exitCode = exitCode;
      processes.set(id, stored);
    }
  });

  return record;
}

function shutdownChildren() {
  for (const pid of spawnedPids) {
    try {
      process.kill(pid);
    } catch {}
  }
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
    transport: record.transport,
  };
}

const server = Bun.serve({
  port: PORT,
  routes: {
    '/': index,
    '/hub.ts': {
      GET: async () => {
        const file = Bun.file(new URL('./hub.ts', import.meta.url));
        const text = await file.text();
        const transpiler = new Bun.Transpiler({ loader: 'ts' });
        const js = transpiler.transformSync(text);
        return new Response(js, {
          headers: { 'content-type': 'application/javascript' },
        });
      },
    },
    '/hub.css': {
      GET: () =>
        new Response(Bun.file(new URL('./hub.css', import.meta.url)), {
          headers: { 'content-type': 'text/css' },
        }),
    },
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
          const record = upsertAgent(payload);
          return jsonResponse({ ok: true, agent: buildPublicAgent(record) });
        } catch (error: any) {
          return jsonResponse({ ok: false, error: error.message }, 400);
        }
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/spawn': {
      POST: async (req) => {
        if (!requireAuth(req)) {
          return unauthorized();
        }
        if (!ALLOW_SPAWN) {
          return jsonResponse({ ok: false, error: 'spawn_disabled' }, 403);
        }
        const payload = await readJson(req);
        if (!payload) {
          return jsonResponse({ ok: false, error: 'invalid_json' }, 400);
        }
        const agentId = payload?.agent_id ?? payload?.agentId;
        const command = payload?.command;
        const args = Array.isArray(payload?.args) ? payload.args.map(String) : [];
        const transport = payload?.transport === 'http' ? 'http' : 'stdio';
        const mcpUrl =
          transport === 'http'
            ? String(payload?.mcp_url ?? payload?.mcpUrl ?? '')
            : `stdio://${agentId}`;
        if (!agentId || !command) {
          return jsonResponse({ ok: false, error: 'agent_id and command are required' }, 400);
        }
        if (transport === 'http' && !mcpUrl) {
          return jsonResponse({ ok: false, error: 'mcp_url is required for http transport' }, 400);
        }

        const env =
          payload?.env && typeof payload.env === 'object'
            ? Object.fromEntries(
                Object.entries(payload.env).map(([key, value]) => [key, String(value)])
              )
            : undefined;
        const cwd = payload?.cwd ? String(payload.cwd) : undefined;
        const record = spawnProcess({
          agentId: String(agentId),
          command: String(command),
          args,
          cwd,
          env,
          capabilities: Array.isArray(payload?.capabilities) ? payload.capabilities : [],
          registerAgent: true,
          transport,
          mcpUrl,
        });

        return jsonResponse({ ok: true, process: record });
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/processes': {
      GET: () => {
        return jsonResponse({ ok: true, processes: Array.from(processes.values()) });
      },
      OPTIONS: () => jsonResponse({ ok: true }),
    },
    '/process/:id/stop': {
      POST: async (req) => {
        if (!requireAuth(req)) {
          return unauthorized();
        }
        const record = processes.get(req.params.id);
        if (!record) {
          return jsonResponse({ ok: false, error: 'unknown_process' }, 404);
        }
        try {
          process.kill(record.pid);
          record.status = 'stopped';
          processes.set(record.id, record);
          return jsonResponse({ ok: true, process: record });
        } catch (error: any) {
          return jsonResponse({ ok: false, error: error.message }, 500);
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
        if (record.transport === 'stdio') {
          return jsonResponse({ ok: false, error: 'tool_unavailable_for_stdio' }, 409);
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

if (Bun.env.HUB_BOOTSTRAP === 'true') {
  const root = new URL('..', import.meta.url).pathname;
  const mcpPort = Bun.env.MCP_HTTP_PORT ?? '7001';
  const listenerPort = Bun.env.LISTENER_PORT ?? '7002';
  const agentId = Bun.env.HUB_BOOTSTRAP_AGENT_ID ?? 'agent-alpha';

  const sharedEnv = {
    ...process.env,
    MCP_HTTP_PORT: mcpPort,
    LISTENER_PORT: listenerPort,
    XB77_PAYMENT_MODE: Bun.env.XB77_PAYMENT_MODE ?? 'mock',
    XB77_OFFLINE: Bun.env.XB77_OFFLINE ?? 'true',
  } as Record<string, string>;

  spawnProcess({
    agentId: 'listener',
    command: 'bun',
    args: ['run', 'mcp/src/listener.ts'],
    cwd: root,
    env: {
      ...sharedEnv,
      XB77_LISTENER_URL: `http://localhost:${listenerPort}`,
    },
  });

  spawnProcess({
    agentId,
    command: 'bun',
    args: ['run', 'mcp/src/http.ts'],
    cwd: root,
    env: sharedEnv,
    capabilities: ['agent.pay', 'agent.status', 'agent.receipts.latest'],
    registerAgent: true,
  });

  console.log(`[Boot] Spawned listener on :${listenerPort} and agent ${agentId} on :${mcpPort}`);
}

process.on('SIGINT', () => {
  shutdownChildren();
  process.exit(0);
});
