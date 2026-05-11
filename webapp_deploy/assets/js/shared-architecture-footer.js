function ArchDiagram({ theme }) {
  const t = THEMES[theme];
  const bp = typeof useBreakpoint === "function" ? useBreakpoint() : { mobile: false };
  return /* @__PURE__ */ React.createElement("section", { style: { padding: bp.mobile ? "60px 20px" : "100px 40px", background: t.bg } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "ARCHITECTURE"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: bp.mobile ? 32 : "clamp(32px, 4vw, 52px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 60px",
    lineHeight: 1.1
  } }, "Infrastructure ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Map")), /* @__PURE__ */ React.createElement("div", { style: {
    position: "relative",
    width: "100%",
    maxWidth: 700,
    margin: "0 auto",
    aspectRatio: "7/5",
    background: t.terminalBg,
    border: `1px solid ${t.border}`,
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement("style", null, `
            @keyframes archPulse {
              0%, 100% { opacity: 0.15; }
              50% { opacity: 0.5; }
            }
            @keyframes flowDash {
              0% { stroke-dashoffset: 12; }
              100% { stroke-dashoffset: 0; }
            }
          `), /* @__PURE__ */ React.createElement("svg", { style: { position: "absolute", inset: 0, width: "100%", height: "100%" }, viewBox: "0 0 100 100", preserveAspectRatio: "none" }, ARCH_CONNS.map(([a, b], i) => /* @__PURE__ */ React.createElement(
    "line",
    {
      key: i,
      x1: ARCH_NODES[a].x,
      y1: ARCH_NODES[a].y,
      x2: ARCH_NODES[b].x,
      y2: ARCH_NODES[b].y,
      stroke: t.accent,
      strokeWidth: "0.2",
      opacity: "0.3",
      strokeDasharray: "1.2 0.6",
      style: { animation: `flowDash 1.5s linear infinite`, animationDelay: `${i * 0.2}s` }
    }
  ))), ARCH_NODES.map((node, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    position: "absolute",
    left: `${node.x}%`,
    top: `${node.y}%`,
    transform: "translate(-50%, -50%)",
    textAlign: "center"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    inset: -6,
    borderRadius: "50%",
    border: `1px solid ${t.accent}`,
    animation: "archPulse 3s ease-in-out infinite",
    animationDelay: `${i * 0.5}s`,
    pointerEvents: "none"
  } }), /* @__PURE__ */ React.createElement(
    "div",
    {
      style: {
        background: t.bg,
        border: `1px solid ${t.border}`,
        padding: bp.mobile ? "8px 12px" : "12px 20px",
        transition: "border-color 0.3s, box-shadow 0.3s",
        cursor: "default"
      },
      onMouseEnter: (e) => {
        e.currentTarget.style.borderColor = t.accent;
        e.currentTarget.style.boxShadow = `0 0 20px ${t.terminalGlow}`;
      },
      onMouseLeave: (e) => {
        e.currentTarget.style.borderColor = t.border;
        e.currentTarget.style.boxShadow = "";
      }
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: bp.mobile ? 9 : 11, color: t.text, fontWeight: 600, letterSpacing: "0.05em", whiteSpace: "nowrap" } }, node.label),
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: bp.mobile ? 7 : 9, color: t.textDim, marginTop: 3, letterSpacing: "0.08em", whiteSpace: "nowrap" } }, node.sub)
  ))))));
}
function SiteFooter({ theme }) {
  const t = THEMES[theme];
  return /* @__PURE__ */ React.createElement("footer", { style: {
    background: t.bgSecondary,
    borderTop: `1px solid ${t.border}`,
    padding: "60px 40px"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    maxWidth: 1100,
    margin: "0 auto",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-end"
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontWeight: 700, fontSize: 18, color: t.accent, letterSpacing: "0.05em", marginBottom: 8 } }, "xB77"), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--sans)", fontSize: 13, color: t.textDim, lineHeight: 1.5 } }, "Autonomous Financial Infrastructure", /* @__PURE__ */ React.createElement("br", null), "Built for the Solana Privacy Hackathon 2026")), /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    gap: 24,
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: t.textDim,
    letterSpacing: "0.1em",
    textTransform: "uppercase"
  } }, ["Docs", "Whitepaper", "GitHub", "Explorer"].map((l) => /* @__PURE__ */ React.createElement(
    "a",
    {
      key: l,
      style: { color: t.textDim, textDecoration: "none", cursor: "pointer", transition: "color 0.2s" },
      onMouseEnter: (e) => e.target.style.color = t.accent,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    l
  )))), /* @__PURE__ */ React.createElement("div", { style: {
    maxWidth: 1100,
    margin: "24px auto 0",
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.textDim,
    opacity: 0.4,
    letterSpacing: "0.1em"
  } }, "\xA9 2026 xB77 Labs"));
}
const PIPELINE_STEPS = [
  { num: "01", tag: "SOVEREIGN_INTENT", title: "Sovereign Intent", desc: "Agent identifies a need \u2014 compute, API, liquidity. Negotiates price via AWP with zero human intervention." },
  { num: "02", tag: "ZK_PRIVACY", title: "ZK Privacy Layer", desc: "xB77's proprietary ZK engine shields the transaction. Strategy-opaque, math-enforced \u2014 no third-party dependencies." },
  { num: "03", tag: "GHOST_RECEIPT", title: "The Ghost Receipt", desc: "Noir generates a ZK proof the payment occurred \u2014 without revealing the Agent's internal strategy. Math-enforced Constitution compliance." },
  { num: "04", tag: "INFRA_TAX", title: "Infra Tax Collection", desc: "Smart contract deducts 2.011% on-chain. Funds flow to the Sovereign Credits pool \u2014 subsidizing RPCs, storage, and ZK proof generation." }
];
function Tokenomics({ theme }) {
  const t = THEMES[theme];
  const [hovered, setHovered] = React.useState(null);
  return /* @__PURE__ */ React.createElement("section", { style: { padding: "120px 40px", background: t.bg, borderTop: `1px solid ${t.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "TOKENOMICS"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(36px, 5vw, 64px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 16px",
    lineHeight: 1.05
  } }, "The ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "2.011%"), " Engine"), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 16,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 560,
    margin: "0 0 64px"
  } }, "No inflationary token. Infrastructure sustainability through usage \u2014 xB77 charges for autonomy, not transactions."), /* @__PURE__ */ React.createElement("div", { style: { position: "relative", display: "flex", flexDirection: "column", gap: 0 } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    left: 23,
    top: 24,
    bottom: 24,
    width: 1,
    background: `linear-gradient(to bottom, ${t.accent}, ${t.border})`,
    opacity: 0.3
  } }), PIPELINE_STEPS.map((step, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        display: "grid",
        gridTemplateColumns: "48px 1fr",
        gap: 24,
        padding: "28px 0",
        cursor: "default"
      },
      onMouseEnter: () => setHovered(i),
      onMouseLeave: () => setHovered(null)
    },
    /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "center", paddingTop: 4 } }, /* @__PURE__ */ React.createElement("div", { style: {
      width: 14,
      height: 14,
      borderRadius: "50%",
      background: hovered === i ? t.accent : t.bg,
      border: `2px solid ${hovered === i ? t.accent : t.textDim}`,
      transition: "all 0.3s",
      boxShadow: hovered === i ? `0 0 16px ${t.terminalGlow}` : "none",
      position: "relative",
      zIndex: 1
    } })),
    /* @__PURE__ */ React.createElement("div", { style: {
      background: hovered === i ? t.bgCard : "transparent",
      border: `1px solid ${hovered === i ? t.border : "transparent"}`,
      padding: "20px 24px",
      transition: "all 0.3s",
      transform: hovered === i ? "translateX(6px)" : "none"
    } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 12, marginBottom: 10 } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.15em", opacity: 0.5 } }, step.tag)), /* @__PURE__ */ React.createElement("h3", { style: {
      fontFamily: "var(--serif)",
      fontSize: 26,
      fontWeight: 400,
      color: t.text,
      margin: "0 0 8px"
    } }, /* @__PURE__ */ React.createElement("span", { style: { color: t.accent, fontStyle: "italic" } }, step.num, "."), " ", step.title), /* @__PURE__ */ React.createElement("p", { style: {
      fontFamily: "var(--sans)",
      fontSize: 14,
      color: t.textDim,
      lineHeight: 1.65,
      margin: 0,
      maxWidth: 480
    } }, step.desc))
  ))), /* @__PURE__ */ React.createElement("div", { style: {
    marginTop: 48,
    padding: "28px 32px",
    borderLeft: `3px solid ${t.accent}`,
    background: t.accentDim
  } }, /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--serif)",
    fontSize: 22,
    fontStyle: "italic",
    color: t.text,
    margin: 0,
    lineHeight: 1.4
  } }, '"xB77 no cobra por transacci\xF3n, cobra por ', /* @__PURE__ */ React.createElement("span", { style: { color: t.accent } }, "autonom\xEDa"), '."'))));
}
const ROADMAP_PHASES = [
  {
    phase: "Phase 1",
    name: "Frontier",
    period: "Hackathon \u2014 May 2026",
    status: "current",
    items: [
      "Z-Node Core \u2014 Native Zig implementation of compressed state engine",
      "xB77 ZK Engine \u2014 Proprietary privacy + compression on Solana",
      "Easy Deploy \u2014 One-click agent provisioning, self-hosted or cloud"
    ]
  },
  {
    phase: "Phase 2",
    name: "Infiltration",
    period: "Q3 2026",
    status: "future",
    items: [
      "Multi-Agent Mesh \u2014 Sovereign flash loans between agents",
      "x402 Protocol \u2014 Standard payment protocol for any AI wallet",
      "Marketplace \u2014 Agent templates, plugins, and strategy modules"
    ]
  },
  {
    phase: "Phase 3",
    name: "Sovereignty",
    period: "2027",
    status: "future",
    items: [
      "Recursive Proof Aggregation \u2014 10K agent txns \u2192 1 ZK proof (32 bytes)",
      "Sovereign Financial OS \u2014 Agents as autonomous legal entities with cryptographic receipts"
    ]
  }
];
function Roadmap({ theme }) {
  const t = THEMES[theme];
  const [hovered, setHovered] = React.useState(null);
  return /* @__PURE__ */ React.createElement("section", { style: {
    padding: "120px 40px",
    background: t.bgSecondary,
    borderTop: `1px solid ${t.border}`
  } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "ROADMAP"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(36px, 5vw, 64px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 16px",
    lineHeight: 1.05
  } }, "The Frontier ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Expansion")), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 16,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 500,
    margin: "0 0 72px"
  } }, "Phased infiltration into the traditional financial system."), /* @__PURE__ */ React.createElement("div", { style: { position: "relative" } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    left: 23,
    top: 0,
    bottom: 0,
    width: 2,
    background: `linear-gradient(to bottom, ${t.accent}, ${t.border} 40%, ${t.border})`
  } }), ROADMAP_PHASES.map((phase, pi) => {
    const isCurrent = phase.status === "current";
    const isFuture = phase.status === "future";
    return /* @__PURE__ */ React.createElement("div", { key: pi, style: { position: "relative", marginBottom: pi < ROADMAP_PHASES.length - 1 ? 56 : 0 } }, /* @__PURE__ */ React.createElement("div", { style: {
      position: "absolute",
      left: 12,
      top: 0,
      zIndex: 2,
      width: 24,
      height: 24,
      borderRadius: "50%",
      background: isCurrent ? t.accent : t.bg,
      border: `2px solid ${isCurrent ? t.accent : t.textDim}`,
      boxShadow: isCurrent ? `0 0 20px ${t.terminalGlow}, 0 0 40px ${t.terminalGlow}` : "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center"
    } }, isCurrent && /* @__PURE__ */ React.createElement("div", { style: { width: 8, height: 8, borderRadius: "50%", background: t.bg } })), /* @__PURE__ */ React.createElement("div", { style: { marginLeft: 56 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "baseline", gap: 12, marginBottom: 6 } }, /* @__PURE__ */ React.createElement("span", { style: {
      fontFamily: "var(--mono)",
      fontSize: 10,
      letterSpacing: "0.15em",
      color: isCurrent ? t.accent : t.textDim,
      textTransform: "uppercase"
    } }, phase.phase), isCurrent && /* @__PURE__ */ React.createElement("span", { style: {
      fontFamily: "var(--mono)",
      fontSize: 9,
      letterSpacing: "0.1em",
      color: t.bg,
      background: t.accent,
      padding: "2px 8px",
      fontWeight: 600
    } }, "CURRENT")), /* @__PURE__ */ React.createElement("h3", { style: {
      fontFamily: "var(--serif)",
      fontSize: 32,
      fontWeight: 400,
      color: isFuture ? t.textDim : t.text,
      margin: "0 0 4px",
      fontStyle: "italic"
    } }, phase.name), /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontSize: 11,
      color: t.textDim,
      letterSpacing: "0.06em",
      marginBottom: 20
    } }, phase.period), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 0 } }, phase.items.map((item, ii) => /* @__PURE__ */ React.createElement(
      "div",
      {
        key: ii,
        style: {
          display: "grid",
          gridTemplateColumns: "24px 1fr",
          gap: 12,
          padding: "12px 0",
          cursor: "default"
        },
        onMouseEnter: () => setHovered(`${pi}-${ii}`),
        onMouseLeave: () => setHovered(null)
      },
      /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "center" } }, /* @__PURE__ */ React.createElement("div", { style: {
        width: 8,
        height: 8,
        borderRadius: "50%",
        border: `1.5px ${isFuture ? "dashed" : "solid"} ${hovered === `${pi}-${ii}` ? t.accent : t.textDim}`,
        background: isCurrent && hovered === `${pi}-${ii}` ? t.accent : "transparent",
        transition: "all 0.2s"
      } })),
      /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--sans)",
        fontSize: 14,
        color: isFuture ? t.textDim : t.text,
        lineHeight: 1.5,
        opacity: hovered === `${pi}-${ii}` ? 1 : isFuture ? 0.6 : 0.85,
        transition: "opacity 0.2s"
      } }, /* @__PURE__ */ React.createElement("strong", { style: { color: isFuture ? t.textDim : t.text } }, item.split("\u2014")[0]), item.includes("\u2014") && /* @__PURE__ */ React.createElement("span", { style: { color: t.textDim } }, " \u2014 ", item.split("\u2014").slice(1).join("\u2014")))
    )))));
  }))));
}
Object.assign(window, { ArchDiagram, SiteFooter, Tokenomics, Roadmap });
