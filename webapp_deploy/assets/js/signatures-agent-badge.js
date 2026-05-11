(function() {
  const PALETTE = {
    bg: "var(--bg)",
    lime: "var(--accent)",
    cyan: "#5cf2ff",
    magenta: "#ff2e88",
    dim: "var(--border)",
    text: "var(--text)",
    textDim: "rgba(232,232,236,0.5)"
  };
  function fnv1a(str) {
    let h = 2166136261 >>> 0;
    for (let i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i);
      h = Math.imul(h, 16777619) >>> 0;
    }
    return h >>> 0;
  }
  function expandHash(seed) {
    const out = new Uint8Array(8);
    let h = seed >>> 0;
    for (let i = 0; i < 8; i++) {
      h = Math.imul(h ^ h >>> 16, 2246822507) >>> 0;
      h = Math.imul(h ^ h >>> 13, 3266489909) >>> 0;
      h = (h ^ h >>> 16) >>> 0;
      out[i] = h & 255;
    }
    return out;
  }
  function pickColors(seed) {
    const colors = [PALETTE.lime, PALETTE.cyan, PALETTE.magenta];
    const primaryIdx = seed % 3;
    const secondaryIdx = (primaryIdx + 1 + (seed >>> 8) % 2) % 3;
    return { primary: colors[primaryIdx], secondary: colors[secondaryIdx] };
  }
  function truncate(pk) {
    if (!pk) return "\u2014";
    if (pk.length <= 11) return pk;
    return pk.slice(0, 4) + "\u2026" + pk.slice(-4);
  }
  function AgentBadge(props) {
    const pubkey = props.pubkey || "";
    const size = props.size || 48;
    const showLabel = props.showLabel !== false;
    const interactive = props.interactive !== false;
    const [hover, setHover] = React.useState(false);
    const [copied, setCopied] = React.useState(false);
    const seed = React.useMemo(() => fnv1a(pubkey), [pubkey]);
    const bytes = React.useMemo(() => expandHash(seed), [seed]);
    const { primary, secondary } = React.useMemo(() => pickColors(seed), [seed]);
    const cells = [];
    for (let r = 0; r < 8; r++) {
      const row = [];
      for (let c = 0; c < 4; c++) {
        const bit = bytes[r] >> c & 1;
        const colorBit = bytes[(r + 4) % 8] >> c + 4 & 1;
        row.push(bit ? colorBit ? primary : secondary : null);
      }
      const mirrored = row.slice().reverse();
      cells.push([...row, ...mirrored]);
    }
    const cellPx = size / 8;
    const reputation = (seed >>> 24 & 127) / 127;
    const handleCopy = React.useCallback((e) => {
      if (!interactive || !pubkey) return;
      e.stopPropagation();
      if (navigator.clipboard) {
        navigator.clipboard.writeText(pubkey).then(() => {
          setCopied(true);
          setTimeout(() => setCopied(false), 1400);
        }).catch(() => {
        });
      }
    }, [interactive, pubkey]);
    const halo = hover && interactive ? `0 0 0 1px ${primary}, 0 0 24px ${primary}55, 0 0 48px ${primary}22` : `0 0 0 1px rgba(255,255,255,0.08)`;
    return /* @__PURE__ */ React.createElement(
      "div",
      {
        onMouseEnter: () => setHover(true),
        onMouseLeave: () => setHover(false),
        onClick: handleCopy,
        title: interactive ? copied ? "Copied" : pubkey : pubkey,
        style: {
          display: "inline-flex",
          alignItems: "center",
          gap: 10,
          cursor: interactive ? "pointer" : "default",
          userSelect: "none"
        }
      },
      /* @__PURE__ */ React.createElement(
        "div",
        {
          style: {
            position: "relative",
            width: size,
            height: size,
            background: PALETTE.bg,
            boxShadow: halo,
            transition: "box-shadow 0.25s ease",
            flexShrink: 0,
            overflow: "hidden"
          }
        },
        /* @__PURE__ */ React.createElement("svg", { width: size, height: size, viewBox: `0 0 ${size} ${size}`, style: { display: "block" } }, cells.map(
          (row, r) => row.map(
            (col, c) => col ? /* @__PURE__ */ React.createElement(
              "rect",
              {
                key: `${r}-${c}`,
                x: c * cellPx,
                y: r * cellPx,
                width: cellPx + 0.5,
                height: cellPx + 0.5,
                fill: col,
                opacity: hover && interactive ? 0.95 : 0.85
              }
            ) : null
          )
        )),
        hover && interactive && /* @__PURE__ */ React.createElement(
          "div",
          {
            style: {
              position: "absolute",
              inset: 0,
              pointerEvents: "none",
              background: `linear-gradient(120deg, transparent 40%, ${primary}33 50%, transparent 60%)`,
              animation: "xb77BadgeShimmer 1.4s ease-out"
            }
          }
        )
      ),
      showLabel && /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 4, minWidth: 0 } }, /* @__PURE__ */ React.createElement("div", { style: {
        fontFamily: 'var(--mono, "Geist Mono", "JetBrains Mono", monospace)',
        fontSize: Math.max(10, Math.round(size * 0.22)),
        color: copied ? primary : hover && interactive ? PALETTE.text : PALETTE.textDim,
        letterSpacing: "0.04em",
        transition: "color 0.2s",
        whiteSpace: "nowrap"
      } }, copied ? "COPIED" : hover && interactive ? pubkey : truncate(pubkey)), /* @__PURE__ */ React.createElement("div", { style: {
        display: "flex",
        alignItems: "center",
        gap: 6
      } }, /* @__PURE__ */ React.createElement("span", { style: {
        width: 6,
        height: 6,
        borderRadius: "50%",
        background: primary,
        boxShadow: `0 0 6px ${primary}`
      } }), /* @__PURE__ */ React.createElement("div", { style: {
        position: "relative",
        width: Math.max(40, size * 1.1),
        height: 4,
        background: PALETTE.dim,
        overflow: "hidden"
      } }, /* @__PURE__ */ React.createElement("div", { style: {
        position: "absolute",
        left: 0,
        top: 0,
        bottom: 0,
        width: `${reputation * 100}%`,
        background: PALETTE.lime,
        boxShadow: `0 0 6px ${PALETTE.lime}99`
      } }))))
    );
  }
  if (typeof document !== "undefined" && !document.getElementById("xb77-badge-keyframes")) {
    const s = document.createElement("style");
    s.id = "xb77-badge-keyframes";
    s.textContent = "@keyframes xb77BadgeShimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }";
    document.head.appendChild(s);
  }
  window.AgentBadge = AgentBadge;
})();
