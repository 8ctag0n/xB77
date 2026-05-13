const MESH_NODES = [
  { id: "cfo-alpha", label: "cfo-alpha", type: "LEAD", x: 50, y: 28, color: "var(--accent)", status: "online" },
  { id: "worker-01", label: "worker_01", type: "TREASURY", x: 24, y: 50, color: "#34d399", status: "online" },
  { id: "worker-02", label: "worker_02", type: "TRADING", x: 76, y: 50, color: "#4de8d0", status: "online" },
  { id: "worker-03", label: "worker_03", type: "PAYMENTS", x: 30, y: 74, color: "#a78bfa", status: "online" },
  { id: "worker-04", label: "worker_04", type: "RECON", x: 70, y: 74, color: "#fbbf24", status: "idle" },
  // External nodes
  { id: "zk-engine", label: "xB77 ZK Engine", type: "PRIVACY", x: 10, y: 30, color: "var(--accent)", status: "active", ext: true },
  { id: "light", label: "xB77 ZK Engine", type: "ZK-RECEIPTS", x: 90, y: 30, color: "#4de8d0", status: "active", ext: true },
  { id: "solana", label: "Solana", type: "SETTLEMENT", x: 50, y: 95, color: "#a78bfa", status: "active", ext: true },
  { id: "cafe", label: "Caf\xE9 Sovereign", type: "MERCHANT", x: 12, y: 80, color: "#fbbf24", status: "indexed", ext: true },
  { id: "pool", label: "Privacy Pool", type: "OBFUSCATION", x: 88, y: 80, color: "var(--accent)", status: "active", ext: true }
];
const MESH_EDGES = [
  ["cfo-alpha", "worker-01"],
  ["cfo-alpha", "worker-02"],
  ["cfo-alpha", "worker-03"],
  ["cfo-alpha", "worker-04"],
  ["cfo-alpha", "zk-engine"],
  ["cfo-alpha", "light"],
  ["worker-01", "solana"],
  ["worker-02", "solana"],
  ["worker-03", "cafe"],
  ["worker-03", "zk-engine"],
  ["worker-04", "cafe"],
  ["worker-04", "pool"],
  ["zk-engine", "solana"],
  ["light", "solana"],
  ["pool", "solana"]
];
function Particle({ x1, y1, x2, y2, color, duration, delay }) {
  const [progress, setProgress] = React.useState(0);
  const [visible, setVisible] = React.useState(false);
  React.useEffect(() => {
    const t1 = setTimeout(() => {
      setVisible(true);
      const start = performance.now();
      const dur = duration || 1500;
      const animate = (now) => {
        const p = Math.min((now - start) / dur, 1);
        setProgress(p);
        if (p < 1) requestAnimationFrame(animate);
        else setVisible(false);
      };
      requestAnimationFrame(animate);
    }, delay || 0);
    return () => clearTimeout(t1);
  }, []);
  if (!visible) return null;
  const cx = x1 + (x2 - x1) * progress;
  const cy = y1 + (y2 - y1) * progress;
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("circle", { cx, cy, r: "0.6", fill: color, opacity: 1 - progress * 0.5 }, /* @__PURE__ */ React.createElement("animate", { attributeName: "r", values: "0.4;0.8;0.4", dur: "0.6s", repeatCount: "indefinite" })), /* @__PURE__ */ React.createElement(
    "line",
    {
      x1: x1 + (x2 - x1) * Math.max(0, progress - 0.15),
      y1: y1 + (y2 - y1) * Math.max(0, progress - 0.15),
      x2: cx,
      y2: cy,
      stroke: color,
      strokeWidth: "0.3",
      opacity: 0.4
    }
  ));
}
function MeshViz({ events }) {
  const [hoveredNode, setHoveredNode] = React.useState(null);
  const [particles, setParticles] = React.useState([]);
  const particleId = React.useRef(0);
  React.useEffect(() => {
    if (events.length === 0) return;
    const ev = events[0];
    const edge = MESH_EDGES[Math.floor(Math.random() * MESH_EDGES.length)];
    const n1 = MESH_NODES.find((n) => n.id === edge[0]);
    const n2 = MESH_NODES.find((n) => n.id === edge[1]);
    if (n1 && n2) {
      const id = particleId.current++;
      const color = n1.color;
      setParticles((prev) => [...prev.slice(-8), { id, x1: n1.x, y1: n1.y, x2: n2.x, y2: n2.y, color }]);
    }
  }, [events.length]);
  const nodeMap = {};
  MESH_NODES.forEach((n) => {
    nodeMap[n.id] = n;
  });
  return /* @__PURE__ */ React.createElement("div", { style: { position: "relative", width: "100%", height: "100%" } }, /* @__PURE__ */ React.createElement(
    "svg",
    {
      viewBox: "0 0 100 100",
      preserveAspectRatio: "xMidYMid meet",
      style: { position: "absolute", inset: 0, width: "100%", height: "100%" }
    },
    /* @__PURE__ */ React.createElement("defs", null, /* @__PURE__ */ React.createElement("radialGradient", { id: "meshGlow" }, /* @__PURE__ */ React.createElement("stop", { offset: "0%", stopColor: "rgba(200,255,46,0.06)" }), /* @__PURE__ */ React.createElement("stop", { offset: "100%", stopColor: "rgba(200,255,46,0)" }))),
    /* @__PURE__ */ React.createElement("circle", { cx: "50", cy: "50", r: "35", fill: "url(#meshGlow)" }),
    MESH_EDGES.map(([a, b], i) => {
      const n1 = nodeMap[a], n2 = nodeMap[b];
      if (!n1 || !n2) return null;
      const isHovered = hoveredNode === a || hoveredNode === b;
      return /* @__PURE__ */ React.createElement(
        "line",
        {
          key: i,
          x1: n1.x,
          y1: n1.y,
          x2: n2.x,
          y2: n2.y,
          stroke: isHovered ? "var(--accent)" : "var(--border)",
          strokeWidth: isHovered ? "0.25" : "0.12",
          strokeDasharray: n1.ext || n2.ext ? "0.6 0.4" : "none",
          style: { transition: "stroke 0.3s, stroke-width 0.3s" }
        }
      );
    }),
    particles.map((p) => /* @__PURE__ */ React.createElement(Particle, { key: p.id, x1: p.x1, y1: p.y1, x2: p.x2, y2: p.y2, color: p.color, duration: 1200 })),
    MESH_NODES.map((node) => {
      const isHov = hoveredNode === node.id;
      const isAgent = !node.ext;
      const r = isAgent ? 1.8 : 1.2;
      return /* @__PURE__ */ React.createElement(
        "g",
        {
          key: node.id,
          onMouseEnter: () => setHoveredNode(node.id),
          onMouseLeave: () => setHoveredNode(null),
          style: { cursor: "pointer" }
        },
        isAgent && node.status === "online" && /* @__PURE__ */ React.createElement(
          "circle",
          {
            cx: node.x,
            cy: node.y,
            r: r + 1,
            fill: "none",
            stroke: node.color,
            strokeWidth: "0.1",
            opacity: "0.3"
          },
          /* @__PURE__ */ React.createElement("animate", { attributeName: "r", values: `${r};${r + 2};${r}`, dur: "3s", repeatCount: "indefinite" }),
          /* @__PURE__ */ React.createElement("animate", { attributeName: "opacity", values: "0.3;0;0.3", dur: "3s", repeatCount: "indefinite" })
        ),
        /* @__PURE__ */ React.createElement(
          "rect",
          {
            x: node.x - r,
            y: node.y - r,
            width: r * 2,
            height: r * 2,
            fill: isHov ? node.color : D.bg,
            stroke: node.color,
            strokeWidth: isHov ? "0.3" : "0.15",
            opacity: isHov ? 1 : 0.8,
            style: { transition: "all 0.3s" }
          }
        ),
        isAgent && /* @__PURE__ */ React.createElement(
          "circle",
          {
            cx: node.x,
            cy: node.y,
            r: "0.5",
            fill: node.status === "online" ? node.color : "#fbbf24",
            opacity: 0.8
          },
          node.status === "online" && /* @__PURE__ */ React.createElement("animate", { attributeName: "opacity", values: "0.8;0.3;0.8", dur: "2s", repeatCount: "indefinite" })
        )
      );
    })
  ), MESH_NODES.map((node) => {
    const isHov = hoveredNode === node.id;
    const isAgent = !node.ext;
    return /* @__PURE__ */ React.createElement("div", { key: node.id + "-label", style: {
      position: "absolute",
      left: `${node.x}%`,
      top: `${node.y}%`,
      transform: "translate(-50%, 14px)",
      textAlign: "center",
      pointerEvents: "none",
      transition: "opacity 0.3s",
      opacity: isHov ? 1 : isAgent ? 0.7 : 0.4
    } }, /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontSize: isAgent ? 8 : 7,
      fontWeight: isAgent ? 600 : 500,
      color: isHov ? node.color : D.text,
      letterSpacing: "0.06em",
      whiteSpace: "nowrap"
    } }, node.label), /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontSize: 6,
      color: node.color,
      opacity: isHov ? 0.8 : 0.4,
      letterSpacing: "0.1em",
      textTransform: "uppercase"
    } }, node.type));
  }), hoveredNode && (() => {
    const node = MESH_NODES.find((n) => n.id === hoveredNode);
    if (!node) return null;
    const isAgent = !node.ext;
    return /* @__PURE__ */ React.createElement("div", { style: {
      position: "absolute",
      left: `${Math.min(Math.max(node.x, 20), 80)}%`,
      top: `${node.y - 12}%`,
      transform: "translate(-50%, -100%)",
      background: D.bg2,
      border: `1px solid ${node.color}30`,
      padding: "10px 14px",
      minWidth: 140,
      boxShadow: `0 0 30px ${node.color}15`,
      pointerEvents: "none",
      zIndex: 10
    } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 6, marginBottom: 4 } }, /* @__PURE__ */ React.createElement(Dot, { color: node.status === "online" || node.status === "active" ? D.green : D.amber }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, fontWeight: 600, color: D.text } }, node.label)), /* @__PURE__ */ React.createElement(DM, { size: 7, color: node.color }, node.type), isAgent && /* @__PURE__ */ React.createElement("div", { style: { marginTop: 6, display: "flex", gap: 12 } }, /* @__PURE__ */ React.createElement(DM, { size: 7 }, "12 txns"), /* @__PURE__ */ React.createElement(DM, { size: 7, color: D.green }, "+$201")));
  })());
}
function DashboardView() {
  const [events, setEvents] = React.useState([]);
  const [pulse, setPulse] = React.useState({ agentsOnline: 0, proofsVerified24h: 0, _rpcLive: false });

  React.useEffect(() => {
    let active = true;
    const fetchEvents = async () => {
      try {
        const res = await fetch('http://localhost:8787/api/v1/pipelines/recent?limit=30');
        if (!res.ok) return;
        const data = await res.json();
        if (data.pipelines && active) {
          const formatted = data.pipelines.map((p) => {
            const time = new Date(p.started_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
            let icon = "⚡";
            let color = D.dim;
            if (p.verdict === "FAILED") { icon = "⚠️"; color = D.red; }
            else if (p.status === "completed") { icon = "✅"; color = D.green; }
            return {
              id: p.signature || Math.random().toString(),
              icon,
              text: `${p.agent || 'system'} \u2014 ${p.kind}: ${p.verdict}`,
              color,
              time
            };
          });
          setEvents(formatted);
        }
      } catch (err) {
        console.error("Gateway fetch failed:", err);
      }
    };
    const fetchPulse = async () => {
      try {
        const res = await fetch('/api/v1/network/pulse');
        if (res.ok) {
          const data = await res.json();
          if (active) setPulse(data);
        }
      } catch (err) {}
    };

    fetchEvents();
    fetchPulse();
    const id1 = setInterval(fetchEvents, 5000);
    const id2 = setInterval(fetchPulse, 10000);
    return () => { active = false; clearInterval(id1); clearInterval(id2); };
  }, []);
  const sparkTxns = [3, 5, 4, 7, 6, 8, 5, 9, 11, 8, 12, 10, 14, 11, 13, 15, 12, 14, 16, 14];
  return /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column", minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: "repeat(5, 1fr)",
    gap: 0,
    borderBottom: `1px solid ${D.border}`,
    flexShrink: 0
  } }, [
    { label: "TREASURY", value: "$24,847", change: "SECURED" },
    { label: "AGENTS", value: `${pulse.agentsOnline}`, sub: pulse._rpcLive ? "SWARM ONLINE" : "OFFLINE" },
    { label: "PIPELINES", value: `${events.length}`, sub: "active ingest" },
    { label: "TXNS TODAY", value: `${pulse.proofsVerified24h}`, change: "+LIVE" },
    { label: "NETWORK", value: pulse._rpcLive ? "CONNECTED" : "OFFLINE", change: "Localnet" }
  ].map((s, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    padding: "14px 18px",
    borderRight: i < 4 ? `1px solid ${D.border}` : "none"
  } }, /* @__PURE__ */ React.createElement(DM, { size: 7 }, s.label), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--serif)", fontSize: 22, color: D.text, marginTop: 4, fontStyle: "italic" } }, s.value), s.change && /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: s.change.startsWith("+") ? D.green : D.red, marginTop: 2 } }, s.change), s.sub && /* @__PURE__ */ React.createElement(DM, { size: 7, color: D.green, style: { marginTop: 2 } }, s.sub)))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "grid", gridTemplateColumns: "1fr 300px", minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { position: "relative", overflow: "hidden" } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    inset: 0,
    pointerEvents: "none",
    fontFamily: "var(--mono)",
    fontSize: 8,
    color: "rgba(200,255,46,0.015)",
    lineHeight: 2.4,
    letterSpacing: "0.5em",
    whiteSpace: "pre-wrap",
    wordBreak: "break-all",
    padding: 20,
    userSelect: "none",
    zIndex: 0
  } }, Array(20).fill("MESH AGENT PIPELINE ZK_ENGINE ZK_ENGINE ZK PRIVACY SOVEREIGN AUTONOMOUS SWARM TREASURY ").join("")), /* @__PURE__ */ React.createElement(MeshViz, { events })), /* @__PURE__ */ React.createElement("div", { style: { borderLeft: `1px solid ${D.border}`, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "12px 16px", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement(DM, { size: 7 }, "TRANSACTIONS 7D"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(Spark, { data: sparkTxns, color: D.accent, height: 28 }))), /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 16px 4px", display: "flex", alignItems: "center", gap: 6 } }, /* @__PURE__ */ React.createElement(Dot, { color: D.green, pulse: true }), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.text }, "LIVE FEED")), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto", padding: "0 16px" } }, events.map((ev, i) => /* @__PURE__ */ React.createElement(EventLine, { key: ev.id, idx: i, time: ev.time, icon: ev.icon, text: ev.text, color: ev.color, isNew: true }))))));
}
function MeshTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    flexDirection: "column",
    minHeight: 520,
    border: "1px solid var(--border-soft)",
    background: "var(--bg)"
  } }, /* @__PURE__ */ React.createElement(DashboardView, null));
}
Object.assign(window, { DashboardView, MeshTab });
