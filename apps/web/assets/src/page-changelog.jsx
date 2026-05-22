/* Changelog page */

const CHANGELOG = [
  {
    version: 'v2.1',
    date: 'May 2026',
    tag: 'CURRENT',
    title: 'Multi-Chain Settlement',
    changes: [
      { type: 'new', text: 'Chain-agnostic core — agent runtime, ZK engine, AWP mesh and QVAC brain decoupled from any single chain' },
      { type: 'new', text: 'Arc Edition (Agora) — USDC-native settlement, USYC yield, Yul-optimized Settlement.sol' },
      { type: 'new', text: 'Sui Edition (Overflow) — sovereign Move package published, PTB-orchestrated bridge' },
      { type: 'new', text: 'Pluggable settlement adapters — the same sovereign agent settles on Solana, Arc or Sui' },
      { type: 'improved', text: 'Repo restructure — apps/ (executables), onchain/ (per-chain contracts), sdk/ (per-language)' },
      { type: 'roadmap', text: 'On-chain SNARK verification (Honk/Groth16) — today the verifier anchors proof bytes + commitment hash' },
    ],
  },
  {
    version: 'v2.0',
    date: 'May 2026',
    tag: '',
    title: 'Agent Infrastructure Pivot',
    changes: [
      { type: 'breaking', text: 'Removed ShadowWire and Privacy Cash pools — replaced with proprietary xB77 ZK Engine' },
      { type: 'breaking', text: 'Removed Light Protocol dependency — built proprietary ZK compression layer' },
      { type: 'new', text: 'Easy Deploy — one-click agent provisioning, self-hosted or cloud' },
      { type: 'new', text: 'Proprietary ZK Engine — protocol-level privacy + 99.7% on-chain compression' },
      { type: 'new', text: 'Interactive Pipeline Demo — live visualization of agent transaction flow' },
      { type: 'new', text: 'Live Metrics Dashboard — real-time network stats with animated counters' },
      { type: 'new', text: 'Why xB77 page — competitive comparison vs Tornado Cash, Aztec, Zcash, Secret Network' },
      { type: 'new', text: 'Full documentation suite — Quickstart, API Reference, SDK Guide, Protocol Specs' },
      { type: 'new', text: 'Architecture page — interactive layer diagram + data flow visualization' },
      { type: 'new', text: 'Whitepaper — web editorial format with inline diagrams' },
      { type: 'improved', text: 'Repositioned as Agent Infrastructure (like OpenClaw) — not a mixer or privacy coin' },
      { type: 'improved', text: 'Scroll animations + fade-in across all pages' },
      { type: 'improved', text: 'Mobile responsive layouts' },
      { type: 'improved', text: 'Micro-animations — shimmer buttons, glow hovers, animated architecture diagram' },
      { type: 'improved', text: 'Syntax highlighting in documentation code blocks' },
      { type: 'improved', text: 'OG Meta tags on all 11 pages for social sharing' },
      { type: 'improved', text: 'Unified navigation across entire ecosystem' },
      { type: 'improved', text: 'Tokenomics section — "The 2.011% Engine" pipeline visualization' },
      { type: 'improved', text: 'Git-graph style Roadmap with 3 phases' },
    ],
  },
  {
    version: 'v1.0',
    date: 'April 2026',
    tag: 'LEGACY',
    title: 'Initial Release — VitePress',
    link: 'https://8ctag0n.github.io/xB77/',
    changes: [
      { type: 'new', text: 'VitePress-based documentation site' },
      { type: 'new', text: 'Landing page with terminal animation' },
      { type: 'new', text: 'ShadowWire shielded payment concept' },
      { type: 'new', text: 'Privacy Cash pool obfuscation design' },
      { type: 'new', text: 'Light Protocol ZK-compressed receipts integration' },
      { type: 'new', text: 'Whitepaper (EN/ES)' },
      { type: 'new', text: 'Architecture diagrams' },
      { type: 'new', text: 'Vimeo demo video embed' },
      { type: 'new', text: 'i18n support (English + Español)' },
      { type: 'new', text: 'GitHub Pages deployment' },
    ],
  },
];

const TYPE_STYLES = {
  breaking: { label: 'BREAKING', color: '#ff4466' },
  new: { label: 'NEW', color: 'var(--accent)' },
  improved: { label: 'IMPROVED', color: '#4de8d0' },
  fixed: { label: 'FIXED', color: '#ffaa44' },
  roadmap: { label: 'ROADMAP', color: '#9b8cff' },
};

