const POSEIDON_TYPES = ["PAYMENT_COMMIT", "RECEIPT_HASH", "MERCHANT_SETTLE", "AGENT_ESCROW", "PRIVACY_PROOF", "STATE_COMPRESS"];
function generatePoseidonCommit(i) {
  const now = Date.now();
  return {
    id: "psd-" + generateHash(8),
    hash: "0x" + generateHash(16),
    type: POSEIDON_TYPES[Math.floor(Math.random() * POSEIDON_TYPES.length)],
    agent: AGENT_NAMES[Math.floor(Math.random() * AGENT_NAMES.length)],
    merchant: Math.random() > 0.4 ? MOCK_MERCHANTS_LIST[Math.floor(Math.random() * MOCK_MERCHANTS_LIST.length)].name : null,
    amount: (Math.random() * 5e3 + 10).toFixed(2),
    status: Math.random() > 0.08 ? "VERIFIED" : "PENDING",
    timestamp: now - Math.floor(Math.random() * 36e5 * 48),
    blockHeight: 28e7 + Math.floor(Math.random() * 1e6),
    zkProof: generateHash(12),
    gasUsed: Math.floor(Math.random() * 5e3 + 200),
    compressedSize: Math.floor(Math.random() * 256 + 32) + " bytes"
  };
}
const MERCHANT_CATEGORIES = ["SaaS", "Infrastructure", "DeFi Protocol", "Data Provider", "AI Services", "Payments", "Exchange", "Oracle"];
const MOCK_MERCHANTS_LIST = [
  { name: "NeuralPay Systems", domain: "neuralpay.io", category: "Payments", verified: true },
  { name: "ShadowStack Infra", domain: "shadowstack.dev", category: "Infrastructure", verified: true },
  { name: "Quantum Yield", domain: "qyield.fi", category: "DeFi Protocol", verified: true },
  { name: "DataMesh Labs", domain: "datamesh.xyz", category: "Data Provider", verified: true },
  { name: "CipherCompute", domain: "ciphercompute.ai", category: "AI Services", verified: true },
  { name: "ArkFlow Exchange", domain: "arkflow.exchange", category: "Exchange", verified: false },
  { name: "ZeroOracle", domain: "zerooracle.io", category: "Oracle", verified: true },
  { name: "PrivaCloud", domain: "privacloud.net", category: "SaaS", verified: true },
  { name: "LightBridge Pay", domain: "lightbridge.pay", category: "Payments", verified: false },
  { name: "TrustMesh Protocol", domain: "trustmesh.io", category: "DeFi Protocol", verified: true },
  { name: "Cortex AI Agents", domain: "cortex-ai.dev", category: "AI Services", verified: true },
  { name: "SolVault Treasury", domain: "solvault.fi", category: "DeFi Protocol", verified: true }
];
function generateMerchant(m, i) {
  return {
    ...m,
    id: "mrc-" + generateHash(6),
    num: i,
    address: generateAddress(),
    totalVolume: (Math.random() * 5e5 + 5e3).toFixed(0),
    txCount: Math.floor(Math.random() * 3e3 + 50),
    agents: Math.floor(Math.random() * 6 + 1),
    avgTxSize: (Math.random() * 500 + 20).toFixed(2),
    lastActive: Date.now() - Math.floor(Math.random() * 864e5 * 3),
    appVersion: "APP-" + (Math.random() > 0.5 ? "v2.1" : "v1.8"),
    rating: (3.5 + Math.random() * 1.5).toFixed(1),
    telegramLinked: Math.random() > 0.3,
    mcpEnabled: Math.random() > 0.4,
    poseidonCommits: Math.floor(Math.random() * 800 + 20),
    sparkVolume: Array.from({ length: 14 }, () => Math.random() * 1e3 + 100)
  };
}
var MOCK_MERCHANTS = MOCK_MERCHANTS_LIST.map((m, i) => generateMerchant(m, i));
var MOCK_POSEIDON = Array.from({ length: 150 }, (_, i) => generatePoseidonCommit(i));
function enhanceAgent(a, i) {
  return {
    ...a,
    poseidonCommits: Math.floor(Math.random() * 1200 + 20),
    merchantsServed: Math.floor(Math.random() * 8 + 1),
    telegramStatus: Math.random() > 0.25 ? "CONNECTED" : "OFFLINE",
    telegramHandle: "@xb77_" + a.name.toLowerCase().replace("agent_", ""),
    mcpEndpoint: Math.random() > 0.3 ? "mcp://" + a.name.toLowerCase().replace("agent_", "") + ".xb77.local" : null,
    appVersion: "APP-v" + (Math.random() > 0.5 ? "2.1" : "1.8"),
    recentCommits: Array.from({ length: 5 }, () => ({
      type: POSEIDON_TYPES[Math.floor(Math.random() * POSEIDON_TYPES.length)],
      hash: "0x" + generateHash(8),
      ts: Date.now() - Math.floor(Math.random() * 36e5),
      amount: (Math.random() * 2e3 + 10).toFixed(2)
    })),
    sparkActivity: Array.from({ length: 20 }, () => Math.floor(Math.random() * 50 + 5)),
    uptime: (0.85 + Math.random() * 0.15).toFixed(4),
    totalEarnings: (Math.random() * 5e4 + 500).toFixed(0)
  };
}
var MOCK_AGENTS_V2 = MOCK_AGENTS.map((a, i) => enhanceAgent(a, i));
const TELEGRAM_EVENTS = [
  { type: "COMMAND", msg: "/status \u2014 all systems nominal", agent: "CFO_ALPHA" },
  { type: "ALERT", msg: "\u26A0 Governance lockdown triggered on pipeline pip-3a8f", agent: "COMPLIANCE" },
  { type: "INTEL", msg: "New merchant onboarded: CipherCompute (AI Services)", agent: "SYSTEM" },
  { type: "COMMAND", msg: "/balance \u2014 $124,891 USDC shielded", agent: "TREASURY_01" },
  { type: "REPORT", msg: "Daily yield harvest: +$2,340 across 4 pools", agent: "YIELD_HUNTER" },
  { type: "ALERT", msg: "Znode zn-8f2a1c latency spike: 180ms", agent: "SYSTEM" },
  { type: "COMMAND", msg: "/route \u2014 ZK privacy layer rebalance initiated", agent: "LIQUIDITY" },
  { type: "INTEL", msg: "Poseidon commit verified: batch of 47 settlements", agent: "SETTLER_V2" },
  { type: "COMMAND", msg: "/hedge \u2014 delta-neutral position opened", agent: "HEDGE_PRIME" },
  { type: "REPORT", msg: "MCP endpoint health: 11/12 agents responsive", agent: "SYSTEM" },
  { type: "ALERT", msg: "New APP version deployed: v2.1.3", agent: "SYSTEM" },
  { type: "INTEL", msg: "Merchant volume spike: NeuralPay +340% last 1h", agent: "RISK_MGMT" }
];
const MCP_COMMANDS = [
  { cmd: "xb77 status", output: "MESH: ONLINE | ZNODES: 28/32 | AGENTS: 12 ACTIVE | LATENCY: 34ms" },
  { cmd: "xb77 agents list", output: "CFO_ALPHA    ACTIVE  284 pipelines  $89,201 vol\nCFO_BETA     ACTIVE  201 pipelines  $67,440 vol\nTREASURY_01  ACTIVE  156 pipelines  $45,100 vol\n... 9 more agents" },
  { cmd: "xb77 poseidon --recent", output: "psd-a8f21c  PAYMENT_COMMIT   $2,400  VERIFIED  12s ago\npsd-b3e9f0  MERCHANT_SETTLE  $890    VERIFIED  34s ago\npsd-c1d4a2  STATE_COMPRESS   $0      VERIFIED  1m ago" },
  { cmd: 'xb77 merchant discover --category "AI Services"', output: "CipherCompute    VERIFIED  $124K vol  APP-v2.1\nCortex AI Agents VERIFIED  $89K vol   APP-v2.1" },
  { cmd: "xb77 pipeline shield --amount 5000 --to mrc-a3f2b1", output: "[SHIELDING] 5000 USDC via xB77 ZK Engine...\n[ZKP] Generating proof... OK\n[POSEIDON] Commit hash: 0x8a3f2b1c9d...\n[SETTLE] Compressed state written. Fee: 0.0024 SOL" }
];
Object.assign(window, {
  MOCK_POSEIDON,
  MOCK_MERCHANTS,
  MOCK_AGENTS_V2,
  TELEGRAM_EVENTS,
  MCP_COMMANDS,
  POSEIDON_TYPES
});
