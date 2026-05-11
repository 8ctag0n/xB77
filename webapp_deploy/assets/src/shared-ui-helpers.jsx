/* Shared UI enhancements: scroll animations + responsive helpers */

/* ── Scroll Fade-In Hook ── */
function useFadeIn(threshold = 0.15) {
  const ref = React.useRef(null);
  const [visible, setVisible] = React.useState(false);
  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) { setVisible(true); obs.unobserve(el); }
    }, { threshold });
    obs.observe(el);
    return () => obs.disconnect();
  }, []);
  return [ref, visible];
}

/* ── FadeIn wrapper component ── */
function FadeIn({ children, delay = 0, direction = 'up', style = {}, ...props }) {
  const [ref, visible] = useFadeIn(0.1);
  const dirs = { up: [0, 24], down: [0, -24], left: [24, 0], right: [-24, 0], none: [0, 0] };
  const [dx, dy] = dirs[direction] || dirs.up;
  return (
    <div ref={ref} style={{
      ...style,
      opacity: visible ? 1 : 0,
      transform: visible ? 'translate(0, 0)' : `translate(${dx}px, ${dy}px)`,
      transition: `opacity 0.7s ease ${delay}s, transform 0.7s ease ${delay}s`,
    }} {...props}>{children}</div>
  );
}

/* ── Stagger: wraps children with incremental delays ── */
function Stagger({ children, baseDelay = 0, step = 0.1, direction = 'up', style = {} }) {
  return (
    <div style={style}>
      {React.Children.map(children, (child, i) => (
        <FadeIn delay={baseDelay + i * step} direction={direction}>{child}</FadeIn>
      ))}
    </div>
  );
}

/* ── Responsive hook ── */
function useBreakpoint() {
  const [w, setW] = React.useState(window.innerWidth);
  React.useEffect(() => {
    const h = () => setW(window.innerWidth);
    window.addEventListener('resize', h);
    return () => window.removeEventListener('resize', h);
  }, []);
  return { mobile: w < 768, tablet: w >= 768 && w < 1024, desktop: w >= 1024, w };
}

