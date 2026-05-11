const NET_MAGENTA = "#e94da4";
function _netSourceColor(source) {
  if (source === "live") return D.accent;
  if (source === "cached") return NET_MAGENTA;
  return D.muted;
}
function _netSourceLabel(payload) {
  if (!payload) return "// \u2026";
  if (payload._source === "live") return "// LIVE";
  if (payload._source === "cached") {
    const s = Math.round((payload._ageMs || 0) / 1e3);
    return `// CACHED ${s}s`;
  }
  return "// SNAPSHOT";
}
function NetBigStat({ label, value, hint }) {
  return /* @__PURE__ */ React.createElement("div", { style: {
    flex: 1,
    minWidth: 180,
    padding: "24px 22px",
    background: D.bg2,
    border: `1px solid ${D.border}`
  } }, /* @__PURE__ */ React.createElement(DM, { size: 9 }, label), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--serif)",
    fontSize: 44,
    fontStyle: "italic",
    color: D.text,
    marginTop: 12,
    lineHeight: 1,
    letterSpacing: "-0.02em"
  } }, value), hint && /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: D.dim, marginTop: 10, letterSpacing: "0.1em" } }, hint));
}
function NetStatusPill({ payload }) {
  const color = _netSourceColor(payload?._source);
  const label = _netSourceLabel(payload);
  const blink = payload?._source === "cached";
  return /* @__PURE__ */ React.createElement("div", { style: {
    display: "inline-flex",
    alignItems: "center",
    gap: 8,
    padding: "6px 12px",
    border: `1px solid ${D.border}`,
    background: D.bg2
  } }, /* @__PURE__ */ React.createElement("span", { style: {
    width: 7,
    height: 7,
    borderRadius: "50%",
    background: color,
    flexShrink: 0,
    animation: blink ? "livePulse 1.4s ease infinite" : "none",
    boxShadow: payload?._source === "live" ? `0 0 8px ${color}` : "none"
  } }), /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    fontSize: 10,
    fontWeight: 600,
    letterSpacing: "0.14em",
    color
  } }, label));
}
function NetworkPulseSection() {
  const [pulse, setPulse] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    const off = window.DataSource.subscribe("networkPulse", setPulse, 3e3);
    return off;
  }, []);
  const fmt = (n) => typeof n === "number" ? n.toLocaleString("en-US") : "\u2014";
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, null, "Network Pulse"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "Live network state."))), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: pulse })), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexWrap: "wrap", gap: 12 } }, /* @__PURE__ */ React.createElement(NetBigStat, { label: "Slot", value: fmt(pulse?.slot), hint: "solana validator" }), /* @__PURE__ */ React.createElement(NetBigStat, { label: "Block Height", value: fmt(pulse?.blockHeight), hint: "finalized" }), /* @__PURE__ */ React.createElement(NetBigStat, { label: "Agents Online", value: fmt(pulse?.agentsOnline), hint: "autonomous CFO mesh" }), /* @__PURE__ */ React.createElement(NetBigStat, { label: "Proofs Verified 24h", value: fmt(pulse?.proofsVerified24h), hint: "zk-pipeline throughput" })));
}
const VERDICT_COLOR = {
  VALID: D.accent,
  INVALID: NET_MAGENTA,
  PENDING: D.cyan
};
function GhostAuditSection() {
  const [hash, setHash] = React.useState("");
  const [result, setResult] = React.useState(null);
  const [loading, setLoading] = React.useState(false);
  async function runAudit() {
    if (!hash.trim() || !window.DataSource) return;
    setLoading(true);
    try {
      const r = await window.DataSource.auditTx(hash.trim());
      setResult(r);
    } finally {
      setLoading(false);
    }
  }
  const verdictColor = result ? VERDICT_COLOR[result.verdict] || D.text : D.text;
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0" } }, /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 24 } }, /* @__PURE__ */ React.createElement(DM, null, "Ghost Audit Portal"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "Verify any transaction.")), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--sans)",
    fontSize: 13,
    color: D.dim,
    marginTop: 8,
    maxWidth: 560,
    lineHeight: 1.6
  } }, "Paste a transaction hash. The portal queries the zk verifier on-chain and returns the verdict, proof ID, and the agent that signed the pipeline.")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 0, marginBottom: 20, maxWidth: 720 } }, /* @__PURE__ */ React.createElement(
    "input",
    {
      type: "text",
      value: hash,
      onChange: (e) => setHash(e.target.value),
      onKeyDown: (e) => {
        if (e.key === "Enter") runAudit();
      },
      placeholder: "tx hash (e.g. 5K3sP9...)",
      style: {
        flex: 1,
        fontFamily: "var(--mono)",
        fontSize: 12,
        background: D.bg2,
        color: D.text,
        border: `1px solid ${D.border}`,
        borderRight: "none",
        padding: "14px 16px",
        outline: "none",
        letterSpacing: "0.04em"
      }
    }
  ), /* @__PURE__ */ React.createElement(
    "button",
    {
      onClick: runAudit,
      disabled: loading || !hash.trim(),
      style: {
        fontFamily: "var(--mono)",
        fontSize: 11,
        fontWeight: 600,
        letterSpacing: "0.18em",
        textTransform: "uppercase",
        background: loading ? D.bg3 : D.accent,
        color: loading ? D.dim : D.bg,
        border: `1px solid ${D.accent}`,
        padding: "0 28px",
        cursor: loading || !hash.trim() ? "not-allowed" : "pointer",
        transition: "all 0.15s"
      }
    },
    loading ? "auditing\u2026" : "audit"
  )), result && /* @__PURE__ */ React.createElement("div", { style: {
    padding: "24px 28px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    borderLeft: `3px solid ${verdictColor}`,
    maxWidth: 720
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 20 } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 22,
    fontWeight: 700,
    letterSpacing: "0.18em",
    color: verdictColor
  } }, result.verdict), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: result })), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: 18 } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Proof ID"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.text, marginTop: 6, wordBreak: "break-all" } }, result.proofId)), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Agent"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.accent, marginTop: 6 } }, result.agent)), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Chunks"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.text, marginTop: 6 } }, result.chunks)), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Timestamp"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.text, marginTop: 6 } }, result.timestamp ? new Date(result.timestamp).toISOString().replace("T", " ").slice(0, 19) : "\u2014"))), /* @__PURE__ */ React.createElement("div", { style: {
    marginTop: 20,
    paddingTop: 16,
    borderTop: `1px solid ${D.border}`,
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: D.dim,
    letterSpacing: "0.04em",
    wordBreak: "break-all"
  } }, "tx: ", result.txhash)));
}
function NetworkPage() {
  return /* @__PURE__ */ React.createElement("div", { style: { background: D.bg, minHeight: "100vh", color: D.text } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1200, margin: "0 auto", padding: "60px 32px 80px" } }, /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 32 } }, /* @__PURE__ */ React.createElement(DM, null, "// xB77 \xB7 Network"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 12 } }, /* @__PURE__ */ React.createElement(DS, { size: 48, italic: true }, "The mesh, observed.")), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--sans)",
    fontSize: 14,
    color: D.dim,
    maxWidth: 640,
    marginTop: 12,
    lineHeight: 1.6
  } }, "Real-time view of the xB77 zk-pipeline network. Slot, block height, agent fleet, and a public audit portal for any verified transaction.")), /* @__PURE__ */ React.createElement(NetworkPulseSection, null), /* @__PURE__ */ React.createElement(GhostAuditSection, null)));
}
window.NetworkPage = NetworkPage;
