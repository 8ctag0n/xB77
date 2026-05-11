const PAGE_SIZE = 12;
function MeshCanvas({ znodes }) {
  const canvasRef = React.useRef(null);
  const animRef = React.useRef(null);
  const stateRef = React.useRef(null);
  React.useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const W = 320, H = 240;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    ctx.scale(dpr, dpr);
    if (!stateRef.current) {
      const nodes2 = znodes.slice(0, 24).map((z) => ({
        x: 30 + Math.random() * (W - 60),
        y: 20 + Math.random() * (H - 40),
        vx: (Math.random() - 0.5) * 0.18,
        vy: (Math.random() - 0.5) * 0.18,
        r: z.status === "ONLINE" ? 3.5 : 2.5,
        color: z.status === "ONLINE" ? "var(--accent)" : z.status === "SYNCING" ? "#f0c040" : "#ff4455",
        status: z.status,
        ring: Math.random() * Math.PI * 2,
        // ring phase
        ringRate: 0.018 + Math.random() * 0.012
        // ring breathing speed
      }));
      stateRef.current = { nodes: nodes2, packets: [], lastPacket: 0 };
    }
    const { nodes } = stateRef.current;
    function spawnPacket(now) {
      const active = nodes.filter((n) => n.status === "ONLINE");
      if (active.length < 2) return;
      const a = active[Math.floor(Math.random() * active.length)];
      const within = active.filter((b2) => b2 !== a && Math.hypot(a.x - b2.x, a.y - b2.y) < 95);
      if (!within.length) return;
      const b = within[Math.floor(Math.random() * within.length)];
      stateRef.current.packets.push({ from: a, to: b, t: 0, born: now });
    }
    function draw(now) {
      ctx.clearRect(0, 0, W, H);
      nodes.forEach((n) => {
        n.x += n.vx;
        n.y += n.vy;
        if (n.x < 20 || n.x > W - 20) n.vx *= -1;
        if (n.y < 15 || n.y > H - 15) n.vy *= -1;
        n.ring += n.ringRate;
      });
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const dx = nodes[i].x - nodes[j].x, dy = nodes[i].y - nodes[j].y;
          const dist = Math.hypot(dx, dy);
          if (dist < 100) {
            const alpha = (1 - dist / 100) * 0.14;
            ctx.beginPath();
            ctx.moveTo(nodes[i].x, nodes[i].y);
            ctx.lineTo(nodes[j].x, nodes[j].y);
            ctx.strokeStyle = `rgba(200,255,46,${alpha})`;
            ctx.lineWidth = 0.5;
            ctx.stroke();
          }
        }
      }
      if (!stateRef.current.lastPacket || now - stateRef.current.lastPacket > 250) {
        spawnPacket(now);
        stateRef.current.lastPacket = now;
      }
      stateRef.current.packets = stateRef.current.packets.filter((p) => {
        p.t += 0.018;
        if (p.t >= 1) return false;
        const x = p.from.x + (p.to.x - p.from.x) * p.t;
        const y = p.from.y + (p.to.y - p.from.y) * p.t;
        const tx = p.from.x + (p.to.x - p.from.x) * Math.max(0, p.t - 0.18);
        const ty = p.from.y + (p.to.y - p.from.y) * Math.max(0, p.t - 0.18);
        const grad = ctx.createLinearGradient(tx, ty, x, y);
        grad.addColorStop(0, "rgba(0,240,255,0)");
        grad.addColorStop(1, "rgba(0,240,255,0.9)");
        ctx.beginPath();
        ctx.moveTo(tx, ty);
        ctx.lineTo(x, y);
        ctx.strokeStyle = grad;
        ctx.lineWidth = 1.4;
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(x, y, 1.6, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(0,240,255,0.95)";
        ctx.fill();
        return true;
      });
      nodes.forEach((n) => {
        const glow = ctx.createRadialGradient(n.x, n.y, 0, n.x, n.y, n.r * 4);
        glow.addColorStop(0, n.color + "40");
        glow.addColorStop(1, n.color + "00");
        ctx.fillStyle = glow;
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.r * 4, 0, Math.PI * 2);
        ctx.fill();
        if (n.status === "ONLINE") {
          const phase = (Math.sin(n.ring) + 1) / 2;
          ctx.beginPath();
          ctx.arc(n.x, n.y, n.r + 2 + phase * 6, 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(200,255,46,${0.22 - phase * 0.18})`;
          ctx.lineWidth = 0.7;
          ctx.stroke();
        }
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2);
        ctx.fillStyle = n.color + "dd";
        ctx.fill();
      });
      animRef.current = requestAnimationFrame(draw);
    }
    draw(performance.now());
    return () => cancelAnimationFrame(animRef.current);
  }, []);
  return /* @__PURE__ */ React.createElement("canvas", { ref: canvasRef, style: { width: "100%", height: 240, display: "block" } });
}
function PipelinesView({ data, search, onSelect }) {
  const [page, setPage] = React.useState(1);
  const [statusF, setStatusF] = React.useState("ALL");
  const filtered = data.filter((p) => {
    if (statusF !== "ALL" && p.status !== statusF) return false;
    if (search) {
      const s = search.toLowerCase();
      return p.id.includes(s) || p.agent.toLowerCase().includes(s) || p.type.toLowerCase().includes(s);
    }
    return true;
  });
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageData = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  React.useEffect(() => setPage(1), [search, statusF]);
  const th = { padding: "10px 12px", fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.14em", textTransform: "uppercase", fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: "left" };
  const td = { padding: "11px 12px", fontFamily: "var(--mono)", fontSize: 11.5, color: T.text, borderBottom: `1px solid ${T.border}` };
  return /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 6, padding: "14px 0", flexWrap: "wrap", alignItems: "center" } }, ["ALL", "COMPLETED", "IN_PROGRESS", "PENDING", "FAILED"].map((s) => /* @__PURE__ */ React.createElement(FilterChip, { key: s, label: s, active: statusF === s, onClick: () => setStatusF(s) })), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, color: T.textDim, marginLeft: "auto" } }, filtered.length, " results")), /* @__PURE__ */ React.createElement("div", { style: { overflowX: "auto" } }, /* @__PURE__ */ React.createElement("table", { style: { width: "100%", borderCollapse: "collapse" } }, /* @__PURE__ */ React.createElement("thead", null, /* @__PURE__ */ React.createElement("tr", null, /* @__PURE__ */ React.createElement("th", { style: th }, "PIPELINE"), /* @__PURE__ */ React.createElement("th", { style: th }, "TYPE"), /* @__PURE__ */ React.createElement("th", { style: th }, "AGENT"), /* @__PURE__ */ React.createElement("th", { style: th }, "AMOUNT"), /* @__PURE__ */ React.createElement("th", { style: th }, "ZNODE"), /* @__PURE__ */ React.createElement("th", { style: th }, "STATUS"), /* @__PURE__ */ React.createElement("th", { style: th }, "AGE"))), /* @__PURE__ */ React.createElement("tbody", null, pageData.map((p, i) => /* @__PURE__ */ React.createElement(Row, { key: p.id, idx: i, onClick: () => onSelect({ type: "pipeline", data: p }) }, /* @__PURE__ */ React.createElement("td", { style: { ...td, color: T.accent, cursor: "pointer" } }, /* @__PURE__ */ React.createElement("span", { className: "xb-row-id", style: { display: "inline-block" } }, p.id)), /* @__PURE__ */ React.createElement("td", { style: { ...td, fontSize: 9.5, color: T.textMid } }, p.type), /* @__PURE__ */ React.createElement("td", { style: td }, p.agent), /* @__PURE__ */ React.createElement("td", { style: td }, /* @__PURE__ */ React.createElement("span", { style: { color: T.text } }, p.amount), " ", /* @__PURE__ */ React.createElement("span", { style: { color: T.textDim, fontSize: 10 } }, p.currency)), /* @__PURE__ */ React.createElement("td", { style: { ...td, fontSize: 10, color: T.textMid } }, p.znode), /* @__PURE__ */ React.createElement("td", { style: td }, /* @__PURE__ */ React.createElement(Status, { status: p.status })), /* @__PURE__ */ React.createElement("td", { style: { ...td, color: T.textDim, fontSize: 10 } }, timeAgo(p.timestamp))))))), /* @__PURE__ */ React.createElement(Pager, { page, total: totalPages, onChange: setPage }));
}
function ZnodesView({ data, search, onSelect }) {
  const filtered = data.filter((z) => !search || z.id.includes(search.toLowerCase()) || z.region.toLowerCase().includes(search.toLowerCase()));
  const th = { padding: "10px 12px", fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.14em", textTransform: "uppercase", fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: "left" };
  const td = { padding: "11px 12px", fontFamily: "var(--mono)", fontSize: 11.5, color: T.text, borderBottom: `1px solid ${T.border}` };
  return /* @__PURE__ */ React.createElement("div", { style: { overflowX: "auto", marginTop: 12 } }, /* @__PURE__ */ React.createElement("table", { style: { width: "100%", borderCollapse: "collapse" } }, /* @__PURE__ */ React.createElement("thead", null, /* @__PURE__ */ React.createElement("tr", null, /* @__PURE__ */ React.createElement("th", { style: th }, "ZNODE"), /* @__PURE__ */ React.createElement("th", { style: th }, "REGION"), /* @__PURE__ */ React.createElement("th", { style: th }, "STATUS"), /* @__PURE__ */ React.createElement("th", { style: th }, "PEERS"), /* @__PURE__ */ React.createElement("th", { style: th }, "LATENCY"), /* @__PURE__ */ React.createElement("th", { style: th }, "UPTIME"), /* @__PURE__ */ React.createElement("th", { style: th }, "PIPELINES"), /* @__PURE__ */ React.createElement("th", { style: th }, "STAKE"))), /* @__PURE__ */ React.createElement("tbody", null, filtered.map((z, i) => /* @__PURE__ */ React.createElement(Row, { key: z.id, idx: i, onClick: () => onSelect({ type: "znode", data: z }) }, /* @__PURE__ */ React.createElement("td", { style: { ...td, color: T.accent } }, /* @__PURE__ */ React.createElement("span", { className: "xb-row-id", style: { display: "inline-block" } }, z.id)), /* @__PURE__ */ React.createElement("td", { style: td }, z.region), /* @__PURE__ */ React.createElement("td", { style: td }, /* @__PURE__ */ React.createElement(Status, { status: z.status })), /* @__PURE__ */ React.createElement("td", { style: td }, z.peers), /* @__PURE__ */ React.createElement("td", { style: td }, z.latency, /* @__PURE__ */ React.createElement("span", { style: { color: T.textDim, fontSize: 9 } }, "ms")), /* @__PURE__ */ React.createElement("td", { style: td }, (z.uptime * 100).toFixed(1), "%"), /* @__PURE__ */ React.createElement("td", { style: td }, z.pipelines.toLocaleString()), /* @__PURE__ */ React.createElement("td", { style: td }, Number(z.stake).toLocaleString(), " ", /* @__PURE__ */ React.createElement("span", { style: { color: T.textDim, fontSize: 9 } }, "SOL")))))));
}
function AgentsView({ data, search, onSelect }) {
  const filtered = data.filter((a) => !search || a.name.toLowerCase().includes(search.toLowerCase()) || a.address.includes(search.toLowerCase()));
  const th = { padding: "10px 12px", fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.14em", textTransform: "uppercase", fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: "left" };
  const td = { padding: "11px 12px", fontFamily: "var(--mono)", fontSize: 11.5, color: T.text, borderBottom: `1px solid ${T.border}` };
  return /* @__PURE__ */ React.createElement("div", { style: { overflowX: "auto", marginTop: 12 } }, /* @__PURE__ */ React.createElement("table", { style: { width: "100%", borderCollapse: "collapse" } }, /* @__PURE__ */ React.createElement("thead", null, /* @__PURE__ */ React.createElement("tr", null, /* @__PURE__ */ React.createElement("th", { style: th }, "AGENT"), /* @__PURE__ */ React.createElement("th", { style: th }, "ADDRESS"), /* @__PURE__ */ React.createElement("th", { style: th }, "STATUS"), /* @__PURE__ */ React.createElement("th", { style: th }, "PIPELINES"), /* @__PURE__ */ React.createElement("th", { style: th }, "VOLUME"), /* @__PURE__ */ React.createElement("th", { style: th }, "GOVERNANCE"), /* @__PURE__ */ React.createElement("th", { style: th }, "LAST SEEN"))), /* @__PURE__ */ React.createElement("tbody", null, filtered.map((a, i) => /* @__PURE__ */ React.createElement(Row, { key: a.name, idx: i, onClick: () => onSelect({ type: "agent", data: a }) }, /* @__PURE__ */ React.createElement("td", { style: { ...td, color: T.accent } }, /* @__PURE__ */ React.createElement("span", { className: "xb-row-id", style: { display: "inline-block" } }, a.name)), /* @__PURE__ */ React.createElement("td", { style: { ...td, fontSize: 10, color: T.textMid } }, a.address), /* @__PURE__ */ React.createElement("td", { style: td }, /* @__PURE__ */ React.createElement(Status, { status: a.status })), /* @__PURE__ */ React.createElement("td", { style: td }, a.pipelines), /* @__PURE__ */ React.createElement("td", { style: td }, "$", Number(a.volume).toLocaleString()), /* @__PURE__ */ React.createElement("td", { style: td }, /* @__PURE__ */ React.createElement(Status, { status: a.governanceLevel })), /* @__PURE__ */ React.createElement("td", { style: { ...td, color: T.textDim, fontSize: 10 } }, timeAgo(a.lastActive)))))));
}
function DetailSlide({ sel, onClose }) {
  if (!sel) return null;
  const { type, data } = sel;
  let _fieldIdx = 0;
  const field = (label, value, accent) => {
    const i = _fieldIdx++;
    return /* @__PURE__ */ React.createElement("div", { style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      padding: "10px 0",
      borderBottom: `1px solid ${T.border}`,
      opacity: 0,
      animation: "fadeInLine 0.32s ease forwards",
      animationDelay: `${0.04 + Math.min(i, 18) * 0.035}s`
    } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.12em" } }, label), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11.5, color: accent ? T.accent : T.text, textAlign: "right", maxWidth: "60%", wordBreak: "break-all" } }, value));
  };
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement("div", { style: { position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", zIndex: 299, backdropFilter: "blur(4px)" }, onClick: onClose }), /* @__PURE__ */ React.createElement("div", { style: {
    position: "fixed",
    top: 0,
    right: 0,
    bottom: 0,
    width: 520,
    background: T.bg2,
    borderLeft: `1px solid ${T.border}`,
    zIndex: 300,
    overflowY: "auto",
    boxShadow: "-30px 0 80px rgba(0,0,0,0.6)",
    animation: "slideInRight 0.2s ease"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "18px 28px",
    borderBottom: `1px solid ${T.border}`,
    position: "sticky",
    top: 0,
    background: T.bg2,
    zIndex: 1
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.15em", marginBottom: 4 } }, type.toUpperCase(), " DETAIL"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 14, color: T.accent, fontWeight: 600 } }, type === "pipeline" ? data.id : type === "znode" ? data.id : data.name)), /* @__PURE__ */ React.createElement(
    "button",
    {
      onClick: onClose,
      style: {
        background: T.card,
        border: `1px solid ${T.border}`,
        color: T.textMid,
        width: 32,
        height: 32,
        cursor: "pointer",
        fontFamily: "var(--mono)",
        fontSize: 14,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        transition: "border-color 0.2s"
      },
      onMouseEnter: (e) => e.target.style.borderColor = T.accent + "44",
      onMouseLeave: (e) => e.target.style.borderColor = T.border
    },
    "\u2715"
  )), /* @__PURE__ */ React.createElement("div", { style: { padding: "20px 28px" } }, /* @__PURE__ */ React.createElement("div", { style: {
    background: T.card,
    border: `1px solid ${T.border}`,
    padding: "14px 18px",
    marginBottom: 24,
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between"
  } }, /* @__PURE__ */ React.createElement(Status, { status: type === "pipeline" ? data.status : type === "znode" ? data.status : data.status, size: "lg" }), type === "pipeline" && /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, color: T.textDim } }, data.type)), type === "pipeline" && /* @__PURE__ */ React.createElement(React.Fragment, null, field("AGENT", data.agent, true), field("AMOUNT", `${data.amount} ${data.currency}`), field("FROM", data.from), field("TO", data.to), field("ZNODE", data.znode, true), field("BLOCK HEIGHT", data.blockHeight.toLocaleString()), field("FEE", `${data.fee} SOL`), field("ZK PROOF", data.zkProof), field("COMPRESSED STATE", data.compressedState), field("TIMESTAMP", new Date(data.timestamp).toLocaleString()), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, letterSpacing: "0.15em", margin: "28px 0 14px" } }, "PIPELINE EXECUTION"), /* @__PURE__ */ React.createElement("div", { style: { position: "relative", paddingLeft: 20 } }, /* @__PURE__ */ React.createElement("div", { style: { position: "absolute", left: 3, top: 4, bottom: 4, width: 1, background: T.border } }), data.steps.map((step, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { display: "flex", alignItems: "center", gap: 14, padding: "10px 0", position: "relative" } }, /* @__PURE__ */ React.createElement("div", { style: {
    width: 8,
    height: 8,
    borderRadius: "50%",
    flexShrink: 0,
    background: step.status === "done" ? T.green : T.yellow,
    boxShadow: `0 0 8px ${step.status === "done" ? T.green : T.yellow}44`,
    position: "absolute",
    left: -20
  } }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11, color: T.text } }, step.label), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: T.textDim, marginLeft: "auto" } }, step.status === "done" ? "\u2713 DONE" : "\u29D7 PENDING"))))), type === "znode" && /* @__PURE__ */ React.createElement(React.Fragment, null, field("REGION", data.region), field("PEERS", data.peers), field("LATENCY", `${data.latency}ms`), field("UPTIME", `${(data.uptime * 100).toFixed(2)}%`), field("PIPELINES", data.pipelines.toLocaleString()), field("STAKE", `${Number(data.stake).toLocaleString()} SOL`), field("VERSION", data.version)), type === "agent" && /* @__PURE__ */ React.createElement(React.Fragment, null, field("ADDRESS", data.address), field("ZK IDENTITY", data.zkIdentity), field("PIPELINES", data.pipelines.toLocaleString()), field("VOLUME", `$${Number(data.volume).toLocaleString()}`), field("GOVERNANCE", data.governanceLevel), field("LAST ACTIVE", timeAgo(data.lastActive) + " ago")))));
}
function LiveFeed2() {
  const [events, setEvents] = React.useState([]);
  React.useEffect(() => {
    let cancelled = false;
    function add() {
      if (cancelled) return;
      const types = ["PIPELINE_COMPLETE", "ZK_VERIFIED", "AGENT_AUTH", "SETTLEMENT", "SHIELDING", "STATE_COMPRESSED", "ZNODE_SYNC"];
      const agents = ["CFO_ALPHA", "CFO_BETA", "TREASURY_01", "YIELD_HUNTER", "RISK_MGMT", "LIQUIDITY"];
      const colors = [T.green, T.cyan, T.accent, T.green, T.yellow, T.blue, T.accent];
      const idx = Math.floor(Math.random() * types.length);
      setEvents((prev) => [{
        id: Math.random().toString(36).slice(2, 8),
        type: types[idx],
        agent: agents[Math.floor(Math.random() * agents.length)],
        color: colors[idx],
        ts: Date.now()
      }, ...prev].slice(0, 30));
      timerId = setTimeout(add, 1200 + Math.random() * 2500);
    }
    let timerId = setTimeout(add, 500);
    return () => {
      cancelled = true;
      clearTimeout(timerId);
    };
  }, []);
  return /* @__PURE__ */ React.createElement("div", { style: { border: `1px solid ${T.border}`, background: T.bg2, flex: 1, display: "flex", flexDirection: "column", minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    padding: "10px 16px",
    borderBottom: `1px solid ${T.border}`,
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: T.textDim,
    letterSpacing: "0.12em",
    flexShrink: 0
  } }, /* @__PURE__ */ React.createElement("span", { style: { width: 6, height: 6, borderRadius: "50%", background: T.green, animation: "livePulse 2s ease infinite" } }), "LIVE ACTIVITY"), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, events.map((e) => /* @__PURE__ */ React.createElement("div", { key: e.id, style: {
    display: "flex",
    gap: 8,
    padding: "7px 16px",
    borderBottom: `1px solid ${T.border}`,
    fontFamily: "var(--mono)",
    fontSize: 10,
    animation: "fadeInLine 0.25s ease"
  } }, /* @__PURE__ */ React.createElement("span", { style: { color: T.textDim, flexShrink: 0, width: 55 } }, new Date(e.ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })), /* @__PURE__ */ React.createElement("span", { style: { color: e.color, flex: 1 } }, e.type), /* @__PURE__ */ React.createElement("span", { style: { color: T.textDim } }, e.agent)))));
}
Object.assign(window, { MeshCanvas, PipelinesView, ZnodesView, AgentsView, DetailSlide, LiveFeed2 });
