/* xB77 Explorer v2 — Enhanced UI Components */

const T = {
  bg: 'var(--bg)', bg2: 'var(--bg-2)', bg3: 'var(--bg-3)', bg4: 'var(--bg-4)',
  card: 'var(--bg-2)', cardHover: 'var(--bg-4)',
  accent: 'var(--accent)', accentDim: 'var(--accent-faint)', accentMid: 'var(--accent-dim)',
  text: 'var(--text)', textMid: 'var(--text-dim)', textDim: 'var(--text-soft)',
  border: 'var(--border)', borderHover: 'var(--border-strong)',
  red: '#ff4455', green: '#44ee88', yellow: '#f0c040', blue: '#4da8ff', cyan: '#4de8d0',
};

/* ── Status with dot ── */
function Status({ status, size = 'sm' }) {
  const map = {
    COMPLETED: T.green, ACTIVE: T.green, ONLINE: T.green,
    PENDING: T.yellow, SYNCING: T.yellow, IDLE: T.yellow, IN_PROGRESS: T.cyan,
    FAILED: T.red, OFFLINE: T.red,
    STANDARD: T.textMid, ELEVATED: T.yellow, LOCKDOWN: T.red,
  };
  const c = map[status] || T.textDim;
  const fs = size === 'lg' ? 12 : 10;
  const isLive = status === 'ACTIVE' || status === 'ONLINE' || status === 'IN_PROGRESS' || status === 'SYNCING';
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
      <span
        className={isLive ? 'xb-pulse-dot' : ''}
        style={{ width: 6, height: 6, borderRadius: '50%', background: c, color: c, boxShadow: `0 0 8px ${c}66`, flexShrink: 0 }}
      ></span>
      <span style={{ fontFamily: 'var(--mono)', fontSize: fs, color: c, letterSpacing: '0.06em' }}>{status}</span>
    </span>
  );
}

/* ── Animated counter that eases from 0 → target on mount ── */
function useCountUp(target, ms = 900) {
  const [v, setV] = React.useState(0);
  const startRef = React.useRef(null);
  React.useEffect(() => {
    if (typeof target !== 'number' || !isFinite(target)) return;
    const start = performance.now();
    startRef.current = start;
    let raf;
    const tick = (t) => {
      const elapsed = t - start;
      const p = Math.min(1, elapsed / ms);
      // easeOutCubic
      const eased = 1 - Math.pow(1 - p, 3);
      setV(target * eased);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, ms]);
  return v;
}

/* ── Mini sparkline with gradient fill + animated draw on mount ── */
function Sparkline({ data, color = T.accent, width = 80, height = 24 }) {
  if (!data || data.length < 2) return null;
  const min = Math.min(...data), max = Math.max(...data);
  const range = max - min || 1;
  const coords = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / range) * (height - 4) - 2;
    return [x, y];
  });
  const linePoints = coords.map(([x, y]) => `${x},${y}`).join(' ');
  const fillPoints = `0,${height} ${linePoints} ${width},${height}`;
  const gradId = React.useMemo(() => 'sg' + Math.random().toString(36).slice(2, 8), []);
  const [last] = coords.slice(-1);
  return (
    <svg width={width} height={height} style={{ display: 'block', overflow: 'visible' }}>
      <defs>
        <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.28" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <polygon points={fillPoints} fill={`url(#${gradId})`} />
      <polyline points={linePoints} fill="none" stroke={color} strokeWidth="1.4" opacity="0.85"
        strokeLinecap="round" strokeLinejoin="round"
        style={{ strokeDasharray: 100, animation: 'dashFlow 1.2s ease-out forwards' }} />
      <circle cx={last[0]} cy={last[1]} r="2.2" fill={color}>
        <animate attributeName="r" values="2.2;3.4;2.2" dur="2.2s" repeatCount="indefinite" />
      </circle>
    </svg>
  );
}

/* ── Big stat card with number count-up on mount ── */
function StatCard({ label, value, change, sparkData, color }) {
  const [h, setH] = React.useState(false);

  // Parse a numeric prefix from `value` so we can count up the visible portion
  // and re-render the rest (suffix / prefix decoration) as-is.
  const parsed = React.useMemo(() => {
    if (typeof value !== 'string') return null;
    const m = value.match(/^([^\d-]*)(-?\d[\d,]*(?:\.\d+)?)([\s\S]*)$/);
    if (!m) return null;
    const num = parseFloat(m[2].replace(/,/g, ''));
    if (!isFinite(num)) return null;
    return { prefix: m[1], num, suffix: m[3], hasComma: m[2].includes(','), decimals: (m[2].split('.')[1] || '').length };
  }, [value]);

  const animated = useCountUp(parsed ? parsed.num : 0, 1100);

  const display = parsed
    ? `${parsed.prefix}${
        parsed.hasComma
          ? Math.round(animated).toLocaleString()
          : animated.toFixed(parsed.decimals)
      }${parsed.suffix}`
    : value;

  return (
    <div style={{
      padding: '20px 22px', background: h ? T.cardHover : T.card,
      border: `1px solid ${h ? T.borderHover : T.border}`,
      transition: 'all 0.25s', cursor: 'default',
      position: 'relative', overflow: 'hidden',
    }} onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}>
      {h && (
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 1,
          background: `linear-gradient(90deg, transparent, ${color || T.accent}, transparent)`,
        }} />
      )}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.18em', marginBottom: 8 }}>{label}</div>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 22, color: h ? T.accent : T.text, fontWeight: 700, transition: 'color 0.2s', letterSpacing: '-0.02em', fontVariantNumeric: 'tabular-nums' }}>{display}</div>
          {change && <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: change.startsWith('+') ? T.green : T.red, marginTop: 4 }}>{change}</div>}
        </div>
        {sparkData && <Sparkline data={sparkData} color={color || T.accent} />}
      </div>
    </div>
  );
}

