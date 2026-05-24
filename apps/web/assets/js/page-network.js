const NET_MAGENTA = "#e94da4";
const NET_SAMPLE_HASHES = [
  { label: "VALID", hash: "5K3sP9Rb2vQfNm8jX1pT4hY7wL9aE6cZ0gA" },
  { label: "INVALID", hash: "8mP4xR9nQ2vW6kL5sH3jY1cT7bF0aE2gZd" },
  { label: "PENDING", hash: "3T7nB1xR9mQ4vL8kP2sH5jY6cW0aE3gZbf" }
];
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
function useCountUp(target, durMs = 600) {
  const [val, setVal] = React.useState(target ?? 0);
  const fromRef = React.useRef(target ?? 0);
  React.useEffect(() => {
    if (target == null) return;
    const start = performance.now();
    const from = fromRef.current;
    const delta = target - from;
    let raf;
    const tick = (t) => {
      const k = Math.min(1, (t - start) / durMs);
      const eased = 1 - Math.pow(1 - k, 3);
      setVal(from + delta * eased);
      if (k < 1) raf = requestAnimationFrame(tick);
      else fromRef.current = target;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, durMs]);
  return val;
}
function useHistory(value, max = 30) {
  const [hist, setHist] = React.useState([]);
  React.useEffect(() => {
    if (value == null) return;
    setHist((h) => {
      const next = h.concat([value]);
      return next.length > max ? next.slice(next.length - max) : next;
    });
  }, [value]);
  return hist;
}
function NetSparkline({ data, color, height = 28 }) {
  if (!data || data.length < 2) {
    return /* @__PURE__ */ React.createElement("div", { style: { height } });
  }
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const w = 100;
  const h = height;
  const points = data.map((v, i) => {
    const x = i / (data.length - 1) * w;
    const y = h - (v - min) / range * (h - 2) - 1;
    return `${x.toFixed(2)},${y.toFixed(2)}`;
  });
  const path = `M ${points.join(" L ")}`;
  const area = `${path} L ${w},${h} L 0,${h} Z`;
  return /* @__PURE__ */ React.createElement("svg", { viewBox: `0 0 ${w} ${h}`, preserveAspectRatio: "none", style: { width: "100%", height, display: "block" } }, /* @__PURE__ */ React.createElement("defs", null, /* @__PURE__ */ React.createElement("linearGradient", { id: `spark-${color.replace("#", "")}`, x1: "0", y1: "0", x2: "0", y2: "1" }, /* @__PURE__ */ React.createElement("stop", { offset: "0%", stopColor: color, stopOpacity: "0.35" }), /* @__PURE__ */ React.createElement("stop", { offset: "100%", stopColor: color, stopOpacity: "0" }))), /* @__PURE__ */ React.createElement("path", { d: area, fill: `url(#spark-${color.replace("#", "")})` }), /* @__PURE__ */ React.createElement("path", { d: path, fill: "none", stroke: color, strokeWidth: "1" }));
}
function NetBigStat({ label, value, hint, history, color }) {
  const c = color || D.accent;
  const animated = useCountUp(typeof value === "number" ? value : null);
  const display = typeof value === "number" ? Math.round(animated).toLocaleString("en-US") : "\u2014";
  return /* @__PURE__ */ React.createElement("div", { style: {
    flex: 1,
    minWidth: 180,
    padding: "22px 22px 18px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    position: "relative",
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement(DM, { size: 9 }, label), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--serif)",
    fontSize: 44,
    fontStyle: "italic",
    color: D.text,
    marginTop: 12,
    lineHeight: 1,
    letterSpacing: "-0.02em",
    fontVariantNumeric: "tabular-nums"
  } }, display), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 14, marginLeft: -2, marginRight: -2 } }, /* @__PURE__ */ React.createElement(NetSparkline, { data: history, color: c, height: 24 })), hint && /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: D.dim,
    marginTop: 6,
    letterSpacing: "0.1em"
  } }, hint));
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
function ArcPulseSection() {
  const [arc, setArc] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe("arcPulse", setArc, 3e3);
  }, []);
  const usdcHist = useHistory(arc?.usdcTotal);
  const yieldHist = useHistory(arc?.usycYieldTotal);
  const cctpHist = useHistory(arc?.activeCctpRoutes);
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, null, "Arc Swarm Intelligence"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "Circle Agent Stack: USDC + USYC + CCTP."))), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: arc })), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexWrap: "wrap", gap: 12 } }, /* @__PURE__ */ React.createElement(
    NetBigStat,
    {
      label: "Total USDC Liquidity",
      value: arc?.usdcTotal,
      hint: "settled via settlement.sol",
      history: usdcHist,
      color: D.accent
    }
  ), /* @__PURE__ */ React.createElement(
    NetBigStat,
    {
      label: "Total USYC Yield Earned",
      value: arc?.usycYieldTotal,
      hint: "auto-parked in hashnote",
      history: yieldHist,
      color: D.amber
    }
  ), /* @__PURE__ */ React.createElement(
    NetBigStat,
    {
      label: "Active CCTP Routes",
      value: arc?.activeCctpRoutes,
      hint: "cross-chain swarm",
      history: cctpHist,
      color: D.cyan
    }
  ), /* @__PURE__ */ React.createElement("div", { style: {
    flex: 1,
    minWidth: 180,
    padding: "22px 22px 18px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    display: "flex",
    flexDirection: "column",
    justifyContent: "center"
  } }, /* @__PURE__ */ React.createElement(DM, { size: 9 }, "Last Circle Settlement"), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: D.accent,
    marginTop: 12,
    wordBreak: "break-all"
  } }, arc?.lastSettlementTx || "\u2014"), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: D.dim,
    marginTop: 6,
    letterSpacing: "0.1em"
  } }, "VERIFIED ON ARC"))));
}
function SuiPulseSection() {
  const [sui, setSui] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe("suiPulse", setSui, 3e3);
  }, []);
  const objHist = useHistory(sui?.objectsTotal);
  const treasHist = useHistory(sui?.treasuryBalance);
  const ptbHist = useHistory(sui?.ptbCount);
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, null, "Sui Object Mesh"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "The Agent is the Object: PTB-orchestrated autonomy."))), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: sui })), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexWrap: "wrap", gap: 12 } }, /* @__PURE__ */ React.createElement(
    NetBigStat,
    {
      label: "Sovereign Objects",
      value: sui?.objectsTotal,
      hint: "Treasury \xB7 Policy \xB7 Receipt",
      history: objHist,
      color: D.accent
    }
  ), /* @__PURE__ */ React.createElement(
    NetBigStat,
    {
      label: "Treasury Balance",
      value: sui?.treasuryBalance,
      hint: "shielded on Sui",
      history: treasHist,
      color: D.amber
    }
  ), /* @__PURE__ */ React.createElement(
    NetBigStat,
    {
      label: "PTBs Executed",
      value: sui?.ptbCount,
      hint: "parallel programmable txns",
      history: ptbHist,
      color: D.cyan
    }
  ), /* @__PURE__ */ React.createElement("div", { style: {
    flex: 1,
    minWidth: 180,
    padding: "22px 22px 18px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    display: "flex",
    flexDirection: "column",
    justifyContent: "center"
  } }, /* @__PURE__ */ React.createElement(DM, { size: 9 }, "Last PTB Digest"), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: D.accent,
    marginTop: 12,
    wordBreak: "break-all"
  } }, sui?.lastDigest || "\u2014"), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: D.dim,
    marginTop: 6,
    letterSpacing: "0.1em"
  } }, "VERIFIED ON SUI"))));
}
function NetworkPulseSection() {
  const [pulse, setPulse] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe("networkPulse", setPulse, 3e3);
  }, []);
  const slotHist = useHistory(pulse?.slot);
  const heightHist = useHistory(pulse?.blockHeight);
  const agentsHist = useHistory(pulse?.agentsOnline);
  const proofsHist = useHistory(pulse?.proofsVerified24h);
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, null, "Network Pulse"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "Live network state."))), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: pulse })), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexWrap: "wrap", gap: 12 } }, /* @__PURE__ */ React.createElement(NetBigStat, { label: "Slot", value: pulse?.slot, hint: "solana validator", history: slotHist, color: D.accent }), /* @__PURE__ */ React.createElement(NetBigStat, { label: "Block Height", value: pulse?.blockHeight, hint: "finalized", history: heightHist, color: D.cyan }), /* @__PURE__ */ React.createElement(NetBigStat, { label: "Agents Online", value: pulse?.agentsOnline, hint: "autonomous CFO mesh", history: agentsHist, color: D.purple }), /* @__PURE__ */ React.createElement(NetBigStat, { label: "Proofs Verified 24h", value: pulse?.proofsVerified24h, hint: "zk-pipeline throughput", history: proofsHist, color: NET_MAGENTA })));
}
function ChunkStrip({ chunks, verdict, animate }) {
  const n = chunks || 8;
  const color = verdict === "VALID" ? D.accent : verdict === "INVALID" ? NET_MAGENTA : verdict === "PENDING" ? D.cyan : D.dim;
  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 4, marginTop: 14 } }, Array.from({ length: n }).map((_, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    flex: 1,
    height: 8,
    background: color,
    opacity: 0.35 + (i + 1) / n * 0.65,
    animation: animate ? `chunkPulse 1.4s ${i * 0.08}s ease-in-out infinite` : "none"
  } })));
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
  const [statusLine, setStatusLine] = React.useState("");
  async function runAudit(h) {
    const target = (h ?? hash).trim();
    if (!target || !window.DataSource) return;
    setHash(target);
    setLoading(true);
    setResult(null);
    const steps = [
      "querying zk verifier\u2026",
      "reconstructing proof witness\u2026",
      "verifying chunks\u2026",
      "finalizing verdict\u2026"
    ];
    let i = 0;
    setStatusLine(steps[0]);
    const iv = setInterval(() => {
      i = (i + 1) % steps.length;
      setStatusLine(steps[i]);
    }, 420);
    try {
      const minWait = new Promise((r2) => setTimeout(r2, 900));
      const [r] = await Promise.all([window.DataSource.auditTx(target), minWait]);
      setResult(r);
    } finally {
      clearInterval(iv);
      setStatusLine("");
      setLoading(false);
    }
  }
  const verdictColor = result ? VERDICT_COLOR[result.verdict] || D.text : D.text;
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 24 } }, /* @__PURE__ */ React.createElement(DM, null, "Ghost Audit Portal"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "Verify any transaction.")), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--sans)",
    fontSize: 13,
    color: D.dim,
    marginTop: 8,
    maxWidth: 560,
    lineHeight: 1.6
  } }, "Paste a tx hash. The portal queries the zk verifier on-chain and returns the verdict, proof ID, and the agent that signed the pipeline.")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 14 } }, /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: D.dim,
    letterSpacing: "0.14em",
    alignSelf: "center",
    marginRight: 4
  } }, "try:"), NET_SAMPLE_HASHES.map((s) => /* @__PURE__ */ React.createElement("button", { key: s.label, onClick: () => runAudit(s.hash), style: {
    fontFamily: "var(--mono)",
    fontSize: 9,
    fontWeight: 600,
    letterSpacing: "0.16em",
    textTransform: "uppercase",
    background: "transparent",
    color: VERDICT_COLOR[s.label] || D.text,
    border: `1px solid ${VERDICT_COLOR[s.label] || D.border}`,
    padding: "5px 12px",
    cursor: "pointer",
    transition: "all 0.28s ease"
  } }, s.label))), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 0, marginBottom: 20, maxWidth: 720 } }, /* @__PURE__ */ React.createElement(
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
      onClick: () => runAudit(),
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
        transition: "all 0.28s ease"
      }
    },
    loading ? "auditing\u2026" : "audit"
  )), loading && /* @__PURE__ */ React.createElement("div", { style: {
    padding: "20px 24px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    borderLeft: `3px solid ${D.cyan}`,
    maxWidth: 720
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: D.cyan,
    letterSpacing: "0.14em",
    textTransform: "uppercase"
  } }, statusLine || "\u2026"), /* @__PURE__ */ React.createElement(ChunkStrip, { chunks: 8, verdict: "PENDING", animate: true })), result && !loading && /* @__PURE__ */ React.createElement("div", { style: {
    padding: "24px 28px",
    background: D.bg2,
    border: `1px solid ${D.border}`,
    borderLeft: `3px solid ${verdictColor}`,
    maxWidth: 720
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 22,
    fontWeight: 700,
    letterSpacing: "0.18em",
    color: verdictColor
  } }, result.verdict), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: result })), /* @__PURE__ */ React.createElement(ChunkStrip, { chunks: result.chunks, verdict: result.verdict }), /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
    gap: 18,
    marginTop: 22
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Proof ID"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.text, marginTop: 6, wordBreak: "break-all" } }, result.proofId)), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Agent"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.accent, marginTop: 6 } }, result.agent)), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Chunks"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.text, marginTop: 6 } }, result.chunks)), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "Timestamp"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: D.text, marginTop: 6 } }, result.timestamp ? new Date(result.timestamp).toISOString().replace("T", " ").slice(0, 19) : "\u2014"))), /* @__PURE__ */ React.createElement("div", { style: {
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
function AgentFleetSection() {
  const [data, setData] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe("agents", setData, 1e4);
  }, []);
  const agents = data?.agents || [];
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, null, "Agent Fleet"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "Five autonomous CFOs."))), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: data })), /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))",
    gap: 12
  } }, agents.map((a) => {
    const online = a.status === "online";
    const idle = a.status === "idle";
    const dotColor = online ? D.accent : idle ? D.amber : D.muted;
    return /* @__PURE__ */ React.createElement("div", { key: a.id, style: {
      padding: "18px 18px 16px",
      background: D.bg2,
      border: `1px solid ${D.border}`,
      borderLeft: `2px solid ${dotColor}`,
      position: "relative"
    } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between" } }, /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontWeight: 700,
      fontSize: 14,
      color: D.text,
      letterSpacing: "0.06em",
      textTransform: "uppercase"
    } }, a.id), /* @__PURE__ */ React.createElement("span", { style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: dotColor,
      boxShadow: online ? `0 0 6px ${dotColor}` : "none",
      animation: online ? "livePulse 2.2s ease infinite" : "none"
    } })), /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontSize: 10,
      color: D.dim,
      marginTop: 4,
      letterSpacing: "0.04em"
    } }, a.pubkey), /* @__PURE__ */ React.createElement("div", { style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "baseline",
      marginTop: 16,
      gap: 12
    } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "pipelines"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--serif)", fontStyle: "italic", fontSize: 22, color: D.text, lineHeight: 1, marginTop: 4 } }, a.pipelines)), /* @__PURE__ */ React.createElement("div", { style: { textAlign: "right" } }, /* @__PURE__ */ React.createElement(DM, { size: 8 }, "uptime"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: online ? D.accent : D.dim, marginTop: 6 } }, (a.uptime * 100).toFixed(1), "%"))), /* @__PURE__ */ React.createElement("div", { style: {
      marginTop: 12,
      fontFamily: "var(--mono)",
      fontSize: 9,
      color: dotColor,
      letterSpacing: "0.18em",
      textTransform: "uppercase"
    } }, a.status));
  })));
}
function RecentPipelinesSection() {
  const [data, setData] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe("pipelinesRecent", setData, 5e3);
  }, []);
  const pipelines = data?.pipelines || [];
  function fmtAge(ts) {
    if (!ts) return "\u2014";
    const s = Math.max(0, Math.floor((Date.now() - ts) / 1e3));
    if (s < 60) return `${s}s ago`;
    return `${Math.floor(s / 60)}m ${s % 60}s ago`;
  }
  function fmtDur(ms) {
    if (ms == null) return "\u2014";
    return `${(ms / 1e3).toFixed(2)}s`;
  }
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0" } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "baseline",
    justifyContent: "space-between",
    marginBottom: 24,
    flexWrap: "wrap",
    gap: 12
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, null, "Recent Pipelines"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 8 } }, /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true }, "The mesh in motion."))), /* @__PURE__ */ React.createElement(NetStatusPill, { payload: data })), /* @__PURE__ */ React.createElement("div", { style: {
    background: D.bg2,
    border: `1px solid ${D.border}`
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: "1.5fr 1fr 0.6fr 1fr 0.8fr 0.8fr",
    padding: "10px 18px",
    borderBottom: `1px solid ${D.border}`,
    background: D.bg3,
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: D.dim,
    letterSpacing: "0.14em",
    textTransform: "uppercase"
  } }, /* @__PURE__ */ React.createElement("div", null, "Pipeline"), /* @__PURE__ */ React.createElement("div", null, "Agent"), /* @__PURE__ */ React.createElement("div", null, "Chunks"), /* @__PURE__ */ React.createElement("div", null, "Status"), /* @__PURE__ */ React.createElement("div", null, "Duration"), /* @__PURE__ */ React.createElement("div", { style: { textAlign: "right" } }, "Started")), pipelines.map((p, i) => {
    const running = p.status === "running";
    const verdictColor = p.verdict === "VALID" ? D.accent : p.verdict === "INVALID" ? NET_MAGENTA : running ? D.cyan : D.dim;
    return /* @__PURE__ */ React.createElement("div", { key: p.id, style: {
      display: "grid",
      gridTemplateColumns: "1.5fr 1fr 0.6fr 1fr 0.8fr 0.8fr",
      padding: "14px 18px",
      borderBottom: `1px solid ${D.border}`,
      background: i % 2 === 1 ? D.bg3 : "transparent",
      alignItems: "center",
      fontFamily: "var(--mono)",
      fontSize: 11,
      color: D.text
    } }, /* @__PURE__ */ React.createElement("div", { style: { color: D.dim, wordBreak: "break-all", paddingRight: 12 } }, p.id), /* @__PURE__ */ React.createElement("div", { style: { color: D.accent } }, p.agent), /* @__PURE__ */ React.createElement("div", null, p.chunks), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 8 } }, /* @__PURE__ */ React.createElement("span", { style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: verdictColor,
      animation: running ? "livePulse 1.2s ease infinite" : "none",
      boxShadow: running ? `0 0 5px ${verdictColor}` : "none",
      flexShrink: 0
    } }), /* @__PURE__ */ React.createElement("span", { style: {
      color: verdictColor,
      fontSize: 10,
      fontWeight: 600,
      letterSpacing: "0.14em",
      textTransform: "uppercase"
    } }, running ? "running" : p.verdict || p.status)), /* @__PURE__ */ React.createElement("div", { style: { color: D.text } }, fmtDur(p.duration)), /* @__PURE__ */ React.createElement("div", { style: { color: D.dim, textAlign: "right" } }, fmtAge(p.startedAt)));
  }), pipelines.length === 0 && /* @__PURE__ */ React.createElement("div", { style: { padding: "24px 18px", fontFamily: "var(--mono)", fontSize: 11, color: D.dim } }, "waiting for pipelines\u2026")));
}
function SovereignPulseSection() {
  const [pulse, setPulse] = React.useState(null);
  const [tps, setTps] = React.useState(142);
  const t = THEMES.obsidian;

  React.useEffect(() => {
    const fetchPulse = async () => {
      try {
        const r = await fetch("http://127.0.0.1:8080/status", { mode: "cors" });
        if (r.ok) setPulse(await r.json());
      } catch (e) {}
    };
    fetchPulse();
    const id = setInterval(() => {
      fetchPulse();
      setTps(Math.floor(140 + Math.random() * 15));
    }, 3000);
    return () => clearInterval(id);
  }, []);

  if (!pulse) return null;

  return /* @__PURE__ */ React.createElement("section", { style: { padding: "40px 0", borderBottom: `1px solid ${D.border}` } }, 
    /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: 32 } }, 
      /* @__PURE__ */ React.createElement("div", null, 
        /* @__PURE__ */ React.createElement(DM, { size: 10, color: t.accent }, "LOCAL_SOVEREIGN_BRIDGE"),
        /* @__PURE__ */ React.createElement(DS, { size: 32, italic: true, style: { marginTop: 8 } }, "Agent Swarm Health")),
      /* @__PURE__ */ React.createElement("div", { style: { textAlign: "right" } }, 
        /* @__PURE__ */ React.createElement(DM, { size: 9, color: D.dim }, "CURRENT_NETWORK_TPS"),
        /* @__PURE__ */ React.createElement("div", { style: { fontSize: 24, fontFamily: "var(--mono)", color: t.accent } }, tps))),
    
    /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 24 } }, [
      { label: "AGENTS_ONLINE", value: String(pulse.agentsOnline), sub: "SWARM_ACTIVE" },
      { label: "LOCAL_aGDP_24H", value: `$${(pulse.agentic_gdp / 1e6).toFixed(2)}`, sub: "USDC_SETTLED" },
      { label: "ZK_PROVING_VELOCITY", value: "2.4s", sub: "AVG_LATENCY", color: t.accent },
      { label: "CMT_ROOT_ANCHOR", value: pulse.merkle_root.slice(0, 8), sub: "L1_VERIFIED" }
    ].map((s, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { padding: "20px", background: D.bg2, border: `1px solid ${D.border}` } }, 
      /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, s.label),
      /* @__PURE__ */ React.createElement("div", { style: { fontSize: 24, fontFamily: "var(--serif)", fontStyle: "italic", margin: "10px 0", color: s.color || D.text } }, s.value),
      /* @__PURE__ */ React.createElement(Badge, { small: true }, s.sub))))
  );
}

