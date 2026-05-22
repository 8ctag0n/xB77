/* Architecture page — Interactive diagrams + technical documentation */

function ArchPage() {
  const t = THEMES.obsidian;
  const [activeLayer, setActiveLayer] = React.useState(null);
  const [hoveredNode, setHoveredNode] = React.useState(null);

  const layers = [
    {
      id: 'agents', label: 'Agent Layer', color: t.accent,
      nodes: [
        { name: 'CFO Agent', desc: 'Autonomous treasury management. Identifies payment needs, negotiates via AWP, executes without human intervention.', x: 20, y: 50 },
        { name: 'Ops Agent', desc: 'Infrastructure procurement — compute, storage, API access. Auto-scaling resource allocation.', x: 50, y: 50 },
        { name: 'Compliance Agent', desc: 'Monitors governance constraints. Triggers human signature lockdowns when Constitution thresholds are breached.', x: 80, y: 50 },
      ],
    },
    {
      id: 'core', label: 'xB77 Core', color: '#8888ff',
      nodes: [
        { name: 'Pipeline Engine', desc: 'Z-Node Core — native Zig implementation. Compressed state transitions, sub-millisecond routing.', x: 25, y: 50 },
        { name: 'Neural Key Auth', desc: 'Agent identity verification. ZK-based key management with revocation and rotation.', x: 50, y: 50 },
        { name: 'Governance Module', desc: 'Constitution enforcement. Multi-sig thresholds, spending limits, strategy constraints.', x: 75, y: 50 },
      ],
    },
    {
      id: 'privacy', label: 'Privacy Layer', color: '#ff6688',
      nodes: [
        { name: 'ZK Privacy Engine', desc: 'xB77\'s proprietary ZK layer. Shields transactions, compresses state, generates Ghost Receipts — no third-party dependencies.', x: 20, y: 50 },
        { name: 'Deploy Manager', desc: 'One-click agent provisioning. Self-hosted or cloud. Handles key management, config, and pipeline orchestration.', x: 50, y: 50 },
        { name: 'Noir ZK Prover', desc: 'Ghost Receipt generation. Proves transaction validity without revealing strategy, amounts, or counterparties.', x: 80, y: 50 },
      ],
    },
    {
      id: 'settlement', label: 'Settlement Layer', color: '#ffaa44',
      nodes: [
        { name: 'Solana L1', desc: 'Final settlement. Agave 2.0 runtime. ZK-compressed state transitions verified on-chain.', x: 25, y: 50 },
        { name: 'xB77 ZK Engine', desc: 'Proprietary ZK compression. On-chain storage reduced by 99.7% via recursive proof aggregation.', x: 50, y: 50 },
        { name: 'MagicBlock', desc: 'Turbo Rail — zero-latency ephemeral rollups for high-frequency agent transactions.', x: 75, y: 50 },
      ],
    },
  ];

  const dataFlows = [
    { label: 'Agent → Pipeline', from: 'Sovereign Intent', desc: 'Agent identifies a payment need and submits to the Pipeline Engine via AWP negotiation.' },
    { label: 'Pipeline → ZK Engine', from: 'Privacy Routing', desc: 'Pipeline routes through xB77\'s proprietary ZK layer. Transaction shielded, strategy remains opaque.' },
    { label: 'ZK Engine → Noir', from: 'Ghost Receipt', desc: 'Transaction executes. Noir generates a ZK proof (Ghost Receipt) — math-verified, strategy-opaque.' },
    { label: 'Noir → Solana', from: 'Settlement + Tax', desc: 'Proof anchored on Solana L1. Smart contract deducts 2.011% Infra Tax → Sovereign Credits pool.' },
    { label: 'Solana → Compress', from: 'Compressed Storage', desc: 'Receipt compressed via xB77 ZK Engine. 10K transactions → 1 ZK proof, 32 bytes on-chain.' },
  ];

  const techSpecs = [
    { label: 'Runtime', value: 'Zig (Z-Node Core)', detail: 'Native compiled, no VM overhead. ~4μs state transitions.' },
    { label: 'ZK Backend', value: 'Noir + Barretenberg', detail: 'ACIR circuit compilation. ~200ms proof generation per transaction.' },
    { label: 'L1 Settlement', value: 'Solana Agave 2.0', detail: 'Parallel transaction execution. 400ms block times.' },
    { label: 'Compression', value: 'xB77 ZK Engine', detail: 'Proprietary ZK compression. 99.7% storage reduction.' },
    { label: 'Fast Lane', value: 'MagicBlock Turbo', detail: 'Ephemeral rollups. Sub-100ms finality for HFT agents.' },
    { label: 'Deploy', value: 'Self-hosted / Cloud', detail: 'One-click provisioning. Like Vercel for AI finance.' },
  ];

  return (
    <div style={{ background: t.bg, minHeight: '100vh', color: t.text }}>
      <InnerNav active="Architecture" />

      {/* Hero */}
      <section style={{ padding: '100px 40px 80px', maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>SYSTEM ARCHITECTURE</div>
        <h1 style={{
          fontFamily: 'var(--serif)', fontSize: 'clamp(40px, 6vw, 80px)',
          fontWeight: 400, color: t.text, lineHeight: 1.0, margin: '0 0 20px',
        }}>
          Infrastructure <em style={{ color: t.accent, fontStyle: 'italic' }}>Map</em>
        </h1>
        <p style={{
          fontFamily: 'var(--sans)', fontSize: 17, color: t.textDim, lineHeight: 1.7,
          maxWidth: 560,
        }}>
          Four layers of sovereign financial infrastructure — from autonomous agents to ZK-compressed, pluggable settlement (Solana · Arc · Sui).
        </p>
      </section>

      {/* Interactive Layer Diagram */}
      <section style={{ padding: '0 40px 100px', maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.textDim, letterSpacing: '0.15em', marginBottom: 24, textTransform: 'uppercase' }}>CLICK A LAYER TO EXPLORE</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
          {layers.map((layer, li) => {
            const isActive = activeLayer === li;
            return (
              <div key={layer.id}>
                {/* Layer bar */}
                <div
                  onClick={() => setActiveLayer(isActive ? null : li)}
                  style={{
                    display: 'grid', gridTemplateColumns: '48px 200px 1fr 40px',
                    alignItems: 'center', gap: 16,
                    padding: '20px 24px', cursor: 'pointer',
                    background: isActive ? t.bgCard : 'transparent',
                    border: `1px solid ${isActive ? t.border : 'transparent'}`,
                    borderBottom: `1px solid ${t.border}`,
                    transition: 'all 0.3s',
                  }}
                >
                  <div style={{
                    width: 10, height: 10, borderRadius: '50%',
                    background: layer.color, opacity: isActive ? 1 : 0.4,
                    boxShadow: isActive ? `0 0 12px ${layer.color}40` : 'none',
                    transition: 'all 0.3s',
                  }}></div>
                  <div style={{
                    fontFamily: 'var(--mono)', fontSize: 13, fontWeight: 600,
                    color: isActive ? layer.color : t.text,
                    letterSpacing: '0.05em', transition: 'color 0.3s',
                  }}>{layer.label}</div>
                  <div style={{
                    fontFamily: 'var(--sans)', fontSize: 13, color: t.textDim,
                  }}>{layer.nodes.length} components</div>
                  <div style={{
                    fontFamily: 'var(--mono)', fontSize: 16, color: t.textDim,
                    transform: isActive ? 'rotate(90deg)' : 'none',
                    transition: 'transform 0.3s',
                  }}>→</div>
                </div>

                {/* Expanded nodes */}
                {isActive && (
                  <div style={{
                    display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 0,
                    borderBottom: `1px solid ${t.border}`,
                  }}>
                    {layer.nodes.map((node, ni) => (
                      <div key={ni}
                        style={{
                          padding: '28px 24px',
                          borderRight: ni < 2 ? `1px solid ${t.border}` : 'none',
                          background: hoveredNode === `${li}-${ni}` ? t.bgCard : 'transparent',
                          transition: 'background 0.3s', cursor: 'default',
                        }}
                        onMouseEnter={() => setHoveredNode(`${li}-${ni}`)}
                        onMouseLeave={() => setHoveredNode(null)}
                      >
                        <div style={{
                          fontFamily: 'var(--mono)', fontSize: 14, fontWeight: 600,
                          color: layer.color, marginBottom: 8,
                        }}>{node.name}</div>
                        <p style={{
                          fontFamily: 'var(--sans)', fontSize: 13, color: t.textDim,
                          lineHeight: 1.6, margin: 0,
                        }}>{node.desc}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </section>

      {/* Data Flow */}
      <section style={{ padding: '100px 40px', background: t.bgSecondary, borderTop: `1px solid ${t.border}` }}>
        <div style={{ maxWidth: 1100, margin: '0 auto' }}>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>DATA FLOW</div>
          <h2 style={{
            fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 52px)',
            fontWeight: 400, color: t.text, margin: '0 0 60px', lineHeight: 1.1,
          }}>
            Transaction <em style={{ color: t.accent, fontStyle: 'italic' }}>Pipeline</em>
          </h2>

          <div style={{ position: 'relative' }}>
            {/* Vertical line */}
            <div style={{
              position: 'absolute', left: 23, top: 20, bottom: 20, width: 2,
              background: `linear-gradient(to bottom, ${t.accent}, ${t.border})`, opacity: 0.4,
            }}></div>

            {dataFlows.map((flow, i) => (
              <div key={i} style={{
                display: 'grid', gridTemplateColumns: '48px 1fr', gap: 24,
                padding: '24px 0',
              }}>
                <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 6 }}>
                  <div style={{
                    width: 12, height: 12, borderRadius: '50%', position: 'relative', zIndex: 1,
                    background: t.accent, border: `2px solid ${t.accent}`,
                    boxShadow: `0 0 12px ${t.terminalGlow}`,
                  }}></div>
                </div>
                <div style={{
                  background: t.bgCard, border: `1px solid ${t.border}`,
                  padding: '20px 24px',
                }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginBottom: 8 }}>
                    <span style={{ fontFamily: 'var(--mono)', fontSize: 12, color: t.accent, fontWeight: 600 }}>{flow.label}</span>
                    <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.textDim, letterSpacing: '0.1em' }}>{flow.from}</span>
                  </div>
                  <p style={{ fontFamily: 'var(--sans)', fontSize: 14, color: t.textDim, lineHeight: 1.6, margin: 0 }}>{flow.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Tech Specs Grid */}
      <section style={{ padding: '100px 40px', borderTop: `1px solid ${t.border}` }}>
        <div style={{ maxWidth: 1100, margin: '0 auto' }}>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>TECH STACK</div>
          <h2 style={{
            fontFamily: 'var(--serif)', fontSize: 'clamp(32px, 4vw, 52px)',
            fontWeight: 400, color: t.text, margin: '0 0 48px', lineHeight: 1.1,
          }}>
            Under the <em style={{ color: t.accent, fontStyle: 'italic' }}>Hood</em>
          </h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 0 }}>
            {techSpecs.map((spec, i) => (
              <div key={i} style={{
                padding: '28px 24px',
                borderRight: (i % 3 < 2) ? `1px solid ${t.border}` : 'none',
                borderBottom: i < 3 ? `1px solid ${t.border}` : 'none',
                transition: 'background 0.3s', cursor: 'default',
              }}
                onMouseEnter={e => e.currentTarget.style.background = t.bgCard}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: t.textDim, letterSpacing: '0.15em', marginBottom: 8, textTransform: 'uppercase' }}>{spec.label}</div>
                <div style={{ fontFamily: 'var(--mono)', fontSize: 16, color: t.accent, fontWeight: 600, marginBottom: 6 }}>{spec.value}</div>
                <div style={{ fontFamily: 'var(--sans)', fontSize: 13, color: t.textDim, lineHeight: 1.5 }}>{spec.detail}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <DocsDeepDive
        kicker="// FULL ARCHITECTURE BRIEF"
        label="The complete layered architecture."
        path="/architecture"
      />

      <PageFooter />
    </div>
  );
}

Object.assign(window, { ArchPage });
