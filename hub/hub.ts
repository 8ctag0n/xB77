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

// --- DOM Elements ---
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
const refreshObservability = document.getElementById('refresh-observability') as HTMLButtonElement;
const obsBalance = document.getElementById('obs-balance') as HTMLDivElement;
const obsBalanceMeta = document.getElementById('obs-balance-meta') as HTMLDivElement;
const obsLatestReceipt = document.getElementById('obs-latest-receipt') as HTMLPreElement;
const obsReceipts = document.getElementById('obs-receipts') as HTMLDivElement;
const connectionStatus = document.getElementById('connection-status') as HTMLSpanElement;

// Merchant Elements
const statSales = document.getElementById('stat-sales') as HTMLSpanElement;
const statPending = document.getElementById('stat-pending') as HTMLSpanElement;
const productGrid = document.getElementById('product-grid') as HTMLDivElement;
const activityFeed = document.getElementById('activity-feed') as HTMLDivElement;
const thoughtStream = document.getElementById('thought-stream') as HTMLDivElement;
const btnAddProduct = document.getElementById('btn-add-product') as HTMLButtonElement;

function logThought(message: string) {
  if (!thoughtStream) return;
  
  // Remove empty state if present
  const empty = thoughtStream.querySelector('.empty');
  if (empty) empty.remove();

  const entry = document.createElement('div');
  entry.className = 'thought-entry';
  entry.innerHTML = `
    <span class="thought-time">${new Date().toLocaleTimeString()}</span>
    ${message}
  `;
  thoughtStream.prepend(entry);

  // Keep limit
  if (thoughtStream.children.length > 50) {
    thoughtStream.lastElementChild?.remove();
  }
}

async function streamThoughts(thoughts: string[]) {
  for (const thought of thoughts) {
    logThought(thought);
    await new Promise(r => setTimeout(r, 400)); // Simulate thinking speed
  }
}

const LISTENER_URL = 'http://localhost:7002';

// --- State ---
let selectedAgentId: string | null = null;
let agents: AgentSummary[] = [];
let salesTotal = 0;
let pendingCount = 0;
let revealedReceipts = new Set<string>();

const PAYMENT_METHODS = {
  PRIVACY_CASH: 'privacy_cash',
  STARPAY: 'starpay',
  SHADOWWIRE: 'shadowwire',
};

// ... (previous code)

const govList = document.getElementById('governance-list') as HTMLDivElement;
const govLog = document.getElementById('gov-log') as HTMLDivElement;
const refreshGovBtn = document.getElementById('refresh-gov') as HTMLButtonElement;

function logGov(msg: string) {
  if (!govLog) return;
  const line = document.createElement('div');
  line.className = 'log-line';
  line.innerHTML = `<span class="time">${new Date().toLocaleTimeString()}</span> ${msg}`;
  govLog.appendChild(line);
  govLog.scrollTop = govLog.scrollHeight;
}

async function refreshGovernance() {
  if (!govList) return;
  try {
    const response = await fetch(`${LISTENER_URL}/governance/requests`);
    if (!response.ok) return;
    const { requests } = await response.json();
    
    govList.innerHTML = '';
    if (requests.length === 0) {
      govList.innerHTML = '<div class="empty-state">No pending requests.</div>';
      return;
    }

    requests.forEach((req: any) => {
      if (req.status !== 'pending') return; // Filter for pending only in this view
      
      const card = document.createElement('div');
      card.className = 'gov-card';
      card.id = `card-${req.id}`;
      card.innerHTML = `
        <div class="gov-header">
          <div class="gov-icon">${ICONS.LOCK}</div>
          <div class="gov-title">Encrypted Intent #${req.id.slice(-4)}</div>
          <div class="gov-agent">${req.agentId}</div>
        </div>
        <div class="gov-body">
          <div class="encrypted-blob">${req.encryptedPayload.slice(0, 32)}...</div>
          <div class="decrypted-content hidden" id="content-${req.id}">
             <!-- Injected after decrypt -->
          </div>
        </div>
        <div class="gov-actions">
           <button class="btn-sm btn-outline" onclick="window.decryptRequest('${req.id}', '${req.encryptedPayload}')">Decrypt & Inspect</button>
           <div class="approval-actions hidden" id="actions-${req.id}">
             <button class="btn-sm btn-danger" onclick="window.rejectRequest('${req.id}')">Reject</button>
             <button class="btn-sm btn-success" onclick="window.approveRequest('${req.id}')">Sign & Approve</button>
           </div>
        </div>
      `;
      govList.appendChild(card);
    });
  } catch (e) {
    console.error('Gov refresh failed', e);
  }
}

