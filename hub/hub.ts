// --- CONFIGURATION & STATE ---
const CONFIG = {
  typingSpeed: 10, // Faster typing for "AI speed"
  stepDelay: 1200, // Time between agent steps (dramatic pause)
};

let state = {
  salesTotal: 4250.00,
  treasury: {
    cash: 12500.00,
    yield: 85000.00, // Kamino/Yield interaction simulation
    apy: 8.5
  },
  pendingOps: 0,
  history: [] as any[],
  governanceRequests: [] as any[],
  isLockdown: false,
  agentStatus: 'idle' // idle, working, panic
};

const ICONS = {
  SHIELD: '🛡️', LOCK: '🔒', UNLOCK: '🔓', BADGE: '🏅', CHECK: '✅', 
  CLOUD: '☁️', TOOL: '🛠️', DATA: '💾'
};

const products = [
  { id: 'p1', name: 'AWS Credits ($100)', price: 95, icon: ICONS.CLOUD, recipient: 'So11...AWS', risk: 'low' },
  { id: 'p2', name: 'DevOps Hour', price: 150, icon: ICONS.TOOL, recipient: 'So11...DEV', risk: 'low' },
  { id: 'p3', name: 'VPN Subscription', price: 12, icon: ICONS.LOCK, recipient: 'So11...VPN', risk: 'low' },
  { id: 'p4', name: 'Dark Web Data', price: 499, icon: ICONS.DATA, recipient: 'BAD...ADDR', risk: 'critical' }, // TRIGGER
  { id: 'p5', name: 'Quantum Farm', price: 50000, icon: ICONS.SHIELD, recipient: 'So11...QTM', risk: 'high' },
];

// --- DOM ELEMENTS ---
const el = {
  sales: document.getElementById('stat-sales'),
  pending: document.getElementById('stat-pending'),
  feed: document.getElementById('activity-feed'),
  thoughts: document.getElementById('thought-stream'),
  radar: document.getElementById('forensic-radar'),
  radarTarget: document.getElementById('radar-target'),
  radarScore: document.getElementById('radar-score'),
  radarComp: document.getElementById('radar-compliance'),
  govOverlay: document.getElementById('governance-overlay'),
  govList: document.getElementById('governance-list'),
  invoiceModal: document.getElementById('invoice-modal'),
  btnCloseInvoice: document.getElementById('btn-close-invoice'),
  navStatus: document.getElementById('connection-status'),
  statusPill: document.querySelector('.status-pill'),
  // Control Plane
  obsBalance: document.getElementById('obs-balance'),
  obsBalanceMeta: document.getElementById('obs-balance-meta'),
  obsReceipts: document.getElementById('obs-receipts'),
};

// --- SIMULATION ENGINE ---

function updateDashboard() {
  if (el.sales) el.sales.textContent = `$${state.salesTotal.toFixed(2)}`;
  if (el.pending) el.pending.textContent = state.pendingOps.toString();
  
  // Update Control Plane Balance (CFO View)
  if (el.obsBalance) {
      el.obsBalance.innerHTML = `$${(state.treasury.cash + state.treasury.yield).toFixed(2)}`;
      if (el.obsBalanceMeta) {
          el.obsBalanceMeta.innerHTML = `<span style="color:var(--accent-cyan)">CASH: $${state.treasury.cash}</span> | <span style="color:var(--accent-gold)">YIELD: $${state.treasury.yield} (${state.treasury.apy}% APY)</span>`;
      }
  }

  renderHistory();
  renderGovernance();
}

async function logThought(agent: string, text: string, type: 'info' | 'risk' | 'intel' | 'success' = 'info') {
  if (!el.thoughts) return;
  const line = document.createElement('div');
  line.className = `thought-entry ${type}`;
  
  const header = document.createElement('span');
  header.className = 'agent-tag';
  header.style.fontWeight = 'bold';
  header.style.marginRight = '8px';
  header.style.color = type === 'risk' ? 'var(--accent-red)' : (type === 'intel' ? 'var(--accent-cyan)' : 'var(--text-muted)');
  header.textContent = `[${agent}]`;

  const content = document.createElement('span');
  
  line.appendChild(header);
  line.appendChild(content);
  
  if (el.thoughts.children.length > 0) {
    el.thoughts.insertBefore(line, el.thoughts.firstChild);
  } else {
    el.thoughts.appendChild(line);
  }

  let i = 0;
  return new Promise<void>(resolve => {
    function typeChar() {
      if (i < text.length) {
        content.textContent += text.charAt(i);
        i++;
        setTimeout(typeChar, CONFIG.typingSpeed);
      } else {
        resolve();
      }
    }
    typeChar();
  });
}

