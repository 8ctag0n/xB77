function PerformanceChart({ data }) {
  if (!data || !data.pnl_history) return null;
  const t = THEMES.obsidian;
  const points = data.pnl_history;
  const max = Math.max(...points);
  const min = Math.min(...points);
  const range = max - min || 1;
  const w = 600;
  const h = 160;

  const polyPoints = points.map((v, i) => {
    const x = (i / (points.length - 1)) * w;
    const y = h - ((v - min) / range) * (h - 20) - 20;
    return `${x},${y}`;
  }).join(" ");

  return /* @__PURE__ */ React.createElement("div", { style: { marginTop: 24 } }, 
    /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint, style: { marginBottom: 12 } }, "CUMULATIVE_PNL_30D"),
    /* @__PURE__ */ React.createElement("svg", { viewBox: `0 0 ${w} ${h}`, style: { width: "100%", height: h, display: "block" } }, 
      /* @__PURE__ */ React.createElement("polyline", { fill: "none", stroke: t.accent, strokeWidth: "2", points: polyPoints, style: { filter: `drop-shadow(0 0 5px ${t.accent}40)` } }),
      /* @__PURE__ */ React.createElement("path", { d: `M 0,${h} L ${polyPoints} L ${w},${h} Z`, fill: t.accent, style: { opacity: 0.1 } })
    ),
    /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginTop: 12 } }, 
       /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 7 }, "YIELD_EFFICIENCY"), /* @__PURE__ */ React.createElement("div", { style: { color: D.green, fontSize: 14, fontWeight: 700 } }, data.yield_efficiency, "%")),
       /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement(DM, { size: 7 }, "SHARPE_RATIO"), /* @__PURE__ */ React.createElement("div", { style: { color: t.accent, fontSize: 14, fontWeight: 700 } }, data.sharpe_ratio)))
  );
}

