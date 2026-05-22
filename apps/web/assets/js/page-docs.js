const DOC_SECTIONS = [
  { id: "quickstart", label: "Quickstart" },
  { id: "api", label: "API Reference" },
  { id: "sdk", label: "SDK Guide" },
  { id: "network", label: "Network API" },
  { id: "protocol", label: "Protocol Specs" }
];
function DocsPage() {
  const t = THEMES.obsidian;
  const [active, setActive] = React.useState("quickstart");
  const scrollTo = (id) => {
    setActive(id);
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
  };
  React.useEffect(() => {
    const els = DOC_SECTIONS.map((s) => document.getElementById(s.id)).filter(Boolean);
    const obs = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) setActive(e.target.id);
      });
    }, { rootMargin: "-80px 0px -60% 0px", threshold: 0.1 });
    els.forEach((el) => obs.observe(el));
    return () => obs.disconnect();
  }, []);
  const Code = ({ children, block }) => {
    if (block) return /* @__PURE__ */ React.createElement(SyntaxHighlight, { code: children, theme: "obsidian" });
    return /* @__PURE__ */ React.createElement("code", { style: {
      background: t.terminalBg,
      border: `1px solid ${t.border}`,
      padding: "2px 6px",
      fontFamily: "var(--mono)",
      fontSize: 12.5,
      color: t.accent
    } }, children);
  };
  const H3 = ({ children }) => /* @__PURE__ */ React.createElement("h3", { style: { fontFamily: "var(--serif)", fontSize: 26, fontWeight: 400, color: t.text, margin: "48px 0 16px", lineHeight: 1.2 } }, children);
  const P = ({ children }) => /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--sans)", fontSize: 15, color: t.textDim, lineHeight: 1.8, margin: "0 0 16px" } }, children);
  const Table = ({ headers, rows }) => /* @__PURE__ */ React.createElement("div", { style: { overflowX: "auto", margin: "16px 0 24px" } }, /* @__PURE__ */ React.createElement("table", { style: { width: "100%", borderCollapse: "collapse", fontFamily: "var(--mono)", fontSize: 12 } }, /* @__PURE__ */ React.createElement("thead", null, /* @__PURE__ */ React.createElement("tr", null, headers.map((h, i) => /* @__PURE__ */ React.createElement("th", { key: i, style: { textAlign: "left", padding: "10px 16px", borderBottom: `2px solid ${t.border}`, color: t.accent, letterSpacing: "0.08em", fontSize: 10, textTransform: "uppercase" } }, h)))), /* @__PURE__ */ React.createElement("tbody", null, rows.map((row, ri) => /* @__PURE__ */ React.createElement("tr", { key: ri }, row.map((cell, ci) => /* @__PURE__ */ React.createElement("td", { key: ci, style: { padding: "10px 16px", borderBottom: `1px solid ${t.border}`, color: ci === 0 ? t.text : t.textDim, fontWeight: ci === 0 ? 600 : 400 } }, cell)))))));
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh", color: t.text } }, /* @__PURE__ */ React.createElement(InnerNav, { active: "Docs" }), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "240px 1fr", minHeight: "calc(100vh - 56px)" } }, /* @__PURE__ */ React.createElement("aside", { style: {
    borderRight: `1px solid ${t.border}`,
    padding: "32px 0",
    position: "sticky",
    top: 56,
    height: "calc(100vh - 56px)",
    overflowY: "auto"
  } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "0 24px", marginBottom: 24 } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.textDim, letterSpacing: "0.2em", textTransform: "uppercase" } }, "DOCUMENTATION")), DOC_SECTIONS.map((s) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: s.id,
      onClick: () => scrollTo(s.id),
      style: {
        padding: "10px 24px",
        cursor: "pointer",
        fontFamily: "var(--mono)",
        fontSize: 12,
        letterSpacing: "0.04em",
        color: active === s.id ? t.accent : t.textDim,
        borderLeft: active === s.id ? `2px solid ${t.accent}` : "2px solid transparent",
        background: active === s.id ? t.accentDim : "transparent",
        transition: "all 0.2s"
      }
    },
    s.label
  )), /* @__PURE__ */ React.createElement("div", { style: { padding: "32px 24px 0" } }, /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border, marginBottom: 20 } }), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.textDim, letterSpacing: "0.2em", textTransform: "uppercase", marginBottom: 12 } }, "RELATED"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.textDim, lineHeight: 1.8 } }, /* @__PURE__ */ React.createElement(
    "a",
    {
      href: "/index.html#pitch",
      style: { color: t.textDim, textDecoration: "none", display: "block", transition: "color 0.2s" },
      onMouseEnter: (e) => e.target.style.color = t.accent,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    "\u2192 Pitch deck"
  ), /* @__PURE__ */ React.createElement(
    "a",
    {
      href: "/index.html#architecture",
      style: { color: t.textDim, textDecoration: "none", display: "block", transition: "color 0.2s" },
      onMouseEnter: (e) => e.target.style.color = t.accent,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    "\u2192 Architecture"
  ), /* @__PURE__ */ React.createElement(
    "a",
    {
      href: "/index.html#whitepaper",
      style: { color: t.textDim, textDecoration: "none", display: "block", transition: "color 0.2s" },
      onMouseEnter: (e) => e.target.style.color = t.accent,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    "\u2192 Whitepaper"
  )))), /* @__PURE__ */ React.createElement("main", { style: { padding: "48px 60px 120px", maxWidth: 800 } }, /* @__PURE__ */ React.createElement("section", { id: "quickstart" }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "GETTING STARTED"), /* @__PURE__ */ React.createElement("h2", { style: { fontFamily: "var(--serif)", fontSize: "clamp(32px, 4vw, 48px)", fontWeight: 400, color: t.text, margin: "0 0 24px", lineHeight: 1.1 } }, "Quickstart"), /* @__PURE__ */ React.createElement(P, null, "Get a shielded agent pipeline running in under 5 minutes."), /* @__PURE__ */ React.createElement(H3, null, "1. Install the CLI"), /* @__PURE__ */ React.createElement(Code, { block: true }, `$ npm install -g @xb77/cli

# or with cargo (native Zig bindings)
$ cargo install xb77-cli`), /* @__PURE__ */ React.createElement(H3, null, "2. Initialize a Pipeline"), /* @__PURE__ */ React.createElement(Code, { block: true }, `$ xb77 init my-agent --network devnet

\u2713 Created pipeline config: ./my-agent/xb77.config.toml
\u2713 Generated Neural Key pair
\u2713 Connected to Solana devnet`), /* @__PURE__ */ React.createElement(H3, null, "3. Configure Your Constitution"), /* @__PURE__ */ React.createElement(P, null, "The Constitution defines what your agent can and cannot do. Edit ", /* @__PURE__ */ React.createElement(Code, null, "xb77.config.toml"), ":"), /* @__PURE__ */ React.createElement(Code, { block: true }, `[constitution]
max_single_tx = "1000 USDC"
max_daily_spend = "10000 USDC"
allowed_counterparties = ["*"]  # or specific pubkeys
require_human_above = "5000 USDC"
strategy_disclosure = "none"    # none | selective | full`), /* @__PURE__ */ React.createElement(H3, null, "4. Launch the Pipeline"), /* @__PURE__ */ React.createElement(Code, { block: true }, `$ xb77 launch --agent cfo-alpha

[INIT] PIPELINE_START: AGENT_CFO_ALPHA
[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)
[READY] Pipeline active. Awaiting intents...`), /* @__PURE__ */ React.createElement(P, null, "Your agent is now live. Transactions are shielded via xB77's ZK Engine, receipts are compressed on-chain, and the 2.011% Infra Tax is collected automatically.")), /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border, margin: "60px 0" } }), /* @__PURE__ */ React.createElement("section", { id: "api" }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "REFERENCE"), /* @__PURE__ */ React.createElement("h2", { style: { fontFamily: "var(--serif)", fontSize: "clamp(32px, 4vw, 48px)", fontWeight: 400, color: t.text, margin: "0 0 24px", lineHeight: 1.1 } }, "API Reference"), /* @__PURE__ */ React.createElement(P, null, "The xB77 API is JSON-RPC over WebSocket. All endpoints require Neural Key authentication."), /* @__PURE__ */ React.createElement(H3, null, "Authentication"), /* @__PURE__ */ React.createElement(Code, { block: true }, `POST /v1/auth/verify
{
  "neural_key": "<base58-encoded-key>",
  "timestamp": 1716000000,
  "signature": "<ed25519-sig>"
}
\u2192 { "token": "xb77_live_...", "expires": 3600 }`), /* @__PURE__ */ React.createElement(H3, null, "Core Endpoints"), /* @__PURE__ */ React.createElement(
    Table,
    {
      headers: ["Endpoint", "Method", "Description"],
      rows: [
        ["/v1/pipeline/start", "POST", "Initialize a new agent pipeline"],
        ["/v1/pipeline/status", "GET", "Get pipeline status and active intents"],
        ["/v1/intent/submit", "POST", "Submit a sovereign intent for execution"],
        ["/v1/intent/{id}", "GET", "Get intent status and Ghost Receipt"],
        ["/v1/zk/route", "POST", "Route a payment through the ZK privacy layer"],
        ["/v1/receipt/{id}", "GET", "Fetch a ZK-compressed receipt"],
        ["/v1/constitution", "GET/PUT", "Read or update agent constitution"],
        ["/v1/governance/lockdowns", "GET", "List pending lockdown approvals"]
      ]
    }
  ), /* @__PURE__ */ React.createElement(H3, null, "Submit an Intent"), /* @__PURE__ */ React.createElement(Code, { block: true }, `POST /v1/intent/submit
{
  "type": "payment",
  "amount": "500.00",
  "currency": "USDC",
  "destination": "<pubkey or AWP endpoint>",
  "privacy": "shielded",       // shielded | transparent
  "urgency": "turbo",          // turbo (MagicBlock) | standard | batch
  "memo_zk": true              // attach Ghost Receipt
}
\u2192 {
  "intent_id": "int_7x8k...",
  "status": "routing",
  "estimated_fee": "0.012 SOL",
  "infra_tax": "10.055 USDC"   // 2.011% of 500
}`), /* @__PURE__ */ React.createElement(H3, null, "Webhook Events"), /* @__PURE__ */ React.createElement(
    Table,
    {
      headers: ["Event", "Payload", "Description"],
      rows: [
        ["intent.completed", "{intent_id, receipt_id, proof}", "Intent settled on L1"],
        ["intent.lockdown", "{intent_id, reason, threshold}", "Constitution breach \u2014 human sig required"],
        ["receipt.compressed", "{receipt_id, proof_size}", "Receipt compressed via xB77 ZK Engine"],
        ["pipeline.error", "{code, message}", "Pipeline-level error"]
      ]
    }
  )), /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border, margin: "60px 0" } }), /* @__PURE__ */ React.createElement("section", { id: "sdk" }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "INTEGRATION"), /* @__PURE__ */ React.createElement("h2", { style: { fontFamily: "var(--serif)", fontSize: "clamp(32px, 4vw, 48px)", fontWeight: 400, color: t.text, margin: "0 0 24px", lineHeight: 1.1 } }, "SDK Guide"), /* @__PURE__ */ React.createElement(P, null, "Available in TypeScript, Rust, and Python. The SDK wraps the JSON-RPC API with typed clients and convenience helpers."), /* @__PURE__ */ React.createElement(H3, null, "TypeScript"), /* @__PURE__ */ React.createElement(Code, { block: true }, `import { XB77Client, Pipeline } from '@xb77/sdk';

const client = new XB77Client({
  network: 'mainnet',
  neuralKey: process.env.XB77_NEURAL_KEY,
});

// Launch a pipeline
const pipeline = await client.pipeline.start({
  agent: 'cfo-alpha',
  constitution: './xb77.config.toml',
});

// Submit a shielded payment
const intent = await pipeline.submit({
  type: 'payment',
  amount: '500 USDC',
  destination: 'vendor.sol',
  privacy: 'shielded',
});

// Wait for Ghost Receipt
const receipt = await intent.waitForReceipt();
console.log(receipt.proofHash); // 32-byte ZK proof`), /* @__PURE__ */ React.createElement(H3, null, "Rust"), /* @__PURE__ */ React.createElement(Code, { block: true }, `use xb77_sdk::{Client, IntentBuilder};

let client = Client::new(
    Network::Mainnet,
    NeuralKey::from_env()?,
);

let intent = IntentBuilder::payment()
    .amount(500, Currency::USDC)
    .destination("vendor.sol")
    .privacy(Privacy::Shielded)
    .urgency(Urgency::Turbo)
    .build()?;

let receipt = client.submit_and_wait(intent).await?;
println!("Proof: {}", receipt.proof_hash);`), /* @__PURE__ */ React.createElement(H3, null, "Python"), /* @__PURE__ */ React.createElement(Code, { block: true }, `from xb77 import XB77Client

client = XB77Client(
    network="mainnet",
    neural_key=os.environ["XB77_NEURAL_KEY"]
)

receipt = client.pay(
    amount="500 USDC",
    to="vendor.sol",
    privacy="shielded"
)
print(f"Ghost Receipt: {receipt.proof_hash}")`)), /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border, margin: "60px 0" } }), /* @__PURE__ */ React.createElement("section", { id: "network" }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "NETWORK API"), /* @__PURE__ */ React.createElement("h2", { style: { fontFamily: "var(--serif)", fontSize: "clamp(32px, 4vw, 48px)", fontWeight: 400, color: t.text, margin: "0 0 24px", lineHeight: 1.1 } }, "Live network data, in your browser."), /* @__PURE__ */ React.createElement(P, null, "The xB77 adapter exposes 4 REST endpoints with CORS open for any origin. The webapp ships a ", /* @__PURE__ */ React.createElement(Code, null, "window.DataSource"), " client with invisible degradation: live \u2192 cached \u2192 snapshot. The reader never sees a loader, never sees red."), /* @__PURE__ */ React.createElement(H3, null, "Endpoints"), /* @__PURE__ */ React.createElement(
    Table,
    {
      headers: ["Method", "Path", "Returns"],
      rows: [
        ["GET", "/api/network/pulse", "slot, blockHeight, agentsOnline, proofsVerified24h, ts"],
        ["GET", "/api/audit/:txhash", "verdict, proofId, agent, timestamp, chunks"],
        ["GET", "/api/agents", "agents: [{id, pubkey, status, pipelines, uptime}]"],
        ["GET", "/api/pipelines/recent", "pipelines: [{id, agent, chunks, status, verdict, ...}]"]
      ]
    }
  ), /* @__PURE__ */ React.createElement(P, null, "The adapter probes the znode RPC via ", /* @__PURE__ */ React.createElement(Code, null, "ZNODE_RPC_URL"), " (default ", /* @__PURE__ */ React.createElement(Code, null, "localhost:8899"), ") with a 1.5s timeout. If the RPC is unreachable, returns deterministic mock data so the webapp never breaks."), /* @__PURE__ */ React.createElement(H3, null, "DataSource client"), /* @__PURE__ */ React.createElement(P, null, "Drop ", /* @__PURE__ */ React.createElement(Code, null, "data-source.js"), " on the page and call any method. Every response carries ", /* @__PURE__ */ React.createElement(Code, null, "_source"), " (", /* @__PURE__ */ React.createElement(Code, null, "'live' | 'cached' | 'snapshot'"), ") and ", /* @__PURE__ */ React.createElement(Code, null, "_ageMs"), ". The client never throws."), /* @__PURE__ */ React.createElement(Code, { block: true }, `// Live data with automatic fallback
const pulse = await window.DataSource.networkPulse();
console.log(pulse.slot, pulse._source);   // 250412311 'live'

// Audit any transaction hash
const audit = await window.DataSource.auditTx('5K3sP9...');
console.log(audit.verdict, audit.chunks); // 'VALID' 8

// Polling subscription (returns unsubscribe)
const off = window.DataSource.subscribe(
  'networkPulse',
  (p) => console.log(p.slot),
  3000,
);
// later: off();`), /* @__PURE__ */ React.createElement(H3, null, "Degradation chain"), /* @__PURE__ */ React.createElement(P, null, "Each call walks three layers before returning. The UI dot color (", /* @__PURE__ */ React.createElement("span", { style: { color: t.accent, fontFamily: "var(--mono)" } }, "lime"), " / ", /* @__PURE__ */ React.createElement("span", { style: { color: "#e94da4", fontFamily: "var(--mono)" } }, "magenta"), " / ", /* @__PURE__ */ React.createElement("span", { style: { color: t.textDim, fontFamily: "var(--mono)" } }, "muted"), ") reflects which layer answered."), /* @__PURE__ */ React.createElement(
    Table,
    {
      headers: ["Source", "TTL", "When"],
      rows: [
        ["live", "\u2014", "Adapter reachable, returns 200"],
        ["cached", "30s", "localStorage hit, adapter unreachable"],
        ["snapshot", "\u221E", "Last-resort frozen payload bundled with the client"]
      ]
    }
  ), /* @__PURE__ */ React.createElement(H3, null, "Try it"), /* @__PURE__ */ React.createElement(P, null, "Open ", /* @__PURE__ */ React.createElement(Code, null, "/network"), " in the webapp to see all four endpoints driving a live page. Kill the adapter mid-session \u2014 the status pill flips to ", /* @__PURE__ */ React.createElement(Code, null, "// CACHED Xs"), " magenta, the numbers stay on screen."), /* @__PURE__ */ React.createElement(Code, { block: true }, `# spin up the adapter locally
cd gateway/worker && bunx wrangler@latest dev

# in another terminal
curl http://localhost:8787/api/network/pulse
# { "slot": 250412311, "blockHeight": 250411104, ... }`)), /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border, margin: "60px 0" } }), /* @__PURE__ */ React.createElement("section", { id: "protocol" }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "PROTOCOL"), /* @__PURE__ */ React.createElement("h2", { style: { fontFamily: "var(--serif)", fontSize: "clamp(32px, 4vw, 48px)", fontWeight: 400, color: t.text, margin: "0 0 24px", lineHeight: 1.1 } }, "Protocol Specs"), /* @__PURE__ */ React.createElement(H3, null, "ZK Privacy Engine"), /* @__PURE__ */ React.createElement(P, null, "xB77's proprietary privacy engine shields transactions at the protocol level. Payments are routed through the ZK layer, generating compressed proofs that verify validity without revealing strategy."), /* @__PURE__ */ React.createElement(
    Table,
    {
      headers: ["Parameter", "Value", "Notes"],
      rows: [
        ["Proof batch size", "100 txns", "Optimal batch for compression ratio"],
        ["Compression ratio", "99.7%", "10K txns \u2192 32 bytes on-chain"],
        ["Proof generation", "~200ms", "Per-transaction via Noir/Barretenberg"],
        ["Recursive aggregation", "Up to 10K", "Batched proofs merged recursively"],
        ["ZK fee", "0.001 SOL", "Paid from Sovereign Credits"]
      ]
    }
  ), /* @__PURE__ */ React.createElement(H3, null, "Ghost Receipt (Noir Circuit)"), /* @__PURE__ */ React.createElement(P, null, "The Ghost Receipt circuit proves the following without revealing any private inputs:"), /* @__PURE__ */ React.createElement("div", { style: { margin: "16px 0 24px", display: "flex", flexDirection: "column", gap: 8 } }, [
    "Amount is within Constitution-defined bounds",
    "Destination is in the allowed counterparty set",
    "Agent has sufficient balance (range proof)",
    "Cumulative daily spend \u2264 Constitution limit",
    "Infra Tax (2.011%) has been correctly computed"
  ].map((item, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { display: "flex", gap: 12, alignItems: "baseline" } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent } }, "\u2713"), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--sans)", fontSize: 14, color: t.textDim, lineHeight: 1.6 } }, item)))), /* @__PURE__ */ React.createElement(
    Table,
    {
      headers: ["Metric", "Value"],
      rows: [
        ["Circuit size", "~12,000 ACIR gates"],
        ["Proof generation", "~200ms (Barretenberg)"],
        ["Proof size", "256 bytes (before compression)"],
        ["Verification cost", "~50,000 CU on Solana"],
        ["Compressed size", "32 bytes (via xB77 ZK Engine)"]
      ]
    }
  ), /* @__PURE__ */ React.createElement(H3, null, "Neural Key Authentication"), /* @__PURE__ */ React.createElement(P, null, "Neural Keys are Ed25519 keypairs with an additional ZK identity layer. An agent proves it holds a valid key without revealing the key itself \u2014 preventing key-based identity correlation."), /* @__PURE__ */ React.createElement(Code, { block: true }, `NeuralKey = {
  public:  Ed25519PublicKey,     // on-chain identity
  private: Ed25519PrivateKey,    // never leaves agent
  zkid:    NoirCommitment,       // ZK commitment to key
  nonce:   u64,                  // replay protection
  ttl:     u64,                  // key rotation schedule
}`)))), /* @__PURE__ */ React.createElement(
    DocsDeepDive,
    {
      kicker: "// FULL DOCUMENTATION",
      label: "Reference, programs, proof format and more.",
      path: "/guide/quickstart"
    }
  ), /* @__PURE__ */ React.createElement(PageFooter, null));
}
Object.assign(window, { DocsPage });