async function wait(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

function setupNavTabs() {
  const tabs = document.querySelectorAll<HTMLButtonElement>('.nav-tab');
  tabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const targetId = tab.dataset.target;
      if (!targetId) return;
      document.querySelectorAll<HTMLElement>('.view').forEach((view) => {
        view.classList.add('hidden');
      });
      const target = document.getElementById(targetId);
      if (target) {
        target.classList.remove('hidden');
      }
      tabs.forEach((item) => item.classList.remove('active'));
      tab.classList.add('active');
    });
  });
}

// --- AGENT ORCHESTRATION ---

async function handleBuy(product: typeof products[0]) {
  if (state.isLockdown) {
    alert('SYSTEM LOCKDOWN ACTIVE. RESOLVE GOVERNANCE FIRST.');
    return;
  }

  state.pendingOps++;
  state.agentStatus = 'working';
  updateDashboard();

  // --- STEP 1: SITUATIONAL AWARENESS (CFO) ---
  await logThought('CFO', `Analysing treasury liquidity for $${product.price}...`, 'info');
  await wait(CONFIG.stepDelay);
  
  if (state.treasury.cash < product.price) {
      await logThought('CFO', `Insufficient cash. Rebalancing yield positions...`, 'intel');
      await wait(800);
  }
  await logThought('CFO', `Liquidity allocated. Passing to RISK agent.`, 'success');

  // --- STEP 2: THREAT ANALYSIS (RADAR) ---
  if (el.radar) el.radar.classList.remove('hidden');
  if (el.radarTarget) el.radarTarget.textContent = product.recipient;
  if (el.radarScore) el.radarScore.textContent = "SCANNING...";
  if (el.radarComp) el.radarComp.textContent = "PENDING...";

  await logThought('RISK', `Scanning recipient ${product.recipient} via HELIUS...`, 'info');
  await wait(CONFIG.stepDelay);

  if (product.risk === 'critical') {
    // --- CRISIS BRANCH ---
    if (el.radarScore) el.radarScore.textContent = "CRITICAL (98/100)";
    if (el.radarScore) el.radarScore.style.color = "var(--accent-red)";
    if (el.radarComp) el.radarComp.textContent = "OFAC SANCTIONED";
    
    await logThought('RISK', `🚨 ALERT: Destination is flagged by Range Protocol!`, 'risk');
    await logThought('STRATEGY', `ABORTING AUTOMATION. TRIGGERING GOVERNANCE LOCKDOWN.`, 'risk');
    
    triggerLockdown(product);
    return;
  }

  // --- HAPPY PATH ---
  if (el.radarScore) el.radarScore.textContent = "SAFE (0.02/100)";
  if (el.radarComp) el.radarComp.textContent = "VERIFIED";
  await wait(600);
  if (el.radar) el.radar.classList.add('hidden');
  
  await logThought('RISK', `Compliance verified. No threats detected.`, 'success');

  // --- STEP 3: STRATEGY & EXECUTION (SOLVER) ---
  await logThought('STRATEGY', `Selecting privacy route...`, 'info');
  await wait(600);
  await logThought('STRATEGY', `Route Selected: SHADOW WIRE (High Anonymity).`, 'intel');
  
  await logThought('EXEC', `Generating ZK-Proof (Noir Circuit)...`, 'info');
  await wait(1500); // Compute simulation
  await logThought('EXEC', `Proof Generated. Broadcasting via LIGHT PROTOCOL...`, 'success');
  
  // --- FINALIZATION ---
  state.salesTotal += product.price;
  state.treasury.cash -= product.price;
  state.pendingOps--;
  state.agentStatus = 'idle';
  
  const txId = `tx-${Date.now()}`;
  state.history.unshift({
    id: txId,
    time: Date.now(),
    product: product.name,
    amount: product.price,
    provider: 'ShadowWire', 
    sig: '5x...zk99'
  });
  
  updateDashboard();
  
  // Log to control plane "Recent Traffic"
  if (el.obsReceipts) {
      const line = document.createElement('div');
      line.className = 'receipt-item';
      line.textContent = `> ${new Date().toLocaleTimeString()} | ${product.name} | CONFIRMED`;
      el.obsReceipts.prepend(line);
  }
}

