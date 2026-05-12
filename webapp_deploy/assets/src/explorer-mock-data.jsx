/* xB77 Explorer — Mock Data Generator */

function generateHash(len = 12) {
  const chars = '0123456789abcdef';
  return Array.from({ length: len }, () => chars[Math.floor(Math.random() * 16)]).join('');
}

function generateAddress() {
  return 'xB' + generateHash(8) + '...' + generateHash(4);
}

function generateZnodeId() {
  const prefixes = ['zn', 'ZN', 'mesh'];
  return prefixes[Math.floor(Math.random() * prefixes.length)] + '-' + generateHash(6);
}

const AGENT_NAMES = [
  'AGENT_CFO_ALPHA', 'AGENT_CFO_BETA', 'AGENT_TREASURY_01', 'AGENT_YIELD_HUNTER',
  'AGENT_RISK_MGMT', 'AGENT_LIQUIDITY', 'AGENT_REBALANCER', 'AGENT_COMPLIANCE',
  'AGENT_PAYROLL_X', 'AGENT_HEDGE_PRIME', 'AGENT_ARB_DELTA', 'AGENT_SETTLER_V2',
];

const PIPELINE_TYPES = ['SHIELDED_PAYMENT', 'ZK_RECEIPT', 'ZK_PRIVACY_ROUTE', 'ZK_ENGINE', 'COMPRESSED_SETTLE', 'GOVERNANCE_LOCK', 'YIELD_HARVEST', 'REBALANCE'];
const STATUSES = ['COMPLETED', 'PENDING', 'IN_PROGRESS', 'FAILED'];
const STATUS_WEIGHTS = [0.6, 0.15, 0.2, 0.05];

function weightedStatus() {
  const r = Math.random();
  let cum = 0;
  for (let i = 0; i < STATUSES.length; i++) {
    cum += STATUS_WEIGHTS[i];
    if (r < cum) return STATUSES[i];
  }
  return STATUSES[0];
}

function generatePipeline(id) {
  const now = Date.now();
  const ago = Math.floor(Math.random() * 86400000 * 7);
  return {
    id: 'pip-' + generateHash(8),
    num: id,
    type: PIPELINE_TYPES[Math.floor(Math.random() * PIPELINE_TYPES.length)],
    agent: AGENT_NAMES[Math.floor(Math.random() * AGENT_NAMES.length)],
    status: weightedStatus(),
    amount: (Math.random() * 50000 + 100).toFixed(2),
    currency: 'USDC',
    from: generateAddress(),
    to: generateAddress(),
    znode: generateZnodeId(),
    timestamp: now - ago,
    blockHeight: 280000000 + Math.floor(Math.random() * 1000000),
    fee: (Math.random() * 0.05 + 0.001).toFixed(4),
    zkProof: generateHash(16),
    compressedState: generateHash(20),
    steps: [
      { label: 'NEURAL_KEY_VERIFIED', status: 'done', ts: now - ago },
      { label: 'SHIELDING_ASSETS', status: 'done', ts: now - ago + 2000 },
      { label: 'ZK_PROOF_GENERATED', status: 'done', ts: now - ago + 5000 },
      { label: 'SETTLEMENT', status: Math.random() > 0.1 ? 'done' : 'pending', ts: now - ago + 8000 },
    ],
  };
}

function generateZnode(id) {
  const regions = ['US-EAST', 'US-WEST', 'EU-CENTRAL', 'ASIA-SE', 'SA-EAST', 'EU-WEST'];
  const statuses = ['ONLINE', 'ONLINE', 'ONLINE', 'ONLINE', 'SYNCING', 'OFFLINE'];
  return {
    id: generateZnodeId(),
    num: id,
    region: regions[Math.floor(Math.random() * regions.length)],
    status: statuses[Math.floor(Math.random() * statuses.length)],
    peers: Math.floor(Math.random() * 48 + 4),
    uptime: (Math.random() * 0.3 + 0.7).toFixed(4),
    pipelines: Math.floor(Math.random() * 2000 + 50),
    latency: Math.floor(Math.random() * 120 + 8),
    stake: (Math.random() * 100000 + 1000).toFixed(0),
    version: '0.7.' + Math.floor(Math.random() * 5),
  };
}

function generateAgent(i) {
  const name = AGENT_NAMES[i % AGENT_NAMES.length];
  return {
    name,
    address: generateAddress(),
    status: Math.random() > 0.15 ? 'ACTIVE' : 'IDLE',
    pipelines: Math.floor(Math.random() * 500 + 10),
    volume: (Math.random() * 2000000 + 10000).toFixed(0),
    lastActive: Date.now() - Math.floor(Math.random() * 3600000),
    zkIdentity: generateHash(12),
    governanceLevel: ['STANDARD', 'ELEVATED', 'LOCKDOWN'][Math.floor(Math.random() * 3)],
  };
}

// Generate datasets
const MOCK_PIPELINES = Array.from({ length: 200 }, (_, i) => generatePipeline(i + 1));
const MOCK_ZNODES = Array.from({ length: 32 }, (_, i) => generateZnode(i + 1));
const MOCK_AGENTS = Array.from({ length: 12 }, (_, i) => generateAgent(i));

const GLOBAL_STATS = {
  tvl: '$12.4M',
  totalPipelines: '48,291',
  activeAgents: '12',
  znodesOnline: '28',
  avgLatency: '34ms',
  compressedStates: '1.2M',
};

Object.assign(window, {
  MOCK_PIPELINES, MOCK_ZNODES, MOCK_AGENTS, GLOBAL_STATS,
  generateHash, generateAddress,
});
