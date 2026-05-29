/* Shared: Architecture diagram + Footer */

function ArchDiagram({ theme }) {
  const t = THEMES[theme];
  const bp = typeof useBreakpoint === 'function' ? useBreakpoint() : { mobile: false };
  return (
    <section style={{ padding: bp.mobile ? '60px 20px' : '100px 40px', background: t.bg }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>ARCHITECTURE</div>
        <h2 style={{
          fontFamily: 'var(--serif)', fontSize: bp.mobile ? 32 : 'clamp(32px, 4vw, 52px)',
          fontWeight: 400, color: t.text, margin: '0 0 60px', lineHeight: 1.1,
        }}>
          Infrastructure <em style={{ color: t.accent, fontStyle: 'italic' }}>Map</em>
        </h2>
        <div style={{
          position: 'relative', width: '100%', maxWidth: 700,
          margin: '0 auto', aspectRatio: '7/5',
          background: t.terminalBg, border: `1px solid ${t.border}`,
          overflow: 'hidden',
        }}>
          {/* Animated pulse overlay */}
          <style>{`
            @keyframes archPulse {
              0%, 100% { opacity: 0.15; }
              50% { opacity: 0.5; }
            }
            @keyframes flowDash {
              0% { stroke-dashoffset: 12; }
              100% { stroke-dashoffset: 0; }
            }
          `}</style>
          <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} viewBox="0 0 100 100" preserveAspectRatio="none">
            {ARCH_CONNS.map(([a, b], i) => (
              <line key={i}
                x1={ARCH_NODES[a].x} y1={ARCH_NODES[a].y}
                x2={ARCH_NODES[b].x} y2={ARCH_NODES[b].y}
                stroke={t.accent} strokeWidth="0.2" opacity="0.3"
                strokeDasharray="1.2 0.6"
                style={{ animation: `flowDash 1.5s linear infinite`, animationDelay: `${i * 0.2}s` }}
              />
            ))}
          </svg>
          {ARCH_NODES.map((node, i) => (
            <div key={i} style={{
              position: 'absolute', left: `${node.x}%`, top: `${node.y}%`,
              transform: 'translate(-50%, -50%)', textAlign: 'center',
            }}>
              {/* Pulse ring */}
              <div style={{
                position: 'absolute', inset: -6, borderRadius: '50%',
                border: `1px solid ${t.accent}`,
                animation: 'archPulse 3s ease-in-out infinite',
                animationDelay: `${i * 0.5}s`,
                pointerEvents: 'none',
              }}></div>
              <div style={{
                background: t.bg, border: `1px solid ${t.border}`,
                padding: bp.mobile ? '8px 12px' : '12px 20px',
                transition: 'border-color 0.3s, box-shadow 0.3s', cursor: 'default',
              }}
                onMouseEnter={e => { e.currentTarget.style.borderColor = t.accent; e.currentTarget.style.boxShadow = `0 0 20px ${t.terminalGlow}`; }}
                onMouseLeave={e => { e.currentTarget.style.borderColor = t.border; e.currentTarget.style.boxShadow = ''; }}
              >
                <div style={{ fontFamily: 'var(--mono)', fontSize: bp.mobile ? 9 : 11, color: t.text, fontWeight: 600, letterSpacing: '0.05em', whiteSpace: 'nowrap' }}>{node.label}</div>
                <div style={{ fontFamily: 'var(--mono)', fontSize: bp.mobile ? 7 : 9, color: t.textDim, marginTop: 3, letterSpacing: '0.08em', whiteSpace: 'nowrap' }}>{node.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function SiteFooter({ theme }) {
  const t = THEMES[theme];
  return (
    <footer style={{
      background: t.bgSecondary, borderTop: `1px solid ${t.border}`, padding: '60px 40px',
    }}>
      <div style={{
        maxWidth: 1100, margin: '0 auto',
        display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end',
      }}>
        <div>
          <div style={{ fontFamily: 'var(--mono)', fontWeight: 700, fontSize: 18, color: t.accent, letterSpacing: '0.05em', marginBottom: 8 }}>xB77</div>
          <div style={{ fontFamily: 'var(--sans)', fontSize: 13, color: t.textDim, lineHeight: 1.5 }}>
            Autonomous Financial Infrastructure<br />
            Built for the Solana Privacy Hackathon 2026
          </div>
        </div>
        <div style={{
          display: 'flex', gap: 24,
          fontFamily: 'var(--mono)', fontSize: 11, color: t.textDim,
          letterSpacing: '0.1em', textTransform: 'uppercase',
        }}>
          {['Docs', 'Whitepaper', 'GitHub', 'Explorer'].map(l => (
            <a key={l} style={{ color: t.textDim, textDecoration: 'none', cursor: 'pointer', transition: 'color 0.2s' }}
              onMouseEnter={e => e.target.style.color = t.accent}
              onMouseLeave={e => e.target.style.color = t.textDim}>{l}</a>
          ))}
        </div>
      </div>
      <div style={{
        maxWidth: 1100, margin: '24px auto 0',
        fontFamily: 'var(--mono)', fontSize: 10, color: t.textDim,
        opacity: 0.4, letterSpacing: '0.1em',
      }}>© 2026 xB77 Labs</div>
    </footer>
  );
}

/* ── Tokenomics: The 2.011% Engine ── */

const PIPELINE_STEPS = [
  { num: '01', tag: 'SOVEREIGN_INTENT', title: 'Sovereign Intent', desc: 'Agent identifies a need — compute, API, liquidity. Negotiates price via AWP with zero human intervention.' },
  { num: '02', tag: 'ZK_PRIVACY', title: 'ZK Privacy Layer', desc: 'xB77\'s proprietary ZK engine shields the transaction. Strategy-opaque, math-enforced — no third-party dependencies.' },
  { num: '03', tag: 'GHOST_RECEIPT', title: 'The Ghost Receipt', desc: 'Noir generates a ZK proof the payment occurred — without revealing the Agent\'s internal strategy. Math-enforced Constitution compliance.' },
  { num: '04', tag: 'INFRA_TAX', title: 'Infra Tax Collection', desc: 'Smart contract deducts 2.011% on-chain. Funds flow to the Sovereign Credits pool — subsidizing RPCs, storage, and ZK proof generation.' },
];

function Tokenomics({ theme }) {
  const t = THEMES[theme];
  const [hovered, setHovered] = React.useState(null);

  return (
    <section style={{ padding: '120px 40px', background: t.bg, borderTop: `1px solid ${t.border}` }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>TOKENOMICS</div>
        <h2 style={{
          fontFamily: 'var(--serif)', fontSize: 'clamp(36px, 5vw, 64px)',
          fontWeight: 400, color: t.text, margin: '0 0 16px', lineHeight: 1.05,
        }}>
          The <em style={{ color: t.accent, fontStyle: 'italic' }}>2.011%</em> Engine
        </h2>
        <p style={{
          fontFamily: 'var(--sans)', fontSize: 16, color: t.textDim, lineHeight: 1.7,
          maxWidth: 560, margin: '0 0 64px',
        }}>
          No inflationary token. Infrastructure sustainability through usage — xB77 charges for autonomy, not transactions.
        </p>

        {/* Pipeline flow */}
        <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', gap: 0 }}>
          {/* Vertical line */}
          <div style={{
            position: 'absolute', left: 23, top: 24, bottom: 24, width: 1,
            background: `linear-gradient(to bottom, ${t.accent}, ${t.border})`,
            opacity: 0.3,
          }}></div>

          {PIPELINE_STEPS.map((step, i) => (
            <div key={i}
              style={{
                display: 'grid', gridTemplateColumns: '48px 1fr', gap: 24,
                padding: '28px 0', cursor: 'default',
              }}
              onMouseEnter={() => setHovered(i)}
              onMouseLeave={() => setHovered(null)}
            >
              {/* Node dot */}
              <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 4 }}>
                <div style={{
                  width: 14, height: 14, borderRadius: '50%',
                  background: hovered === i ? t.accent : t.bg,
                  border: `2px solid ${hovered === i ? t.accent : t.textDim}`,
                  transition: 'all 0.3s',
                  boxShadow: hovered === i ? `0 0 16px ${t.terminalGlow}` : 'none',
                  position: 'relative', zIndex: 1,
                }}></div>
              </div>

              {/* Content */}
              <div style={{
                background: hovered === i ? t.bgCard : 'transparent',
                border: `1px solid ${hovered === i ? t.border : 'transparent'}`,
                padding: '20px 24px', transition: 'all 0.3s',
                transform: hovered === i ? 'translateX(6px)' : 'none',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
                  <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.15em', opacity: 0.5 }}>{step.tag}</span>
                </div>
                <h3 style={{
                  fontFamily: 'var(--serif)', fontSize: 26, fontWeight: 400, color: t.text,
                  margin: '0 0 8px',
                }}>
                  <span style={{ color: t.accent, fontStyle: 'italic' }}>{step.num}.</span> {step.title}
                </h3>
                <p style={{
                  fontFamily: 'var(--sans)', fontSize: 14, color: t.textDim,
                  lineHeight: 1.65, margin: 0, maxWidth: 480,
                }}>{step.desc}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Quote callout */}
        <div style={{
          marginTop: 48, padding: '28px 32px',
          borderLeft: `3px solid ${t.accent}`,
          background: t.accentDim,
        }}>
          <p style={{
            fontFamily: 'var(--serif)', fontSize: 22, fontStyle: 'italic',
            color: t.text, margin: 0, lineHeight: 1.4,
          }}>
            "xB77 doesn't charge per transaction, it charges for <span style={{ color: t.accent }}>autonomy</span>."
          </p>
        </div>
      </div>
    </section>
  );
}


/* ── Roadmap: Git Graph style ── */

const ROADMAP_PHASES = [
  {
    phase: 'Phase 1', name: 'Frontier', period: 'Hackathon — May 2026',
    status: 'current',
    items: [
      'Z-Node Core — Native Zig implementation of compressed state engine',
      'xB77 ZK Engine — Proprietary privacy + compression on Solana',
      'Easy Deploy — One-click agent provisioning, self-hosted or cloud',
    ],
  },
  {
    phase: 'Phase 2', name: 'Infiltration', period: 'Q3 2026',
    status: 'future',
    items: [
      'Multi-Agent Mesh — Sovereign flash loans between agents',
      'x402 Protocol — Standard payment protocol for any AI wallet',
      'Marketplace — Agent templates, plugins, and strategy modules',
    ],
  },
  {
    phase: 'Phase 3', name: 'Sovereignty', period: '2027',
    status: 'future',
    items: [
      'Recursive Proof Aggregation — 10K agent txns → 1 ZK proof (32 bytes)',
      'Sovereign Financial OS — Agents as autonomous legal entities with cryptographic receipts',
    ],
  },
];

function Roadmap({ theme }) {
  const t = THEMES[theme];
  const [hovered, setHovered] = React.useState(null);

  return (
    <section style={{
      padding: '120px 40px', background: t.bgSecondary,
      borderTop: `1px solid ${t.border}`,
    }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>ROADMAP</div>
        <h2 style={{
          fontFamily: 'var(--serif)', fontSize: 'clamp(36px, 5vw, 64px)',
          fontWeight: 400, color: t.text, margin: '0 0 16px', lineHeight: 1.05,
        }}>
          The Frontier <em style={{ color: t.accent, fontStyle: 'italic' }}>Expansion</em>
        </h2>
        <p style={{
          fontFamily: 'var(--sans)', fontSize: 16, color: t.textDim, lineHeight: 1.7,
          maxWidth: 500, margin: '0 0 72px',
        }}>
          Phased infiltration into the traditional financial system.
        </p>

        {/* Git graph */}
        <div style={{ position: 'relative' }}>
          {/* Main branch line */}
          <div style={{
            position: 'absolute', left: 23, top: 0, bottom: 0, width: 2,
            background: `linear-gradient(to bottom, ${t.accent}, ${t.border} 40%, ${t.border})`,
          }}></div>

          {ROADMAP_PHASES.map((phase, pi) => {
            const isCurrent = phase.status === 'current';
            const isFuture = phase.status === 'future';
            return (
              <div key={pi} style={{ position: 'relative', marginBottom: pi < ROADMAP_PHASES.length - 1 ? 56 : 0 }}>
                {/* Commit node */}
                <div style={{
                  position: 'absolute', left: 12, top: 0, zIndex: 2,
                  width: 24, height: 24, borderRadius: '50%',
                  background: isCurrent ? t.accent : t.bg,
                  border: `2px solid ${isCurrent ? t.accent : t.textDim}`,
                  boxShadow: isCurrent ? `0 0 20px ${t.terminalGlow}, 0 0 40px ${t.terminalGlow}` : 'none',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {isCurrent && <div style={{ width: 8, height: 8, borderRadius: '50%', background: t.bg }}></div>}
                </div>

                {/* Phase content */}
                <div style={{ marginLeft: 56 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 6 }}>
                    <span style={{
                      fontFamily: 'var(--mono)', fontSize: 10, letterSpacing: '0.15em',
                      color: isCurrent ? t.accent : t.textDim,
                      textTransform: 'uppercase',
                    }}>{phase.phase}</span>
                    {isCurrent && (
                      <span style={{
                        fontFamily: 'var(--mono)', fontSize: 9, letterSpacing: '0.1em',
                        color: t.bg, background: t.accent, padding: '2px 8px',
                        fontWeight: 600,
                      }}>CURRENT</span>
                    )}
                  </div>
                  <h3 style={{
                    fontFamily: 'var(--serif)', fontSize: 32, fontWeight: 400,
                    color: isFuture ? t.textDim : t.text, margin: '0 0 4px',
                    fontStyle: 'italic',
                  }}>{phase.name}</h3>
                  <div style={{
                    fontFamily: 'var(--mono)', fontSize: 11, color: t.textDim,
                    letterSpacing: '0.06em', marginBottom: 20,
                  }}>{phase.period}</div>

                  {/* Branch items */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                    {phase.items.map((item, ii) => (
                      <div key={ii}
                        style={{
                          display: 'grid', gridTemplateColumns: '24px 1fr', gap: 12,
                          padding: '12px 0',
                          cursor: 'default',
                        }}
                        onMouseEnter={() => setHovered(`${pi}-${ii}`)}
                        onMouseLeave={() => setHovered(null)}
                      >
                        {/* Branch dot */}
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                          <div style={{
                            width: 8, height: 8, borderRadius: '50%',
                            border: `1.5px ${isFuture ? 'dashed' : 'solid'} ${hovered === `${pi}-${ii}` ? t.accent : t.textDim}`,
                            background: isCurrent && hovered === `${pi}-${ii}` ? t.accent : 'transparent',
                            transition: 'all 0.2s',
                          }}></div>
                        </div>
                        <div style={{
                          fontFamily: 'var(--sans)', fontSize: 14, color: isFuture ? t.textDim : t.text,
                          lineHeight: 1.5,
                          opacity: hovered === `${pi}-${ii}` ? 1 : (isFuture ? 0.6 : 0.85),
                          transition: 'opacity 0.2s',
                        }}>
                          <strong style={{ color: isFuture ? t.textDim : t.text }}>{item.split('—')[0]}</strong>
                          {item.includes('—') && <span style={{ color: t.textDim }}> — {item.split('—').slice(1).join('—')}</span>}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

Object.assign(window, { ArchDiagram, SiteFooter, Tokenomics, Roadmap });