function triggerLockdown(product: any) {
  state.isLockdown = true;
  document.body.classList.add('system-lockdown');
  if (el.thoughts) el.thoughts.classList.add('panic-mode');
  
  if (el.govOverlay) el.govOverlay.classList.remove('hidden');
  
  state.governanceRequests.unshift({
    id: `gov-${Date.now()}`,
    agentId: 'agent-risk-01',
    target: product.recipient,
    amount: product.price,
    reason: 'Range Protocol: OFAC Match',
    status: 'pending',
    timestamp: Date.now()
  });
  
  renderGovernance();
}

// --- GOVERNANCE RESOLUTION ---

(window as any).resolveLockdown = async (action: 'approve' | 'reject') => {
  if (el.govOverlay) el.govOverlay.classList.add('hidden');
  
  const req = state.governanceRequests[0]; // Assume latest
  req.status = action === 'approve' ? 'approved' : 'rejected';
  
  if (action === 'reject') {
    await logThought('GOV', `Authority REJECTED the transaction.`, 'info');
    await logThought('STRATEGY', `Blacklisting address. Reverting state.`, 'info');
  } else {
    await logThought('GOV', `Authority APPROVED override.`, 'risk');
    await logThought('EXEC', `Forcing transaction execution...`, 'risk');
    await wait(1000);
    
    state.salesTotal += 499;
    state.history.unshift({
      id: `tx-${Date.now()}-forced`,
      time: Date.now(),
      product: 'Dark Web Data (Forced)',
      amount: 499,
      provider: 'PrivacyCash (Override)',
      sig: 'ov...err'
    });
  }

  state.isLockdown = false;
  state.pendingOps = 0;
  document.body.classList.remove('system-lockdown');
  if (el.thoughts) el.thoughts.classList.remove('panic-mode');
  
  renderGovernance();
  updateDashboard();
};

// --- HISTORY & RECEIPTS ---

function renderHistory() {
  if (!el.feed) return;
  el.feed.innerHTML = '';
  
  state.history.forEach(tx => {
    const item = document.createElement('div');
    item.className = 'feed-item sale';
    item.innerHTML = `
        <span class="time">${new Date(tx.time).toLocaleTimeString()}</span>
        <div class="feed-content" style="flex:1;">
          <div class="receipt-row" style="display:flex; justify-content:space-between;">
             <span><strong>$${tx.amount.toFixed(2)}</strong> via ${tx.provider}</span>
             <button class="btn-xs" style="background:none; border:1px solid #333; color:#666; cursor:pointer;" onclick="window.openInvoice('${tx.id}')">📄 PROOF</button>
          </div>
          <div class="receipt-meta">
             Sig: ${tx.sig}
          </div>
        </div>
    `;
    el.feed.appendChild(item);
  });
}

(window as any).openInvoice = (id: string) => {
  if (!el.invoiceModal) return;
  el.invoiceModal.classList.remove('hidden');
  
  // ZK Reveal Logic
  const body = document.getElementById('inv-body');
  if (body) {
    body.innerHTML = `
      <div id="zk-content" class="zk-blur" style="padding:20px; text-align:center;">
         <h3>ENCRYPTED RECEIPT DATA</h3>
         <p>vendor_id: 0x99...aa</p>
         <p>amount: [HIDDEN]</p>
         <p>memo: [HIDDEN]</p>
      </div>
      <div style="margin-top:20px; text-align:center;">
        <button id="btn-verify-zk" class="btn-sm" style="background:var(--accent-cyan); color:black; font-weight:bold;">VERIFY ON-CHAIN (LIGHT PROTOCOL)</button>
      </div>
    `;
    
    document.getElementById('btn-verify-zk')?.addEventListener('click', async () => {
        const btn = document.getElementById('btn-verify-zk') as HTMLButtonElement;
        btn.textContent = "VERIFYING PROOF...";
        btn.disabled = true;
        
        await wait(1200);
        
        const content = document.getElementById('zk-content');
        if (content) {
            content.classList.remove('zk-blur');
            content.classList.add('zk-revealed');
            content.innerHTML = `
                <div style="color:var(--accent-cyan); font-weight:bold; margin-bottom:10px;">✅ PROOF VERIFIED</div>
                <div class="line-item"><span>PROVIDER</span> <strong>ShadowWire</strong></div>
                <div class="line-item"><span>AMOUNT</span> <strong>$${state.salesTotal > 0 ? '95.00' : '0.00'}</strong></div>
                <div class="line-item"><span>COMPRESSION</span> <strong>Light Protocol</strong></div>
            `;
        }
        btn.textContent = "VERIFIED";
    });
  }
};