/* ── Live Metrics counter animation ── */
function AnimatedCounter({ target, duration = 2000, prefix = '', suffix = '' }) {
  const [ref, visible] = useFadeIn(0.1);
  const [val, setVal] = React.useState(0);
  React.useEffect(() => {
    if (!visible) return;
    const start = Date.now();
    const tick = () => {
      const elapsed = Date.now() - start;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setVal(Math.round(target * eased));
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }, [visible, target, duration]);
  return <span ref={ref}>{prefix}{val.toLocaleString()}{suffix}</span>;
}

/* ── Syntax Highlighting (simple keyword-based) ── */
function SyntaxHighlight({ code, theme }) {
  const t = THEMES[theme || 'obsidian'];
  const keywords = /\b(const|let|var|function|async|await|import|from|export|return|if|else|new|typeof|use|pub|fn|let|mut|println|struct)\b/g;
  const strings = /(["'`])(?:(?!\1)[^\\]|\\.)*?\1/g;
  const comments = /(\/\/.*$|\/\*[\s\S]*?\*\/|#.*$)/gm;
  const numbers = /\b(\d+\.?\d*)\b/g;
  const types = /\b(Client|Network|NeuralKey|IntentBuilder|Currency|Privacy|Urgency|Pipeline|XB77Client)\b/g;
  const specials = /(\$|→|✓|✗)/g;

  const codeStr = typeof code === 'string' ? code : String(code);
  const lines = codeStr.split('\n');
  return (
    <pre style={{
      background: t.terminalBg, border: `1px solid ${t.border}`,
      padding: '20px 24px', margin: '16px 0 24px', overflowX: 'auto',
      fontFamily: 'var(--mono)', fontSize: 12.5, lineHeight: 1.8, color: t.textDim,
    }}>
      {lines.map((line, i) => {
        let html = line
          .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
          .replace(comments, `<span style="color:${t.textDim};opacity:0.5">$&</span>`)
          .replace(strings, `<span style="color:#a8d8a0">$&</span>`)
          .replace(keywords, `<span style="color:${t.accent}">$&</span>`)
          .replace(types, `<span style="color:#8888ff">$&</span>`)
          .replace(numbers, `<span style="color:#ffaa44">$&</span>`)
          .replace(specials, `<span style="color:${t.accent}">$&</span>`);
        return <div key={i} dangerouslySetInnerHTML={{ __html: html }} />;
      })}
    </pre>
  );
}

/* ── DocsDeepDive: cross-link from webapp page → vitepress deep dive ──
 *
 * Drop-in CTA card for the bottom of every webapp doc-ish page. Sends the
 * reader to the full markdown spec on the GitHub Pages docs site.
 * Brand-matched: kicker mono accent, label serif italic, URL mono dim.
 *
 * Usage:
 *   <DocsDeepDive kicker="// CONTINUE READING"
 *                 label="Full architecture spec"
 *                 path="/architecture" />
 *
 * `path` is appended to XB77_DOCS_BASE. Use `href` for absolute overrides.
 */
const XB77_DOCS_BASE = 'https://8ctag0n.github.io/xB77';

function DocsDeepDive({ kicker, label, path, href, theme }) {
  const t = theme || (typeof THEMES !== 'undefined' ? THEMES.obsidian : {
    bgCard: 'rgba(255,255,255,0.03)',
    accent: '#c8ff2e', text: '#e8e8ec', textDim: '#6e6e7a',
    border: 'rgba(255,255,255,0.06)',
  });
  const url = href || `${XB77_DOCS_BASE}${path || '/'}`;
  const display = url.replace(/^https?:\/\//, '');
  const [hover, setHover] = React.useState(false);
  return (
    <section style={{ padding: '60px 40px', borderTop: `1px solid ${t.border}` }}>
      <div style={{ maxWidth: 1100, margin: '0 auto' }}>
        <a
          href={url}
          target="_blank"
          rel="noopener noreferrer"
          onMouseEnter={() => setHover(true)}
          onMouseLeave={() => setHover(false)}
          style={{
            display: 'block',
            padding: '28px 32px',
            background: hover ? t.bgCard : 'transparent',
            border: `1px solid ${hover ? t.accent : t.border}`,
            textDecoration: 'none',
            transition: 'all 0.25s ease',
          }}
        >
          <div style={{
            fontFamily: 'var(--mono)', fontSize: 10, fontWeight: 600,
            color: t.accent, letterSpacing: '0.2em', textTransform: 'uppercase',
            marginBottom: 12,
          }}>{kicker || '// CONTINUE READING'}</div>
          <div style={{
            display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
            gap: 16, flexWrap: 'wrap',
          }}>
            <h3 style={{
              fontFamily: 'var(--serif)', fontSize: 'clamp(24px, 3vw, 32px)',
              fontWeight: 400, fontStyle: 'italic', color: t.text,
              margin: 0, lineHeight: 1.2,
            }}>{label || 'Read the full spec'}</h3>
            <div style={{
              fontFamily: 'var(--mono)', fontSize: 16, fontWeight: 600,
              color: t.accent,
              transform: hover ? 'translateX(6px)' : 'translateX(0)',
              transition: 'transform 0.25s ease',
            }}>→</div>
          </div>
          <div style={{
            marginTop: 14,
            fontFamily: 'var(--mono)', fontSize: 11, color: t.textDim,
            letterSpacing: '0.04em',
          }}>{display}</div>
        </a>
      </div>
    </section>
  );
}

Object.assign(window, { useFadeIn, FadeIn, Stagger, useBreakpoint, AnimatedCounter, SyntaxHighlight, DocsDeepDive, XB77_DOCS_BASE });