// Mock Decryption Key
const MASTER_KEY = "x77-shadow-key";

async function decryptRequest(id: string, payload: string) {
  logGov(`Decrypting intent ${id}...`);
  // Mock delay
  await new Promise(r => setTimeout(r, 600));
  
  // In a real scenario, we would use window.crypto.subtle to decrypt 'payload' using 'MASTER_KEY'
  // Here we just decode the mock payload which we assume is Base64 encoded JSON for the demo
  let content = "Unknown payload";
  try {
     content = atob(payload); // Mock: Payload is just base64 for demo
  } catch {
     content = "Failed to decrypt. Invalid ciphertext.";
  }

  const contentDiv = document.getElementById(`content-${id}`);
  const actionsDiv = document.getElementById(`actions-${id}`);
  
  if (contentDiv) {
    contentDiv.innerHTML = `
      <div class="intent-details">
        <div class="intent-row"><span>Action:</span> <strong>Transfer</strong></div>
        <div class="intent-row"><span>Amount:</span> <strong>${content.split('|')[1]}</strong></div>
        <div class="intent-row"><span>To:</span> <strong>${content.split('|')[2]}</strong></div>
        <div class="intent-row"><span>Reason:</span> <strong>${content.split('|')[3]}</strong></div>
      </div>
    `;
    contentDiv.classList.remove('hidden');
  }
  
  if (actionsDiv) {
    actionsDiv.classList.remove('hidden');
    // Hide the decrypt button parent
    const decryptBtn = actionsDiv.previousElementSibling;
    if (decryptBtn) decryptBtn.classList.add('hidden');
  }
  
  logGov(`Intent ${id} revealed.`);
}

async function approveRequest(id: string) {
  logGov(`Signing approval for ${id}...`);
  // Mock signing delay
  await new Promise(r => setTimeout(r, 800));
  
  try {
    await fetch(`${LISTENER_URL}/governance/approve/${id}`, { method: 'POST' });
    logGov(`Request ${id} APPROVED. Signature broadcasted.`);
    
    // UI Update
    const card = document.getElementById(`card-${id}`);
    if (card) {
      card.classList.add('approved-anim');
      setTimeout(() => card.remove(), 1000);
    }
  } catch (e) {
    logGov(`Error approving: ${e}`);
  }
}

async function rejectRequest(id: string) {
   try {
    await fetch(`${LISTENER_URL}/governance/reject/${id}`, { method: 'POST' });
    logGov(`Request ${id} REJECTED.`);
    const card = document.getElementById(`card-${id}`);
    if (card) card.remove();
  } catch (e) {
    logGov(`Error rejecting: ${e}`);
  }
}

// Expose globals
(window as any).decryptRequest = decryptRequest;
(window as any).approveRequest = approveRequest;
(window as any).rejectRequest = rejectRequest;

// ... (init)

if (refreshGovBtn) refreshGovBtn.addEventListener('click', () => refreshGovernance());

setInterval(() => {
  refreshGovernance().catch(() => null);
}, 5000);

// Update nav init to include governance refresh
// (Implicitly handled by polling, but nice to trigger on tab switch)
const govTab = document.querySelector('button[data-target="view-governance"]');
if (govTab) govTab.addEventListener('click', () => refreshGovernance());

