/* Interactive Pipeline Demo + Live Metrics Dashboard */

const DEMO_STEPS = [
  { id: 'intent', label: 'Sovereign Intent', tag: 'AGENT_CFO', detail: 'Agent identifies need: 500 USDC compute purchase. AWP negotiation — zero human input.', icon: '◈', duration: 1200 },
  { id: 'zk', label: 'ZK Privacy Layer', tag: 'ZK_ENGINE', detail: 'xB77 proprietary ZK engine shields the transaction. Strategy-opaque, no third-party dependencies.', icon: '◇', duration: 1500 },
  { id: 'ghost', label: 'Ghost Receipt', tag: 'ZK_PROOF', detail: 'Noir generates ZK proof: amount valid, Constitution compliant, strategy opaque. 200ms proving time.', icon: '◆', duration: 1800 },
  { id: 'settle', label: 'Settlement', tag: 'SOLANA_L1', detail: 'Proof anchored on Solana. 2.011% Infra Tax collected. Receipt compressed via xB77 ZK Engine → 32 bytes.', icon: '◈', duration: 10000 },
];

function PipelineDemo({ theme }) {
  const t = THEMES[theme || 'obsidian'];
  const bp = useBreakpoint();
  const [activeStep, setActiveStep] = React.useState(-1);
  const [running, setRunning] = React.useState(false);
  const [completed, setCompleted] = React.useState(new Set());
  const timeoutRef = React.useRef(null);

  const runDemo = () => {
    if (running) return;
    setRunning(true);
    setCompleted(new Set());
    setActiveStep(0);
    let step = 0;
    const advance = () => {
      setCompleted(prev => new Set([...prev, step]));
      step++;
      if (step < DEMO_STEPS.length) {
        setActiveStep(step);
        timeoutRef.current = setTimeout(advance, DEMO_STEPS[step].duration);
      } else {
        setCompleted(prev => new Set([...prev, step - 1]));
        setActiveStep(-1);
        setRunning(false);
      }
    };
    timeoutRef.current = setTimeout(advance, DEMO_STEPS[0].duration);
  };

  React.useEffect(() => () => clearTimeout(timeoutRef.current), []);

  const allDone = completed.size === DEMO_STEPS.length;

  return (
    <section style={{
      padding: bp.mobile ? '60px 20px' : '100px 40px',
      background: t.bgSecondary, borderTop: `1px solid ${t.border}`, borderBottom: `1px solid ${t.border}`,
    }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <FadeIn>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>LIVE DEMO</div>
          <h2 style={{
            fontFamily: 'var(--serif)', fontSize: bp.mobile ? 32 : 'clamp(36px, 5vw, 56px)',
            fontWeight: 400, color: t.text, margin: '0 0 12px', lineHeight: 1.05,
          }}>
            See it <em style={{ color: t.accent, fontStyle: 'italic' }}>run</em>
          </h2>
          <p style={{
            fontFamily: 'var(--sans)', fontSize: 15, color: t.textDim, lineHeight: 1.7,
            margin: '0 0 40px', maxWidth: 480,
          }}>
            Watch an autonomous agent execute a shielded payment through the full xB77 pipeline.
          </p>
        </FadeIn>

        {/* Pipeline visualization */}
        <FadeIn delay={0.15}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: bp.mobile ? '1fr' : 'repeat(4, 1fr)',
            gap: 0, marginBottom: 32,
          }}>
            {DEMO_STEPS.map((step, i) => {
              const isActive = activeStep === i;
              const isDone = completed.has(i);
              const isPending = !isActive && !isDone;
              return (
                <div key={step.id} style={{
                  position: 'relative', padding: bp.mobile ? '20px' : '28px 24px',
                  background: isActive ? t.accentDim : (isDone ? t.bgCard : 'transparent'),
                  border: `1px solid ${isActive ? t.accent : t.border}`,
                  borderRight: (!bp.mobile && i < 3) ? 'none' : `1px solid ${isActive ? t.accent : t.border}`,
                  transition: 'all 0.4s',
                }}>
                  {/* Progress bar */}
                  {isActive && (
                    <div style={{
                      position: 'absolute', bottom: 0, left: 0, height: 2,
                      background: t.accent,
                      animation: `progressBar ${step.duration}ms linear forwards`,
                    }}></div>
                  )}

                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                    <div style={{
                      width: 10, height: 10, borderRadius: '50%',
                      background: isDone ? t.accent : (isActive ? t.accent : 'transparent'),
                      border: `2px solid ${isDone ? t.accent : (isActive ? t.accent : t.textDim)}`,
                      transition: 'all 0.3s',
                      boxShadow: isActive ? `0 0 12px ${t.terminalGlow}` : 'none',
                    }}></div>
                    <span style={{
                      fontFamily: 'var(--mono)', fontSize: 9, letterSpacing: '0.12em',
                      color: isDone ? t.accent : (isActive ? t.accent : t.textDim),
                      transition: 'color 0.3s',
                    }}>{step.tag}</span>
                  </div>

                  <h4 style={{
                    fontFamily: 'var(--mono)', fontSize: 14, fontWeight: 600,
                    color: isPending ? t.textDim : t.text,
                    margin: '0 0 8px', transition: 'color 0.3s',
                  }}>{step.label}</h4>

                  <p style={{
                    fontFamily: 'var(--sans)', fontSize: 12.5, color: t.textDim,
                    lineHeight: 1.5, margin: 0,
                    opacity: isPending ? 0.4 : 0.8, transition: 'opacity 0.3s',
                  }}>{step.detail}</p>

                  {isDone && (
                    <div style={{
                      position: 'absolute', top: 12, right: 12,
                      fontFamily: 'var(--mono)', fontSize: 10, color: t.accent,
                    }}>✓</div>
                  )}
                </div>
              );
            })}
          </div>
        </FadeIn>

        {/* Run button */}
        <FadeIn delay={0.25}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <button onClick={runDemo} disabled={running} data-tour-run style={{
              fontFamily: 'var(--mono)', fontSize: 12,
              background: running ? 'transparent' : t.accent,
              color: running ? t.accent : t.bg,
              border: `1px solid ${t.accent}`,
              padding: '14px 32px', cursor: running ? 'default' : 'pointer',
              fontWeight: 600, letterSpacing: '0.06em', textTransform: 'uppercase',
              transition: 'all 0.3s', opacity: running ? 0.6 : 1,
            }}>
              {running ? 'Executing...' : (allDone ? 'Run Again' : 'Execute Pipeline')}
            </button>
            {allDone && (
              <span style={{
                fontFamily: 'var(--mono)', fontSize: 12, color: t.accent,
                animation: 'fadeInLine 0.5s ease',
              }}>Pipeline complete — Ghost Receipt generated ✓</span>
            )}
          </div>
        </FadeIn>
      </div>
      <style>{`
        @keyframes progressBar {
          from { width: 0%; }
          to { width: 100%; }
        }
      `}</style>
    </section>
  );
}


