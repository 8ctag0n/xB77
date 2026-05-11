function CipherVariant({ theme }) {
  const t = THEMES[theme];
  const { lines, cursor, termRef } = useTerminal();
  const [activeNode, setActiveNode] = React.useState(null);
  return /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("nav", { style: {
    position: "sticky",
    top: 0,
    zIndex: 100,
    background: t.navBg,
    backdropFilter: "blur(20px)",
    borderBottom: `1px solid ${t.border}`,
    display: "grid",
    gridTemplateColumns: "1fr auto",
    alignItems: "center",
    padding: "0 40px",
    height: 56
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "baseline", gap: 20 } }, /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--serif)", fontWeight: 400, fontSize: 24, color: t.text, fontStyle: "italic" } }, "xB77"), /* @__PURE__ */ React.createElement("span", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.textDim, letterSpacing: "0.2em" } }, "AUTONOMOUS FINANCE")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 24, alignItems: "center" } }, [
    { label: "Why", href: "Why xB77.html" },
    { label: "Docs", href: "Docs.html" },
    { label: "Paper", href: "Whitepaper.html" },
    { label: "Infra", href: "Architecture.html" }
  ].map((l) => /* @__PURE__ */ React.createElement(
    "a",
    {
      key: l.label,
      href: l.href,
      style: {
        fontFamily: "var(--mono)",
        fontSize: 11,
        color: t.textDim,
        letterSpacing: "0.1em",
        textTransform: "uppercase",
        cursor: "pointer",
        transition: "color 0.2s",
        textDecoration: "none"
      },
      onMouseEnter: (e) => e.target.style.color = t.accent,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    l.label
  )), /* @__PURE__ */ React.createElement(
    "button",
    {
      style: {
        fontFamily: "var(--mono)",
        fontSize: 10,
        color: t.accent,
        background: "transparent",
        border: `1px solid ${t.accent}`,
        padding: "7px 14px",
        cursor: "pointer",
        letterSpacing: "0.08em",
        textTransform: "uppercase",
        transition: "background 0.2s"
      },
      onMouseEnter: (e) => {
        e.target.style.background = t.accent;
        e.target.style.color = t.bg;
      },
      onMouseLeave: (e) => {
        e.target.style.background = "transparent";
        e.target.style.color = t.accent;
      }
    },
    "Connect Wallet"
  ))), /* @__PURE__ */ React.createElement("section", { style: {
    position: "relative",
    minHeight: "92vh",
    display: "grid",
    gridTemplateColumns: "55% 45%",
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "relative",
    display: "flex",
    flexDirection: "column",
    justifyContent: "center",
    padding: "80px 60px",
    background: t.bgSecondary,
    borderRight: `1px solid ${t.border}`
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    inset: 0,
    pointerEvents: "none",
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.patternColor,
    lineHeight: 2,
    letterSpacing: "0.4em",
    whiteSpace: "pre-wrap",
    wordBreak: "break-all",
    padding: 30,
    userSelect: "none",
    opacity: 0.8,
    transform: "rotate(-3deg) scale(1.1)"
  } }, Array(35).fill("xB77 CIPHER DEPLOY ZKP ENGINE NEURAL AGENT SOVEREIGN PROTOCOL INFRASTRUCTURE AUTONOMOUS ").join(""))), /* @__PURE__ */ React.createElement("div", { style: { position: "relative", zIndex: 1 } }, /* @__PURE__ */ React.createElement("h1", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(48px, 7vw, 100px)",
    fontWeight: 400,
    fontStyle: "italic",
    color: t.text,
    lineHeight: 0.92,
    margin: 0,
    letterSpacing: "-0.02em"
  } }, "Autonomy\u2014", /* @__PURE__ */ React.createElement("br", null), "it's the", /* @__PURE__ */ React.createElement("br", null), /* @__PURE__ */ React.createElement("span", { style: { color: t.accent, fontStyle: "italic" } }, "Foundation")), /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    gap: 16,
    marginTop: 48
  } }, /* @__PURE__ */ React.createElement("button", { className: "btn-primary", style: { "--ac": t.accent, "--bg": t.bg } }, "Launch Pipeline"), /* @__PURE__ */ React.createElement("button", { className: "btn-ghost", style: { "--ac": t.accent, "--border": t.border, "--text": t.text } }, "Whitepaper")))), /* @__PURE__ */ React.createElement("div", { style: {
    position: "relative",
    display: "flex",
    flexDirection: "column",
    justifyContent: "center",
    alignItems: "center",
    padding: "60px 40px",
    gap: 24
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    width: 300,
    height: 300,
    borderRadius: "50%",
    background: t.accent,
    opacity: 0.03,
    filter: "blur(100px)",
    top: "30%",
    left: "30%",
    pointerEvents: "none"
  } }), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 12, position: "relative", zIndex: 1 } }, [
    { label: "STATUS", value: "ACTIVE" },
    { label: "PRIVACY", value: "MAX" },
    { label: "PROTOCOL", value: "xB77 ZK" }
  ].map((s, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        border: `1px solid ${t.border}`,
        padding: "10px 16px",
        background: t.bgCard,
        transition: "border-color 0.2s"
      },
      onMouseEnter: (e) => e.currentTarget.style.borderColor = t.accent,
      onMouseLeave: (e) => e.currentTarget.style.borderColor = t.border
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 8, color: t.textDim, letterSpacing: "0.15em", marginBottom: 4 } }, s.label),
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: t.accent, fontWeight: 600 } }, s.value)
  ))), /* @__PURE__ */ React.createElement("div", { style: {
    background: t.terminalBg,
    border: `1px solid ${t.border}`,
    fontFamily: "var(--mono)",
    fontSize: 12,
    lineHeight: 1.7,
    width: "100%",
    maxWidth: 480,
    position: "relative",
    zIndex: 1,
    boxShadow: `0 0 80px ${t.terminalGlow}`
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    padding: "10px 16px",
    borderBottom: `1px solid ${t.border}`,
    fontSize: 9,
    color: t.textDim,
    letterSpacing: "0.1em"
  } }, /* @__PURE__ */ React.createElement("span", { style: { width: 7, height: 7, borderRadius: "50%", background: t.accent, opacity: 0.6 } }), "XB77_CFO_MVP", /* @__PURE__ */ React.createElement("span", { style: { marginLeft: "auto", fontFamily: "var(--mono)", fontSize: 9, color: t.accent, opacity: 0.5 } }, "\u25A0 LIVE")), /* @__PURE__ */ React.createElement("div", { ref: termRef, style: { padding: "16px 20px", height: 280, overflowY: "auto" } }, lines.map((line, i) => /* @__PURE__ */ React.createElement(TerminalLine, { key: i, line, theme })), /* @__PURE__ */ React.createElement("span", { style: { color: t.accent, opacity: cursor ? 1 : 0 } }, "\u258A"))))), /* @__PURE__ */ React.createElement(LiveMetrics, { theme }), /* @__PURE__ */ React.createElement("section", { style: { borderTop: `1px solid ${t.border}` } }, FEATURES.map((f, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        display: "grid",
        gridTemplateColumns: "60px 1fr 1fr",
        borderBottom: `1px solid ${t.border}`,
        padding: "0",
        cursor: "default",
        transition: "background 0.3s",
        background: activeNode === i ? t.bgCard : "transparent"
      },
      onMouseEnter: () => setActiveNode(i),
      onMouseLeave: () => setActiveNode(null)
    },
    /* @__PURE__ */ React.createElement("div", { style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      borderRight: `1px solid ${t.border}`,
      fontFamily: "var(--mono)",
      fontSize: 11,
      color: t.textDim,
      padding: "40px 0"
    } }, String(i + 1).padStart(2, "0")),
    /* @__PURE__ */ React.createElement("div", { style: {
      padding: "40px 36px",
      borderRight: `1px solid ${t.border}`,
      display: "flex",
      alignItems: "center"
    } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.accent, letterSpacing: "0.15em", marginBottom: 8, opacity: 0.6 } }, f.tag), /* @__PURE__ */ React.createElement("h3", { style: {
      fontFamily: "var(--serif)",
      fontSize: 32,
      fontWeight: 400,
      fontStyle: "italic",
      color: t.text,
      margin: 0,
      transform: activeNode === i ? "translateX(4px)" : "none",
      transition: "transform 0.3s"
    } }, f.title))),
    /* @__PURE__ */ React.createElement("div", { style: {
      padding: "40px 36px",
      display: "flex",
      alignItems: "center"
    } }, /* @__PURE__ */ React.createElement("p", { style: {
      fontFamily: "var(--sans)",
      fontSize: 14,
      color: t.textDim,
      lineHeight: 1.65,
      margin: 0,
      opacity: activeNode === i ? 1 : 0.5,
      transition: "opacity 0.3s"
    } }, f.desc))
  ))), /* @__PURE__ */ React.createElement(PipelineDemo, { theme }), /* @__PURE__ */ React.createElement(Tokenomics, { theme }), /* @__PURE__ */ React.createElement("section", { style: { padding: "100px 40px", background: t.bgSecondary, borderTop: `1px solid ${t.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "ARCHITECTURE"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(32px, 4vw, 52px)",
    fontWeight: 400,
    fontStyle: "italic",
    color: t.text,
    margin: "0 0 50px",
    lineHeight: 1.1
  } }, "Infrastructure ", /* @__PURE__ */ React.createElement("span", { style: { color: t.accent } }, "Map")), /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    gap: 0,
    overflowX: "auto",
    padding: "20px 0"
  } }, ["AI Agent", "xB77 Core", "ZK Engine", "Governance", "Deploy Layer", "Solana"].map((node, i) => /* @__PURE__ */ React.createElement(React.Fragment, { key: i }, /* @__PURE__ */ React.createElement(
    "div",
    {
      style: {
        border: `1px solid ${t.border}`,
        padding: "20px 28px",
        background: t.bg,
        flexShrink: 0,
        transition: "border-color 0.3s, box-shadow 0.3s",
        cursor: "default"
      },
      onMouseEnter: (e) => {
        e.currentTarget.style.borderColor = t.accent;
        e.currentTarget.style.boxShadow = `0 0 24px ${t.terminalGlow}`;
      },
      onMouseLeave: (e) => {
        e.currentTarget.style.borderColor = t.border;
        e.currentTarget.style.boxShadow = "none";
      }
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 12, color: t.text, fontWeight: 600, whiteSpace: "nowrap" } }, node),
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.textDim, marginTop: 4, letterSpacing: "0.08em" } }, ARCH_NODES[i]?.sub || "")
  ), i < 5 && /* @__PURE__ */ React.createElement("div", { style: {
    width: 40,
    height: 1,
    background: t.border,
    flexShrink: 0,
    position: "relative"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    right: -3,
    top: -3,
    width: 0,
    height: 0,
    borderTop: "3px solid transparent",
    borderBottom: "3px solid transparent",
    borderLeft: `5px solid ${t.textDim}`
  } }))))))), /* @__PURE__ */ React.createElement(Roadmap, { theme }), /* @__PURE__ */ React.createElement(SiteFooter, { theme }));
}
Object.assign(window, { CipherVariant });