const products = [
  { id: 'p1', name: 'AWS Credits ($100)', price: 95, icon: ICONS.CLOUD, recipient: 'So11111111111111111111111111111111111111112' },
  { id: 'p2', name: 'DevOps Hour', price: 150, icon: ICONS.TOOL, recipient: 'So11111111111111111111111111111111111111112' },
  { id: 'p3', name: 'VPN Subscription', price: 12, icon: ICONS.LOCK, recipient: 'So11111111111111111111111111111111111111112' },
  { id: 'p4', name: 'Dark Web Data', price: 499, icon: ICONS.DATA, recipient: 'BAD_sanctioned_address_123' },
  { id: 'p5', name: 'Quantum Farm', price: 50000, icon: ICONS.SHIELD, recipient: 'So11111111111111111111111111111111111111112' },
];

if (hubPort) {
  hubPort.textContent = `:${window.location.port || '7777'}`;
}

// --- Navigation ---
function initNav() {
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.nav-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
      
      tab.classList.add('active');
      const target = (tab as HTMLElement).dataset.target;
      if (target) {
        document.getElementById(target)?.classList.remove('hidden');
      }
    });
  });
}

// --- API Helpers ---
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

// --- Control Plane Logic ---

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

// --- Icons ---
const ICONS = {
  SHIELD: `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>`,
  LOCK: `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>`,
  UNLOCK: `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 9.9-1"></path></svg>`,
  BADGE: `<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.78 4.78 4 4 0 0 1-6.74 0 4 4 0 0 1-4.78-4.78"></path></svg>`,
  CHECK: `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>`,
  CLOUD: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"></path></svg>`,
  TOOL: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg>`,
  DATA: `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"></path><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"></path><ellipse cx="12" cy="5" rx="9" ry="3"></ellipse></svg>`,
};

// ... (existing code) ...

function renderAgentDetail(agent?: AgentSummary) {
  if (!agent) {
    agentDetail.classList.add('muted');
    agentDetail.textContent = 'Select an agent to see details.';
    connectionStatus.textContent = 'Disconnected';
    connectionStatus.style.color = 'var(--muted)';
    return;
  }
  
  // Mocking Noir Proof Data for Demo
  const hasBadge = true; 
  const badgeHtml = hasBadge ? `
    <div class="noir-badge" title="Verified by Noir ZK-Circuit">
      <div class="badge-icon">${ICONS.BADGE}</div>
      <div class="badge-info">
        <span class="badge-label">IDENTITY VERIFIED</span>
        <span class="badge-sub">Noir Proof: 0x9f...a2</span>
      </div>
      <div class="badge-check">${ICONS.CHECK}</div>
    </div>
  ` : '';

  agentDetail.classList.remove('muted');
  agentDetail.innerHTML = `
    <div class="detail-header">
      <div class="detail-title">
        <strong>${agent.id}</strong>
        ${badgeHtml}
      </div>
      <div class="agent-status-pill ${agent.status}">
        <span class="dot"></span> ${agent.status}
      </div>
    </div>
    
    <div class="detail-grid">
      <div class="detail-item">
        <label>Transport</label>
        <span>${agent.transport}</span>
      </div>
      <div class="detail-item">
        <label>Capabilities</label>
        <span>${agent.capabilities.length} active</span>
      </div>
      <div class="detail-item full-width">
        <label>MCP Endpoint</label>
        <span class="code-font">${agent.mcpUrl}</span>
      </div>
       <div class="detail-item full-width">
        <label>Public Key</label>
        <span class="code-font text-xs">${agent.pubkey ?? 'n/a'}</span>
      </div>
    </div>
    
    <div class="detail-footer">
      <span>Last seen ${Math.round(agent.lastSeenAgeMs / 1000)}s ago</span>
    </div>
  `;
  
  if (agent.transport === 'stdio') {
    agentDetail.innerHTML += `<div class="detail-note">Tool calls are disabled for stdio agents.</div>`;
  }
  
  if (agent.status === 'online') {
    connectionStatus.textContent = `Connected: ${agent.id}`;
    connectionStatus.style.color = 'var(--accent-2)';
  } else {
    connectionStatus.textContent = `Stale: ${agent.id}`;
    connectionStatus.style.color = 'var(--danger)';
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
  try {
    const response = await fetchJson<{ ok: boolean; agents: AgentSummary[] }>('/agents');
    agents = response.agents;
    
    // Auto-select first online agent if none selected
    if (!selectedAgentId && agents.length > 0) {
      const firstOnline = agents.find(a => a.status === 'online');
      if (firstOnline) selectAgent(firstOnline.id);
    }
    
    renderAgents(agents);
    renderAgentDetail(agents.find((agent) => agent.id === selectedAgentId));
  } catch (e) {
    console.error('Failed to refresh agents', e);
  }
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
  
  // CFO State (Snapshot with yield)
  if (typeof balance === 'object' && 'treasury' in balance) {
    const t = balance.treasury;
    const available = t.crypto.available || 0;
    const yieldAmt = t.yield?.available || 0;
    const total = available + yieldAmt;
    
    obsBalance.innerHTML = `
      <div class="balance-main">$${total.toFixed(2)}</div>
      <div class="balance-split">
        <span class="bal-cash" title="Liquid Privacy Rail">$${available.toFixed(2)}</span> + 
        <span class="bal-yield" title="Interest Bearing Assets (Kamino)">$${yieldAmt.toFixed(2)}</span>
      </div>
    `;
    obsBalanceMeta.innerHTML = `<span class="tag-solana">OPTIMIZING YIELD (8.5% APY)</span>`;
    return;
  }

  if (typeof balance === 'object' && 'credit' in balance) {
    const available = (balance as any).available || 0;
    const credit = (balance as any).credit || 0;
    const total = available + credit;
    
    obsBalance.innerHTML = `
      <div class="balance-main">$${total.toFixed(2)}</div>
      <div class="balance-split">
        <span class="bal-cash" title="Vault Cash">$${available.toFixed(2)}</span> + 
        <span class="bal-credit" title="On-Chain Credit">$${credit.toFixed(2)}</span>
      </div>
    `;
    obsBalanceMeta.innerHTML = `<span class="tag-solana">ON-CHAIN SYNCED</span>`;
    return;
  }

  if (typeof balance === 'number' || typeof balance === 'string') {
    obsBalance.textContent = `$${Number(balance).toFixed(2)}`;
    obsBalanceMeta.textContent = '';
    return;
  }
  
  obsBalance.textContent = String((balance as any).available || '0');
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

// --- Merchant Terminal Logic ---

function logActivity(message: string, type: 'info' | 'sale' = 'info') {
  const item = document.createElement('div');
  item.className = `feed-item ${type}`;
  item.innerHTML = `
    <span class="time">${new Date().toLocaleTimeString()}</span>
    ${message}
  `;
  activityFeed.prepend(item);
  // Keep limit
  if (activityFeed.children.length > 20) {
    activityFeed.lastElementChild?.remove();
  }
}

function toggleReceiptReveal(sig: string) {
  if (revealedReceipts.has(sig)) {
    revealedReceipts.delete(sig);
  } else {
    revealedReceipts.add(sig);
  }
  refreshLiveActivity().catch(() => null);
}

// ... (imports)

const invoiceModal = document.getElementById('invoice-modal') as HTMLDivElement;
const invId = document.getElementById('inv-id') as HTMLElement;
const invDate = document.getElementById('inv-date') as HTMLElement;
const invBody = document.getElementById('inv-body') as HTMLElement;
const invHash = document.getElementById('inv-hash') as HTMLElement;

async function showInvoice(receipt: any) {
  if (!invoiceModal) return;
  
  // 1. Show Loading State
  invId.textContent = "GENREATING CERTIFIED PROOF...";
  invBody.innerHTML = `<div class="loading-spinner"></div><p class="muted">Requesting selective disclosure from Agent Auditor...</p>`;
  invoiceModal.classList.remove('hidden');

  try {
    // 2. Call Auditor via MCP
    // We only reveal what's necessary for a basic invoice
    const response = await callTool('agent.audit.report', {
      receiptId: receipt.txSignature,
      fields: ['type', 'provider', 'metadata'] 
    });
    
    const proof = unwrapToolResponse(response);
    const data = proof.revealedData;

    // 3. Populate UI with Certified Data
    const vendor = data.metadata?.vendorName || receipt.recipient.slice(0, 8) + '...';
    const amount = data.amount / 100;
    const tax = amount * 0.21;
    const subtotal = amount - tax;
    
    invId.textContent = `#INV-${proof.receiptId.slice(0, 6).toUpperCase()}`;
    invDate.textContent = new Date(data.timestamp).toLocaleString();
    invHash.textContent = `ATTESTATION: ${proof.attestation.slice(0, 32)}...`;
    
    invBody.innerHTML = `
      <div class="line-item"><span>Vendor</span> <strong>${vendor}</strong></div>
      <div class="line-item"><span>Status</span> <span class="badge success">CERTIFIED</span></div>
      <div class="line-divider"></div>
      <div class="line-item"><span>Service (Audit Ready)</span> <span>$${subtotal.toFixed(2)}</span></div>
      <div class="line-item"><span>VAT (21%)</span> <span>$${tax.toFixed(2)}</span></div>
      <div class="line-divider"></div>
      <div class="invoice-total"><span>TOTAL</span> <span>$${amount.toFixed(2)}</span></div>
      
      <div class="verification-zone" id="verif-${proof.receiptId}">
         <button class="btn-verify" onclick="window.verifyOnChain('${proof.receiptId}', '${proof.attestation}')">
           Verify ZK-Proof on Solana
         </button>
      </div>

      <div class="proof-footer">
        <label>Agent Attestation (Ed25519)</label>
        <div class="code-font text-xxs break-all">${proof.attestation}</div>
      </div>
    `;

  } catch (e: any) {
    invId.textContent = "AUDIT ERROR";
    invBody.innerHTML = `<p class="danger">Failed to generate proof: ${e.message}</p>`;
  }
}

