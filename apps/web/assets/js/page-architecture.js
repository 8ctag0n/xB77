function ArchPage() {
  const t = THEMES.obsidian;
  const [activeLayer, setActiveLayer] = React.useState(null);
  const [hoveredNode, setHoveredNode] = React.useState(null);
  const layers = [
    {
      id: "agents",
      label: "Agent Layer",
      color: t.accent,
      nodes: [
        { name: "CFO Agent", desc: "Autonomous treasury management. Identifies payment needs, negotiates via AWP, executes without human intervention.", x: 20, y: 50 },
        { name: "Ops Agent", desc: "Infrastructure procurement \u2014 compute, storage, API access. Auto-scaling resource allocation.", x: 50, y: 50 },
        { name: "Compliance Agent", desc: "Monitors governance constraints. Triggers human signature lockdowns when Constitution thresholds are breached.", x: 80, y: 50 }
      ]
    },
    {
      id: "core",
      label: "xB77 Core",
      color: "#8888ff",
      nodes: [
        { name: "Pipeline Engine", desc: "Z-Node Core \u2014 native Zig implementation. Compressed state transitions, sub-millisecond routing.", x: 25, y: 50 },
        { name: "Neural Key Auth", desc: "Agent identity verification. ZK-based key management with revocation and rotation.", x: 50, y: 50 },
        { name: "Governance Module", desc: "Constitution enforcement. Multi-sig thresholds, spending limits, strategy constraints.", x: 75, y: 50 }
      ]
    },
    {
      id: "privacy",
      label: "Security & Privacy",
      color: "#ff6688",
      nodes: [
        { name: "Semantic Shield", desc: "Arbitrum Stylus contract written in Zig. Performs vector cosine similarity on-chain to enforce agent intent.", x: 20, y: 50 },
        { name: "Deploy Manager", desc: "One-click agent provisioning. Self-hosted or cloud. Handles key management, config, and pipeline orchestration.", x: 50, y: 50 },
        { name: "Noir ZK Prover", desc: "Ghost Receipt generation. Proves transaction validity without revealing strategy, amounts, or counterparties.", x: 80, y: 50 }
      ]
    },
    {
      id: "settlement",
      label: "Settlement Layer",
      color: "#ffaa44",
      nodes: [
        { name: "Arbitrum Stylus", desc: "Primary smart contract environment. Zero-click execution via ZeroDev Kernel v3.", x: 25, y: 50 },
        { name: "Multi-Chain Hooks", desc: "Circle CCTP V2 integration for atomic cross-chain settlement across Solana, Sui, and EVM.", x: 50, y: 50 },
        { name: "Robinhood Chain", desc: "Institutional RWA settlement. High-performance Orbit chain.", x: 75, y: 50 }
      ]
    }
  ];
  const dataFlows = [
    { label: "Agent \u2192 Pipeline", from: "Sovereign Intent", desc: "Agent generates a deterministic 128-dim Intent Vector from natural language." },
    { label: "Pipeline \u2192 Stylus", from: "Semantic Check", desc: "Vector sent to Arbitrum Stylus. Zig-native engine calculates cosine similarity against blocked concepts." },
    { label: "Stylus \u2192 ZeroDev", from: "Execution", desc: "If similarity < 80%, ZeroDev Kernel v3 executes gaslessly via EIP-7715 session keys." },
    { label: "ZeroDev \u2192 Settlement", from: "Multi-Chain", desc: "Transaction settles on Arbitrum or bridges via CCTP to Solana/Sui/Robinhood." },
    { label: "Settlement \u2192 Identity", from: "Reputation", desc: "Success/Failure updates the agent's ERC-8004 reputation score." }
  ];
  const techSpecs = [
    { label: "Runtime", value: "Zig (Z-Node Core)", desc: "Native compiled, no VM overhead. ~4\u03BCs state transitions." },
    { label: "Smart Contracts", value: "Arbitrum Stylus (Zig)", desc: "Semantic Vector Engine compiled to WASM. 100x cheaper than EVM." },
    { label: "Execution", value: "ZeroDev Kernel v3", desc: "EIP-7715 Session Keys + Account Abstraction." },
    { label: "ZK Backend", value: "Noir (UltraHonk)", desc: "ACIR circuit compilation. Proof of Model Execution." },
    { label: "Settlement", value: "Multi-Chain", desc: "Arbitrum, Robinhood Chain, Solana, Arc, Sui." },
    { label: "Deploy", value: "Self-hosted / Cloud", desc: "One-click provisioning. Like Vercel for AI finance." }
  ];
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh", color: t.text } }, /* @__PURE__ */ React.createElement(InnerNav, { active: "Architecture" }), /* @__PURE__ */ React.createElement("section", { style: { padding: "100px 40px 80px", maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "SYSTEM ARCHITECTURE"), /* @__PURE__ */ React.createElement("h1", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(40px, 6vw, 80px)",
    fontWeight: 400,
    color: t.text,
    lineHeight: 1,
    margin: "0 0 20px"
  } }, "Infrastructure ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Map")), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 17,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 560
  } }, "Four layers of sovereign financial infrastructure \u2014 from autonomous agents to ZK-compressed, pluggable settlement (Arbitrum \xB7 Solana \xB7 Arc \xB7 Sui).")), /* @__PURE__ */ React.createElement("section", { style: { padding: "0 40px 100px", maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.textDim, letterSpacing: "0.15em", marginBottom: 24, textTransform: "uppercase" } }, "CLICK A LAYER TO EXPLORE"), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 0 } }, layers.map((layer, li) => {
    const isActive = activeLayer === li;
    return /* @__PURE__ */ React.createElement("div", { key: layer.id }, /* @__PURE__ */ React.createElement(
      "div",
      {
        onClick: () => setActiveLayer(isActive ? null : li),
        style: {
          display: "grid",
          gridTemplateColumns: "48px 200px 1fr 40px",
          alignItems: "center",
          gap: 16,
          padding: "20px 24px",
          cursor: "pointer",
          background: isActive ? t.bgCard : "transparent",
          border: `1px solid ${isActive ? t.border : "transparent"}`,
          borderBottom: `1px solid ${t.border}`,
          transition: "all 0.3s"
        }
      },
      /* @__PURE__ */ React.createElement("div", { style: {
        width: 10,
        height: 10,
        borderRadius: "50%",
        background: layer.color,
        opacity: isActive ? 1 : 0.4,
        boxShadow: isActive ? `0 0 12px ${layer.color}40` : "none",
        transition: "all 0.3s"
      } }),
      /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--mono)",
        fontSize: 13,
        fontWeight: 600,
        color: isActive ? layer.color : t.text,
        letterSpacing: "0.05em",
        transition: "color 0.3s"
      } }, layer.label),
      /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--sans)",
        fontSize: 13,
        color: t.textDim
      } }, layer.nodes.length, " components"),
      /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--mono)",
        fontSize: 16,
        color: t.textDim,
        transform: isActive ? "rotate(90deg)" : "none",
        transition: "transform 0.3s"
      } }, "\u2192")
    ), isActive && /* @__PURE__ */ React.createElement("div", { style: {
      display: "grid",
      gridTemplateColumns: "repeat(3, 1fr)",
      gap: 0,
      borderBottom: `1px solid ${t.border}`
    } }, layer.nodes.map((node, ni) => /* @__PURE__ */ React.createElement(
      "div",
      {
        key: ni,
        style: {
          padding: "28px 24px",
          borderRight: ni < 2 ? `1px solid ${t.border}` : "none",
          background: hoveredNode === `${li}-${ni}` ? t.bgCard : "transparent",
          transition: "background 0.3s",
          cursor: "default"
        },
        onMouseEnter: () => setHoveredNode(`${li}-${ni}`),
        onMouseLeave: () => setHoveredNode(null)
      },
      /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--mono)",
        fontSize: 14,
        fontWeight: 600,
        color: layer.color,
        marginBottom: 8
      } }, node.name),
      /* @__PURE__ */ React.createElement("p", { style: {
        fontFamily: "var(--sans)",
        fontSize: 13,
        color: t.textDim,
        lineHeight: 1.6,
        margin: 0
      } }, node.desc)
    ))));
  }))), /* @__PURE__ */ React.createElement("section", { style: { padding: "100px 40px", background: t.bgSecondary, borderTop: `1px solid ${t.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "DATA FLOW"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(32px, 4vw, 52px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 60px",
    lineHeight: 1.1
  } }, "Transaction ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Pipeline")), /* @__PURE__ */ React.createElement("div", { style: { position: "relative" } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    left: 23,
    top: 20,
    bottom: 20,
    width: 2,
    background: `linear-gradient(to bottom, ${t.accent}, ${t.border})`,
    opacity: 0.4
  } }), dataFlows.map((flow, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: {
    display: "grid",
    gridTemplateColumns: "48px 1fr",
    gap: 24,
    padding: "24px 0"
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", justifyContent: "center", paddingTop: 6 } }, /* @__PURE__ */ React.createElement("div", { style: {
    width: 12,
    height: 12,
    borderRadius: "50%",
    position: "relative",
    zIndex: 1,
    background: t.accent,
    border: `2px solid ${t.accent}`,
    boxShadow: `0 0 12px ${t.terminalGlow}`
  } })), /* @__PURE__ */ React.createElement("div", { style: {
    background: t.bgCard,
    border: `1px solid ${t.border}`,
    padding: "20px 24px"
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "baseline", gap: 16, marginBottom: 8 } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 12, color: t.accent, fontWeight: 600 } }, flow.label), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.textDim, letterSpacing: "0.1em" } }, flow.from)), /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--sans)", fontSize: 14, color: t.textDim, lineHeight: 1.6, margin: 0 } }, flow.desc))))))), /* @__PURE__ */ React.createElement("section", { style: { padding: "100px 40px", borderTop: `1px solid ${t.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "TECH STACK"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(32px, 4vw, 52px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 48px",
    lineHeight: 1.1
  } }, "Under the ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Hood")), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 0 } }, techSpecs.map((spec, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        padding: "28px 24px",
        borderRight: i % 3 < 2 ? `1px solid ${t.border}` : "none",
        borderBottom: i < 3 ? `1px solid ${t.border}` : "none",
        transition: "background 0.3s",
        cursor: "default"
      },
      onMouseEnter: (e) => e.currentTarget.style.background = t.bgCard,
      onMouseLeave: (e) => e.currentTarget.style.background = "transparent"
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.textDim, letterSpacing: "0.15em", marginBottom: 8, textTransform: "uppercase" } }, spec.label),
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 16, color: t.accent, fontWeight: 600, marginBottom: 6 } }, spec.value),
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--sans)", fontSize: 13, color: t.textDim, lineHeight: 1.5 } }, spec.detail)
  ))))), /* @__PURE__ */ React.createElement(
    DocsDeepDive,
    {
      kicker: "// FULL ARCHITECTURE BRIEF",
      label: "The complete layered architecture.",
      path: "/architecture"
    }
  ), /* @__PURE__ */ React.createElement(PageFooter, null));
}
Object.assign(window, { ArchPage });
