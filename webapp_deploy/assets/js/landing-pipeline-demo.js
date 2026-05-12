const DEMO_STEPS = [
  { id: "intent", label: "Sovereign Intent", tag: "AGENT_CFO", detail: "Agent identifies need: 500 USDC compute purchase. AWP negotiation \u2014 zero human input.", icon: "\u25C8", duration: 1200 },
  { id: "zk", label: "ZK Privacy Layer", tag: "ZK_ENGINE", detail: "xB77 proprietary ZK engine shields the transaction. Strategy-opaque, no third-party dependencies.", icon: "\u25C7", duration: 1500 },
  { id: "ghost", label: "Ghost Receipt", tag: "ZK_PROOF", detail: "Noir generates ZK proof: amount valid, Constitution compliant, strategy opaque. 200ms proving time.", icon: "\u25C6", duration: 1800 },
  { id: "settle", label: "Settlement", tag: "SOLANA_L1", detail: "Proof anchored on Solana. 2.011% Infra Tax collected. Receipt compressed via xB77 ZK Engine \u2192 32 bytes.", icon: "\u25C8", duration: 1e4 }
];
function PipelineDemo({ theme }) {
  const t = THEMES[theme || "obsidian"];
  const bp = useBreakpoint();
  const [activeStep, setActiveStep] = React.useState(-1);
  const [running, setRunning] = React.useState(false);
  const [completed, setCompleted] = React.useState(/* @__PURE__ */ new Set());
  const timeoutRef = React.useRef(null);
  const runDemo = () => {
    if (running) return;
    setRunning(true);
    setCompleted(/* @__PURE__ */ new Set());
    setActiveStep(0);
    let step = 0;
    const advance = () => {
      setCompleted((prev) => /* @__PURE__ */ new Set([...prev, step]));
      step++;
      if (step < DEMO_STEPS.length) {
        setActiveStep(step);
        timeoutRef.current = setTimeout(advance, DEMO_STEPS[step].duration);
      } else {
        setCompleted((prev) => /* @__PURE__ */ new Set([...prev, step - 1]));
        setActiveStep(-1);
        setRunning(false);
      }
    };
    timeoutRef.current = setTimeout(advance, DEMO_STEPS[0].duration);
  };
  React.useEffect(() => () => clearTimeout(timeoutRef.current), []);
  const allDone = completed.size === DEMO_STEPS.length;
  return /* @__PURE__ */ React.createElement("section", { style: {
    padding: bp.mobile ? "60px 20px" : "100px 40px",
    background: t.bgSecondary,
    borderTop: `1px solid ${t.border}`,
    borderBottom: `1px solid ${t.border}`
  } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "LIVE DEMO"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: bp.mobile ? 32 : "clamp(36px, 5vw, 56px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 12px",
    lineHeight: 1.05
  } }, "See it ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "run")), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 15,
    color: t.textDim,
    lineHeight: 1.7,
    margin: "0 0 40px",
    maxWidth: 480
  } }, "Watch an autonomous agent execute a shielded payment through the full xB77 pipeline.")), /* @__PURE__ */ React.createElement(FadeIn, { delay: 0.15 }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: bp.mobile ? "1fr" : "repeat(4, 1fr)",
    gap: 0,
    marginBottom: 32
  } }, DEMO_STEPS.map((step, i) => {
    const isActive = activeStep === i;
    const isDone = completed.has(i);
    const isPending = !isActive && !isDone;
    return /* @__PURE__ */ React.createElement("div", { key: step.id, style: {
      position: "relative",
      padding: bp.mobile ? "20px" : "28px 24px",
      background: isActive ? t.accentDim : isDone ? t.bgCard : "transparent",
      border: `1px solid ${isActive ? t.accent : t.border}`,
      borderRight: !bp.mobile && i < 3 ? "none" : `1px solid ${isActive ? t.accent : t.border}`,
      transition: "all 0.4s"
    } }, isActive && /* @__PURE__ */ React.createElement("div", { style: {
      position: "absolute",
      bottom: 0,
      left: 0,
      height: 2,
      background: t.accent,
      animation: `progressBar ${step.duration}ms linear forwards`
    } }), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 10, marginBottom: 12 } }, /* @__PURE__ */ React.createElement("div", { style: {
      width: 10,
      height: 10,
      borderRadius: "50%",
      background: isDone ? t.accent : isActive ? t.accent : "transparent",
      border: `2px solid ${isDone ? t.accent : isActive ? t.accent : t.textDim}`,
      transition: "all 0.3s",
      boxShadow: isActive ? `0 0 12px ${t.terminalGlow}` : "none"
    } }), /* @__PURE__ */ React.createElement("span", { style: {
      fontFamily: "var(--mono)",
      fontSize: 9,
      letterSpacing: "0.12em",
      color: isDone ? t.accent : isActive ? t.accent : t.textDim,
      transition: "color 0.3s"
    } }, step.tag)), /* @__PURE__ */ React.createElement("h4", { style: {
      fontFamily: "var(--mono)",
      fontSize: 14,
      fontWeight: 600,
      color: isPending ? t.textDim : t.text,
      margin: "0 0 8px",
      transition: "color 0.3s"
    } }, step.label), /* @__PURE__ */ React.createElement("p", { style: {
      fontFamily: "var(--sans)",
      fontSize: 12.5,
      color: t.textDim,
      lineHeight: 1.5,
      margin: 0,
      opacity: isPending ? 0.4 : 0.8,
      transition: "opacity 0.3s"
    } }, step.detail), isDone && /* @__PURE__ */ React.createElement("div", { style: {
      position: "absolute",
      top: 12,
      right: 12,
      fontFamily: "var(--mono)",
      fontSize: 10,
      color: t.accent
    } }, "\u2713"));
  }))), /* @__PURE__ */ React.createElement(FadeIn, { delay: 0.25 }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 16 } }, /* @__PURE__ */ React.createElement("button", { onClick: runDemo, disabled: running, "data-tour-run": true, style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    background: running ? "transparent" : t.accent,
    color: running ? t.accent : t.bg,
    border: `1px solid ${t.accent}`,
    padding: "14px 32px",
    cursor: running ? "default" : "pointer",
    fontWeight: 600,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
    transition: "all 0.3s",
    opacity: running ? 0.6 : 1
  } }, running ? "Executing..." : allDone ? "Run Again" : "Execute Pipeline"), allDone && /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    color: t.accent,
    animation: "fadeInLine 0.5s ease"
  } }, "Pipeline complete \u2014 Ghost Receipt generated \u2713")))), /* @__PURE__ */ React.createElement("style", null, `
        @keyframes progressBar {
          from { width: 0%; }
          to { width: 100%; }
        }
      `));
}
function LiveMetrics({ theme }) {
  const t = THEMES[theme || "obsidian"];
  const bp = useBreakpoint();
  const [hovered, setHovered] = React.useState(null);
  const metrics = [
    { label: "Pipelines Active", value: 2847, suffix: "", prefix: "" },
    { label: "Shielded Txns", value: 184329, suffix: "", prefix: "" },
    { label: "ZK Proofs Generated", value: 91204, suffix: "", prefix: "" },
    { label: "Infra Tax Collected", value: 47891, suffix: " USDC", prefix: "" },
    { label: "Avg Proof Time", value: 198, suffix: "ms", prefix: "" },
    { label: "Compression Ratio", value: 99.7, suffix: "%", prefix: "" }
  ];
  return /* @__PURE__ */ React.createElement("section", { style: {
    padding: bp.mobile ? "60px 20px" : "80px 40px",
    borderBottom: `1px solid ${t.border}`,
    background: t.bg
  } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "NETWORK STATUS")), /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: bp.mobile ? "repeat(2, 1fr)" : "repeat(6, 1fr)",
    gap: 0
  } }, metrics.map((m, i) => /* @__PURE__ */ React.createElement(FadeIn, { key: i, delay: 0.05 * i }, /* @__PURE__ */ React.createElement(
    "div",
    {
      style: {
        padding: bp.mobile ? "20px 16px" : "24px 20px",
        borderRight: !bp.mobile && i < 5 ? `1px solid ${t.border}` : "none",
        borderBottom: bp.mobile && i < 4 ? `1px solid ${t.border}` : bp.mobile ? "none" : `1px solid ${t.border}`,
        borderTop: `1px solid ${t.border}`,
        cursor: "default",
        transition: "background 0.3s",
        background: hovered === i ? t.bgCard : "transparent"
      },
      onMouseEnter: () => setHovered(i),
      onMouseLeave: () => setHovered(null)
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 8, color: t.textDim, letterSpacing: "0.15em", marginBottom: 8, textTransform: "uppercase" } }, m.label),
    /* @__PURE__ */ React.createElement("div", { style: {
      fontFamily: "var(--mono)",
      fontSize: bp.mobile ? 18 : 22,
      fontWeight: 700,
      color: hovered === i ? t.accent : t.text,
      transition: "color 0.3s"
    } }, /* @__PURE__ */ React.createElement(AnimatedCounter, { target: m.value, prefix: m.prefix, suffix: m.suffix, duration: 1800 }))
  ))))));
}
Object.assign(window, { PipelineDemo, LiveMetrics, DEMO_STEPS });