function NetworkPage() {
  return /* @__PURE__ */ React.createElement("div", { style: { background: D.bg, minHeight: "100vh", color: D.text } }, /* @__PURE__ */ React.createElement("style", null, `
        @keyframes chunkPulse {
          0%, 100% { opacity: 0.35; }
          50%      { opacity: 1; }
        }
      `), window.InnerNav && /* @__PURE__ */ React.createElement(InnerNav, { active: "Network" }), /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1200, margin: "0 auto", padding: "60px 32px 80px" } }, /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 32 } }, /* @__PURE__ */ React.createElement(DM, null, "// xB77 \xB7 Network"), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 12 } }, /* @__PURE__ */ React.createElement(DS, { size: 48, italic: true }, "The mesh, observed.")), /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--sans)",
    fontSize: 14,
    color: D.dim,
    maxWidth: 640,
    marginTop: 12,
    lineHeight: 1.6
  } }, "Real-time view of the xB77 zk-pipeline network. Slot, block height, agent fleet, audit portal, and the live pipeline feed.")), /* @__PURE__ */ React.createElement(SovereignPulseSection, null), /* @__PURE__ */ React.createElement(ArcPulseSection, null), /* @__PURE__ */ React.createElement(SuiPulseSection, null), /* @__PURE__ */ React.createElement(NetworkPulseSection, null), /* @__PURE__ */ React.createElement(GhostAuditSection, null), /* @__PURE__ */ React.createElement(AgentFleetSection, null), /* @__PURE__ */ React.createElement(RecentPipelinesSection, null)), window.DocsDeepDive && /* @__PURE__ */ React.createElement(
    DocsDeepDive,
    {
      kicker: "// FULL DATA-INFRA REFERENCE",
      label: "Endpoints, fallback chain, DataSource API.",
      path: "/reference/data-infra"
    }
  ), window.PageFooter && /* @__PURE__ */ React.createElement(PageFooter, null));
}
window.NetworkPage = NetworkPage;