/* ── Search ── */
function SearchBar({ value, onChange }) {
  const [f, setF] = React.useState(false);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      border: `1px solid ${f ? T.accent + '44' : T.border}`,
      padding: '12px 18px', background: T.bg2,
      transition: 'border-color 0.25s, box-shadow 0.25s',
      boxShadow: f ? `0 0 20px ${T.accentDim}` : 'none',
    }}>
      <span style={{ color: T.textDim, fontSize: 16, opacity: 0.6 }}>⌕</span>
      <input type="text" value={value} onChange={e => onChange(e.target.value)}
        onFocus={() => setF(true)} onBlur={() => setF(false)}
        placeholder="Search pipeline, agent, znode, tx hash..."
        style={{
          background: 'none', border: 'none', outline: 'none', flex: 1,
          fontFamily: 'var(--mono)', fontSize: 13, color: T.text,
        }} />
      {value && <span onClick={() => onChange('')} style={{ color: T.textDim, cursor: 'pointer', fontSize: 12, fontFamily: 'var(--mono)' }}>ESC</span>}
    </div>
  );
}

/* ── Tabs ── */
function Tabs({ tabs, active, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 2, padding: '4px', background: T.bg2, border: `1px solid ${T.border}` }}>
      {tabs.map(tab => {
        const isActive = active === tab.id;
        return (
          <button key={tab.id} onClick={() => onChange(tab.id)} style={{
            fontFamily: 'var(--mono)', fontSize: 11, letterSpacing: '0.08em',
            textTransform: 'uppercase', padding: '10px 20px', flex: 1,
            background: isActive ? T.accentDim : 'transparent',
            border: isActive ? `1px solid ${T.accent}33` : '1px solid transparent',
            color: isActive ? T.accent : T.textDim,
            cursor: 'pointer', transition: 'all 0.2s',
          }}>{tab.label}<span style={{ marginLeft: 6, opacity: 0.4, fontSize: 10 }}>{tab.count}</span></button>
        );
      })}
    </div>
  );
}

/* ── Filter chip ── */
function FilterChip({ label, active, onClick }) {
  return (
    <button onClick={onClick} style={{
      fontFamily: 'var(--mono)', fontSize: 9.5, letterSpacing: '0.06em',
      padding: '5px 12px', cursor: 'pointer',
      background: active ? T.accentDim : 'transparent',
      border: `1px solid ${active ? T.accent + '44' : T.border}`,
      color: active ? T.accent : T.textDim,
      transition: 'all 0.2s',
    }}>{label}</button>
  );
}

/* ── Pagination ── */
function Pager({ page, total, onChange }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '14px 0', fontFamily: 'var(--mono)', fontSize: 10, color: T.textDim,
    }}>
      <span>{page} / {total}</span>
      <div style={{ display: 'flex', gap: 2 }}>
        {[['←', Math.max(1, page - 1), page <= 1], ['→', Math.min(total, page + 1), page >= total]].map(([lbl, pg, dis]) => (
          <button key={lbl} onClick={() => !dis && onChange(pg)} style={{
            fontFamily: 'var(--mono)', fontSize: 11, padding: '6px 14px',
            background: T.bg2, border: `1px solid ${T.border}`, color: T.textDim,
            cursor: dis ? 'not-allowed' : 'pointer', opacity: dis ? 0.25 : 1,
            transition: 'border-color 0.2s',
          }}
            onMouseEnter={e => !dis && (e.target.style.borderColor = T.accent + '44')}
            onMouseLeave={e => e.target.style.borderColor = T.border}
          >{lbl}</button>
        ))}
      </div>
    </div>
  );
}

/* ── Animated row: stagger fly-in on mount + glow accent on hover ── */
function Row({ children, onClick, idx }) {
  const [h, setH] = React.useState(false);
  const delay = Math.min(idx, 12) * 0.025; // cap stagger so big tables don't drag
  return (
    <tr
      className="xb-row-anim"
      style={{
        background: h ? T.cardHover : (idx % 2 === 0 ? 'transparent' : T.card),
        cursor: onClick ? 'pointer' : 'default',
        transition: 'background 0.28s ease, box-shadow 0.3s ease',
        boxShadow: h ? `inset 3px 0 0 ${T.accent}` : 'inset 3px 0 0 transparent',
        animationDelay: `${delay}s`,
      }}
      onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)} onClick={onClick}
    >{children}</tr>
  );
}

/* ── Time ── */
function timeAgo(ts) {
  const d = Date.now() - ts;
  if (d < 60000) return Math.floor(d / 1000) + 's';
  if (d < 3600000) return Math.floor(d / 60000) + 'm';
  if (d < 86400000) return Math.floor(d / 3600000) + 'h';
  return Math.floor(d / 86400000) + 'd';
}

Object.assign(window, { T, Status, Sparkline, StatCard, SearchBar, Tabs, FilterChip, Pager, Row, timeAgo });