async function verifyOnChain(receiptId: string, attestation: string) {
  const zone = document.getElementById(`verif-${receiptId}`);
  if (!zone) return;

  zone.innerHTML = `<div class="loading-spinner"></div><p class="text-xxs muted">Invoking On-Chain Verifier...</p>`;

  try {
    const response = await callTool('agent.audit.verify_onchain', {
      receiptId,
      proof: attestation
    });
    
    const result = unwrapToolResponse(response);

    zone.innerHTML = `
      <div class="zk-success-badge">
        <span class="icon">✅</span>
        <div class="text">
          <strong>MATH VERIFIED ON-CHAIN</strong>
          <span>Ref: ${result.onChainRef}</span>
        </div>
      </div>
    `;
    
    logThought(`Proof for ${receiptId.slice(0,8)} verified by Solana Verifier Program.`);
  } catch (e: any) {
    zone.innerHTML = `<p class="danger text-xs">Verification failed: ${e.message}</p>`;
  }
}

(window as any).verifyOnChain = verifyOnChain;
(window as any).showInvoice = showInvoice; // Expose for onclick

async function refreshLiveActivity() {
  try {
    const response = await fetch(`${LISTENER_URL}/history?limit=10`);
    if (!response.ok) return;
    const { receipts } = await response.json();
    
    activityFeed.innerHTML = '';
    
    receipts.forEach((r: any) => {
      const isPrivate = r.provider === 'shadowwire' || r.provider === 'privacy_cash';
      const isRevealed = revealedReceipts.has(r.txSignature);
      const item = document.createElement('div');
      item.className = `feed-item ${r.type === 'external' ? 'sale' : 'info'}`;
      
      const amountDisplay = (isPrivate && !isRevealed) ? '*******' : `$${(r.amount / 100).toFixed(2)}`;
      const vendorDisplay = (isPrivate && !isRevealed) ? 'Shielded Destination' : (r.metadata?.vendorName || r.recipient.slice(0, 8) + '...');
      const privacyIcon = isPrivate ? '🔒' : '🔓';
      
      // Pass the whole receipt object to the function. We need to serialize it safely or store it.
      // For simplicity in this demo, we'll attach it to the button's click handler via closure? 
      // No, passing JSON string in HTML is messy. Let's just pass the ID/Sig and find it? 
      // Or just pass the fields we need. 
      // Better: Store receipts in a map? 
      // Simplest for now: Pass key fields.
      const safeVendor = (r.metadata?.vendorName || 'Unknown').replace(/'/g, "\\'");
      
      // Using a global map to store receipts for easy access by ID would be cleaner, 
      // but let's just stick the receipt JSON into a data attribute for the "View Invoice" button.
      const receiptJson = JSON.stringify(r).replace(/"/g, '&quot;');

      item.innerHTML = `
        <span class="time">${new Date(r.timestamp).toLocaleTimeString()}</span>
        <div class="feed-content">
          <span class="privacy-toggle" onclick="window.toggleReceiptReveal('${r.txSignature}')">${privacyIcon}</span>
          <strong>${amountDisplay}</strong> to ${vendorDisplay}
          <div class="receipt-meta">
            ${r.provider} · ${r.txSignature.slice(0, 8)}...
            <button class="btn-invoice" onclick='window.showInvoice(${receiptJson})'>📄 Invoice</button>
          </div>
        </div>
      `;
      activityFeed.appendChild(item);
    });
  } catch (e) {
    // Silent fail for polling
  }
}

// ... (rest of code)

// Expose to window for onclick
(window as any).toggleReceiptReveal = toggleReceiptReveal;

function renderProductGrid() {
  productGrid.innerHTML = '';
  products.forEach(p => {
    const card = document.createElement('div');
    card.className = 'product-card';
    card.innerHTML = `
      <div class="product-icon">${p.icon}</div>
      <div class="product-info">
        <h3>${p.name}</h3>
        <div class="product-price">$${p.price.toFixed(2)}</div>
      </div>
      <button class="btn-sm" data-id="${p.id}">Buy Now</button>
    `;
    card.querySelector('button')?.addEventListener('click', () => handleBuy(p));
    productGrid.appendChild(card);
  });
}

const complianceModal = document.getElementById('compliance-modal') as HTMLDivElement;
const riskEntity = document.getElementById('risk-entity') as HTMLElement;
const riskScore = document.getElementById('risk-score') as HTMLElement;
const riskReason = document.getElementById('risk-reason') as HTMLElement;
const closeModal = document.getElementById('close-modal') as HTMLButtonElement;

if (closeModal) {
  closeModal.onclick = () => complianceModal.classList.add('hidden');
}

function showComplianceAlert(error: any) {
  if (riskEntity) riskEntity.textContent = 'Sanctioned Address';
  if (riskScore) riskScore.textContent = 'High Risk (90/100)';
  if (riskReason) riskReason.textContent = error || 'Range Protocol Flag';
  complianceModal.classList.remove('hidden');
}

async function handleBuy(product: typeof products[0]) {
  const agent = getSelectedAgent();
  if (!agent) {
    alert('No agent connected. Please connect an agent in the Control Plane.');
    return;
  }

  // 1. STRATEGY ANALYSIS
  logActivity(`🤖 Analyzing optimal route for ${product.name}...`);
  logThought(`Analyzing purchase intent: ${product.name} ($${product.price})`);

  try {
    const strategyRes = await callTool('agent.strategy.evaluate', {
      recipient: product.recipient,
      amount: product.price * 100,
      context: {
        vendorCategory: product.price > 1000 ? 'high_value_asset' : 'standard',
        isNewVendor: product.recipient.startsWith('BAD') // Simulating heuristic
      }
    });
    
    const strategy = unwrapToolResponse(strategyRes);
    
    // Stream agent reasoning to the sidebar
    if (strategy.thoughts) {
      await streamThoughts(strategy.thoughts);
    }
    
    // Visual Feedback based on strategy
    if (strategy.privacyLevel === 'ghost') {
       logActivity(`👻 GHOST MODE: Ephemeral Identity spawned.`, 'info');
    } else if (strategy.privacyLevel === 'standard') {
       logActivity(`🛡️ SHIELDED ROUTE: Balancing Privacy vs Cost...`, 'info');
    }
    
    logActivity(`🧠 Strategy: ${strategy.strategy} (${strategy.reason})`, 'info');

  } catch (e) {
    console.error('Strategy failed', e);
  }

  // 2. GOVERNANCE TRIGGER (Legacy Check kept for safety, but logic is redundant with Strategy)
  if (product.price > 1000) {
    const confirmMsg = `High Value Alert: $${product.price} exceeds autonomous limit.\nInitiating Shadow Governance Protocol?`;
    if (!confirm(confirmMsg)) return;

    logActivity(`⚠️ Blocked: $${product.price} exceeds limit. Requesting approval...`, 'info');
    
    // Simulate Agent sending encrypted intent to Listener
    try {
      const payload = {
        agentId: agent.id,
        // Mocking encryption: Base64 of "CMD|AMOUNT|RECIPIENT|REASON"
        encryptedPayload: btoa(`TRANSFER|${product.price}|${product.recipient.slice(0,8)}...|Asset Acquisition: ${product.name}`)
      };
      
      await fetch(`${LISTENER_URL}/governance/request`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(payload)
      });

      alert('🚫 Transaction requires human approval.\nCheck the "Governance" tab to inspect and sign.');
      // Switch tab helper (optional, user can do it manually)
      const govTab = document.querySelector('button[data-target="view-governance"]');
      if (govTab) govTab.classList.add('pulse-anim');
    } catch (e) {
      console.error(e);
      logActivity('Governance handshake failed.', 'info');
    }
    return;
  }
  
  // Get strategy
  const strategyInput = document.querySelector('input[name="strategy"]:checked') as HTMLInputElement;
  const strategy = strategyInput?.value || 'privacy_cash';
  
  logActivity(`Initiating purchase: ${product.name} via ${strategy}...`);
  
  try {
    const response = await callTool('agent.pay', {
      amount: product.price * 100, // Convert to atomic units (cents)
      token: 'USDC',
      recipient: product.recipient,
      provider: strategy // Map UI 'strategy' to tool 'provider'
    });
    
    const result = unwrapToolResponse(response);
    const error = extractToolError(result);
    
    if (error) {
      if (error.includes('Range') || error.includes('Compliance') || error.includes('Risk')) {
        showComplianceAlert(error);
      } else {
        logActivity(`Payment failed: ${error}`, 'info');
      }
    } else {
      salesTotal += product.price;
      statSales.textContent = `$${salesTotal.toFixed(2)}`;
      logActivity(`Payment confirmed! ${product.name} sold.`, 'sale');
    }
  } catch (e: any) {
    logActivity(`Error: ${e.message}`, 'info');
  }
}

btnAddProduct.addEventListener('click', () => {
  const name = prompt('Product Name:');
  const price = Number(prompt('Price:'));
  if (name && price) {
    products.push({ id: `p${Date.now()}`, name, price, icon: '📦' });
    renderProductGrid();
    logActivity(`New product listed: ${name}`);
  }
});

// --- Initialization ---

initNav();
renderProductGrid();
logActivity('Merchant Terminal initialized.');

refreshBtn.addEventListener('click', () => refreshAgents());
refreshProcesses.addEventListener('click', () => refreshProcessList());
refreshObservability.addEventListener('click', () => refreshObservabilityPanel());
registerForm.addEventListener('submit', submitRegister);
spawnForm.addEventListener('submit', submitSpawn);
toolForm.addEventListener('submit', submitTool);

refreshAgents().catch(() => null);

refreshProcessList().catch(() => null);

refreshObservabilityPanel().catch(() => null);

refreshLiveActivity().catch(() => null);



setInterval(() => {

  refreshAgents().catch(() => null);

  refreshProcessList().catch(() => null);

}, 5000);



setInterval(() => {

  refreshObservabilityPanel().catch(() => null);

}, 10000);



setInterval(() => {

  refreshLiveActivity().catch(() => null);

}, 3000);
