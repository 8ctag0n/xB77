/* Docs page — Sidebar nav, quickstart, API ref, SDK, protocol specs */

const DOC_SECTIONS = [
  { id: 'quickstart', label: 'Quickstart' },
  { id: 'api', label: 'API Reference' },
  { id: 'sdk', label: 'SDK Guide' },
  { id: 'network', label: 'Network API' },
  { id: 'protocol', label: 'Protocol Specs' },
];

function DocsPage() {
  const t = THEMES.obsidian;
  const [active, setActive] = React.useState('quickstart');

  const scrollTo = (id) => {
    setActive(id);
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  // Observe scroll to update active
  React.useEffect(() => {
    const els = DOC_SECTIONS.map(s => document.getElementById(s.id)).filter(Boolean);
    const obs = new IntersectionObserver((entries) => {
      entries.forEach(e => { if (e.isIntersecting) setActive(e.target.id); });
    }, { rootMargin: '-80px 0px -60% 0px', threshold: 0.1 });
    els.forEach(el => obs.observe(el));
    return () => obs.disconnect();
  }, []);

  const Code = ({ children, block }) => {
    if (block) return <SyntaxHighlight code={children} theme="obsidian" />;
    return (
      <code style={{
        background: t.terminalBg, border: `1px solid ${t.border}`,
        padding: '2px 6px', fontFamily: 'var(--mono)', fontSize: 12.5, color: t.accent,
      }}>{children}</code>
    );
  };

  const H3 = ({ children }) => (
    <h3 style={{ fontFamily: 'var(--serif)', fontSize: 26, fontWeight: 400, color: t.text, margin: '48px 0 16px', lineHeight: 1.2 }}>{children}</h3>
  );

  const P = ({ children }) => (
    <p style={{ fontFamily: 'var(--sans)', fontSize: 15, color: t.textDim, lineHeight: 1.8, margin: '0 0 16px' }}>{children}</p>
  );

  const Table = ({ headers, rows }) => (
    <div style={{ overflowX: 'auto', margin: '16px 0 24px' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'var(--mono)', fontSize: 12 }}>
        <thead>
          <tr>{headers.map((h, i) => (
            <th key={i} style={{ textAlign: 'left', padding: '10px 16px', borderBottom: `2px solid ${t.border}`, color: t.accent, letterSpacing: '0.08em', fontSize: 10, textTransform: 'uppercase' }}>{h}</th>
          ))}</tr>
        </thead>
        <tbody>
          {rows.map((row, ri) => (
            <tr key={ri}>{row.map((cell, ci) => (
              <td key={ci} style={{ padding: '10px 16px', borderBottom: `1px solid ${t.border}`, color: ci === 0 ? t.text : t.textDim, fontWeight: ci === 0 ? 600 : 400 }}>{cell}</td>
            ))}</tr>
          ))}
        </tbody>
      </table>
    </div>
  );

  return (
    <div style={{ background: t.bg, minHeight: '100vh', color: t.text }}>
      <InnerNav active="Docs" />

      <div style={{ display: 'grid', gridTemplateColumns: '240px 1fr', minHeight: 'calc(100vh - 56px)' }}>
        {/* Sidebar */}
        <aside style={{
          borderRight: `1px solid ${t.border}`, padding: '32px 0',
          position: 'sticky', top: 56, height: 'calc(100vh - 56px)', overflowY: 'auto',
        }}>
          <div style={{ padding: '0 24px', marginBottom: 24 }}>
            <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: t.textDim, letterSpacing: '0.2em', textTransform: 'uppercase' }}>DOCUMENTATION</div>
          </div>
          {DOC_SECTIONS.map(s => (
            <div key={s.id}
              onClick={() => scrollTo(s.id)}
              style={{
                padding: '10px 24px', cursor: 'pointer',
                fontFamily: 'var(--mono)', fontSize: 12, letterSpacing: '0.04em',
                color: active === s.id ? t.accent : t.textDim,
                borderLeft: active === s.id ? `2px solid ${t.accent}` : '2px solid transparent',
                background: active === s.id ? t.accentDim : 'transparent',
                transition: 'all 0.2s',
              }}
            >{s.label}</div>
          ))}

          <div style={{ padding: '32px 24px 0' }}>
            <div style={{ width: '100%', height: 1, background: t.border, marginBottom: 20 }}></div>
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.textDim, lineHeight: 1.8 }}>
              <a href="/index.html#architecture" style={{ color: t.textDim, textDecoration: 'none', display: 'block', transition: 'color 0.2s' }}
                onMouseEnter={e => e.target.style.color = t.accent}
                onMouseLeave={e => e.target.style.color = t.textDim}>→ Architecture</a>
              <a href="/index.html#whitepaper" style={{ color: t.textDim, textDecoration: 'none', display: 'block', transition: 'color 0.2s' }}
                onMouseEnter={e => e.target.style.color = t.accent}
                onMouseLeave={e => e.target.style.color = t.textDim}>→ Whitepaper</a>
            </div>
          </div>
        </aside>

        {/* Content */}
        <main style={{ padding: '48px 60px 120px', maxWidth: 800 }}>

          {/* QUICKSTART */}
          <section id="quickstart">
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>GETTING STARTED</div>
            <h2 style={{ fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 48px)', fontWeight: 400, color: t.text, margin: '0 0 24px', lineHeight: 1.1 }}>
              Quickstart
            </h2>
            <P>Get a shielded agent pipeline running in under 5 minutes.</P>

            <H3>1. Install the CLI</H3>
            <Code block>{`$ npm install -g @xb77/cli

# or with cargo (native Zig bindings)
$ cargo install xb77-cli`}</Code>

            <H3>2. Initialize a Pipeline</H3>
            <Code block>{`$ xb77 init my-agent --network devnet

✓ Created pipeline config: ./my-agent/xb77.config.toml
✓ Generated Neural Key pair
✓ Connected to Solana devnet`}</Code>

            <H3>3. Configure Your Constitution</H3>
            <P>The Constitution defines what your agent can and cannot do. Edit <Code>xb77.config.toml</Code>:</P>
            <Code block>{`[constitution]
max_single_tx = "1000 USDC"
max_daily_spend = "10000 USDC"
allowed_counterparties = ["*"]  # or specific pubkeys
require_human_above = "5000 USDC"
strategy_disclosure = "none"    # none | selective | full`}</Code>

            <H3>4. Launch the Pipeline</H3>
            <Code block>{`$ xb77 launch --agent cfo-alpha

[INIT] PIPELINE_START: AGENT_CFO_ALPHA
[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)
[READY] Pipeline active. Awaiting intents...`}</Code>
            <P>Your agent is now live. Transactions are shielded via xB77's ZK Engine, receipts are compressed on-chain, and the 2.011% Infra Tax is collected automatically.</P>
          </section>

          <div style={{ width: '100%', height: 1, background: t.border, margin: '60px 0' }}></div>

          {/* API REFERENCE */}
          <section id="api">
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>REFERENCE</div>
            <h2 style={{ fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 48px)', fontWeight: 400, color: t.text, margin: '0 0 24px', lineHeight: 1.1 }}>
              API Reference
            </h2>
            <P>The xB77 API is JSON-RPC over WebSocket. All endpoints require Neural Key authentication.</P>

            <H3>Authentication</H3>
            <Code block>{`POST /v1/auth/verify
{
  "neural_key": "<base58-encoded-key>",
  "timestamp": 1716000000,
  "signature": "<ed25519-sig>"
}
→ { "token": "xb77_live_...", "expires": 3600 }`}</Code>

            <H3>Core Endpoints</H3>
            <Table
              headers={['Endpoint', 'Method', 'Description']}
              rows={[
                ['/v1/pipeline/start', 'POST', 'Initialize a new agent pipeline'],
                ['/v1/pipeline/status', 'GET', 'Get pipeline status and active intents'],
                ['/v1/intent/submit', 'POST', 'Submit a sovereign intent for execution'],
                ['/v1/intent/{id}', 'GET', 'Get intent status and Ghost Receipt'],
                ['/v1/zk/route', 'POST', 'Route a payment through the ZK privacy layer'],
                ['/v1/receipt/{id}', 'GET', 'Fetch a ZK-compressed receipt'],
                ['/v1/constitution', 'GET/PUT', 'Read or update agent constitution'],
                ['/v1/governance/lockdowns', 'GET', 'List pending lockdown approvals'],
              ]}
            />

            <H3>Submit an Intent</H3>
            <Code block>{`POST /v1/intent/submit
{
  "type": "payment",
  "amount": "500.00",
  "currency": "USDC",
  "destination": "<pubkey or AWP endpoint>",
  "privacy": "shielded",       // shielded | transparent
  "urgency": "turbo",          // turbo (MagicBlock) | standard | batch
  "memo_zk": true              // attach Ghost Receipt
}
→ {
  "intent_id": "int_7x8k...",
  "status": "routing",
  "estimated_fee": "0.012 SOL",
  "infra_tax": "10.055 USDC"   // 2.011% of 500
}`}</Code>

            <H3>Webhook Events</H3>
            <Table
              headers={['Event', 'Payload', 'Description']}
              rows={[
                ['intent.completed', '{intent_id, receipt_id, proof}', 'Intent settled on L1'],
                ['intent.lockdown', '{intent_id, reason, threshold}', 'Constitution breach — human sig required'],
                ['receipt.compressed', '{receipt_id, proof_size}', 'Receipt compressed via xB77 ZK Engine'],
                ['pipeline.error', '{code, message}', 'Pipeline-level error'],
              ]}
            />
          </section>

          <div style={{ width: '100%', height: 1, background: t.border, margin: '60px 0' }}></div>

          {/* SDK GUIDE */}
          <section id="sdk">
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>INTEGRATION</div>
            <h2 style={{ fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 48px)', fontWeight: 400, color: t.text, margin: '0 0 24px', lineHeight: 1.1 }}>
              SDK Guide
            </h2>
            <P>Available in TypeScript, Rust, and Python. The SDK wraps the JSON-RPC API with typed clients and convenience helpers.</P>

            <H3>TypeScript</H3>
            <Code block>{`import { XB77Client, Pipeline } from '@xb77/sdk';

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
console.log(receipt.proofHash); // 32-byte ZK proof`}</Code>

            <H3>Rust</H3>
            <Code block>{`use xb77_sdk::{Client, IntentBuilder};

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
println!("Proof: {}", receipt.proof_hash);`}</Code>

            <H3>Python</H3>
            <Code block>{`from xb77 import XB77Client

client = XB77Client(
    network="mainnet",
    neural_key=os.environ["XB77_NEURAL_KEY"]
)

receipt = client.pay(
    amount="500 USDC",
    to="vendor.sol",
    privacy="shielded"
)
print(f"Ghost Receipt: {receipt.proof_hash}")`}</Code>
          </section>

          <div style={{ width: '100%', height: 1, background: t.border, margin: '60px 0' }}></div>

          {/* NETWORK API (W3 — public adapter + DataSource client) */}
          <section id="network">
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>NETWORK API</div>
            <h2 style={{ fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 48px)', fontWeight: 400, color: t.text, margin: '0 0 24px', lineHeight: 1.1 }}>
              Live network data, in your browser.
            </h2>
            <P>The xB77 adapter exposes 4 REST endpoints with CORS open for any origin. The webapp ships a <Code>window.DataSource</Code> client with invisible degradation: live → cached → snapshot. The reader never sees a loader, never sees red.</P>

            <H3>Endpoints</H3>
            <Table
              headers={['Method', 'Path', 'Returns']}
              rows={[
                ['GET', '/api/network/pulse',       'slot, blockHeight, agentsOnline, proofsVerified24h, ts'],
                ['GET', '/api/audit/:txhash',       'verdict, proofId, agent, timestamp, chunks'],
                ['GET', '/api/agents',              'agents: [{id, pubkey, status, pipelines, uptime}]'],
                ['GET', '/api/pipelines/recent',    'pipelines: [{id, agent, chunks, status, verdict, ...}]'],
              ]}
            />
            <P>The adapter probes the znode RPC via <Code>ZNODE_RPC_URL</Code> (default <Code>localhost:8899</Code>) with a 1.5s timeout. If the RPC is unreachable, returns deterministic mock data so the webapp never breaks.</P>

            <H3>DataSource client</H3>
            <P>Drop <Code>data-source.js</Code> on the page and call any method. Every response carries <Code>_source</Code> (<Code>'live' | 'cached' | 'snapshot'</Code>) and <Code>_ageMs</Code>. The client never throws.</P>
            <Code block>{`// Live data with automatic fallback
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
// later: off();`}</Code>

            <H3>Degradation chain</H3>
            <P>Each call walks three layers before returning. The UI dot color (<span style={{ color: t.accent, fontFamily: 'var(--mono)' }}>lime</span> / <span style={{ color: '#e94da4', fontFamily: 'var(--mono)' }}>magenta</span> / <span style={{ color: t.textDim, fontFamily: 'var(--mono)' }}>muted</span>) reflects which layer answered.</P>
            <Table
              headers={['Source', 'TTL', 'When']}
              rows={[
                ['live',     '—',    'Adapter reachable, returns 200'],
                ['cached',   '30s',  'localStorage hit, adapter unreachable'],
                ['snapshot', '∞',    'Last-resort frozen payload bundled with the client'],
              ]}
            />

            <H3>Try it</H3>
            <P>Open <Code>/network</Code> in the webapp to see all four endpoints driving a live page. Kill the adapter mid-session — the status pill flips to <Code>// CACHED Xs</Code> magenta, the numbers stay on screen.</P>
            <Code block>{`# spin up the adapter locally
cd gateway/worker && bunx wrangler@latest dev

# in another terminal
curl http://localhost:8787/api/network/pulse
# { "slot": 250412311, "blockHeight": 250411104, ... }`}</Code>
          </section>

          <div style={{ width: '100%', height: 1, background: t.border, margin: '60px 0' }}></div>

          {/* PROTOCOL SPECS */}
          <section id="protocol">
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>PROTOCOL</div>
            <h2 style={{ fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 48px)', fontWeight: 400, color: t.text, margin: '0 0 24px', lineHeight: 1.1 }}>
              Protocol Specs
            </h2>

            <H3>ZK Privacy Engine</H3>
            <P>xB77's proprietary privacy engine shields transactions at the protocol level. Payments are routed through the ZK layer, generating compressed proofs that verify validity without revealing strategy.</P>
            <Table
              headers={['Parameter', 'Value', 'Notes']}
              rows={[
                ['Proof batch size', '100 txns', 'Optimal batch for compression ratio'],
                ['Compression ratio', '99.7%', '10K txns → 32 bytes on-chain'],
                ['Proof generation', '~200ms', 'Per-transaction via Noir/Barretenberg'],
                ['Recursive aggregation', 'Up to 10K', 'Batched proofs merged recursively'],
                ['ZK fee', '0.001 SOL', 'Paid from Sovereign Credits'],
              ]}
            />

            <H3>Ghost Receipt (Noir Circuit)</H3>
            <P>The Ghost Receipt circuit proves the following without revealing any private inputs:</P>
            <div style={{ margin: '16px 0 24px', display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[
                'Amount is within Constitution-defined bounds',
                'Destination is in the allowed counterparty set',
                'Agent has sufficient balance (range proof)',
                'Cumulative daily spend ≤ Constitution limit',
                'Infra Tax (2.011%) has been correctly computed',
              ].map((item, i) => (
                <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'baseline' }}>
                  <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent }}>✓</span>
                  <span style={{ fontFamily: 'var(--sans)', fontSize: 14, color: t.textDim, lineHeight: 1.6 }}>{item}</span>
                </div>
              ))}
            </div>
            <Table
              headers={['Metric', 'Value']}
              rows={[
                ['Circuit size', '~12,000 ACIR gates'],
                ['Proof generation', '~200ms (Barretenberg)'],
                ['Proof size', '256 bytes (before compression)'],
                ['Verification cost', '~50,000 CU on Solana'],
                ['Compressed size', '32 bytes (via xB77 ZK Engine)'],
              ]}
            />

            <H3>Neural Key Authentication</H3>
            <P>Neural Keys are Ed25519 keypairs with an additional ZK identity layer. An agent proves it holds a valid key without revealing the key itself — preventing key-based identity correlation.</P>
            <Code block>{`NeuralKey = {
  public:  Ed25519PublicKey,     // on-chain identity
  private: Ed25519PrivateKey,    // never leaves agent
  zkid:    NoirCommitment,       // ZK commitment to key
  nonce:   u64,                  // replay protection
  ttl:     u64,                  // key rotation schedule
}`}</Code>
          </section>
        </main>
      </div>

      <DocsDeepDive
        kicker="// FULL DOCUMENTATION"
        label="Reference, programs, proof format and more."
        path="/guide/quickstart"
      />

      <PageFooter />
    </div>
  );
}

Object.assign(window, { DocsPage });
