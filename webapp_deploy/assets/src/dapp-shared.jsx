/* xB77 dApp — Shared theme, layout, icons */

const D = {
  bg: 'var(--bg)', bg2: 'var(--bg-2)', bg3: 'var(--bg-3)', bg4: 'var(--bg-4)',
  accent: 'var(--accent)', accentDim: 'var(--accent-dim)', accentGlow: 'var(--accent-glow)',
  text: 'var(--text)', dim: 'var(--text-dim)', faint: '#3a3a42', muted: '#52525e',
  border: 'var(--border)', borderHover: 'rgba(255,255,255,0.12)',
  green: '#34d399', red: '#f87171', amber: '#fbbf24', cyan: '#4de8d0', purple: '#a78bfa',
  sidebar: 'var(--sidebar-bg)', topbar: 'var(--topbar-bg)',
};

/* ── Tiny components ── */
const DM = ({ children, color, size, weight, style: s }) => (
  <span style={{ fontFamily: 'var(--mono)', fontSize: size || 9, fontWeight: weight || 600, letterSpacing: '0.14em', textTransform: 'uppercase', color: color || D.dim, ...s }}>{children}</span>
);

const DS = ({ children, size, color, italic, style: s }) => (
  <span style={{ fontFamily: 'var(--serif)', fontSize: size || 28, fontWeight: 400, color: color || D.text, lineHeight: 1.1, fontStyle: italic ? 'italic' : 'normal', ...s }}>{children}</span>
);

/* ── Status dot ── */
const Dot = ({ color, pulse }) => (
  <span style={{
    width: 6, height: 6, borderRadius: '50%', background: color || D.green,
    display: 'inline-block', flexShrink: 0,
    animation: pulse ? 'livePulse 2s ease infinite' : 'none',
  }}></span>
);

/* ── Badge ── */
const Badge = ({ children, color, bg }) => (
  <span style={{
    fontFamily: 'var(--mono)', fontSize: 8, fontWeight: 600, letterSpacing: '0.12em',
    textTransform: 'uppercase', color: color || D.accent,
    background: bg || D.accentDim, padding: '3px 8px',
  }}>{children}</span>
);

/* ── Stat card ── */
const StatBox = ({ label, value, sub, change, color }) => (
  <div style={{ padding: '16px 18px', background: D.bg2, border: `1px solid ${D.border}` }}>
    <DM size={8}>{label}</DM>
    <div style={{ fontFamily: 'var(--serif)', fontSize: 26, color: color || D.text, marginTop: 8, fontStyle: 'italic' }}>{value}</div>
    {sub && <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: D.dim, marginTop: 4 }}>{sub}</div>}
    {change && (
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, marginTop: 4, color: change.startsWith('+') ? D.green : change.startsWith('-') ? D.red : D.dim }}>{change}</div>
    )}
  </div>
);

/* ── Mini sparkline (CSS bars) ── */
const Spark = ({ data, color, height }) => {
  const max = Math.max(...data);
  const h = height || 24;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 1, height: h }}>
      {data.map((v, i) => (
        <div key={i} style={{
          flex: 1, height: `${(v / max) * 100}%`, minHeight: 1,
          background: color || D.accent, opacity: 0.4 + (i / data.length) * 0.6,
        }}></div>
      ))}
    </div>
  );
};

/* ── Event line (live feed) ── */
const EventLine = ({ time, icon, text, color, isNew }) => (
  <div style={{
    display: 'flex', gap: 10, padding: '8px 0',
    borderBottom: `1px solid ${D.border}`,
    animation: isNew ? 'fadeInLine 0.3s ease' : 'none',
  }}>
    <DM size={8} color={D.faint} style={{ minWidth: 42, flexShrink: 0 }}>{time}</DM>
    <span style={{ fontSize: 11, flexShrink: 0 }}>{icon}</span>
    <span style={{ fontFamily: 'var(--sans)', fontSize: 12, color: color || D.dim, lineHeight: 1.5 }}>{text}</span>
  </div>
);

/* ── Table row helper ── */
const TRow = ({ children, onClick, style: s }) => (
  <div onClick={onClick} style={{
    display: 'contents', cursor: onClick ? 'pointer' : 'default',
    ...s,
  }}>{children}</div>
);

const TCell = ({ children, color, mono, align, style: s }) => (
  <div style={{
    padding: '10px 12px', fontFamily: mono ? 'var(--mono)' : 'var(--sans)',
    fontSize: 12, color: color || D.text, textAlign: align || 'left',
    borderBottom: `1px solid ${D.border}`, display: 'flex', alignItems: 'center', gap: 6,
    ...s,
  }}>{children}</div>
);

/* ── Button ── */
const DBtn = ({ children, primary, small, danger, onClick, style: s }) => (
  <button onClick={onClick} style={{
    fontFamily: 'var(--mono)', fontSize: small ? 9 : 10, fontWeight: 600,
    letterSpacing: '0.08em', textTransform: 'uppercase',
    background: danger ? 'rgba(248,113,113,0.15)' : primary ? D.accent : 'transparent',
    color: danger ? D.red : primary ? D.bg : D.text,
    border: primary ? 'none' : `1px solid ${danger ? 'rgba(248,113,113,0.3)' : D.border}`,
    padding: small ? '5px 10px' : '8px 16px', cursor: 'pointer',
    transition: 'all 0.2s', ...s,
  }}>{children}</button>
);

/* ── Section header ── */
const SectionHead = ({ title, action, onAction, children }) => (
  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <DS size={22} italic>{title}</DS>
      {children}
    </div>
    {action && <DBtn small onClick={onAction}>{action}</DBtn>}
  </div>
);

/* ── Sidebar nav item ── */
const NavItem = ({ icon, label, active, count, onClick }) => (
  <button onClick={onClick} style={{
    display: 'flex', alignItems: 'center', gap: 10, width: '100%',
    padding: '9px 16px', background: active ? D.accentDim : 'transparent',
    border: 'none', borderLeft: `2px solid ${active ? D.accent : 'transparent'}`,
    cursor: 'pointer', transition: 'all 0.28s ease',
  }}>
    <span style={{ fontSize: 13, color: active ? D.accent : D.muted, width: 18, textAlign: 'center' }}>{icon}</span>
    <span style={{ fontFamily: 'var(--mono)', fontSize: 10, fontWeight: active ? 600 : 500, letterSpacing: '0.08em', textTransform: 'uppercase', color: active ? D.accent : D.dim }}>{label}</span>
    {count != null && (
      <span style={{ marginLeft: 'auto', fontFamily: 'var(--mono)', fontSize: 9, color: active ? D.accent : D.faint }}>{count}</span>
    )}
  </button>
);

Object.assign(window, {
  D, DM, DS, Dot, Badge, StatBox, Spark, EventLine, TRow, TCell, DBtn, SectionHead, NavItem,
});
