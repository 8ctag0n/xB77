function AgentsView({ onNavigate }) {
  const [selected, setSelected] = React.useState(null);
  const agents = [
    {
      id: "ag_swarm_lead_0x9c4f",
      name: "cfo-alpha",
      type: "SWARM LEAD",
      status: "online",
      risk: "MODERATE",
      governance: "AUTONOMOUS",
      humanOverride: "$10k",
      txns: 18,
      pnl: "+$412.30",
      balance: "$8,240",
      currencies: ["USDC", "SOL", "EURC"],
      pipeline: "pipe_sw_001",
      uptime: "99.7%",
      color: D.accent,
      workers: 4,
      lastAction: "Swap 240 USDC \u2192 SOL (2m ago)"
    },
    {
      id: "ag_worker_01_0x1a2b",
      name: "ag_worker_01",
      type: "TREASURY",
      status: "online",
      risk: "LOW",
      governance: "LEAD-CONTROLLED",
      txns: 12,
      pnl: "+$201.50",
      balance: "$4,100",
      currencies: ["USDC"],
      pipeline: "pipe_sw_001",
      uptime: "99.9%",
      color: D.green,
      lastAction: "Rebalance complete (8m ago)"
    },
    {
      id: "ag_worker_02_0x3c4d",
      name: "ag_worker_02",
      type: "TRADING",
      status: "online",
      risk: "MODERATE",
      governance: "LEAD-CONTROLLED",
      txns: 9,
      pnl: "+$87.20",
      balance: "$2,400",
      currencies: ["USDC", "SOL"],
      pipeline: "pipe_lp_002",
      uptime: "98.2%",
      color: D.cyan,
      lastAction: "Opened position 500 USDC (15m ago)"
    },
    {
      id: "ag_worker_03_0x5e6f",
      name: "ag_worker_03",
      type: "PAYMENTS",
      status: "online",
      risk: "LOW",
      governance: "LEAD-CONTROLLED",
      txns: 6,
      pnl: "-$12.00",
      balance: "$1,850",
      currencies: ["USDC", "EURC"],
      pipeline: "pipe_hy_003",
      uptime: "99.5%",
      color: D.purple,
      lastAction: "Payment to Caf\xE9 Sovereign (1h ago)"
    },
    {
      id: "ag_worker_04_0x7g8h",
      name: "ag_worker_04",
      type: "RECON",
      status: "idle",
      risk: "NONE",
      governance: "LEAD-CONTROLLED",
      txns: 2,
      pnl: "$0.00",
      balance: "$0",
      currencies: [],
      pipeline: "none",
      uptime: "97.1%",
      color: D.amber,
      lastAction: "Scanned 4 merchants (30m ago)"
    }
  ];
  const sel = agents.find((a) => a.id === selected);
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { width: 360, borderRight: `1px solid ${D.border}`, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 20px", borderBottom: `1px solid ${D.border}`, display: "flex", alignItems: "center", justifyContent: "space-between" } }, /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Agents"), /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true }, "+ NEW AGENT")), /* @__PURE__ */ React.createElement("div", { style: { padding: "12px 20px", borderBottom: `1px solid ${D.border}`, background: D.bg2 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8 } }, /* @__PURE__ */ React.createElement("span", { style: { fontSize: 14, color: D.accent } }, "\u2B21"), /* @__PURE__ */ React.createElement(DM, { size: 9, color: D.accent }, "SWARM sw_0x9c4f"), /* @__PURE__ */ React.createElement(Badge, null, "5 AGENTS")), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: D.dim, marginTop: 6 } }, "Inter-agent comms: ENCRYPTED \u2014 All online")), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, agents.map((ag) => /* @__PURE__ */ React.createElement("div", { key: ag.id, onClick: () => setSelected(ag.id), style: {
    padding: "14px 20px",
    borderBottom: `1px solid ${D.border}`,
    background: selected === ag.id ? D.bg3 : "transparent",
    borderLeft: `2px solid ${selected === ag.id ? ag.color : "transparent"}`,
    cursor: "pointer",
    transition: "all 0.28s ease"
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8, marginBottom: 6 } }, /* @__PURE__ */ React.createElement(Dot, { color: ag.status === "online" ? D.green : D.amber, pulse: ag.status === "online" }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 12, fontWeight: 600, color: D.text } }, ag.name), /* @__PURE__ */ React.createElement(Badge, { color: ag.color, bg: `${ag.color}18` }, ag.type)), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 16 } }, /* @__PURE__ */ React.createElement(DM, { size: 8 }, ag.txns, " txns"), /* @__PURE__ */ React.createElement(DM, { size: 8, color: ag.pnl.startsWith("+") ? D.green : ag.pnl.startsWith("-") ? D.red : D.dim }, ag.pnl), /* @__PURE__ */ React.createElement(DM, { size: 8 }, ag.balance)))))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, !sel ? /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "center", height: "100%", color: D.faint } }, /* @__PURE__ */ React.createElement("div", { style: { textAlign: "center" } }, /* @__PURE__ */ React.createElement("div", { style: { fontSize: 40, marginBottom: 12 } }, "\u2B21"), /* @__PURE__ */ React.createElement(DM, { size: 10 }, "Select an agent to view details"))) : /* @__PURE__ */ React.createElement("div", { style: { padding: 24 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 24 } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 10, marginBottom: 8 } }, /* @__PURE__ */ React.createElement(Dot, { color: sel.status === "online" ? D.green : D.amber, pulse: sel.status === "online" }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 18, fontWeight: 700, color: D.text } }, sel.name), /* @__PURE__ */ React.createElement(Badge, { color: sel.color, bg: `${sel.color}18` }, sel.type)), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.dim }, sel.id)), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 6 } }, /* @__PURE__ */ React.createElement(DBtn, { small: true }, "PAUSE"), /* @__PURE__ */ React.createElement(DBtn, { small: true }, "EDIT RULES"), /* @__PURE__ */ React.createElement(DBtn, { small: true, danger: true }, "KILL"))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10, marginBottom: 24 } }, /* @__PURE__ */ React.createElement(StatBox, { label: "BALANCE", value: sel.balance }), /* @__PURE__ */ React.createElement(StatBox, { label: "PNL TODAY", value: sel.pnl, color: sel.pnl.startsWith("+") ? D.green : D.red }), /* @__PURE__ */ React.createElement(StatBox, { label: "TXNS TODAY", value: String(sel.txns) }), /* @__PURE__ */ React.createElement(StatBox, { label: "UPTIME", value: sel.uptime, color: D.green })), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 24 } }, /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 18 } }, /* @__PURE__ */ React.createElement(DM, { size: 8, color: sel.color, style: { marginBottom: 12, display: "block" } }, "CONFIGURATION"), [
    { k: "RISK", v: sel.risk },
    { k: "GOVERNANCE", v: sel.governance },
    { k: "HUMAN OVERRIDE", v: sel.humanOverride || "N/A" },
    { k: "PIPELINE", v: sel.pipeline },
    { k: "CURRENCIES", v: sel.currencies.join(", ") || "None" }
  ].map((r, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    display: "flex",
    justifyContent: "space-between",
    padding: "8px 10px",
    margin: "0 -10px",
    background: i % 2 === 1 ? D.bg3 : "transparent",
    borderBottom: `1px solid ${D.border}`
  } }, /* @__PURE__ */ React.createElement(DM, { size: 8 }, r.k), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.text } }, r.v)))), /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 18 } }, /* @__PURE__ */ React.createElement(DM, { size: 8, color: sel.color, style: { marginBottom: 12, display: "block" } }, "RECENT ACTIONS"), [
    sel.lastAction,
    "ZK-receipt generated (45m ago)",
    "Risk check passed (1h ago)",
    "Neural key auth verified (2h ago)",
    "Pipeline heartbeat OK (2h ago)"
  ].map((act, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    padding: "8px 10px",
    margin: "0 -10px",
    background: i % 2 === 1 ? D.bg3 : "transparent",
    borderBottom: `1px solid ${D.border}`,
    fontFamily: "var(--sans)",
    fontSize: 11,
    color: i === 0 ? D.text : D.dim,
    lineHeight: 1.5
  } }, act)))), /* @__PURE__ */ React.createElement("div", { style: { background: D.bg, border: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 16px", borderBottom: `1px solid ${D.border}`, display: "flex", alignItems: "center", gap: 8 } }, /* @__PURE__ */ React.createElement(Dot, { color: D.green, pulse: true }), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.text }, "AGENT LOG"), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint, style: { marginLeft: "auto" } }, "LIVE")), /* @__PURE__ */ React.createElement("div", { style: {
    padding: "12px 16px",
    height: 160,
    overflowY: "auto",
    fontFamily: "var(--mono)",
    fontSize: 11,
    lineHeight: 1.7
  } }, [
    { c: D.dim, t: `[${(/* @__PURE__ */ new Date()).toLocaleTimeString()}] heartbeat OK` },
    { c: D.accent, t: `[${new Date(Date.now() - 12e4).toLocaleTimeString()}] ${sel.lastAction.split("(")[0].trim()}` },
    { c: D.dim, t: `[${new Date(Date.now() - 3e5).toLocaleTimeString()}] risk_check PASS` },
    { c: D.green, t: `[${new Date(Date.now() - 6e5).toLocaleTimeString()}] zk_receipt compressed: zk_rcpt_a3f1` },
    { c: D.dim, t: `[${new Date(Date.now() - 9e5).toLocaleTimeString()}] neural_key_auth verified` },
    { c: D.accent, t: `[${new Date(Date.now() - 12e5).toLocaleTimeString()}] pipeline connected: ${sel.pipeline}` },
    { c: D.dim, t: `[${new Date(Date.now() - 15e5).toLocaleTimeString()}] agent initialized` }
  ].map((l, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { color: l.c } }, l.t)))))));
}
function AgentsTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    flexDirection: "column",
    height: "min(80vh, 820px)",
    minHeight: 520,
    border: "1px solid var(--border-soft)",
    background: "var(--bg)",
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement(AgentsView, null));
}
Object.assign(window, { AgentsView, AgentsTab });