function ChangelogPage() {
  const t = THEMES.obsidian;
  const bp = typeof useBreakpoint === 'function' ? useBreakpoint() : { mobile: false };

  return (
    <div style={{ background: t.bg, minHeight: '100vh', color: t.text }}>
      <InnerNav active="Changelog" />

      {/* Hero */}
      <section style={{ padding: bp.mobile ? '60px 20px' : '100px 40px 80px', maxWidth: 900, margin: '0 auto' }}>
        <FadeIn>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>CHANGELOG</div>
          <h1 style={{
            fontFamily: 'var(--serif)', fontSize: bp.mobile ? 36 : 'clamp(40px, 6vw, 64px)',
            fontWeight: 400, color: t.text, lineHeight: 1.0, margin: '0 0 16px',
          }}>
            What's <em style={{ color: t.accent, fontStyle: 'italic' }}>changed</em>
          </h1>
          <p style={{ fontFamily: 'var(--sans)', fontSize: 16, color: t.textDim, lineHeight: 1.7, maxWidth: 500 }}>
            Evolution of xB77 — from VitePress docs to full agent infrastructure platform.
          </p>
        </FadeIn>
      </section>

      {/* Timeline */}
      <section style={{ padding: bp.mobile ? '0 20px 80px' : '0 40px 120px', maxWidth: 900, margin: '0 auto' }}>
        <div style={{ position: 'relative' }}>
          {/* Vertical line */}
          <div style={{
            position: 'absolute', left: 23, top: 0, bottom: 0, width: 2,
            background: `linear-gradient(to bottom, ${t.accent}, ${t.border})`,
          }}></div>

          {CHANGELOG.map((release, ri) => {
            const isCurrent = release.tag === 'CURRENT';
            return (
              <FadeIn key={ri} delay={ri * 0.1}>
                <div style={{ position: 'relative', marginBottom: 64 }}>
                  {/* Version node */}
                  <div style={{
                    position: 'absolute', left: 12, top: 0, zIndex: 2,
                    width: 24, height: 24, borderRadius: '50%',
                    background: isCurrent ? t.accent : t.bg,
                    border: `2px solid ${isCurrent ? t.accent : t.textDim}`,
                    boxShadow: isCurrent ? `0 0 20px ${t.terminalGlow}` : 'none',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    {isCurrent && <div style={{ width: 8, height: 8, borderRadius: '50%', background: t.bg }}></div>}
                  </div>

                  {/* Content */}
                  <div style={{ marginLeft: 56 }}>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 4, flexWrap: 'wrap' }}>
                      <span style={{
                        fontFamily: 'var(--mono)', fontSize: 22, fontWeight: 700,
                        color: isCurrent ? t.accent : t.text,
                      }}>{release.version}</span>
                      {isCurrent && (
                        <span style={{
                          fontFamily: 'var(--mono)', fontSize: 9, color: t.bg,
                          background: t.accent, padding: '2px 8px', fontWeight: 600,
                        }}>CURRENT</span>
                      )}
                      {release.link && (
                        <a href={release.link} target="_blank" rel="noopener" style={{
                          fontFamily: 'var(--mono)', fontSize: 10, color: t.accent,
                          textDecoration: 'none', opacity: 0.7,
                        }}>VIEW LEGACY SITE →</a>
                      )}
                    </div>
                    <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.textDim, marginBottom: 4 }}>{release.date}</div>
                    <h3 style={{
                      fontFamily: 'var(--serif)', fontSize: 24, fontWeight: 400, fontStyle: 'italic',
                      color: isCurrent ? t.text : t.textDim, margin: '0 0 20px',
                    }}>{release.title}</h3>

                    {/* Changes list */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      {release.changes.map((change, ci) => {
                        const ts = TYPE_STYLES[change.type];
                        return (
                          <div key={ci} style={{
                            display: 'flex', gap: 12, alignItems: 'baseline',
                            padding: '8px 0',
                          }}>
                            <span style={{
                              fontFamily: 'var(--mono)', fontSize: 9, fontWeight: 600,
                              color: ts.color, letterSpacing: '0.08em',
                              minWidth: 72,
                              flexShrink: 0,
                            }}>{ts.label}</span>
                            <span style={{
                              fontFamily: 'var(--sans)', fontSize: 14, color: t.textDim, lineHeight: 1.5,
                            }}>{change.text}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </div>
              </FadeIn>
            );
          })}
        </div>
      </section>

      <DocsDeepDive
        kicker="// FULL CHANGELOG"
        label="Every release, every commit, in markdown."
        path="/changelog"
      />

      <PageFooter />
    </div>
  );
}

Object.assign(window, { ChangelogPage });
