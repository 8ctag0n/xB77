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
      "INITIALIZING_ZK_ORACLE...",
      "QUERYING_ONCHAIN_VERIFIER...",
      "RECONSTRUCTING_PROOF_WITNESS...",
      "VALIDATING_MERKLE_CHUNKS...",
      "FINALIZING_SOVEREIGN_VERDICT..."
    ];
    let i = 0;
    setStatusLine(steps[0]);
    const iv = setInterval(() => {
      i++;
      if (i < steps.length) setStatusLine(steps[i]);
    }, 400);
    try {
      const minWait = new Promise((r2) => setTimeout(r2, 2000));
      const [r] = await Promise.all([window.DataSource.auditTx(target), minWait]);
      setResult(r);
    } finally {
      clearInterval(iv);
      setLoading(false);
    }
  }

  const verdictColor = result ? VERDICT_COLOR[result.verdict] || D.text : D.text;
  
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "60px 0", borderBottom: `1px solid ${D.border}` } }, 
    /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 32 } }, 
      /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.accent }, "// GHOST_AUDIT_PORTAL"), 
      /* @__PURE__ */ React.createElement("div", { style: { marginTop: 12 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 42, italic: true, color: D.text }, "Mathematical Certainty.")
      )
    ),
    /* @__PURE__ */ React.createElement("div", { style: { 
      background: "#050505", 
      border: `1px solid ${D.border}`, 
      padding: "2px",
      maxWidth: 900,
      position: "relative",
      boxShadow: "0 20px 50px rgba(0,0,0,0.5)"
    } },
      /* @__PURE__ */ React.createElement("div", { style: { 
        padding: "16px 20px", 
        borderBottom: `1px solid ${D.border}`,
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        background: D.bg2
      } },
        /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.dim } }, "XB77_TERMINAL // AUDIT_SESSION"),
        /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 6 } }, 
          /* @__PURE__ */ React.createElement("div", { style: { width: 8, height: 8, borderRadius: "50%", background: "#ff5f56" } }),
          /* @__PURE__ */ React.createElement("div", { style: { width: 8, height: 8, borderRadius: "50%", background: "#ffbd2e" } }),
          /* @__PURE__ */ React.createElement("div", { style: { width: 8, height: 8, borderRadius: "50%", background: "#27c93f" } })
        )
      ),
      /* @__PURE__ */ React.createElement("div", { style: { padding: "32px", minHeight: 300 } },
        /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 24 } },
          /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: D.accent, marginBottom: 8 } }, "system@xb77:~$ run_audit --tx_hash"),
          /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 12 } },
            /* @__PURE__ */ React.createElement("input", {
              type: "text",
              value: hash,
              onChange: (e) => setHash(e.target.value),
              onKeyDown: (e) => e.key === "Enter" && runAudit(),
              placeholder: "ENTER_TX_HASH...",
              style: {
                flex: 1,
                background: "transparent",
                border: "none",
                borderBottom: `1px solid ${D.border}`,
                color: D.text,
                fontFamily: "var(--mono)",
                fontSize: 16,
                padding: "8px 0",
                outline: "none"
              }
            }),
            /* @__PURE__ */ React.createElement("button", { 
              onClick: () => runAudit(),
              disabled: loading,
              style: {
                background: D.accent,
                color: "#000",
                border: "none",
                padding: "8px 24px",
                fontFamily: "var(--mono)",
                fontWeight: "bold",
                cursor: "pointer",
                opacity: loading ? 0.5 : 1
              }
            }, loading ? "BUSY..." : "EXEC")
          )
        ),
        
        loading && /* @__PURE__ */ React.createElement("div", { style: { 
          padding: "32px", 
          background: "rgba(0,255,255,0.03)", 
          border: `1px dashed ${D.cyan}`,
          maxWidth: 900,
          fontFamily: "var(--mono)",
          fontSize: 12,
          lineHeight: 1.8,
          color: D.cyan
        } },
          /* @__PURE__ */ React.createElement("div", { style: { marginBottom: 16, fontWeight: "bold" } }, "> " + statusLine),
          /* @__PURE__ */ React.createElement("div", { style: { opacity: 0.7 } }, "[0x01] FETCHING_STATE_ROOT... [OK]"),
          /* @__PURE__ */ React.createElement("div", { style: { opacity: 0.8 } }, "[0x02] DOWNLOAD_CIRCUIT_VK... [OK]"),
          /* @__PURE__ */ React.createElement("div", { style: { opacity: 0.9 } }, "[0x03] RECONSTRUCTING_MERKLE_PATH..."),
          /* @__PURE__ */ React.createElement(ChunkStrip, { chunks: 8, verdict: "PENDING", animate: true })
        ),

        result && !loading && /* @__PURE__ */ React.createElement("div", { style: { 
          fontFamily: "var(--mono)", 
          animation: "xb-row-anim 0.6s ease-out both",
          background: "linear-gradient(135deg, #050505 0%, #0a0a0a 100%)",
          padding: "40px",
          border: `1px solid ${verdictColor}`,
          position: "relative",
          maxWidth: 900
        } },
          /* @__PURE__ */ React.createElement("div", { style: { 
            position: "absolute", top: 10, right: 20, fontSize: 9, color: D.dim, letterSpacing: "2px" 
          } }, "SESSION_ID: " + result.proofId.slice(-8).toUpperCase()),
          
          /* @__PURE__ */ React.createElement("div", { style: { 
            fontSize: 32, fontWeight: "900", color: verdictColor, marginBottom: 30, letterSpacing: "-1px",
            display: "flex", alignItems: "center", gap: 16
          } }, 
            /* @__PURE__ */ React.createElement("span", { style: { 
              width: 12, height: 12, borderRadius: "50%", background: verdictColor, boxShadow: `0 0 15px ${verdictColor}` 
            } }),
            result.verdict === "VALID" ? "GHOST_PROOF_VALIDATED" : "GHOST_PROOF_REJECTED"
          ),

          /* @__PURE__ */ React.createElement("div", { style: { 
            display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "32px" 
          } },
            /* @__PURE__ */ React.createElement("div", null, 
              /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.dim }, "// PROOF_METADATA"),
              /* @__PURE__ */ React.createElement("div", { style: { marginTop: 12, display: "flex", flexDirection: "column", gap: 8 } },
                /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", fontSize: 11 } }, 
                  /* @__PURE__ */ React.createElement("span", { style: { color: D.dim } }, "AGENT_ID"), 
                  /* @__PURE__ */ React.createElement("span", { style: { color: D.accent } }, result.agent)
                ),
                /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", fontSize: 11 } }, 
                  /* @__PURE__ */ React.createElement("span", { style: { color: D.dim } }, "TIMESTAMP"), 
                  /* @__PURE__ */ React.createElement("span", { style: { color: D.text } }, new Date(result.timestamp).toLocaleTimeString())
                ),
                /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", fontSize: 11 } }, 
                  /* @__PURE__ */ React.createElement("span", { style: { color: D.dim } }, "CHUNKS"), 
                  /* @__PURE__ */ React.createElement("span", { style: { color: D.text } }, result.chunks)
                )
              )
            ),
            /* @__PURE__ */ React.createElement("div", null, 
              /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.dim }, "// ZK_INTEGRITY_CHECK"),
              /* @__PURE__ */ React.createElement("div", { style: { marginTop: 12 } },
                /* @__PURE__ */ React.createElement(ChunkStrip, { chunks: result.chunks, verdict: result.verdict }),
                /* @__PURE__ */ React.createElement("div", { style: { 
                  marginTop: 12, fontSize: 10, color: LIME, textAlign: "right", fontFamily: "var(--mono)" 
                } }, "✓ ALL_CHUNKS_VERIFIED_BY_SUNSPOT")
              )
            )
          ),

          /* @__PURE__ */ React.createElement("div", { style: { 
            marginTop: 40, paddingTop: 20, borderTop: `1px solid ${D.border}`,
            display: "flex", justifyContent: "space-between", alignItems: "flex-end"
          } },
            /* @__PURE__ */ React.createElement("div", { style: { flex: 1 } },
              /* @__PURE__ */ React.createElement(DM, { size: 7, color: D.dim }, "L1_SETTLEMENT_TX"),
              /* @__PURE__ */ React.createElement("div", { style: { 
                fontFamily: "var(--mono)", fontSize: 10, color: D.cyan, marginTop: 4, wordBreak: "break-all", opacity: 0.6 
              } }, result.txhash)
            ),
            /* @__PURE__ */ React.createElement("div", { style: { 
              fontFamily: "var(--serif)", fontStyle: "italic", fontSize: 24, color: D.dim, opacity: 0.3 
            } }, "xB77_Labs")
          )
        )
      )
    )
  );
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
function NetworkPage() {
  return /* @__PURE__ */ React.createElement("div", { style: { background: D.bg, minHeight: "100vh", color: D.text } }, /* @__PURE__ */ React.createElement("style", null, `
        @keyframes chunkPulse {
          0%, 100% { opacity: 0.35; }
          50%      { opacity: 1; }
        }
      `), window.InnerNav && /* @__PURE__ */ React.createElement(InnerNav, { active: "Network" }), 
      /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1200, margin: "0 auto", padding: "80px 32px" } }, 
        /* @__PURE__ */ React.createElement("div", { style: { 
          display: "flex", 
          alignItems: "flex-start", 
          justifyContent: "space-between",
          marginBottom: 60,
          flexWrap: "wrap",
          gap: 40
        } }, 
          /* @__PURE__ */ React.createElement("div", { style: { flex: 1, minWidth: 320 } }, 
            /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.accent }, "// XB77_NETWORK_OBSERVATORY"), 
            /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16 } }, 
              /* @__PURE__ */ React.createElement(DS, { size: 64, italic: true }, "The Swarm, Observed.")
            ),
            /* @__PURE__ */ React.createElement("div", { style: {
              fontFamily: "var(--mono)",
              fontSize: 13,
              color: D.dim,
              marginTop: 24,
              lineHeight: 1.8,
              maxWidth: 500
            } }, "Real-time telemetry from the xB77 sovereign mesh. Monitor global flow pressure, verify private receipts, and observe autonomous CFOs in motion.")
          ),
          /* @__PURE__ */ React.createElement("pre", { style: { 
            fontFamily: "var(--mono)", 
            fontSize: 10, 
            color: D.accent, 
            lineHeight: 1.1,
            margin: 0,
            background: D.bg2,
            padding: "20px",
            border: `1px solid ${D.border}`
          } }, ASCII_BANNER)
        ), 
        /* @__PURE__ */ React.createElement(NetworkPulseSection, null), 
        /* @__PURE__ */ React.createElement(GhostAuditSection, null), 
        /* @__PURE__ */ React.createElement(AgentFleetSection, null), 
        /* @__PURE__ */ React.createElement(RecentPipelinesSection, null)
      ), 
      window.DocsDeepDive && /* @__PURE__ */ React.createElement(
        DocsDeepDive,
        {
          kicker: "// FULL DATA-INFRA REFERENCE",
          label: "Endpoints, fallback chain, DataSource API.",
          path: "/reference/data-infra"
        }
      ), 
      window.PageFooter && /* @__PURE__ */ React.createElement(PageFooter, null));
}
window.NetworkPage = NetworkPage;
