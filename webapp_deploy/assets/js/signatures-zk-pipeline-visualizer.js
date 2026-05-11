(function() {
  const STAGES = [
    { id: "AGENT", label: "Agent", contract: "neural_key.sol", hint: "Sign intent" },
    { id: "PROOF_GEN", label: "Proof Gen", contract: "xb77_zk_engine", hint: "SNARK build" },
    { id: "CHUNK_UPLOAD", label: "Chunk Upload", contract: "sframe.upload", hint: "Compress + push" },
    { id: "VERIFY", label: "Verify", contract: "verifier_stub", hint: "On-chain check" },
    { id: "SETTLED", label: "Settled", contract: "magicblock.tx", hint: "< 1s finality" }
  ];
  const COLORS = {
    bg: "#0a0a0c",
    nodeBg: "#101013",
    border: "rgba(255,255,255,0.10)",
    lime: "#c8ff2e",
    cyan: "#5cf2ff",
    text: "#e8e8ec",
    textDim: "rgba(232,232,236,0.55)",
    mono: "rgba(232,232,236,0.35)"
  };
  const CYCLE_MS = 9e3;
  function usePulseProgress(cycleMs) {
    const [t, setT] = React.useState(0);
    React.useEffect(() => {
      let raf, start;
      const tick = (now) => {
        if (start == null) start = now;
        const p = (now - start) % cycleMs / cycleMs;
        setT(p);
        raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
      return () => cancelAnimationFrame(raf);
    }, [cycleMs]);
    return t;
  }
  function ZKPipelineVisualizer(props) {
    const variant = props.variant || "compact";
    const liveData = props.liveData || null;
    const expanded = variant === "expanded";
    const t = usePulseProgress(CYCLE_MS);
    const N = STAGES.length;
    const W = expanded ? 1100 : 720;
    const H = expanded ? 260 : 160;
    const padX = 60;
    const innerW = W - padX * 2;
    const stepX = innerW / (N - 1);
    const cy = expanded ? 130 : 80;
    const r = expanded ? 26 : 20;
    const segCount = N - 1;
    const segT = t * segCount;
    const segIdx = Math.floor(segT) % segCount;
    const segLocal = segT - Math.floor(segT);
    const eased = segLocal < 0.5 ? 2 * segLocal * segLocal : 1 - Math.pow(-2 * segLocal + 2, 2) / 2;
    const packetX = padX + segIdx * stepX + eased * stepX;
    const packetY = cy;
    const arrivalWindow = 0.15;
    const nearTarget = segLocal > 1 - arrivalWindow;
    const activeIdx = nearTarget ? (segIdx + 1) % N : segIdx;
    const pulseStrength = nearTarget ? (segLocal - (1 - arrivalWindow)) / arrivalWindow : 0;
    return /* @__PURE__ */ React.createElement("div", { style: {
      width: "100%",
      background: "transparent",
      overflowX: "auto",
      padding: expanded ? "24px 0" : "12px 0"
    } }, /* @__PURE__ */ React.createElement(
      "svg",
      {
        viewBox: `0 0 ${W} ${H}`,
        width: "100%",
        style: { display: "block", maxWidth: W, margin: "0 auto", minWidth: 560 },
        "aria-label": "xB77 ZK Pipeline"
      },
      /* @__PURE__ */ React.createElement("defs", null, /* @__PURE__ */ React.createElement("filter", { id: "zkGlowCyan", x: "-50%", y: "-50%", width: "200%", height: "200%" }, /* @__PURE__ */ React.createElement("feGaussianBlur", { stdDeviation: "3.2", result: "blur" }), /* @__PURE__ */ React.createElement("feMerge", null, /* @__PURE__ */ React.createElement("feMergeNode", { in: "blur" }), /* @__PURE__ */ React.createElement("feMergeNode", { in: "SourceGraphic" }))), /* @__PURE__ */ React.createElement("filter", { id: "zkGlowLime", x: "-50%", y: "-50%", width: "200%", height: "200%" }, /* @__PURE__ */ React.createElement("feGaussianBlur", { stdDeviation: "2.5", result: "blur" }), /* @__PURE__ */ React.createElement("feMerge", null, /* @__PURE__ */ React.createElement("feMergeNode", { in: "blur" }), /* @__PURE__ */ React.createElement("feMergeNode", { in: "SourceGraphic" }))), /* @__PURE__ */ React.createElement("linearGradient", { id: "zkTrail", x1: "0", x2: "1", y1: "0", y2: "0" }, /* @__PURE__ */ React.createElement("stop", { offset: "0%", stopColor: COLORS.cyan, stopOpacity: "0" }), /* @__PURE__ */ React.createElement("stop", { offset: "100%", stopColor: COLORS.cyan, stopOpacity: "0.7" }))),
      /* @__PURE__ */ React.createElement(
        "line",
        {
          x1: padX,
          y1: cy,
          x2: W - padX,
          y2: cy,
          stroke: COLORS.border,
          strokeWidth: "1",
          strokeDasharray: "2 4"
        }
      ),
      /* @__PURE__ */ React.createElement(
        "rect",
        {
          x: Math.max(padX, packetX - 60),
          y: cy - 1,
          width: Math.min(60, packetX - padX),
          height: 2,
          fill: "url(#zkTrail)"
        }
      ),
      /* @__PURE__ */ React.createElement(
        "circle",
        {
          cx: packetX,
          cy: packetY,
          r: 5,
          fill: COLORS.cyan,
          filter: "url(#zkGlowCyan)"
        }
      ),
      STAGES.map((s, i) => {
        const x = padX + i * stepX;
        const isActive = i === activeIdx;
        const intensity = isActive ? Math.max(0.4, pulseStrength) : 0;
        const ringColor = isActive ? COLORS.lime : COLORS.border;
        const fillColor = COLORS.nodeBg;
        const live = liveData && liveData[s.id];
        return /* @__PURE__ */ React.createElement("g", { key: s.id }, /* @__PURE__ */ React.createElement(
          "circle",
          {
            cx: x,
            cy,
            r,
            fill: fillColor,
            stroke: ringColor,
            strokeWidth: isActive ? 2 : 1,
            filter: isActive ? "url(#zkGlowLime)" : void 0,
            opacity: isActive ? 0.6 + 0.4 * intensity : 1
          }
        ), /* @__PURE__ */ React.createElement(
          "circle",
          {
            cx: x,
            cy,
            r: r - 6,
            fill: "none",
            stroke: isActive ? COLORS.lime : COLORS.mono,
            strokeWidth: "1",
            opacity: isActive ? intensity : 0.35
          }
        ), /* @__PURE__ */ React.createElement(
          "text",
          {
            x,
            y: cy + 4,
            textAnchor: "middle",
            fontFamily: "var(--mono, monospace)",
            fontSize: expanded ? 12 : 10,
            fontWeight: "600",
            fill: isActive ? COLORS.lime : COLORS.text,
            opacity: isActive ? 1 : 0.85
          },
          String(i + 1).padStart(2, "0")
        ), /* @__PURE__ */ React.createElement(
          "text",
          {
            x,
            y: cy + r + 18,
            textAnchor: "middle",
            fontFamily: "var(--mono, monospace)",
            fontSize: expanded ? 11 : 9.5,
            fill: COLORS.textDim,
            letterSpacing: "0.12em"
          },
          s.label.toUpperCase()
        ), expanded && live && /* @__PURE__ */ React.createElement(
          "text",
          {
            x,
            y: cy - r - 14,
            textAnchor: "middle",
            fontFamily: "var(--mono, monospace)",
            fontSize: "13",
            fontWeight: "600",
            fill: COLORS.cyan
          },
          typeof live.count === "number" ? live.count.toLocaleString() : live.count || "\u2014"
        ), expanded && live && /* @__PURE__ */ React.createElement(
          "text",
          {
            x,
            y: cy - r - 30,
            textAnchor: "middle",
            fontFamily: "var(--mono, monospace)",
            fontSize: "9",
            fill: COLORS.mono,
            letterSpacing: "0.15em"
          },
          live.latencyMs != null ? `P50 ${live.latencyMs}ms` : ""
        ));
      })
    ), expanded && /* @__PURE__ */ React.createElement("div", { style: {
      display: "grid",
      gridTemplateColumns: `repeat(${N}, 1fr)`,
      gap: 8,
      maxWidth: W,
      margin: "20px auto 0",
      padding: "0 16px"
    } }, STAGES.map((s, i) => {
      const live = liveData && liveData[s.id];
      return /* @__PURE__ */ React.createElement("div", { key: s.id, style: {
        border: `1px solid ${COLORS.border}`,
        padding: "12px 14px",
        background: "rgba(255,255,255,0.015)"
      } }, /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--mono, monospace)",
        fontSize: 9,
        color: COLORS.lime,
        letterSpacing: "0.15em",
        marginBottom: 6
      } }, String(i + 1).padStart(2, "0"), " \xB7 ", s.label.toUpperCase()), /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--mono, monospace)",
        fontSize: 11,
        color: COLORS.text,
        marginBottom: 4
      } }, s.contract), /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: "var(--sans, system-ui)",
        fontSize: 11,
        color: COLORS.textDim,
        lineHeight: 1.5
      } }, s.hint), live && live.chunkBytes != null && /* @__PURE__ */ React.createElement("div", { style: {
        marginTop: 8,
        fontFamily: "var(--mono, monospace)",
        fontSize: 10,
        color: COLORS.cyan
      } }, "chunk ", live.chunkBytes, "B"));
    })));
  }
  window.ZKPipelineVisualizer = ZKPipelineVisualizer;
})();
