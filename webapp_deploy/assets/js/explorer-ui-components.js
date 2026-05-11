const T = {
  bg: "var(--bg)",
  bg2: "var(--bg-2)",
  bg3: "var(--bg-3)",
  card: "rgba(255,255,255,0.02)",
  cardHover: "rgba(255,255,255,0.05)",
  accent: "var(--accent)",
  accentDim: "rgba(200,255,46,0.08)",
  accentMid: "rgba(200,255,46,0.2)",
  text: "var(--text)",
  textMid: "#9a9aaa",
  textDim: "#55555f",
  border: "rgba(255,255,255,0.05)",
  borderHover: "rgba(255,255,255,0.12)",
  red: "#ff4455",
  green: "#44ee88",
  yellow: "#f0c040",
  blue: "#4da8ff",
  cyan: "#4de8d0"
};
function Status({ status, size = "sm" }) {
  const map = {
    COMPLETED: T.green,
    ACTIVE: T.green,
    ONLINE: T.green,
    PENDING: T.yellow,
    SYNCING: T.yellow,
    IDLE: T.yellow,
    IN_PROGRESS: T.cyan,
    FAILED: T.red,
    OFFLINE: T.red,
    STANDARD: T.textMid,
    ELEVATED: T.yellow,
    LOCKDOWN: T.red
  };
  const c = map[status] || T.textDim;
  const fs = size === "lg" ? 12 : 10;
  const isLive = status === "ACTIVE" || status === "ONLINE" || status === "IN_PROGRESS" || status === "SYNCING";
  return /* @__PURE__ */ React.createElement("span", { style: { display: "inline-flex", alignItems: "center", gap: 6 } }, /* @__PURE__ */ React.createElement(
    "span",
    {
      className: isLive ? "xb-pulse-dot" : "",
      style: { width: 6, height: 6, borderRadius: "50%", background: c, color: c, boxShadow: `0 0 8px ${c}66`, flexShrink: 0 }
    }
  ), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: fs, color: c, letterSpacing: "0.06em" } }, status));
}
function useCountUp(target, ms = 900) {
  const [v, setV] = React.useState(0);
  const startRef = React.useRef(null);
  React.useEffect(() => {
    if (typeof target !== "number" || !isFinite(target)) return;
    const start = performance.now();
    startRef.current = start;
    let raf;
    const tick = (t) => {
      const elapsed = t - start;
      const p = Math.min(1, elapsed / ms);
      const eased = 1 - Math.pow(1 - p, 3);
      setV(target * eased);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, ms]);
  return v;
}
function Sparkline({ data, color = T.accent, width = 80, height = 24 }) {
  if (!data || data.length < 2) return null;
  const min = Math.min(...data), max = Math.max(...data);
  const range = max - min || 1;
  const coords = data.map((v, i) => {
    const x = i / (data.length - 1) * width;
    const y = height - (v - min) / range * (height - 4) - 2;
    return [x, y];
  });
  const linePoints = coords.map(([x, y]) => `${x},${y}`).join(" ");
  const fillPoints = `0,${height} ${linePoints} ${width},${height}`;
  const gradId = React.useMemo(() => "sg" + Math.random().toString(36).slice(2, 8), []);
  const [last] = coords.slice(-1);
  return /* @__PURE__ */ React.createElement("svg", { width, height, style: { display: "block", overflow: "visible" } }, /* @__PURE__ */ React.createElement("defs", null, /* @__PURE__ */ React.createElement("linearGradient", { id: gradId, x1: "0", y1: "0", x2: "0", y2: "1" }, /* @__PURE__ */ React.createElement("stop", { offset: "0%", stopColor: color, stopOpacity: "0.28" }), /* @__PURE__ */ React.createElement("stop", { offset: "100%", stopColor: color, stopOpacity: "0" }))), /* @__PURE__ */ React.createElement("polygon", { points: fillPoints, fill: `url(#${gradId})` }), /* @__PURE__ */ React.createElement(
    "polyline",
    {
      points: linePoints,
      fill: "none",
      stroke: color,
      strokeWidth: "1.4",
      opacity: "0.85",
      strokeLinecap: "round",
      strokeLinejoin: "round",
      style: { strokeDasharray: 100, animation: "dashFlow 1.2s ease-out forwards" }
    }
  ), /* @__PURE__ */ React.createElement("circle", { cx: last[0], cy: last[1], r: "2.2", fill: color }, /* @__PURE__ */ React.createElement("animate", { attributeName: "r", values: "2.2;3.4;2.2", dur: "2.2s", repeatCount: "indefinite" })));
}
function StatCard({ label, value, change, sparkData, color }) {
  const [h, setH] = React.useState(false);
  const parsed = React.useMemo(() => {
    if (typeof value !== "string") return null;
    const m = value.match(/^([^\d-]*)(-?\d[\d,]*(?:\.\d+)?)([\s\S]*)$/);
    if (!m) return null;
    const num = parseFloat(m[2].replace(/,/g, ""));
    if (!isFinite(num)) return null;
    return { prefix: m[1], num, suffix: m[3], hasComma: m[2].includes(","), decimals: (m[2].split(".")[1] || "").length };
  }, [value]);
  const animated = useCountUp(parsed ? parsed.num : 0, 1100);
  const display = parsed ? `${parsed.prefix}${parsed.hasComma ? Math.round(animated).toLocaleString() : animated.toFixed(parsed.decimals)}${parsed.suffix}` : value;
  return /* @__PURE__ */ React.createElement("div", { style: {
    padding: "20px 22px",
    background: h ? T.cardHover : T.card,
    border: `1px solid ${h ? T.borderHover : T.border}`,
    transition: "all 0.25s",
    cursor: "default",
    position: "relative",
    overflow: "hidden"
  }, onMouseEnter: () => setH(true), onMouseLeave: () => setH(false) }, h && /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    background: `linear-gradient(90deg, transparent, ${color || T.accent}, transparent)`
  } }), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", alignItems: "flex-start" } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.18em", marginBottom: 8 } }, label), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 22, color: h ? T.accent : T.text, fontWeight: 700, transition: "color 0.2s", letterSpacing: "-0.02em", fontVariantNumeric: "tabular-nums" } }, display), change && /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: change.startsWith("+") ? T.green : T.red, marginTop: 4 } }, change)), sparkData && /* @__PURE__ */ React.createElement(Sparkline, { data: sparkData, color: color || T.accent })));
}
function SearchBar({ value, onChange }) {
  const [f, setF] = React.useState(false);
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    border: `1px solid ${f ? T.accent + "44" : T.border}`,
    padding: "12px 18px",
    background: T.bg2,
    transition: "border-color 0.25s, box-shadow 0.25s",
    boxShadow: f ? `0 0 20px ${T.accentDim}` : "none"
  } }, /* @__PURE__ */ React.createElement("span", { style: { color: T.textDim, fontSize: 16, opacity: 0.6 } }, "\u2315"), /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "text",
      value,
      onChange: (e) => onChange(e.target.value),
      onFocus: () => setF(true),
      onBlur: () => setF(false),
      placeholder: "Search pipeline, agent, znode, tx hash...",
      style: {
        background: "none",
        border: "none",
        outline: "none",
        flex: 1,
        fontFamily: "var(--mono)",
        fontSize: 13,
        color: T.text
      }
    }
  ), value && /* @__PURE__ */ React.createElement("span", { onClick: () => onChange(""), style: { color: T.textDim, cursor: "pointer", fontSize: 12, fontFamily: "var(--mono)" } }, "ESC"));
}
function Tabs({ tabs, active, onChange }) {
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 2, padding: "4px", background: T.bg2, border: `1px solid ${T.border}` } }, tabs.map((tab) => {
    const isActive = active === tab.id;
    return /* @__PURE__ */ React.createElement("button", { key: tab.id, onClick: () => onChange(tab.id), style: {
      fontFamily: "var(--mono)",
      fontSize: 11,
      letterSpacing: "0.08em",
      textTransform: "uppercase",
      padding: "10px 20px",
      flex: 1,
      background: isActive ? T.accentDim : "transparent",
      border: isActive ? `1px solid ${T.accent}33` : "1px solid transparent",
      color: isActive ? T.accent : T.textDim,
      cursor: "pointer",
      transition: "all 0.2s"
    } }, tab.label, /* @__PURE__ */ React.createElement("span", { style: { marginLeft: 6, opacity: 0.4, fontSize: 10 } }, tab.count));
  }));
}
function FilterChip({ label, active, onClick }) {
  return /* @__PURE__ */ React.createElement("button", { onClick, style: {
    fontFamily: "var(--mono)",
    fontSize: 9.5,
    letterSpacing: "0.06em",
    padding: "5px 12px",
    cursor: "pointer",
    background: active ? T.accentDim : "transparent",
    border: `1px solid ${active ? T.accent + "44" : T.border}`,
    color: active ? T.accent : T.textDim,
    transition: "all 0.2s"
  } }, label);
}
function Pager({ page, total, onChange }) {
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "14px 0",
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: T.textDim
  } }, /* @__PURE__ */ React.createElement("span", null, page, " / ", total), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 2 } }, [["\u2190", Math.max(1, page - 1), page <= 1], ["\u2192", Math.min(total, page + 1), page >= total]].map(([lbl, pg, dis]) => /* @__PURE__ */ React.createElement(
    "button",
    {
      key: lbl,
      onClick: () => !dis && onChange(pg),
      style: {
        fontFamily: "var(--mono)",
        fontSize: 11,
        padding: "6px 14px",
        background: T.bg2,
        border: `1px solid ${T.border}`,
        color: T.textDim,
        cursor: dis ? "not-allowed" : "pointer",
        opacity: dis ? 0.25 : 1,
        transition: "border-color 0.2s"
      },
      onMouseEnter: (e) => !dis && (e.target.style.borderColor = T.accent + "44"),
      onMouseLeave: (e) => e.target.style.borderColor = T.border
    },
    lbl
  ))));
}
function Row({ children, onClick, idx }) {
  const [h, setH] = React.useState(false);
  const delay = Math.min(idx, 12) * 0.025;
  return /* @__PURE__ */ React.createElement(
    "tr",
    {
      className: "xb-row-anim",
      style: {
        background: h ? T.cardHover : idx % 2 === 0 ? "transparent" : T.card,
        cursor: onClick ? "pointer" : "default",
        transition: "background 0.28s ease, box-shadow 0.3s ease",
        boxShadow: h ? `inset 3px 0 0 ${T.accent}` : "inset 3px 0 0 transparent",
        animationDelay: `${delay}s`
      },
      onMouseEnter: () => setH(true),
      onMouseLeave: () => setH(false),
      onClick
    },
    children
  );
}
function timeAgo(ts) {
  const d = Date.now() - ts;
  if (d < 6e4) return Math.floor(d / 1e3) + "s";
  if (d < 36e5) return Math.floor(d / 6e4) + "m";
  if (d < 864e5) return Math.floor(d / 36e5) + "h";
  return Math.floor(d / 864e5) + "d";
}
Object.assign(window, { T, Status, Sparkline, StatCard, SearchBar, Tabs, FilterChip, Pager, Row, timeAgo });