if (el.btnCloseInvoice && el.invoiceModal) {
    el.btnCloseInvoice.addEventListener('click', () => {
        el.invoiceModal?.classList.add('hidden');
    });
}

// --- GOVERNANCE UI ---

function renderGovernance() {
  if (!el.govList) return;
  el.govList.innerHTML = '';
  
  if (state.governanceRequests.length === 0) {
    el.govList.innerHTML = '<div class="empty-state">:: No pending requests.</div>';
    return;
  }

  state.governanceRequests.forEach(req => {
      const card = document.createElement('div');
      card.className = 'gov-card';
      card.innerHTML = `
        <div class="gov-header">
            <span class="gov-title">REQ: ${req.id}</span>
            <span style="color:${req.status === 'pending' ? 'var(--accent-gold)' : (req.status === 'approved' ? 'var(--accent-cyan)' : 'var(--accent-red)')}">${req.status.toUpperCase()}</span>
        </div>
        <div class="gov-body">
            <p>Agent: ${req.agentId}</p>
            <p>Target: ${req.target}</p>
            <p>Reason: ${req.reason}</p>
        </div>
        ${req.status === 'pending' ? `
        <div class="gov-actions" style="margin-top:10px; display:flex; gap:10px;">
            <button class="btn-danger" onclick="window.resolveLockdown('reject')" style="flex:1;">REJECT</button>
            <button class="btn-success" onclick="window.resolveLockdown('approve')" style="flex:1;">AUTHORIZE</button>
        </div>` : ''}
      `;
      el.govList.appendChild(card);
  });
}

// --- INITIALIZATION ---

function init() {
  console.log("xB77 Merchant Hub :: ORCHESTRATION MODE ACTIVE");
  setupNavTabs();
  
  // Render Products
  const grid = document.getElementById('product-grid');
  if (grid) {
    grid.innerHTML = '';
    products.forEach(p => {
        const card = document.createElement('div');
        card.className = 'product-card';
        card.innerHTML = `
            <div class="product-icon">${p.icon}</div>
            <div class="product-info">
                <h3>${p.name}</h3>
                <div class="product-price">$${p.price.toFixed(2)}</div>
            </div>
            <button class="btn-full" id="btn-buy-${p.id}">BUY NOW</button>
        `;
        grid.appendChild(card);
        document.getElementById(`btn-buy-${p.id}`)?.addEventListener('click', () => handleBuy(p));
    });
  }

  if (el.navStatus) {
      el.navStatus.textContent = "CONNECTED (3)"; // Mocking 3 agents online
      el.navStatus.style.color = "var(--accent-cyan)";
      el.statusPill?.classList.add('secure');
      el.statusPill?.classList.add('online');
  }
  
  // Populate Agents List (Showing the Swarm)
  const agentsList = document.getElementById('agents-list');
  if (agentsList) {
      agentsList.innerHTML = `
        <div class="agent-card online">
            <div class="agent-id">agent-cfo-core</div>
            <div class="agent-caps">[TREASURY, YIELD, ANALYTICS]</div>
        </div>
        <div class="agent-card online">
            <div class="agent-id">agent-risk-sentinel</div>
            <div class="agent-caps">[HELIUS_RADAR, COMPLIANCE]</div>
        </div>
        <div class="agent-card online">
            <div class="agent-id">agent-exec-prime</div>
            <div class="agent-caps">[SHADOW_WIRE, LIGHT_PROTO, PAY]</div>
        </div>
      `;
  }

  // Boot Sequence Logs
  (async () => {
      await logThought('SYS', 'Initializing xB77 Autonomous Swarm...', 'info');
      await wait(500);
      await logThought('CFO', 'Treasury connected. Yield optimization active.', 'success');
      await logThought('RISK', 'Helius RPC Node: SYNCHRONIZED.', 'success');
      await logThought('EXEC', 'ShadowWire Privacy Circuits: CHARGED.', 'success');
      await logThought('SYS', 'System Ready. Waiting for intents.', 'info');
  })();
  
  updateDashboard();
}

// Bind Global Listeners
const btnLockReject = document.getElementById('lockdown-reject');
const btnLockApprove = document.getElementById('lockdown-approve');

if (btnLockReject) btnLockReject.onclick = () => (window as any).resolveLockdown('reject');
if (btnLockApprove) btnLockApprove.onclick = () => (window as any).resolveLockdown('approve');

init();
