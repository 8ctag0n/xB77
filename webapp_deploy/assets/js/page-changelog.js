const CHANGELOG = [
  {
    version: "v2.0",
    date: "May 2026",
    tag: "CURRENT",
    title: "Agent Infrastructure Pivot",
    changes: [
      { type: "breaking", text: "Removed ShadowWire and Privacy Cash pools \u2014 replaced with proprietary xB77 ZK Engine" },
      { type: "breaking", text: "Removed Light Protocol dependency \u2014 built proprietary ZK compression layer" },
      { type: "new", text: "Easy Deploy \u2014 one-click agent provisioning, self-hosted or cloud" },
      { type: "new", text: "Proprietary ZK Engine \u2014 protocol-level privacy + 99.7% on-chain compression" },
      { type: "new", text: "Interactive Pipeline Demo \u2014 live visualization of agent transaction flow" },
      { type: "new", text: "Live Metrics Dashboard \u2014 real-time network stats with animated counters" },
      { type: "new", text: "Why xB77 page \u2014 competitive comparison vs Tornado Cash, Aztec, Zcash, Secret Network" },
      { type: "new", text: "Full documentation suite \u2014 Quickstart, API Reference, SDK Guide, Protocol Specs" },
      { type: "new", text: "Architecture page \u2014 interactive layer diagram + data flow visualization" },
      { type: "new", text: "Whitepaper \u2014 web editorial format with inline diagrams" },
      { type: "improved", text: "Repositioned as Agent Infrastructure (like OpenClaw) \u2014 not a mixer or privacy coin" },
      { type: "improved", text: "Scroll animations + fade-in across all pages" },
      { type: "improved", text: "Mobile responsive layouts" },
      { type: "improved", text: "Micro-animations \u2014 shimmer buttons, glow hovers, animated architecture diagram" },
      { type: "improved", text: "Syntax highlighting in documentation code blocks" },
      { type: "improved", text: "OG Meta tags on all 11 pages for social sharing" },
      { type: "improved", text: "Unified navigation across entire ecosystem" },
      { type: "improved", text: 'Tokenomics section \u2014 "The 2.011% Engine" pipeline visualization' },
      { type: "improved", text: "Git-graph style Roadmap with 3 phases" }
    ]
  },
  {
    version: "v1.0",
    date: "April 2026",
    tag: "LEGACY",
    title: "Initial Release \u2014 VitePress",
    link: "https://8ctag0n.github.io/xB77/",
    changes: [
      { type: "new", text: "VitePress-based documentation site" },
      { type: "new", text: "Landing page with terminal animation" },
      { type: "new", text: "ShadowWire shielded payment concept" },
      { type: "new", text: "Privacy Cash pool obfuscation design" },
      { type: "new", text: "Light Protocol ZK-compressed receipts integration" },
      { type: "new", text: "Whitepaper (EN/ES)" },
      { type: "new", text: "Architecture diagrams" },
      { type: "new", text: "Vimeo demo video embed" },
      { type: "new", text: "i18n support (English + Espa\xF1ol)" },
      { type: "new", text: "GitHub Pages deployment" }
    ]
  }
];
const TYPE_STYLES = {
  breaking: { label: "BREAKING", color: "#ff4466" },
  new: { label: "NEW", color: "#c8ff2e" },
  improved: { label: "IMPROVED", color: "#4de8d0" },
  fixed: { label: "FIXED", color: "#ffaa44" }
};
function ChangelogPage() {
  const t = THEMES.obsidian;
  const bp = typeof useBreakpoint === "function" ? useBreakpoint() : { mobile: false };
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh", color: t.text } }, /* @__PURE__ */ React.createElement(InnerNav, { active: "Changelog" }), /* @__PURE__ */ React.createElement("section", { style: { padding: bp.mobile ? "60px 20px" : "100px 40px 80px", maxWidth: 900, margin: "0 auto" } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "CHANGELOG"), /* @__PURE__ */ React.createElement("h1", { style: {
    fontFamily: "var(--serif)",
    fontSize: bp.mobile ? 36 : "clamp(40px, 6vw, 64px)",
    fontWeight: 400,
    color: t.text,
    lineHeight: 1,
    margin: "0 0 16px"
  } }, "What's ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "changed")), /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--sans)", fontSize: 16, color: t.textDim, lineHeight: 1.7, maxWidth: 500 } }, "Evolution of xB77 \u2014 from VitePress docs to full agent infrastructure platform."))), /* @__PURE__ */ React.createElement("section", { style: { padding: bp.mobile ? "0 20px 80px" : "0 40px 120px", maxWidth: 900, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { position: "relative" } }, /* @__PURE__ */ React.createElement("div", { style: {
    position: "absolute",
    left: 23,
    top: 0,
    bottom: 0,
    width: 2,
    background: `linear-gradient(to bottom, ${t.accent}, ${t.border})`
  } }), CHANGELOG.map((release, ri) => {
    const isCurrent = release.tag === "CURRENT";
    return /* @__PURE__ */ React.createElement(FadeIn, { key: ri, delay: ri * 0.1 }, /* @__PURE__ */ React.createElement("div", { style: { position: "relative", marginBottom: 64 } }, /* @__PURE__ */ React.createElement("div", { style: {
      position: "absolute",
      left: 12,
      top: 0,
      zIndex: 2,
      width: 24,
      height: 24,
      borderRadius: "50%",
      background: isCurrent ? t.accent : t.bg,
      border: `2px solid ${isCurrent ? t.accent : t.textDim}`,
      boxShadow: isCurrent ? `0 0 20px ${t.terminalGlow}` : "none",
      display: "flex",
      alignItems: "center",
      justifyContent: "center"
    } }, isCurrent && /* @__PURE__ */ React.createElement("div", { style: { width: 8, height: 8, borderRadius: "50%", background: t.bg } })), /* @__PURE__ */ React.createElement("div", { style: { marginLeft: 56 } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "baseline", gap: 12, marginBottom: 4, flexWrap: "wrap" } }, /* @__PURE__ */ React.createElement("span", { style: {
      fontFamily: "var(--mono)",
      fontSize: 22,
      fontWeight: 700,
      color: isCurrent ? t.accent : t.text
    } }, release.version), isCurrent && /* @__PURE__ */ React.createElement("span", { style: {
      fontFamily: "var(--mono)",
      fontSize: 9,
      color: t.bg,
      background: t.accent,
      padding: "2px 8px",
      fontWeight: 600
    } }, "CURRENT"), release.link && /* @__PURE__ */ React.createElement("a", { href: release.link, target: "_blank", rel: "noopener", style: {
      fontFamily: "var(--mono)",
      fontSize: 10,
      color: t.accent,
      textDecoration: "none",
      opacity: 0.7
    } }, "VIEW LEGACY SITE \u2192")), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.textDim, marginBottom: 4 } }, release.date), /* @__PURE__ */ React.createElement("h3", { style: {
      fontFamily: "var(--serif)",
      fontSize: 24,
      fontWeight: 400,
      fontStyle: "italic",
      color: isCurrent ? t.text : t.textDim,
      margin: "0 0 20px"
    } }, release.title), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 8 } }, release.changes.map((change, ci) => {
      const ts = TYPE_STYLES[change.type];
      return /* @__PURE__ */ React.createElement("div", { key: ci, style: {
        display: "flex",
        gap: 12,
        alignItems: "baseline",
        padding: "8px 0"
      } }, /* @__PURE__ */ React.createElement("span", { style: {
        fontFamily: "var(--mono)",
        fontSize: 9,
        fontWeight: 600,
        color: ts.color,
        letterSpacing: "0.08em",
        minWidth: 72,
        flexShrink: 0
      } }, ts.label), /* @__PURE__ */ React.createElement("span", { style: {
        fontFamily: "var(--sans)",
        fontSize: 14,
        color: t.textDim,
        lineHeight: 1.5
      } }, change.text));
    })))));
  }))), /* @__PURE__ */ React.createElement(PageFooter, null));
}
Object.assign(window, { ChangelogPage });
