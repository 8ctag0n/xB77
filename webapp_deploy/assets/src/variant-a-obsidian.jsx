/* ─── VARIANT A: OBSIDIAN — Enhanced ───
   Aztec-inspired. Bold, maximal, editorial.
   Now with: scroll animations, responsive, interactive demo, live metrics, functional links.
*/

function ObsidianVariant({ theme }) {
  const t = THEMES[theme];
  const bp = useBreakpoint();
  const marqueeItems = ['xB77', 'SHIELDED', 'ZK-PROOF', 'AUTONOMOUS', 'SOLANA', 'PRIVACY', 'PIPELINE', 'SOVEREIGN', 'MACHINE ECONOMY'];
  const tripled = [...marqueeItems, ...marqueeItems, ...marqueeItems];
  const { lines, cursor, termRef } = useTerminal();
  const [hoveredStat, setHoveredStat] = React.useState(null);

  const pad = bp.mobile ? '20px' : '60px';

  return (
    <div>
      {/* ── Ticker ── */}
      <div style={{
        overflow: 'hidden', borderBottom: `1px solid ${t.border}`,
        background: t.accentDim, height: 32, display: 'flex', alignItems: 'center',
      }}>
        <div style={{
          display: 'flex', gap: 40, whiteSpace: 'nowrap',
          animation: 'marquee 20s linear infinite',
          fontFamily: 'var(--mono)', fontSize: 11, fontWeight: 600,
          letterSpacing: '0.15em', color: t.accent, textTransform: 'uppercase',
        }}>
          {tripled.map((item, i) => (
            <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 40 }}>
              {item} <span style={{ opacity: 0.3 }}>◆</span>
            </span>
          ))}
        </div>
      </div>

      {/* ── Nav ── */}
      <nav style={{
        position: 'sticky', top: 0, zIndex: 100,
        background: t.navBg, backdropFilter: 'blur(20px)',
        borderBottom: `1px solid ${t.border}`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 ' + (bp.mobile ? '16px' : '40px'), height: 56,
      }}>
        <div style={{ fontFamily: 'var(--mono)', fontWeight: 700, fontSize: 20, color: t.accent, letterSpacing: '0.08em' }}>xB77</div>
        <div style={{ display: 'flex', gap: bp.mobile ? 12 : 28, alignItems: 'center' }}>
          {!bp.mobile && [
            { label: 'Why xB77', href: 'Why xB77.html' },
            { label: 'Docs', href: 'Docs.html' },
            { label: 'Whitepaper', href: 'Whitepaper.html' },
            { label: 'Architecture', href: 'Architecture.html' },
            { label: 'Explorer', href: 'Explorer.html' },
          ].map(l => (
            <a key={l.label} href={l.href} style={{
              fontFamily: 'var(--mono)', fontSize: 11, color: t.textDim,
              letterSpacing: '0.12em', textTransform: 'uppercase',
              cursor: 'pointer', transition: 'color 0.2s', textDecoration: 'none',
            }}
              onMouseEnter={e => e.target.style.color = t.accent}
              onMouseLeave={e => e.target.style.color = t.textDim}>{l.label}</a>
          ))}
          <a href="dApp.html" style={{
            fontFamily: 'var(--mono)', fontSize: 11, color: t.bg,
            background: t.accent, border: 'none', padding: '8px 16px',
            letterSpacing: '0.08em', cursor: 'pointer', fontWeight: 600, textTransform: 'uppercase',
            textDecoration: 'none',
          }}>Launch dApp</a>
        </div>
      </nav>

      {/* ── Hero: split layout (stacks on mobile) ── */}
      <section style={{
        position: 'relative', minHeight: bp.mobile ? 'auto' : '92vh',
        display: 'grid', gridTemplateColumns: bp.mobile ? '1fr' : '1fr 1fr', alignItems: 'center',
        padding: bp.mobile ? '60px 20px' : '80px 60px', gap: bp.mobile ? 40 : 60, overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', inset: 0, pointerEvents: 'none', opacity: 0.35,
          fontFamily: 'var(--mono)', fontSize: 11, color: t.patternColor,
          lineHeight: 1.8, letterSpacing: '0.3em', whiteSpace: 'pre-wrap',
          wordBreak: 'break-all', padding: 40, userSelect: 'none',
        }}>
          {Array(25).fill('xB77 ZK ENGINE DEPLOY AGENT AUTONOMOUS CFO NEURAL KEY SOVEREIGN PIPELINE GOVERNANCE ').join('')}
        </div>

        <FadeIn style={{ position: 'relative', zIndex: 1 }}>
          <div style={{
            fontFamily: 'var(--mono)', fontSize: 11, color: t.accent,
            letterSpacing: '0.3em', marginBottom: 24, textTransform: 'uppercase', opacity: 0.7,
          }}>Autonomous Financial Infrastructure</div>
          <h1 style={{
            fontFamily: 'var(--serif)', fontSize: bp.mobile ? 'clamp(40px, 12vw, 64px)' : 'clamp(56px, 7vw, 108px)',
            fontWeight: 400, color: t.text, lineHeight: 0.95, margin: 0,
            letterSpacing: '-0.03em',
          }}>
            The<br />Sovereign<br />
            <em style={{ color: t.accent, fontStyle: 'italic' }}>Operating<br />System</em>
          </h1>
          <p style={{
            fontFamily: 'var(--sans)', fontSize: 16, color: t.textDim,
            lineHeight: 1.7, maxWidth: 400, margin: '32px 0 0',
          }}>
            Privacy-first capital management for the machine economy.
            Shielded payments. ZK-compressed receipts. Autonomous agents.
          </p>
          <div style={{ display: 'flex', gap: 12, marginTop: 40, flexWrap: 'wrap' }}>
            <a href="dApp.html" className="btn-primary" style={{ '--ac': t.accent, '--bg': t.bg, textDecoration: 'none' }}>Launch Pipeline</a>
            <a href="Docs.html" className="btn-ghost" style={{ '--ac': t.accent, '--border': t.border, '--text': t.text, textDecoration: 'none' }}>Explore Docs</a>
          </div>
        </FadeIn>

        <FadeIn delay={0.2} style={{ position: 'relative', zIndex: 1 }}>
          <div style={{
            background: t.terminalBg, border: `1px solid ${t.border}`,
            fontFamily: 'var(--mono)', fontSize: bp.mobile ? 11 : 13, lineHeight: 1.7,
            boxShadow: `0 0 120px ${t.terminalGlow}, inset 0 1px 0 ${t.border}`,
          }}>
            <div style={{
              display: 'flex', alignItems: 'center', gap: 8,
              padding: '12px 18px', borderBottom: `1px solid ${t.border}`,
              fontSize: 10, color: t.textDim, letterSpacing: '0.1em',
            }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: t.accent, opacity: 0.7 }}></span>
              XB77_CFO_MVP
              <span style={{ marginLeft: 'auto', opacity: 0.5 }}>PIPELINE_ACTIVE</span>
            </div>
            <div ref={termRef} style={{ padding: '18px 22px', height: bp.mobile ? 220 : 340, overflowY: 'auto' }}>
              {lines.map((line, i) => <TerminalLine key={i} line={line} theme={theme} />)}
              <span style={{ color: t.accent, opacity: cursor ? 1 : 0 }}>▊</span>
            </div>
          </div>
        </FadeIn>
      </section>

      {/* ── Live Metrics ── */}
      <div data-tour="metrics">
        <LiveMetrics theme={theme} />
      </div>

      {/* ── Protocol Stats Band ── */}
      <section style={{
        borderTop: `1px solid ${t.border}`, borderBottom: `1px solid ${t.border}`,
        display: 'grid', gridTemplateColumns: bp.mobile ? 'repeat(2, 1fr)' : 'repeat(4, 1fr)', gap: 0,
        background: t.bgSecondary,
      }}>
        {[
          { label: 'PROTOCOL', value: 'SOLANA', detail: 'Settlement Layer' },
          { label: 'PRIVACY', value: 'ZK-SNARKs', detail: 'xB77 ZK Engine' },
          { label: 'AGENTS', value: 'AUTONOMOUS', detail: 'Neural Key Auth' },
          { label: 'STATUS', value: 'LIVE', detail: 'Hackathon 2026' },
        ].map((s, i) => (
          <FadeIn key={i} delay={0.05 * i}>
            <div style={{
              padding: bp.mobile ? '24px 20px' : '40px 32px',
              borderRight: (!bp.mobile && i < 3) ? `1px solid ${t.border}` : (bp.mobile && i % 2 === 0 ? `1px solid ${t.border}` : 'none'),
              borderBottom: (bp.mobile && i < 2) ? `1px solid ${t.border}` : 'none',
              cursor: 'default', transition: 'background 0.3s',
              background: hoveredStat === i ? t.bgCard : 'transparent',
            }}
              onMouseEnter={() => setHoveredStat(i)}
              onMouseLeave={() => setHoveredStat(null)}
            >
              <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: t.textDim, letterSpacing: '0.2em', marginBottom: 10 }}>{s.label}</div>
              <div style={{
                fontFamily: 'var(--serif)', fontSize: bp.mobile ? 22 : 28, color: hoveredStat === i ? t.accent : t.text,
                fontWeight: 400, transition: 'color 0.3s', marginBottom: 6,
              }}>{s.value}</div>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.textDim, letterSpacing: '0.08em' }}>{s.detail}</div>
            </div>
          </FadeIn>
        ))}
      </section>

      {/* ── Interactive Demo ── */}
      <div data-tour="demo">
        <PipelineDemo theme={theme} />
      </div>

      {/* ── Why Privacy — Manifesto ── */}
      <section style={{
        position: 'relative', padding: bp.mobile ? '80px 20px' : '120px 60px', overflow: 'hidden',
        background: t.bg,
      }}>
        <div style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          fontFamily: 'var(--mono)', fontSize: 9, color: t.patternColor,
          lineHeight: 2.2, letterSpacing: '0.5em',
          whiteSpace: 'pre-wrap', wordBreak: 'break-all',
          padding: 20, userSelect: 'none', opacity: 0.6,
        }}>
          {Array(40).fill('PRIVACY SOVEREIGNTY AUTONOMY DEPLOY ZERO KNOWLEDGE PROOF AGENT INFRASTRUCTURE SELF-HOSTED ').join('')}
        </div>

        <div style={{ position: 'relative', zIndex: 1, maxWidth: 1100, margin: '0 auto' }}>
          <FadeIn>
            <h2 style={{
              fontFamily: 'var(--serif)', fontSize: bp.mobile ? 36 : 'clamp(40px, 6vw, 80px)',
              fontWeight: 400, fontStyle: 'italic', color: t.text,
              lineHeight: 1.0, margin: '0 0 80px', textAlign: bp.mobile ? 'left' : 'right',
              maxWidth: 700, marginLeft: bp.mobile ? 0 : 'auto',
            }}>
              Privacy—<br />
              it's <em style={{ color: t.accent }}>non-negotiable</em>
            </h2>
          </FadeIn>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {[
              { title: 'Agents need it.', body: 'Autonomous financial agents can\'t operate in a transparent fishbowl. Without privacy, every strategy is front-run, every position is exposed, every advantage is erased.' },
              { title: 'Markets demand it.', body: 'Institutional capital won\'t flow through rails where competitors can trace every transaction. Privacy isn\'t a feature — it\'s the minimum bar for serious capital.' },
              { title: 'It must be real.', body: 'Not optional add-ons. Not trusted intermediaries. Not centralized sequencers with backdoors. End-to-end cryptographic privacy, verified by math, enforced by protocol.' },
            ].map((card, i) => (
              <FadeIn key={i} delay={0.1 * i}>
                <div style={{
                  background: t.bgSecondary, border: `1px solid ${t.border}`,
                  padding: bp.mobile ? '28px 20px' : '40px 36px',
                  maxWidth: bp.mobile ? '100%' : 480,
                  marginLeft: bp.mobile ? 0 : i * 100, marginTop: i > 0 ? -1 : 0,
                  transition: 'border-color 0.3s, transform 0.3s', cursor: 'default',
                }}
                  onMouseEnter={e => { e.currentTarget.style.borderColor = t.accent; e.currentTarget.style.transform = 'translateX(6px)'; }}
                  onMouseLeave={e => { e.currentTarget.style.borderColor = t.border; e.currentTarget.style.transform = ''; }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
                    <span style={{ width: 6, height: 6, background: t.accent, display: 'inline-block' }}></span>
                    <h3 style={{ fontFamily: 'var(--serif)', fontSize: bp.mobile ? 22 : 26, fontWeight: 400, fontStyle: 'italic', color: t.accent, margin: 0 }}>{card.title}</h3>
                  </div>
                  <p style={{ fontFamily: 'var(--sans)', fontSize: 14.5, color: t.textDim, lineHeight: 1.65, margin: 0 }}>
                    <strong style={{ color: t.text }}>{card.body.split('.')[0]}.</strong>{' '}
                    {card.body.split('.').slice(1).join('.')}
                  </p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* ── Features ── */}
      <section style={{
        background: t.bgSecondary, borderTop: `1px solid ${t.border}`,
        borderBottom: `1px solid ${t.border}`, padding: bp.mobile ? '60px 20px' : '100px 60px',
      }}>
        <div style={{ maxWidth: 1100, margin: '0 auto' }}>
          <FadeIn>
            <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>INFRASTRUCTURE</div>
            <h2 style={{
              fontFamily: 'var(--serif)', fontSize: bp.mobile ? 32 : 'clamp(36px, 5vw, 64px)',
              fontWeight: 400, color: t.text, margin: '0 0 60px', lineHeight: 1.05,
            }}>
              Built for the<br /><em style={{ color: t.accent, fontStyle: 'italic' }}>Machine Economy</em>
            </h2>
          </FadeIn>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
            {FEATURES.map((f, i) => (
              <FadeIn key={i} delay={0.1 * i}>
                <div style={{
                  background: t.bg, border: `1px solid ${t.border}`,
                  padding: bp.mobile ? '28px 20px' : '44px 40px',
                  marginLeft: bp.mobile ? 0 : i * 80,
                  maxWidth: bp.mobile ? '100%' : 520, cursor: 'default',
                  transition: 'transform 0.3s, border-color 0.3s',
                  marginTop: i > 0 ? -1 : 0,
                }}
                  onMouseEnter={e => { e.currentTarget.style.transform = 'translateX(8px)'; e.currentTarget.style.borderColor = t.accent; }}
                  onMouseLeave={e => { e.currentTarget.style.transform = ''; e.currentTarget.style.borderColor = t.border; }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
                    <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.15em', opacity: 0.6 }}>{f.tag}</span>
                    <span style={{ fontSize: 22, color: t.accent, opacity: 0.25 }}>{f.icon}</span>
                  </div>
                  <h3 style={{ fontFamily: 'var(--serif)', fontSize: bp.mobile ? 24 : 30, fontWeight: 400, color: t.text, margin: '0 0 12px' }}>{f.title}</h3>
                  <p style={{ fontFamily: 'var(--sans)', fontSize: 14, color: t.textDim, lineHeight: 1.6, margin: 0 }}>{f.desc}</p>
                </div>
              </FadeIn>
            ))}
          </div>
        </div>
      </section>

      {/* ── Tokenomics ── */}
      <div data-tour="tokenomics">
        <Tokenomics theme={theme} />
      </div>

      {/* ── Architecture ── */}
      <ArchDiagram theme={theme} />

      {/* ── Roadmap ── */}
      <Roadmap theme={theme} />

      {/* ── CTA Band ── */}
      <section style={{
        position: 'relative', padding: bp.mobile ? '60px 20px' : '100px 60px',
        background: t.accentDim,
        borderTop: `1px solid ${t.border}`, borderBottom: `1px solid ${t.border}`,
        textAlign: 'center', overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: 'var(--serif)', fontSize: 'clamp(120px, 20vw, 280px)',
          fontWeight: 400, fontStyle: 'italic', color: t.accent, opacity: 0.04,
          letterSpacing: '-0.04em', userSelect: 'none',
        }}>xB77</div>

        <FadeIn style={{ position: 'relative', zIndex: 1 }}>
          <h2 style={{
            fontFamily: 'var(--serif)', fontSize: bp.mobile ? 28 : 'clamp(32px, 4vw, 56px)',
            fontWeight: 400, color: t.text, margin: '0 0 16px', lineHeight: 1.1,
          }}>
            Ready to go <em style={{ color: t.accent, fontStyle: 'italic' }}>sovereign?</em>
          </h2>
          <p style={{ fontFamily: 'var(--sans)', fontSize: 16, color: t.textDim, margin: '0 0 40px', lineHeight: 1.6 }}>
            Deploy your first autonomous pipeline in minutes.
          </p>
          <div style={{ display: 'flex', gap: 16, justifyContent: 'center', flexWrap: 'wrap' }}>
            <a href="dApp.html" className="btn-primary" style={{ '--ac': t.accent, '--bg': t.bg, textDecoration: 'none' }}>Launch Pipeline</a>
            <a href="Whitepaper.html" className="btn-ghost" style={{ '--ac': t.accent, '--border': t.border, '--text': t.text, textDecoration: 'none' }}>Read Whitepaper</a>
            <a href="dApp.html" className="btn-ghost" style={{ '--ac': t.accent, '--border': t.border, '--text': t.text, textDecoration: 'none' }}>Connect Wallet</a>
          </div>
        </FadeIn>
      </section>

      {/* ── Footer ── */}
      <SiteFooter theme={theme} />
    </div>
  );
}

Object.assign(window, { ObsidianVariant });
