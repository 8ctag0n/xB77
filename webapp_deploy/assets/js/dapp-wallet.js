const _WALLET_SEED_BALANCES = [
  { currency: "USDC", amount: "\u2014", usd: "\u2014", change: "", pct: "", color: D.accent, rawAmount: 0 },
  { currency: "SOL", amount: "\u2014", usd: "\u2014", change: "", pct: "", color: D.purple, rawAmount: 0 },
  { currency: "EURC", amount: "\u2014", usd: "\u2014", change: "", pct: "", color: D.cyan, rawAmount: 0 }
];
const _WALLET_ALLOC_PLACEHOLDER = [
  { agent: "cfo-alpha", amount: "\u2014", pct: "40%", color: D.accent },
  { agent: "ag_worker_01", amount: "\u2014", pct: "20%", color: D.green },
  { agent: "ag_worker_02", amount: "\u2014", pct: "10%", color: D.cyan },
  { agent: "ag_worker_03", amount: "\u2014", pct: "8%", color: D.purple },
  { agent: "Unallocated", amount: "\u2014", pct: "22%", color: D.faint }
];
function WalletView() {
  const [credits, setCredits] = React.useState(0);
  const [tier, setTier] = React.useState("unauth");
  const [claiming, setClaiming] = React.useState(false);
  const [claimError, setClaimError] = React.useState(null);
  const [creditsPulse, setCreditsPulse] = React.useState(false);
  const [balances, setBalances] = React.useState(_WALLET_SEED_BALANCES);
  const [recentTx, setRecentTx] = React.useState([]);
  const [source, setSource] = React.useState("idle");
  const [agentId, setAgentId] = React.useState(() => window.XB77Actions?.keystore.agentId || null);
  React.useEffect(() => {
    const onConn = () => setAgentId(window.XB77Actions?.keystore.agentId || null);
    window.addEventListener("xb77:connected", onConn);
    return () => window.removeEventListener("xb77:connected", onConn);
  }, []);
  React.useEffect(() => {
    if (!agentId || !window.DataSource) return;
    let cancelled = false;
    async function load() {
      const [b, t] = await Promise.all([
        window.DataSource.walletBalances(agentId),
        window.DataSource.walletTransactions(agentId, 12)
      ]);
      if (cancelled) return;
      if (b && Array.isArray(b.balances) && b.balances.length) setBalances(b.balances);
      if (typeof b?.credits === "number") setCredits(b.credits);
      if (b?.tier) setTier(b.tier);
      if (t && Array.isArray(t.transactions)) setRecentTx(t.transactions);
      setSource(b?._source || "idle");
    }
    load();
    const id = setInterval(load, 1e4);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, [agentId]);
  async function handleClaim() {
    if (claiming) return;
    setClaiming(true);
    setClaimError(null);
    const proof = "proof-stub-" + Date.now().toString(36);
    try {
      const data = await window.XB77Actions.claimCredits(proof);
      setCredits(data.credits_after ?? credits);
      if (data.new_tier) setTier(data.new_tier);
      setCreditsPulse(true);
      setTimeout(() => setCreditsPulse(false), 900);
    } catch (e) {
      setClaimError(e.message || "claim failed");
    } finally {
      setClaiming(false);
    }
  }
  const allocations = _WALLET_ALLOC_PLACEHOLDER;
  const totalUsd = balances.reduce((acc, b) => acc + (Number(b.rawAmount) || 0), 0);
  const totalLabel = totalUsd > 0 ? "$" + totalUsd.toLocaleString(void 0, { maximumFractionDigits: 2 }) : "$ \u2014";
  return /* @__PURE__ */ React.createElement("div", { style: { padding: 24, overflowY: "auto", flex: 1 } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    gap: 14,
    marginBottom: 12,
    padding: "10px 16px",
    background: D.bg2,
    border: `1px solid ${D.border}`
  } }, /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.accent }, "// CREDITS"), /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    fontSize: 14,
    fontWeight: 600,
    color: creditsPulse ? D.green : D.text,
    transition: "color .6s ease, transform .25s ease",
    transform: creditsPulse ? "scale(1.08)" : "scale(1)",
    transformOrigin: "left"
  } }, credits.toLocaleString()), /* @__PURE__ */ React.createElement(DM, { size: 8 }, "tier"), /* @__PURE__ */ React.createElement(
    Badge,
    {
      color: tier === "unauth" ? D.dim : tier === "free" ? D.cyan : tier === "paid" ? D.green : D.accent,
      bg: tier === "unauth" ? `${D.dim}18` : tier === "free" ? `${D.cyan}18` : tier === "paid" ? `${D.green}18` : `${D.accent}18`
    },
    tier
  ), claimError && /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: D.red, marginLeft: 8 } }, "claim: ", claimError), /* @__PURE__ */ React.createElement("span", { style: { flex: 1 } }), /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true, onClick: handleClaim, disabled: claiming }, claiming ? "\u2026CLAIMING" : "CLAIM CREDITS")), /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 24, padding: "28px 32px", background: D.bg2, border: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8 } }, /* @__PURE__ */ React.createElement(DM, { size: 9 }, "TOTAL TREASURY"), source !== "idle" && /* @__PURE__ */ React.createElement(
    Badge,
    {
      color: source === "live" ? D.green : source === "cached" ? D.amber : D.dim,
      bg: source === "live" ? `${D.green}18` : source === "cached" ? `${D.amber}18` : `${D.dim}18`
    },
    source
  )), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "baseline", gap: 16, marginTop: 10 } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--serif)", fontSize: 48, fontWeight: 400, color: D.text, fontStyle: "italic" } }, totalLabel), !agentId && /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint } }, "connect an agent to load")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 6, marginTop: 16 } }, /* @__PURE__ */ React.createElement(DBtn, { small: true, primary: true }, "DEPOSIT"), /* @__PURE__ */ React.createElement(DBtn, { small: true }, "WITHDRAW"), /* @__PURE__ */ React.createElement(DBtn, { small: true }, "ALLOCATE"))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 24 } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(SectionHead, { title: "Balances" }), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 8 } }, balances.map((b, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    display: "flex",
    alignItems: "center",
    gap: 14,
    padding: "14px 18px",
    background: D.bg2,
    border: `1px solid ${D.border}`
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    width: 36,
    height: 36,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: `${b.color}18`,
    border: `1px solid ${b.color}30`,
    fontFamily: "var(--mono)",
    fontSize: 10,
    fontWeight: 700,
    color: b.color
  } }, b.currency.slice(0, 2)), /* @__PURE__ */ React.createElement("div", { style: { flex: 1 } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, fontWeight: 600, color: D.text } }, b.currency), /* @__PURE__ */ React.createElement(DM, { size: 8 }, b.amount)), /* @__PURE__ */ React.createElement("div", { style: { textAlign: "right" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: D.text } }, b.usd), b.change && b.pct && /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: String(b.change).startsWith("+") ? D.green : D.red } }, b.change, " (", b.pct, ")"), b.chain && !b.change && /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: D.faint } }, "on ", b.chain)))))), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(SectionHead, { title: "Allocation" }), /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 18 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", height: 8, marginBottom: 18, gap: 2 } }, allocations.map((a, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    flex: parseInt(a.pct),
    background: a.color,
    opacity: a.agent === "Unallocated" ? 0.2 : 0.7
  } }))), allocations.map((a, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    display: "flex",
    alignItems: "center",
    gap: 10,
    padding: "8px 0",
    borderBottom: i < allocations.length - 1 ? `1px solid ${D.border}` : "none"
  } }, /* @__PURE__ */ React.createElement("div", { style: { width: 8, height: 8, background: a.color, opacity: a.agent === "Unallocated" ? 0.3 : 1 } }), /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: a.agent === "Unallocated" ? D.dim : D.text,
    flex: 1
  } }, a.agent), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.text } }, a.amount), /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, a.pct)))))), /* @__PURE__ */ React.createElement(SectionHead, { title: "Recent Transactions" }), /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "60px 1fr 100px 80px", padding: "0 16px", borderBottom: `1px solid ${D.border}`, background: D.bg3 } }, ["TIME", "DESCRIPTION", "AMOUNT", "TYPE"].map((h) => /* @__PURE__ */ React.createElement("div", { key: h, style: { padding: "8px 0" } }, /* @__PURE__ */ React.createElement(DM, { size: 7 }, h)))), recentTx.length === 0 && /* @__PURE__ */ React.createElement("div", { style: { padding: "20px 16px", textAlign: "center", fontFamily: "var(--mono)", fontSize: 10, color: D.faint } }, agentId ? "no transactions yet" : "connect an agent to load transactions"), recentTx.map((tx, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        display: "grid",
        gridTemplateColumns: "60px 1fr 100px 80px",
        padding: "0 16px",
        borderBottom: i < recentTx.length - 1 ? `1px solid ${D.border}` : "none",
        background: i % 2 === 1 ? D.bg3 : "transparent",
        transition: "background 0.28s ease"
      },
      onMouseEnter: (e) => e.currentTarget.style.background = D.bg4,
      onMouseLeave: (e) => e.currentTarget.style.background = i % 2 === 1 ? D.bg3 : "transparent"
    },
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 11, color: D.faint } }, tx.time),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--sans)", fontSize: 12, color: D.text } }, tx.desc),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0", fontFamily: "var(--mono)", fontSize: 11, color: tx.amount.startsWith("+") ? D.green : D.text } }, tx.amount),
    /* @__PURE__ */ React.createElement("div", { style: { padding: "10px 0" } }, /* @__PURE__ */ React.createElement(
      Badge,
      {
        color: tx.type === "IN" ? D.green : tx.type === "SWAP" ? D.cyan : D.dim,
        bg: tx.type === "IN" ? `${D.green}18` : tx.type === "SWAP" ? `${D.cyan}18` : `${D.dim}18`
      },
      tx.type
    ))
  ))));
}
function WalletTab() {
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    flexDirection: "column",
    minHeight: 520,
    border: "1px solid var(--border-soft)",
    background: "var(--bg)"
  } }, /* @__PURE__ */ React.createElement(WalletView, null));
}
Object.assign(window, { WalletView, WalletTab });
