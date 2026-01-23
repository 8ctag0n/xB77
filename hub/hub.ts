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
const observabilityStatus = document.getElementById('observability-status') as HTMLDivElement;
const refreshObservability = document.getElementById(
  'refresh-observability'
) as HTMLButtonElement;
const obsBalance = document.getElementById('obs-balance') as HTMLDivElement;
const obsBalanceMeta = document.getElementById('obs-balance-meta') as HTMLDivElement;
const obsLatestReceipt = document.getElementById('obs-latest-receipt') as HTMLPreElement;
const obsReceipts = document.getElementById('obs-receipts') as HTMLDivElement;

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
  refreshObservabilityPanel().catch(() => null);
}

function getSelectedAgent() {
  return agents.find((agent) => agent.id === selectedAgentId) ?? null;
}

function unwrapToolResponse(response: any) {
  const data = response?.data ?? response;
  const text = data?.content?.[0]?.text;
  if (typeof text === 'string') {
    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }
  return data;
}

function extractToolError(payload: any): string | null {
  if (!payload) {
    return 'No response.';
  }
  if (payload?.isError && Array.isArray(payload?.content)) {
    const text = payload.content[0]?.text;
    if (typeof text === 'string') {
      try {
        const parsed = JSON.parse(text);
        return parsed?.error?.message ?? text;
      } catch {
        return text;
      }
    }
  }
  return null;
}

async function callTool(name: string, args: Record<string, unknown> = {}) {
  if (!selectedAgentId) {
    throw new Error('Select an agent first.');
  }
  return await fetchJson(`/agent/${selectedAgentId}/tool`, {
    method: 'POST',
    body: JSON.stringify({ name, arguments: args }),
  });
}

function formatTimestamp(value: unknown): string {
  if (typeof value !== 'number') {
    return 'n/a';
  }
  return new Date(value).toLocaleString();
}

function renderBalance(balance: any) {
  if (balance == null) {
    obsBalance.textContent = '-';
    obsBalanceMeta.textContent = '';
    return;
  }
  if (typeof balance === 'number' || typeof balance === 'string') {
    obsBalance.textContent = String(balance);
    obsBalanceMeta.textContent = '';
    return;
  }
  if (typeof balance === 'object' && 'available' in balance) {
    obsBalance.textContent = String((balance as any).available);
    obsBalanceMeta.textContent = JSON.stringify(balance);
    return;
  }
  obsBalance.textContent = 'object';
  obsBalanceMeta.textContent = JSON.stringify(balance);
}

function renderLatestReceipt(receipt: any) {
  if (!receipt) {
    obsLatestReceipt.classList.add('muted');
    obsLatestReceipt.textContent = 'No data yet.';
    return;
  }
  obsLatestReceipt.classList.remove('muted');
  obsLatestReceipt.textContent = JSON.stringify(receipt, null, 2);
}

function renderReceiptsList(receipts: any) {
  obsReceipts.innerHTML = '';
  if (!Array.isArray(receipts) || receipts.length === 0) {
    obsReceipts.classList.add('muted');
    obsReceipts.textContent = 'No receipts yet.';
    return;
  }
  obsReceipts.classList.remove('muted');
  receipts.forEach((receipt: any) => {
    const row = document.createElement('div');
    row.className = 'receipt-item';
    const summary = `${receipt?.amount ?? '-'} ${receipt?.token ?? ''} → ${
      receipt?.recipient ?? 'unknown'
    }`;
    row.innerHTML = `
      <div>${summary}</div>
      <div class="receipt-meta">${receipt?.type ?? 'n/a'} · ${formatTimestamp(
        receipt?.timestamp
      )}</div>
    `;
    obsReceipts.appendChild(row);
  });
}

async function refreshObservabilityPanel() {
  const selected = getSelectedAgent();
  if (!selected) {
    observabilityStatus.classList.add('muted');
    observabilityStatus.textContent = 'Select an agent to load live state.';
    renderBalance(null);
    renderLatestReceipt(null);
    renderReceiptsList([]);
    return;
  }
  if (selected.transport === 'stdio') {
    observabilityStatus.classList.add('muted');
    observabilityStatus.textContent = 'HTTP transport required for live tool calls.';
    renderBalance(null);
    renderLatestReceipt(null);
    renderReceiptsList([]);
    return;
  }
  observabilityStatus.classList.remove('muted');
  observabilityStatus.textContent = 'Loading...';
  try {
    const [stateResponse, listResponse] = await Promise.all([
      callTool('agent.state.get', {}),
      callTool('agent.receipts.list', { limit: 5 }),
    ]);

    const statePayload = unwrapToolResponse(stateResponse);
    const listPayload = unwrapToolResponse(listResponse);

    const stateError = extractToolError(statePayload);
    const listError = extractToolError(listPayload);
    if (stateError || listError) {
      throw new Error(stateError ?? listError ?? 'Tool error.');
    }

    renderBalance(statePayload?.balance ?? statePayload?.data?.balance);
    renderLatestReceipt(statePayload?.latestReceipt ?? statePayload?.data?.latestReceipt);
    renderReceiptsList(listPayload);
    observabilityStatus.textContent = `Updated ${new Date().toLocaleTimeString()}`;
  } catch (error: any) {
    observabilityStatus.classList.add('muted');
    observabilityStatus.textContent = `Error: ${error.message ?? 'failed to load'}`;
    renderBalance(null);
    renderLatestReceipt(null);
    renderReceiptsList([]);
  }
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
refreshObservability.addEventListener('click', () => refreshObservabilityPanel());
registerForm.addEventListener('submit', submitRegister);
spawnForm.addEventListener('submit', submitSpawn);
toolForm.addEventListener('submit', submitTool);

refreshAgents().catch(() => null);
refreshProcessList().catch(() => null);
refreshObservabilityPanel().catch(() => null);
setInterval(() => {
  refreshAgents().catch(() => null);
  refreshProcessList().catch(() => null);
}, 5000);

setInterval(() => {
  refreshObservabilityPanel().catch(() => null);
}, 10000);