function TacticalView() {
  const [yieldData, setYieldData] = React.useState(null);
  const [performance, setPerformance] = React.useState(null);
  const [negotiations, setNegotiations] = React.useState([]);
  const [sentinel, setSentinel] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const t = THEMES.obsidian;

  React.useEffect(() => {
    let cancelled = false;
    const addEvent = () => {
       if (cancelled) return;
       const pool = [
         { t: "[SENTINEL] Mempool Spike: SOL/USDC volume +15%", c: D.cyan },
         { t: "[SENTINEL] Yield Opportunity: Kamino vault cap increased", c: D.green },
         { t: "[SENTINEL] Risk Event: High slippage detected in Raydium pool", c: D.amber },
         { t: "[SENTINEL] AWP Ping: Agent 'ag_wh_04' looking for liquidity", c: t.accent }
       ];
       const ev = pool[Math.floor(Math.random() * pool.length)];
       setSentinel(prev => [{ ...ev, id: Math.random(), time: new Date().toLocaleTimeString() }, ...prev].slice(0, 5));
       setTimeout(addEvent, 3000 + Math.random() * 4000);
    };
    addEvent();
    return () => { cancelled = true; };
  }, []);

  const refresh = async () => {
    try {
      const [rY, rN, rP] = await Promise.all([
        fetch("http://127.0.0.1:8080/api/v1/intelligence/yield", { mode: "cors" }),
        fetch("http://127.0.0.1:8080/api/v1/intelligence/negotiations", { mode: "cors" }),
        fetch("http://127.0.0.1:8080/api/v1/intelligence/performance", { mode: "cors" })
      ]);
      if (rY.ok) setYieldData(await rY.json());
      if (rP.ok) setPerformance(await rP.json());
      if (rN.ok) {
        const j = await rN.json();
        setNegotiations(j.negotiations || []);
      }
    } catch (e) {
      setYieldData(null);
      setPerformance(null);
      setNegotiations([]);
    } finally {
      setLoading(false);
    }
  };

  React.useEffect(() => {
    refresh();
    const id = setInterval(refresh, 5000);
    return () => clearInterval(id);
  }, []);

  return /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flex: 1, minHeight: 0, gap: 24 } }, 
    /* @__PURE__ */ React.createElement("div", { style: { flex: 1, display: "flex", flexDirection: "column", gap: 24 } }, 
      /* @__PURE__ */ React.createElement("div", { style: { background: "rgba(200,255,46,0.02)", border: `1px solid ${t.accent}44`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 20, italic: true }, "Yield Orchestrator"),
        /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint, margin: "8px 0 24px" } }, "Tactical capital allocation analysis via Strategist_v2."),
        
        !yieldData ? /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.faint }, "Connect to a local agent to see live yield strategies.") :
        /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 24 } }, 
          /* @__PURE__ */ React.createElement("div", null, 
            /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "PROTOCOL"),
            /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--serif)", fontSize: 24, color: D.text, fontStyle: "italic", marginTop: 4 } }, yieldData.protocol),
            /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16 } }, 
              /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "STRATEGY"),
              /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: t.accent, marginTop: 4 } }, yieldData.strategy))),
          /* @__PURE__ */ React.createElement("div", { style: { background: D.bg, border: `1px solid ${D.border}`, padding: "16px" } }, 
            /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: 12 } }, 
               /* @__PURE__ */ React.createElement(DM, { size: 9 }, "Expected APY"),
               /* @__PURE__ */ React.createElement("span", { style: { color: D.green, fontWeight: 700 } }, yieldData.expected_apy, "%")),
            /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between" } }, 
               /* @__PURE__ */ React.createElement(DM, { size: 9 }, "Risk Score"),
               /* @__PURE__ */ React.createElement("span", { style: { color: t.accent } }, yieldData.risk_score))),
          /* @__PURE__ */ React.createElement("div", { style: { gridColumn: "span 2", padding: "12px", background: D.bg, borderLeft: `3px solid ${t.accent}` } }, 
             /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "REASONING_TRACE"),
             /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.text, marginTop: 6, lineHeight: 1.5 } }, yieldData.reasoning))),
        /* @__PURE__ */ React.createElement(PerformanceChart, { data: performance })
      ),

      /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 24, flex: 1, display: "flex", flexDirection: "column" } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 18, italic: true }, "Negotiation War-Room (Live AWP)"),
        /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.faint, margin: "8px 0 20px" } }, "Real-time P2P haggling between autonomous agents."),
        
        /* @__PURE__ */ React.createElement("div", { style: { flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: 12 } }, 
          negotiations.length === 0 ? /* @__PURE__ */ React.createElement(DM, { size: 10, color: D.faint }, "Listening for AWP traffic...") :
          negotiations.map((n, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
            padding: "12px 16px",
            background: D.bg,
            border: `1px solid ${D.border}`,
            borderLeft: `3px solid ${n.status === "accepted" ? D.green : D.cyan}`,
            animation: "fadeInLine 0.3s ease"
          } }, 
            /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: 6 } }, 
               /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent } }, n.from, " \u279D ", n.to),
               /* @__PURE__ */ React.createElement(Badge, { color: n.status === "accepted" ? D.green : D.cyan }, n.status.toUpperCase())),
            /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: D.text } }, n.msg),
            /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: D.dim, marginTop: 4 } }, "PAYLOAD: ", n.payload)
          )))
      )
    ),

    /* @__PURE__ */ React.createElement("div", { style: { width: 340, display: "flex", flexDirection: "column", gap: 24 } }, 
      /* @__PURE__ */ React.createElement("div", { style: { background: D.bg2, border: `1px solid ${D.border}`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 14, italic: true }, "Gas Forensics"),
        /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16, display: "flex", flexDirection: "column", gap: 12 } }, [
          { label: "RPC_LATENCY", value: "24ms", color: D.green },
          { label: "GAS_ESTIMATE_24H", value: "0.12 SOL", color: D.text },
          { label: "COMPUTE_UNITS_AVG", value: "140k", color: D.text },
          { label: "ZK_PROVING_TIME", value: "2.4s", color: t.accent }
        ].map((stat, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { display: "flex", justifyContent: "space-between" } }, 
           /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, stat.label),
           /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 11, color: stat.color } }, stat.value)
        )))),
      
      /* @__PURE__ */ React.createElement("div", { style: { background: "rgba(255,107,0,0.03)", border: `1px solid ${D.amber}33`, padding: 24 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 14, italic: true }, "Liquidity Health"),
        /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16 } }, 
          /* @__PURE__ */ React.createElement(DM, { size: 8, color: D.faint }, "SWARM_CASH_RUNWAY"),
          /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 20, color: D.amber, marginTop: 4 } }, "14 Days"),
          /* @__PURE__ */ React.createElement("div", { style: { height: 4, background: D.border, marginTop: 12, borderRadius: 2, overflow: "hidden" } }, 
             /* @__PURE__ */ React.createElement("div", { style: { width: "65%", height: "100%", background: D.amber } }))
        )),

      /* @__PURE__ */ React.createElement("div", { style: { background: "rgba(0,240,255,0.02)", border: `1px solid ${D.cyan}33`, padding: 24, flex: 1 } }, 
        /* @__PURE__ */ React.createElement(DS, { size: 14, italic: true }, "Live Sentinel Feed"),
        /* @__PURE__ */ React.createElement("div", { style: { marginTop: 16, display: "flex", flexDirection: "column", gap: 10 } }, sentinel.map(ev => /* @__PURE__ */ React.createElement("div", { key: ev.id, style: {
          padding: "8px 10px", background: D.bg, borderLeft: `2px solid ${ev.c}`, animation: "fadeInLine 0.2s ease"
        } }, 
          /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: ev.c } }, ev.t),
          /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 7, color: D.dim, textAlign: "right", marginTop: 4 } }, ev.time)
        ))))
    )
  );
}

function TacticalTab() {
  return /* @__PURE__ */ React.createElement("div", { style: { padding: "0", minHeight: 600, display: "flex", flexDirection: "column" } }, /* @__PURE__ */ React.createElement(TacticalView, null));
}
Object.assign(window, { TacticalView, TacticalTab });
