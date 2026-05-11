const PIPELINES_SEED = [
  {
    id: "pipe_sw_001",
    route: "xB77 ZK Engine",
    status: "ACTIVE",
    agent: "cfo-alpha",
    txns: 31,
    volume: "$3,240",
    privacy: "MAX",
    receipts: "ZK-COMPRESSED",
    created: "2h ago",
    lastTx: "2m ago",
    color: D.accent
  },
  {
    id: "pipe_lp_002",
    route: "xB77 ZK Engine",
    status: "ACTIVE",
    agent: "ag_worker_02",
    txns: 12,
    volume: "$1,280",
    privacy: "HIGH",
    receipts: "ZK-COMPRESSED",
    created: "1h ago",
    lastTx: "15m ago",
    color: D.cyan
  },
  {
    id: "pipe_hy_003",
    route: "Hybrid",
    status: "PAUSED",
    agent: "ag_worker_03",
    txns: 4,
    volume: "$600",
    privacy: "MODERATE",
    receipts: "STANDARD",
    created: "45m ago",
    lastTx: "30m ago",
    color: D.amber
  }
];
const TXLOG_SEED = [
  { time: "14:23", from: "cfo-alpha", to: "Caf\xE9 Sovereign", amount: "$47.80", status: "SHIELDED", receipt: "zk_rcpt_88f1" },
  { time: "14:18", from: "cfo-alpha", to: "Pool: USDC/SOL", amount: "$240.00", status: "SHIELDED", receipt: "zk_rcpt_87a2" },
  { time: "14:12", from: "ag_worker_01", to: "Yield Vault", amount: "$500.00", status: "SHIELDED", receipt: "zk_rcpt_86c3" },
  { time: "14:05", from: "cfo-alpha", to: "Privacy Pool", amount: "$1,200.00", status: "SHIELDED", receipt: "zk_rcpt_85d4" },
  { time: "13:51", from: "ag_worker_03", to: "Caf\xE9 Sovereign", amount: "$23.90", status: "SHIELDED", receipt: "zk_rcpt_84e5" },
  { time: "13:40", from: "ag_worker_02", to: "DEX: SOL/USDC", amount: "$380.00", status: "SHIELDED", receipt: "zk_rcpt_83f6" }
];
function hhmm(d = /* @__PURE__ */ new Date()) {
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
function PipelinesView() {
  const [selected, setSelected] = React.useState(null);
  const [pipelines] = React.useState(PIPELINES_SEED);
  const [txLog, setTxLog] = React.useState(TXLOG_SEED);
  const [submitting, setSubmitting] = React.useState(false);
  const [submitError, setSubmitError] = React.useState(null);
  const sel = pipelines.find((p) => p.id === selected);
  async function handleNewOrder() {
    if (submitting) return;
    setSubmitting(true);
    setSubmitError(null);
    const idem = `ord-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    try {
      const data = await window.XB77Actions.submitOrder({
        side: "buy",
        chain: "solana",
        symbol: "USDC",
        amount: 100,
        price: 1e4,
        idempotency_key: idem
      });
      setTxLog((prev) => [{
        time: hhmm(),
        from: sel?.agent || "cfo-alpha",
        to: data.order_id ? `Order ${data.order_id}` : "Pending settlement",
        amount: "$100.00",
        status: data.status === "accepted" ? "SHIELDED" : (data.status || "PENDING").toUpperCase(),
        receipt: data.anchor_tx_hint ? data.anchor_tx_hint.slice(0, 12) : `pending_${idem.slice(-6)}`
      }, ...prev]);
    } catch (e) {
      setSubmitError(e.message || "submit failed");
    } finally {
      setSubmitting(false);
    }
  }
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0 } }, /* @__PURE__ */ React.createElement("div", { style: { width: 320, borderRight: `1px solid ${D.border}`, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement("div", { style: { padding: "16px 20px", borderBottom: `1px solid ${D.border}`, display: "flex", alignItems: "center", justifyContent: "space-between" } }, /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Pipelines"), /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true, onClick: handleNewOrder, disabled: submitting }, submitting ? "\u2026SUBMITTING" : "+ NEW")), submitError && /* @__PURE__ */ React.createElement("div", { style: { padding: "6px 20px", background: `${D.red}18`, borderBottom: `1px solid ${D.border}`, fontFamily: "var(--mono)", fontSize: 10, color: D.red } }, "submit_order: ", submitError), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, pipelines.map((p) => /* @__PURE__ */ React.createElement("div", { key: p.id, onClick: () => setSelected(p.id), style: {
    padding: "16px 20px",
    borderBottom: `1px solid ${D.border}`,
    background: selected === p.id ? D.bg3 : "transparent",
    borderLeft: `2px solid ${selected === p.id ? p.color : "transparent"}`,
    cursor: "pointer",
    transition: "all 0.28s ease"
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8, marginBottom: 8 } }, /* @__PURE__ */ React.createElement(Dot, { color: p.status === "ACTIVE" ? D.green : D.amber, pulse: p.status === "ACTIVE" }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 12, fontWeight: 600, color: D.text } }, p.id)), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 8, flexWrap: "wrap", marginBottom: 6 } }, /* @__PURE__ */ React.createElement(Badge, { color: p.color, bg: `${p.color}18` }, p.route), /* @__PURE__ */ React.createElement(Badge, { color: p.status === "ACTIVE" ? D.green : D.amber, bg: p.status === "ACTIVE" ? `${D.green}18` : `${D.amber}18` }, p.status)), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 16 } }, /* @__PURE__ */ React.createElement(DM, { size: 8 }, p.txns, " txns"), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.text }, p.volume), /* @__PURE__ */ React.createElement(DM, { size: 8 }, "via ", p.agent)))))), /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto" } }, !sel ? /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "center", height: "100%" } }, /* @__PURE__ */ React.createElement("div", { style: { textAlign: "center", color: D.faint } }, /* @__PURE__ */ React.createElement("div", { style: { fontSize: 32, marginBottom: 12 } }, "\u{1F512}"), /* @__PURE__ */ React.createElement(DM, { size: 10 }, "Select a pipeline"))) : /* @__PURE__ */ React.createElement("div", { style: { padding: 24 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: 24 } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 10, marginBottom: 6 } }, /* @__PURE__ */ React.createElement(Dot, { color: sel.status === "ACTIVE" ? D.green : D.amber, pulse: sel.status === "ACTIVE" }), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 18, fontWeight: 700, color: D.text } }, sel.id), /* @__PURE__ */ React.createElement(Badge, { color: sel.color, bg: `${sel.color}18` }, sel.route)), /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Agent: ", sel.agent, " \u2014 Created ", sel.created)), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 6 } }, sel.status === "ACTIVE" ? /* @__PURE__ */ React.createElement(DBtn, { small: true }, "PAUSE") : /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true }, "RESUME"), /* @__PURE__ */ React.createElement(DBtn, { small: true }, "EDIT"), /* @__PURE__ */ React.createElement(DBtn, { small: true, danger: true }, "DELETE"))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 10, marginBottom: 24 } }, /* @__PURE__ */ React.createElement(StatBox, { label: "TRANSACTIONS", value: String(sel.txns) }), /* @__PURE__ */ React.createElement(StatBox, { label: "VOLUME", value: sel.volume, color: D.accent }), /* @__PURE__ */ React.createElement(StatBox, { label: "PRIVACY", value: sel.privacy, color: sel.privacy === "MAX" ? D.green : D.amber }), /* @__PURE__ */ React.createElement(StatBox, { label: "RECEIPTS", value: sel.receipts.replace("ZK-", ""), sub: "xB77 ZK Engine" })), /* @__PURE__ */ React.createElement(SectionHead, { title: "Transactions" }, /* @__PURE__ */ React.createElement(Dot, { color: D.green, pulse: true })), /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "60px 1fr 1fr 100px 90px 120px", borderBottom: `1px solid ${D.border}`, padding: "0 12px", background: D.bg3 } }, ["TIME", "FROM", "TO", "AMOUNT", "STATUS", "RECEIPT"].map((h) => /* @__PURE__ */ React.createElement("div", { key: h, style: { padding: "8px 0" } }, /* @__PURE__ */ React.createElement(DM, { size: 7 }, h)))), txLog.map((tx, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        display: "grid",
        gridTemplateColumns: "60px 1fr 1fr 100px 90px 120px",
        padding: "0 12px",
        borderBottom: i < txLog.length - 1 ? `1px solid ${D.border}` : "none",
        background: i % 2 === 1 ? D.bg3 : "transparent",
        transition: "background 0.28s ease"
      },
      onMouseEnter: (e) => e.currentTarget.style.background = D.bg4,
      onMouseLeave: (e) => e.currentTarget.style.background = i % 2 === 1 ? D.bg3 : "transparent"
    },
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 11, color: D.faint } }, tx.time),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 11, color: D.text } }, tx.from),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 11, color: D.dim } }, tx.to),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 11, color: D.accent } }, tx.amount),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0" } }, /* @__PURE__ */ React.createElement(Badge, { color: D.green, bg: `${D.green}18` }, tx.status)),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 9, color: D.faint } }, tx.receipt)
  ))))));
}
function PipelinesTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    flexDirection: "column",
    height: "min(80vh, 820px)",
    minHeight: 520,
    border: "1px solid var(--border-soft)",
    background: "var(--bg)",
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement(PipelinesView, null));
}
Object.assign(window, { PipelinesView, PipelinesTab });
