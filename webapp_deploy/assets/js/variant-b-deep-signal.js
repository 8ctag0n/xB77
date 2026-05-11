function DeepSignalVariant({ theme }) {
  const t = THEMES[theme];
  const { lines, cursor, termRef } = useTerminal();
  const [hoveredFeature, setHoveredFeature] = React.useState(null);
  return /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("nav", { style: {
    position: "sticky",
    top: 0,
    zIndex: 100,
    background: t.navBg,
    backdropFilter: "blur(24px)",
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "0 48px",
    height: 60,
    borderBottom: `1px solid ${t.border}`
  } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontWeight: 600, fontSize: 14, color: t.text, letterSpacing: "0.15em" } }, "xB77"), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 32, alignItems: "center" } }, [
    { label: "Why xB77", href: "Why xB77.html" },
    { label: "Docs", href: "Docs.html" },
    { label: "Whitepaper", href: "Whitepaper.html" },
    { label: "Explorer", href: "Explorer.html" }
  ].map((l) => /* @__PURE__ */ React.createElement(
    "a",
    {
      key: l.label,
      href: l.href,
      style: {
        fontFamily: "var(--sans)",
        fontSize: 13,
        color: t.textDim,
        cursor: "pointer",
        transition: "color 0.2s",
        textDecoration: "none",
        fontWeight: 500
      },
      onMouseEnter: (e) => e.target.style.color = t.text,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    l.label
  )), /* @__PURE__ */ React.createElement("div", { style: {
    width: 1,
    height: 20,
    background: t.border
  } }), /* @__PURE__ */ React.createElement("a", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: t.accent,
    cursor: "pointer",
    textDecoration: "none",
    letterSpacing: "0.06em"
  } }, "Connect \u2192"))), /* @__PURE__ */ React.createElement("section", { style: {
    position: "relative",
    minHeight: "88vh",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    padding: "0 48px",
    textAlign: "center"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    inset: 0,
    pointerEvents: "none",
    backgroundImage: `
            linear-gradient(${t.border} 1px, transparent 1px),
            linear-gradient(90deg, ${t.border} 1px, transparent 1px)
          `,
    backgroundSize: "80px 80px",
    opacity: 0.4,
    maskImage: "radial-gradient(ellipse 60% 50% at 50% 50%, black 20%, transparent 70%)",
    WebkitMaskImage: "radial-gradient(ellipse 60% 50% at 50% 50%, black 20%, transparent 70%)"
  } }), /* @__PURE__ */ React.createElement("div", { style: { position: "relative", zIndex: 1 } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "inline-block",
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.accent,
    letterSpacing: "0.2em",
    textTransform: "uppercase",
    border: `1px solid ${t.border}`,
    padding: "6px 14px",
    marginBottom: 40,
    background: t.accentDim
  } }, "SOLANA AGENT INFRASTRUCTURE"), /* @__PURE__ */ React.createElement("h1", { style: {
    fontFamily: "var(--sans)",
    fontSize: "clamp(40px, 6vw, 72px)",
    fontWeight: 600,
    color: t.text,
    lineHeight: 1.1,
    margin: 0,
    letterSpacing: "-0.03em",
    maxWidth: 680
  } }, "Autonomous capital.", /* @__PURE__ */ React.createElement("br", null), /* @__PURE__ */ React.createElement("span", { style: { color: t.textDim } }, "Deploy anywhere.")), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 17,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 440,
    margin: "28px auto 0",
    fontWeight: 400
  } }, "The sovereign financial operating system for the machine economy."), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 16, justifyContent: "center", marginTop: 44 } }, /* @__PURE__ */ React.createElement("button", { className: "btn-primary", style: { "--ac": t.accent, "--bg": t.bg, borderRadius: 100 } }, "Launch Pipeline"), /* @__PURE__ */ React.createElement("button", { className: "btn-ghost", style: { "--ac": t.accent, "--border": t.border, "--text": t.text, borderRadius: 100 } }, "Read Whitepaper")))), /* @__PURE__ */ React.createElement(LiveMetrics, { theme }), /* @__PURE__ */ React.createElement("section", { style: {
    borderTop: `1px solid ${t.border}`,
    padding: "80px 48px"
  } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1e3, margin: "0 auto" } }, FEATURES.map((f, i) => /* @__PURE__ */ React.createElement(
    "div",
    {
      key: i,
      style: {
        display: "grid",
        gridTemplateColumns: "200px 1fr",
        gap: 40,
        alignItems: "baseline",
        padding: "36px 0",
        borderBottom: `1px solid ${t.border}`,
        cursor: "default"
      },
      onMouseEnter: () => setHoveredFeature(i),
      onMouseLeave: () => setHoveredFeature(null)
    },
    /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontSize: 10,
      color: hoveredFeature === i ? t.accent : t.textDim,
      letterSpacing: "0.15em",
      transition: "color 0.3s"
    } }, f.tag),
    /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("h3", { style: {
      fontFamily: "var(--sans)",
      fontSize: 24,
      fontWeight: 600,
      color: t.text,
      margin: "0 0 8px",
      transform: hoveredFeature === i ? "translateX(8px)" : "none",
      transition: "transform 0.3s"
    } }, f.title), /* @__PURE__ */ React.createElement("p", { style: {
      fontFamily: "var(--sans)",
      fontSize: 14.5,
      color: t.textDim,
      lineHeight: 1.6,
      margin: 0,
      maxWidth: 500,
      opacity: hoveredFeature === i ? 1 : 0.6,
      transition: "opacity 0.3s"
    } }, f.desc))
  )))), /* @__PURE__ */ React.createElement("section", { style: { padding: "60px 48px 100px", display: "flex", justifyContent: "center" } }, /* @__PURE__ */ React.createElement("div", { style: {
    background: t.terminalBg,
    border: `1px solid ${t.border}`,
    fontFamily: "var(--mono)",
    fontSize: 11.5,
    lineHeight: 1.7,
    maxWidth: 560,
    width: "100%",
    boxShadow: `0 0 60px ${t.terminalGlow}`
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    alignItems: "center",
    gap: 6,
    padding: "8px 14px",
    borderBottom: `1px solid ${t.border}`,
    fontSize: 9,
    color: t.textDim,
    letterSpacing: "0.1em"
  } }, /* @__PURE__ */ React.createElement("span", { style: { width: 6, height: 6, borderRadius: "50%", background: t.accent, opacity: 0.5 } }), "PIPELINE"), /* @__PURE__ */ React.createElement("div", { ref: termRef, style: { padding: "14px 18px", height: 200, overflowY: "auto" } }, lines.map((line, i) => /* @__PURE__ */ React.createElement(TerminalLine, { key: i, line, theme })), /* @__PURE__ */ React.createElement("span", { style: { color: t.accent, opacity: cursor ? 1 : 0 } }, "\u258A")))), /* @__PURE__ */ React.createElement(PipelineDemo, { theme }), /* @__PURE__ */ React.createElement(Tokenomics, { theme }), /* @__PURE__ */ React.createElement(ArchDiagram, { theme }), /* @__PURE__ */ React.createElement(Roadmap, { theme }), /* @__PURE__ */ React.createElement(SiteFooter, { theme }));
}
Object.assign(window, { DeepSignalVariant });