/* ── Live Metrics Dashboard ── */
function LiveMetrics({ theme }) {
  const t = THEMES[theme || 'obsidian'];
  const bp = useBreakpoint();
  const [hovered, setHovered] = React.useState(null);

  const metrics = [
    { label: 'Pipelines Active', value: 2847, suffix: '', prefix: '' },
    { label: 'Shielded Txns', value: 184329, suffix: '', prefix: '' },
    { label: 'ZK Proofs Generated', value: 91204, suffix: '', prefix: '' },
    { label: 'Infra Tax Collected', value: 47891, suffix: ' USDC', prefix: '' },
    { label: 'Avg Proof Time', value: 198, suffix: 'ms', prefix: '' },
    { label: 'Compression Ratio', value: 99.7, suffix: '%', prefix: '' },
  ];

  return (
    <section style={{
      padding: bp.mobile ? '60px 20px' : '80px 40px',
      borderBottom: `1px solid ${t.border}`, background: t.bg,
    }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <FadeIn>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>NETWORK STATUS</div>
        </FadeIn>
        <div style={{
          display: 'grid',
          gridTemplateColumns: bp.mobile ? 'repeat(2, 1fr)' : 'repeat(6, 1fr)',
          gap: 0,
        }}>
          {metrics.map((m, i) => (
            <FadeIn key={i} delay={0.05 * i}>
              <div
                style={{
                  padding: bp.mobile ? '20px 16px' : '24px 20px',
                  borderRight: (!bp.mobile && i < 5) ? `1px solid ${t.border}` : 'none',
                  borderBottom: (bp.mobile && i < 4) ? `1px solid ${t.border}` : (bp.mobile ? 'none' : `1px solid ${t.border}`),
                  borderTop: `1px solid ${t.border}`,
                  cursor: 'default', transition: 'background 0.3s',
                  background: hovered === i ? t.bgCard : 'transparent',
                }}
                onMouseEnter={() => setHovered(i)}
                onMouseLeave={() => setHovered(null)}
              >
                <div style={{ fontFamily: 'var(--mono)', fontSize: 8, color: t.textDim, letterSpacing: '0.15em', marginBottom: 8, textTransform: 'uppercase' }}>{m.label}</div>
                <div style={{
                  fontFamily: 'var(--mono)', fontSize: bp.mobile ? 18 : 22, fontWeight: 700,
                  color: hovered === i ? t.accent : t.text, transition: 'color 0.3s',
                }}>
                  <AnimatedCounter target={m.value} prefix={m.prefix} suffix={m.suffix} duration={1800} />
                </div>
              </div>
            </FadeIn>
          ))}
        </div>
      </div>
    </section>
  );
}

Object.assign(window, { PipelineDemo, LiveMetrics, DEMO_STEPS });
