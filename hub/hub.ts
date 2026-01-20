type AgentSummary = {
  id: string;
  mcpUrl: string;
  capabilities: string[];
  pubkey?: string;
  version?: string;
  metadata?: Record<string, unknown>;
  registeredAt: number;
  lastSeen: number;
  lastSeenAgeMs: number;
  status: 'online' | 'stale';
  transport: 'http' | 'stdio';
};

type ProcessSummary = {
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

const agentsList = document.getElementById('agents-list') as HTMLDivElement;
const agentDetail = document.getElementById('agent-detail') as HTMLDivElement;
const refreshBtn = document.getElementById('refresh-btn') as HTMLButtonElement;
const hubTokenInput = document.getElementById('hub-token') as HTMLInputElement;
const registerForm = document.getElementById('register-form') as HTMLFormElement;
const spawnForm = document.getElementById('spawn-form') as HTMLFormElement;
const toolForm = document.getElementById('tool-form') as HTMLFormElement;
const toolResponse = document.getElementById('tool-response') as HTMLPreElement;
const processList = document.getElementById('process-list') as HTMLDivElement;
const refreshProcesses = document.getElementById('refresh-processes') as HTMLButtonElement;
const hubPort = document.getElementById('hub-port') as HTMLSpanElement | null;

let selectedAgentId: string | null = null;
let agents: AgentSummary[] = [];

if (hubPort) {
  hubPort.textContent = `:${window.location.port || '7777'}`;
}

function getHubToken(): string | undefined {
  const value = hubTokenInput?.value?.trim();
  return value || undefined;
}

function headers(): HeadersInit {
  const token = getHubToken();
  return token ? { 'x-hub-token': token } : {};
}

async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      'content-type': 'application/json',
      ...headers(),
      ...(init?.headers ?? {}),
    },
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed (${response.status})`);
  }
  return response.json() as Promise<T>;
}

function renderAgents(list: AgentSummary[]) {
  agentsList.innerHTML = '';
  if (list.length === 0) {
    agentsList.innerHTML = '<div class="empty muted">No agents registered.</div>';
    return;
  }

  list.forEach((agent) => {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = `agent-card ${agent.status}`;
    card.dataset.id = agent.id;
    if (agent.id === selectedAgentId) {
      card.classList.add('selected');
    }
    card.innerHTML = `
      <div>
        <div class="agent-title">${agent.id}</div>
        <div class="agent-meta">${agent.transport.toUpperCase()} · ${agent.capabilities.join(', ') || 'no caps'}</div>
      </div>
      <div class="agent-status">
        <span class="dot ${agent.status}"></span>
        ${agent.status}
      </div>
    `;
    card.addEventListener('click', () => selectAgent(agent.id));
    agentsList.appendChild(card);
  });
}

function renderAgentDetail(agent?: AgentSummary) {
  if (!agent) {
    agentDetail.classList.add('muted');
    agentDetail.textContent = 'Select an agent to see details.';
    return;
  }
  agentDetail.classList.remove('muted');
  agentDetail.innerHTML = `
    <div class="detail-row"><span>ID</span><strong>${agent.id}</strong></div>
    <div class="detail-row"><span>Status</span><strong>${agent.status}</strong></div>
    <div class="detail-row"><span>Transport</span><strong>${agent.transport}</strong></div>
    <div class="detail-row"><span>MCP URL</span><strong>${agent.mcpUrl}</strong></div>
    <div class="detail-row"><span>Capabilities</span><strong>${agent.capabilities.join(', ') || 'none'}</strong></div>
    <div class="detail-row"><span>Pubkey</span><strong>${agent.pubkey ?? 'n/a'}</strong></div>
    <div class="detail-row"><span>Last Seen</span><strong>${Math.round(agent.lastSeenAgeMs / 1000)}s ago</strong></div>
  `;
  if (agent.transport === 'stdio') {
    agentDetail.innerHTML += `<div class="detail-note">Tool calls are disabled for stdio agents.</div>`;
  }
}

function renderProcesses(list: ProcessSummary[]) {
  if (!list.length) {
    processList.classList.add('muted');
    processList.textContent = 'No processes yet.';
    return;
  }
  processList.classList.remove('muted');
  processList.innerHTML = '';
  list.forEach((process) => {
    const row = document.createElement('div');
    row.className = 'process-row';
    row.innerHTML = `
      <div>
        <div class="process-title">${process.agentId}</div>
        <div class="process-meta">pid ${process.pid} · ${process.command} ${process.args.join(' ')}</div>
      </div>
      <div class="process-actions">
        <span class="badge ${process.status}">${process.status}</span>
        <button data-id="${process.id}" ${process.status !== 'running' ? 'disabled' : ''}>Stop</button>
      </div>
    `;
    row.querySelector('button')?.addEventListener('click', () => stopProcess(process.id));
    processList.appendChild(row);
  });
}

async function refreshAgents() {
  const response = await fetchJson<{ ok: boolean; agents: AgentSummary[] }>('/agents');
  agents = response.agents;
  renderAgents(agents);
  renderAgentDetail(agents.find((agent) => agent.id === selectedAgentId));
}

async function refreshProcessList() {
  const response = await fetchJson<{ ok: boolean; processes: ProcessSummary[] }>('/processes');
  renderProcesses(response.processes);
}

function selectAgent(id: string) {
  selectedAgentId = id;
  renderAgents(agents);
  renderAgentDetail(agents.find((agent) => agent.id === selectedAgentId));
}

function getSelectedAgent() {
  return agents.find((agent) => agent.id === selectedAgentId) ?? null;
}

async function submitRegister(event: SubmitEvent) {
  event.preventDefault();
  const form = new FormData(registerForm);
  const payload = {
    agent_id: form.get('agent_id'),
    mcp_url: form.get('mcp_url'),
    transport: form.get('transport'),
    capabilities: String(form.get('capabilities') ?? '')
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean),
    pubkey: form.get('pubkey') || undefined,
  };
  await fetchJson('/register', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  registerForm.reset();
  await refreshAgents();
}

async function submitSpawn(event: SubmitEvent) {
  event.preventDefault();
  const form = new FormData(spawnForm);
  const rawEnv = String(form.get('env') ?? '{}').trim();
  let env: Record<string, string> | undefined;
  try {
    env = rawEnv ? (JSON.parse(rawEnv) as Record<string, string>) : undefined;
  } catch {
    toolResponse.classList.remove('muted');
    toolResponse.textContent = 'Invalid env JSON.';
    return;
  }
  const args = String(form.get('args') ?? '')
    .split(' ')
    .map((item) => item.trim())
    .filter(Boolean);
  const payload = {
    agent_id: form.get('agent_id'),
    command: form.get('command'),
    args,
    cwd: form.get('cwd') || undefined,
    env,
  };
  await fetchJson('/spawn', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  spawnForm.reset();
  await refreshProcessList();
  await refreshAgents();
}

async function submitTool(event: SubmitEvent) {
  event.preventDefault();
  if (!selectedAgentId) {
    toolResponse.classList.remove('muted');
    toolResponse.textContent = 'Select an agent first.';
    return;
  }
  const selected = getSelectedAgent();
  if (selected?.transport === 'stdio') {
    toolResponse.classList.remove('muted');
    toolResponse.textContent = 'Tool calls are disabled for stdio agents.';
    return;
  }
  const form = new FormData(toolForm);
  const tool = String(form.get('tool') ?? '').trim();
  const rawPayload = String(form.get('payload') ?? '{}');
  let payloadObject: unknown = {};
  try {
    payloadObject = rawPayload ? JSON.parse(rawPayload) : {};
  } catch {
    toolResponse.classList.remove('muted');
    toolResponse.textContent = 'Invalid JSON payload.';
    return;
  }
  const payload = {
    name: tool,
    arguments: payloadObject,
  };
  const response = await fetchJson(`/agent/${selectedAgentId}/tool`, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
  toolResponse.classList.remove('muted');
  toolResponse.textContent = JSON.stringify(response, null, 2);
}

async function stopProcess(id: string) {
  await fetchJson(`/process/${id}/stop`, { method: 'POST' });
  await refreshProcessList();
}

refreshBtn.addEventListener('click', () => refreshAgents());
refreshProcesses.addEventListener('click', () => refreshProcessList());
registerForm.addEventListener('submit', submitRegister);
spawnForm.addEventListener('submit', submitSpawn);
toolForm.addEventListener('submit', submitTool);

refreshAgents().catch(() => null);
refreshProcessList().catch(() => null);
setInterval(() => {
  refreshAgents().catch(() => null);
  refreshProcessList().catch(() => null);
}, 5000);
