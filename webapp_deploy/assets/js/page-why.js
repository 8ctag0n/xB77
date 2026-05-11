const COMPETITORS = [
  {
    name: "Tornado Cash",
    type: "Mixer",
    status: "Sanctioned",
    privacy: "Deposit/Withdraw pools",
    compliance: "None \u2014 sanctioned by OFAC",
    agents: "No agent support",
    chain: "Ethereum",
    compression: "None",
    speed: "~15 min (Ethereum blocks)",
    model: "No sustainability model"
  },
  {
    name: "Aztec / Noir",
    type: "ZK L2",
    status: "Active (testnet)",
    privacy: "Full L2 privacy",
    compliance: "Optional selective disclosure",
    agents: "No native agent framework",
    chain: "Ethereum L2",
    compression: "ZK rollup batching",
    speed: "~10 min (rollup finality)",
    model: "L2 gas fees"
  },
  {
    name: "Zcash",
    type: "L1 Chain",
    status: "Active",
    privacy: "Shielded transactions (Sapling)",
    compliance: "View keys for auditors",
    agents: "No agent support",
    chain: "Zcash (own chain)",
    compression: "None",
    speed: "~75 sec (Zcash blocks)",
    model: "Block rewards (inflationary)"
  },
  {
    name: "Secret Network",
    type: "L1 Chain",
    status: "Active",
    privacy: "Encrypted smart contracts (TEE)",
    compliance: "Limited \u2014 TEE-dependent",
    agents: "No native agent framework",
    chain: "Cosmos IBC",
    compression: "None",
    speed: "~6 sec",
    model: "Staking + gas fees"
  }
];
const XB77_ROW = {
  name: "xB77",
  type: "Infrastructure Layer",
  status: "Active (Hackathon)",
  privacy: "Proprietary ZK Engine \u2014 protocol-level privacy",
  compliance: "Constitutional governance + selective ZK disclosure",
  agents: "Native autonomous agent framework with Neural Key auth",
  chain: "Solana (400ms blocks)",
  compression: "xB77 ZK Engine \u2014 99.7% reduction",
  speed: "< 1 sec (MagicBlock Turbo)",
  model: "2.011% Infra Tax \u2192 Sovereign Credits"
};
const COMPARE_ROWS = [
  { key: "type", label: "Type" },
  { key: "status", label: "Status" },
  { key: "privacy", label: "Privacy Model" },
  { key: "compliance", label: "Compliance" },
  { key: "agents", label: "Agent Support" },
  { key: "chain", label: "Chain" },
  { key: "compression", label: "State Compression" },
  { key: "speed", label: "Finality" },
  { key: "model", label: "Economic Model" }
];
const ADVANTAGES = [
  { title: "Built for Agents, Not Humans", desc: "xB77 is the only agent infrastructure designed from the ground up for autonomous AI agents \u2014 not human wallets. Neural Key auth, Constitutional governance, one-click deploy." },
  { title: "Privacy + Compliance", desc: "Unlike mixers (sanctioned) or full-privacy chains (opaque), xB77 offers selective ZK disclosure \u2014 agents prove compliance without revealing strategy. Math-enforced, not trust-based." },
  { title: "Solana Speed", desc: "Sub-second finality via MagicBlock Turbo Rail. No waiting for Ethereum blocks or rollup batches. Agents trade at machine speed." },
  { title: "99.7% Compression", desc: "xB77's proprietary ZK engine compresses 10,000 transactions into a single 32-byte proof. Orders of magnitude cheaper than any competitor." },
  { title: "Self-Sustaining", desc: "No inflationary token. The 2.011% Infra Tax creates a self-sustaining infrastructure fund (Sovereign Credits) that subsidizes the entire network." }
];
function WhyPage() {
  const t = THEMES.obsidian;
  const bp = typeof useBreakpoint === "function" ? useBreakpoint() : { mobile: false };
  const [hoveredRow, setHoveredRow] = React.useState(null);
  const [hoveredAdv, setHoveredAdv] = React.useState(null);
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh", color: t.text } }, /* @__PURE__ */ React.createElement(InnerNav, { active: "Why xB77" }), /* @__PURE__ */ React.createElement("section", { style: {
    position: "relative",
    padding: bp.mobile ? "80px 20px 60px" : "140px 40px 100px",
    maxWidth: 1200,
    margin: "0 auto",
    overflow: "hidden"
  } }, !bp.mobile && /* @__PURE__ */ React.createElement("div", { "aria-hidden": "true", style: {
    position: "absolute",
    inset: 0,
    pointerEvents: "none",
    display: "flex",
    alignItems: "center",
    justifyContent: "flex-end",
    paddingRight: 40,
    zIndex: 0,
    overflow: "hidden"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--serif)",
    fontStyle: "italic",
    fontSize: "clamp(8rem, 18vw, 22rem)",
    color: t.accent,
    opacity: 0.04,
    lineHeight: 0.85,
    letterSpacing: "-0.04em",
    userSelect: "none",
    whiteSpace: "nowrap"
  } }, "WHY")), /* @__PURE__ */ React.createElement(FadeIn, { style: { position: "relative", zIndex: 1 } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: t.accent,
    letterSpacing: "0.3em",
    marginBottom: 28,
    textTransform: "uppercase"
  } }, "// WHY xB77"), /* @__PURE__ */ React.createElement("h1", { style: {
    fontFamily: "var(--serif)",
    fontSize: bp.mobile ? "clamp(38px, 10vw, 56px)" : "clamp(56px, 7.5vw, 116px)",
    fontWeight: 400,
    fontStyle: "italic",
    color: t.text,
    lineHeight: 0.95,
    margin: "0 0 36px",
    letterSpacing: "-0.035em"
  } }, "Sovereignty is", /* @__PURE__ */ React.createElement("br", null), "not given.", /* @__PURE__ */ React.createElement("br", null), /* @__PURE__ */ React.createElement("span", { style: { color: t.accent } }, "It is computed.")), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: bp.mobile ? 16 : 18,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 640,
    margin: "0 0 18px"
  } }, "xB77 is not a privacy coin, a mixer, or another ZK rollup. It is the substrate for an autonomous machine economy \u2014 where agents settle, prove, and govern without asking permission."), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: bp.mobile ? 15 : 17,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 640,
    margin: 0,
    opacity: 0.85
  } }, "Math-enforced privacy. Sub-second settlement. Selective disclosure on demand. The rules are in the code, not in the prospectus."))), /* @__PURE__ */ React.createElement("section", { style: {
    padding: bp.mobile ? "0 20px 80px" : "0 40px 120px",
    maxWidth: 1200,
    margin: "0 auto"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "grid",
    gridTemplateColumns: bp.mobile ? "1fr" : "1fr 1fr",
    gap: 0,
    borderTop: `1px solid ${t.border}`,
    borderBottom: `1px solid ${t.border}`
  } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("div", { style: {
    padding: bp.mobile ? "40px 0" : "56px 48px 56px 0",
    borderRight: bp.mobile ? "none" : `1px solid ${t.border}`,
    borderBottom: bp.mobile ? `1px solid ${t.border}` : "none"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.accent,
    letterSpacing: "0.25em",
    marginBottom: 18,
    textTransform: "uppercase"
  } }, "// THE THESIS"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontStyle: "italic",
    fontWeight: 400,
    fontSize: bp.mobile ? 28 : "clamp(28px, 3.4vw, 42px)",
    color: t.text,
    margin: "0 0 20px",
    lineHeight: 1.1
  } }, "Agents will move more money than humans."), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 15,
    color: t.textDim,
    lineHeight: 1.7,
    margin: "0 0 20px"
  } }, "The next decade's settlement layer will be operated by software that negotiates, pays, and audits itself. Existing rails were built for humans: KYC at the door, surveillance by default, finality measured in minutes."), /* @__PURE__ */ React.createElement("ul", { style: {
    listStyle: "none",
    padding: 0,
    margin: 0,
    fontFamily: "var(--sans)",
    fontSize: 14,
    color: t.text,
    lineHeight: 1.8
  } }, [
    "Identity as cryptographic keypair, not corporate account",
    "Privacy as protocol default, not opt-in feature",
    "Compliance as selective proof, not bulk disclosure",
    "Settlement as machine-speed, not banking hours"
  ].map((item, i) => /* @__PURE__ */ React.createElement("li", { key: i, style: { display: "flex", gap: 12, padding: "6px 0" } }, /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    color: t.accent,
    fontSize: 11,
    width: 22,
    flexShrink: 0,
    opacity: 0.7
  } }, String(i + 1).padStart(2, "0")), /* @__PURE__ */ React.createElement("span", { style: { color: t.textDim } }, item)))))), /* @__PURE__ */ React.createElement(FadeIn, { delay: 0.15 }, /* @__PURE__ */ React.createElement("div", { style: {
    padding: bp.mobile ? "40px 0" : "56px 0 56px 48px"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.accent,
    letterSpacing: "0.25em",
    marginBottom: 18,
    textTransform: "uppercase"
  } }, "// WHY NOW"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontStyle: "italic",
    fontWeight: 400,
    fontSize: bp.mobile ? 28 : "clamp(28px, 3.4vw, 42px)",
    color: t.text,
    margin: "0 0 20px",
    lineHeight: 1.1
  } }, "The stack just became possible."), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 15,
    color: t.textDim,
    lineHeight: 1.7,
    margin: "0 0 20px"
  } }, "Three things had to converge: ZK proofs cheap enough to run per-action, a chain fast enough to be agent-native, and language models capable enough to be trusted with capital. They have."), /* @__PURE__ */ React.createElement("ul", { style: {
    listStyle: "none",
    padding: 0,
    margin: 0,
    fontFamily: "var(--sans)",
    fontSize: 14,
    color: t.text,
    lineHeight: 1.8
  } }, [
    "SNARK provers now build proofs in milliseconds, not minutes",
    "Solana + MagicBlock deliver sub-second confirmed settlement",
    "Autonomous agents are no longer demos \u2014 they hold real budgets",
    "Regulators want selective disclosure, not surveillance, in 2026"
  ].map((item, i) => /* @__PURE__ */ React.createElement("li", { key: i, style: { display: "flex", gap: 12, padding: "6px 0" } }, /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    color: t.accent,
    fontSize: 11,
    width: 22,
    flexShrink: 0,
    opacity: 0.7
  } }, String(i + 1).padStart(2, "0")), /* @__PURE__ */ React.createElement("span", { style: { color: t.textDim } }, item)))))))), /* @__PURE__ */ React.createElement("section", { style: { padding: bp.mobile ? "0 12px 60px" : "0 40px 100px" } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1200, margin: "0 auto", overflowX: "auto" } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("table", { style: { width: "100%", borderCollapse: "collapse", minWidth: 900 } }, /* @__PURE__ */ React.createElement("thead", null, /* @__PURE__ */ React.createElement("tr", null, /* @__PURE__ */ React.createElement("th", { style: { padding: "16px 20px", textAlign: "left", fontFamily: "var(--mono)", fontSize: 9, color: t.textDim, letterSpacing: "0.15em", borderBottom: `2px solid ${t.border}`, width: 140 } }, "FEATURE"), /* @__PURE__ */ React.createElement("th", { style: { padding: "16px 20px", textAlign: "left", fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.08em", borderBottom: `2px solid ${t.accent}`, background: t.accentDim, fontWeight: 700 } }, "xB77"), COMPETITORS.map((c) => /* @__PURE__ */ React.createElement("th", { key: c.name, style: { padding: "16px 20px", textAlign: "left", fontFamily: "var(--mono)", fontSize: 11, color: t.textDim, letterSpacing: "0.08em", borderBottom: `2px solid ${t.border}`, fontWeight: 500 } }, c.name)))), /* @__PURE__ */ React.createElement("tbody", null, COMPARE_ROWS.map((row, ri) => /* @__PURE__ */ React.createElement(
    "tr",
    {
      key: row.key,
      onMouseEnter: () => setHoveredRow(ri),
      onMouseLeave: () => setHoveredRow(null),
      style: { background: hoveredRow === ri ? t.bgCard : "transparent", transition: "background 0.2s" }
    },
    /* @__PURE__ */ React.createElement("td", { style: { padding: "14px 20px", fontFamily: "var(--mono)", fontSize: 10, color: t.textDim, letterSpacing: "0.1em", borderBottom: `1px solid ${t.border}`, textTransform: "uppercase" } }, row.label),
    /* @__PURE__ */ React.createElement("td", { style: { padding: "14px 20px", fontFamily: "var(--sans)", fontSize: 13, color: t.text, borderBottom: `1px solid ${t.border}`, background: hoveredRow === ri ? t.accentDim : "rgba(200,255,46,0.02)", fontWeight: 500 } }, XB77_ROW[row.key]),
    COMPETITORS.map((c) => /* @__PURE__ */ React.createElement("td", { key: c.name, style: { padding: "14px 20px", fontFamily: "var(--sans)", fontSize: 13, color: t.textDim, borderBottom: `1px solid ${t.border}` } }, c[row.key]))
  ))))))), /* @__PURE__ */ React.createElement("section", { style: { padding: bp.mobile ? "60px 20px" : "100px 40px", background: t.bgSecondary, borderTop: `1px solid ${t.border}` } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 1100, margin: "0 auto" } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, "KEY ADVANTAGES"), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: bp.mobile ? 32 : "clamp(32px, 4vw, 52px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 48px",
    lineHeight: 1.1
  } }, "What makes xB77 ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "different"))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: bp.mobile ? "1fr" : "repeat(3, 1fr)", gap: 0 } }, ADVANTAGES.slice(0, 3).map((adv, i) => /* @__PURE__ */ React.createElement(FadeIn, { key: i, delay: 0.1 * i }, /* @__PURE__ */ React.createElement(
    "div",
    {
      style: {
        padding: "32px 28px",
        borderRight: !bp.mobile && i < 2 ? `1px solid ${t.border}` : "none",
        borderBottom: `1px solid ${t.border}`,
        cursor: "default",
        transition: "background 0.3s",
        background: hoveredAdv === i ? t.bgCard : "transparent"
      },
      onMouseEnter: () => setHoveredAdv(i),
      onMouseLeave: () => setHoveredAdv(null)
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.1em", marginBottom: 12 } }, String(i + 1).padStart(2, "0")),
    /* @__PURE__ */ React.createElement("h3", { style: { fontFamily: "var(--serif)", fontSize: 22, fontWeight: 400, color: t.text, margin: "0 0 10px", fontStyle: "italic" } }, adv.title),
    /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--sans)", fontSize: 14, color: t.textDim, lineHeight: 1.6, margin: 0 } }, adv.desc)
  )))), /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: bp.mobile ? "1fr" : "repeat(2, 1fr)", gap: 0 } }, ADVANTAGES.slice(3).map((adv, i) => /* @__PURE__ */ React.createElement(FadeIn, { key: i, delay: 0.1 * (i + 3) }, /* @__PURE__ */ React.createElement(
    "div",
    {
      style: {
        padding: "32px 28px",
        borderRight: !bp.mobile && i < 1 ? `1px solid ${t.border}` : "none",
        cursor: "default",
        transition: "background 0.3s",
        background: hoveredAdv === i + 3 ? t.bgCard : "transparent"
      },
      onMouseEnter: () => setHoveredAdv(i + 3),
      onMouseLeave: () => setHoveredAdv(null)
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.1em", marginBottom: 12 } }, String(i + 4).padStart(2, "0")),
    /* @__PURE__ */ React.createElement("h3", { style: { fontFamily: "var(--serif)", fontSize: 22, fontWeight: 400, color: t.text, margin: "0 0 10px", fontStyle: "italic" } }, adv.title),
    /* @__PURE__ */ React.createElement("p", { style: { fontFamily: "var(--sans)", fontSize: 14, color: t.textDim, lineHeight: 1.6, margin: 0 } }, adv.desc)
  )))))), /* @__PURE__ */ React.createElement("section", { style: { padding: bp.mobile ? "60px 20px" : "80px 40px", textAlign: "center" } }, /* @__PURE__ */ React.createElement(FadeIn, null, /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: bp.mobile ? 28 : 44,
    fontWeight: 400,
    color: t.text,
    margin: "0 0 24px"
  } }, "Ready to see it ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "in action?")), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 16, justifyContent: "center", flexWrap: "wrap" } }, /* @__PURE__ */ React.createElement("a", { href: "dApp.html", style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    background: t.accent,
    color: t.bg,
    border: "none",
    padding: "14px 28px",
    fontWeight: 600,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
    textDecoration: "none",
    cursor: "pointer"
  } }, "Launch dApp"), /* @__PURE__ */ React.createElement("a", { href: "Whitepaper.html", style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    background: "transparent",
    color: t.text,
    border: `1px solid ${t.border}`,
    padding: "14px 28px",
    fontWeight: 500,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
    textDecoration: "none",
    cursor: "pointer"
  } }, "Read Whitepaper"), /* @__PURE__ */ React.createElement("a", { href: "Docs.html", style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    background: "transparent",
    color: t.text,
    border: `1px solid ${t.border}`,
    padding: "14px 28px",
    fontWeight: 500,
    letterSpacing: "0.06em",
    textTransform: "uppercase",
    textDecoration: "none",
    cursor: "pointer"
  } }, "Explore Docs")))), /* @__PURE__ */ React.createElement(PageFooter, null));
}
Object.assign(window, { WhyPage });
