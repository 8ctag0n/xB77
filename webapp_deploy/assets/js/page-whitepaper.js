function WhitepaperPage() {
  const t = THEMES.obsidian;
  const Section = ({ tag, title, children }) => /* @__PURE__ */ React.createElement("section", { style: { padding: "100px 40px", maxWidth: 860, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.2em", marginBottom: 12, textTransform: "uppercase" } }, tag), /* @__PURE__ */ React.createElement("h2", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(28px, 4vw, 48px)",
    fontWeight: 400,
    color: t.text,
    margin: "0 0 32px",
    lineHeight: 1.1
  } }, title), children);
  const P = ({ children, bold }) => /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 16,
    color: bold ? t.text : t.textDim,
    lineHeight: 1.8,
    margin: "0 0 20px",
    fontWeight: bold ? 500 : 400
  } }, children);
  const Quote = ({ children }) => /* @__PURE__ */ React.createElement("div", { style: {
    borderLeft: `3px solid ${t.accent}`,
    padding: "20px 28px",
    margin: "36px 0",
    background: t.accentDim
  } }, /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--serif)",
    fontSize: 22,
    fontStyle: "italic",
    color: t.text,
    margin: 0,
    lineHeight: 1.5
  } }, children));
  const Diagram = ({ label, children }) => /* @__PURE__ */ React.createElement("div", { style: {
    margin: "40px 0",
    border: `1px solid ${t.border}`,
    background: t.terminalBg
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    padding: "8px 16px",
    borderBottom: `1px solid ${t.border}`,
    fontFamily: "var(--mono)",
    fontSize: 9,
    color: t.textDim,
    letterSpacing: "0.12em"
  } }, label), /* @__PURE__ */ React.createElement("div", { style: { padding: "28px 24px" } }, children));
  const flowNodes = ["Agent Intent", "AWP Negotiation", "xB77 ZK Engine", "Noir ZK Proof", "Solana L1", "Compressed Receipt"];
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh", color: t.text } }, /* @__PURE__ */ React.createElement(InnerNav, { active: "Whitepaper" }), /* @__PURE__ */ React.createElement("section", { style: { padding: "120px 40px 60px", maxWidth: 860, margin: "0 auto" } }, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.accent,
    letterSpacing: "0.2em",
    marginBottom: 16,
    textTransform: "uppercase"
  } }, "WHITEPAPER v0.1 \u2014 MAY 2026"), /* @__PURE__ */ React.createElement("h1", { style: {
    fontFamily: "var(--serif)",
    fontSize: "clamp(44px, 6vw, 76px)",
    fontWeight: 400,
    color: t.text,
    lineHeight: 1,
    margin: "0 0 24px"
  } }, "xB77: Autonomous Financial", /* @__PURE__ */ React.createElement("br", null), /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Infrastructure")), /* @__PURE__ */ React.createElement("p", { style: {
    fontFamily: "var(--sans)",
    fontSize: 18,
    color: t.textDim,
    lineHeight: 1.7,
    maxWidth: 600
  } }, "A privacy-first operating system for machine-to-machine capital management on Solana."), /* @__PURE__ */ React.createElement("div", { style: {
    display: "flex",
    gap: 24,
    marginTop: 32,
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: t.textDim,
    letterSpacing: "0.06em"
  } }, /* @__PURE__ */ React.createElement("span", null, "Authors: xB77 Labs"), /* @__PURE__ */ React.createElement("span", { style: { opacity: 0.3 } }, "|"), /* @__PURE__ */ React.createElement("span", null, "Solana Privacy Hackathon 2026")), /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border, margin: "48px 0 0" } })), /* @__PURE__ */ React.createElement(Section, { tag: "00 \u2014 ABSTRACT", title: "Abstract" }, /* @__PURE__ */ React.createElement(P, { bold: true }, "The machine economy is here. Autonomous agents manage capital, procure resources, and settle obligations at machine speed. Yet they operate on transparent rails where every transaction is visible to adversaries, competitors, and front-runners."), /* @__PURE__ */ React.createElement(P, null, "xB77 introduces a sovereign financial operating system that gives autonomous agents the same privacy guarantees humans expect from traditional finance \u2014 without sacrificing auditability, compliance, or settlement finality."), /* @__PURE__ */ React.createElement(P, null, "Built on Solana with a proprietary ZK engine for compressed receipts, Noir for zero-knowledge proofs, and MagicBlock for sub-second finality, xB77 enables private agent transactions, autonomous governance, and easy deployment \u2014 self-hosted or cloud.")), /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 860, margin: "0 auto", padding: "0 40px" } }, /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border } })), /* @__PURE__ */ React.createElement(Section, { tag: "01 \u2014 PROBLEM", title: /* @__PURE__ */ React.createElement(React.Fragment, null, "The Transparency ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Trap")) }, /* @__PURE__ */ React.createElement(P, null, "Public blockchains are adversarial environments. Every transaction, every balance, every counterparty relationship is visible to anyone with a block explorer. For autonomous agents managing institutional capital, this transparency is a critical vulnerability."), /* @__PURE__ */ React.createElement(P, { bold: true }, "Three failure modes emerge:"), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", flexDirection: "column", gap: 16, margin: "24px 0 24px" } }, [
    { n: "01", title: "Strategy Leakage", desc: "Competitors observe agent behavior and reverse-engineer trading strategies in real-time." },
    { n: "02", title: "Front-Running", desc: "MEV bots detect large agent transactions in the mempool and extract value before settlement." },
    { n: "03", title: "Identity Correlation", desc: "Chain analysis links agent wallets to institutional identities, exposing portfolio positions." }
  ].map((f) => /* @__PURE__ */ React.createElement("div", { key: f.n, style: { display: "grid", gridTemplateColumns: "48px 1fr", gap: 16, padding: "16px 20px", border: `1px solid ${t.border}`, background: t.bgCard } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 20, color: t.accent, fontWeight: 600 } }, f.n), /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, color: t.text, fontWeight: 600, marginBottom: 4 } }, f.title), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--sans)", fontSize: 14, color: t.textDim, lineHeight: 1.6 } }, f.desc))))), /* @__PURE__ */ React.createElement(Quote, null, "Privacy isn't a feature \u2014 it's the minimum bar for serious autonomous capital.")), /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 860, margin: "0 auto", padding: "0 40px" } }, /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border } })), /* @__PURE__ */ React.createElement(Section, { tag: "02 \u2014 SOLUTION", title: /* @__PURE__ */ React.createElement(React.Fragment, null, "The xB77 ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Stack")) }, /* @__PURE__ */ React.createElement(P, null, "xB77 is a four-layer architecture that separates agent logic, privacy, and settlement into composable modules."), /* @__PURE__ */ React.createElement(Diagram, { label: "TRANSACTION PIPELINE" }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 0, overflowX: "auto", padding: "8px 0" } }, flowNodes.map((node, i) => /* @__PURE__ */ React.createElement(React.Fragment, { key: i }, /* @__PURE__ */ React.createElement(
    "div",
    {
      style: {
        border: `1px solid ${t.border}`,
        padding: "14px 18px",
        background: t.bg,
        flexShrink: 0,
        textAlign: "center",
        transition: "border-color 0.2s"
      },
      onMouseEnter: (e) => e.currentTarget.style.borderColor = t.accent,
      onMouseLeave: (e) => e.currentTarget.style.borderColor = t.border
    },
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: t.accent, letterSpacing: "0.08em", marginBottom: 4 } }, String(i + 1).padStart(2, "0")),
    /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 11, color: t.text, fontWeight: 600, whiteSpace: "nowrap" } }, node)
  ), i < flowNodes.length - 1 && /* @__PURE__ */ React.createElement("div", { style: { width: 28, height: 1, background: t.border, flexShrink: 0, position: "relative" } }, /* @__PURE__ */ React.createElement("div", { style: { position: "absolute", right: -2, top: -3, width: 0, height: 0, borderTop: "3px solid transparent", borderBottom: "3px solid transparent", borderLeft: `5px solid ${t.textDim}` } })))))), /* @__PURE__ */ React.createElement(P, null, /* @__PURE__ */ React.createElement("strong", { style: { color: t.text } }, "xB77 ZK Engine"), " is a proprietary privacy and compression layer. Transactions are shielded at the protocol level \u2014 no third-party dependencies, no external mixers, no trust assumptions."), /* @__PURE__ */ React.createElement(P, null, /* @__PURE__ */ React.createElement("strong", { style: { color: t.text } }, "Noir ZK Prover"), " generates Ghost Receipts \u2014 zero-knowledge proofs that verify transaction validity (amounts, compliance, governance) without revealing the agent's internal strategy or counterparty details."), /* @__PURE__ */ React.createElement(P, null, /* @__PURE__ */ React.createElement("strong", { style: { color: t.text } }, "ZK Compression"), " reduces on-chain storage by 99.7%. Ten thousand agent transactions collapse into a single 32-byte ZK proof anchored on Solana L1.")), /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 860, margin: "0 auto", padding: "0 40px" } }, /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border } })), /* @__PURE__ */ React.createElement(Section, { tag: "03 \u2014 ECONOMICS", title: /* @__PURE__ */ React.createElement(React.Fragment, null, "The 2.011% ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Engine")) }, /* @__PURE__ */ React.createElement(P, { bold: true }, "xB77 does not issue a token. The protocol sustains itself through infrastructure usage \u2014 a 2.011% levy on every autonomous transaction, collected on-chain at settlement."), /* @__PURE__ */ React.createElement(Diagram, { label: "VALUE FLOW" }, /* @__PURE__ */ React.createElement("div", { style: { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 } }, [
    { label: "INPUT", title: "2.011% Infra Tax", desc: "Deducted automatically by the xB77 smart contract when Ghost Receipts settle on Solana L1." },
    { label: "OUTPUT", title: "Sovereign Credits", desc: "Funds RPC infrastructure, IPFS storage, and ZK proof generation for all agents in the network." }
  ].map((v, i) => /* @__PURE__ */ React.createElement("div", { key: i, style: { padding: "20px", border: `1px solid ${t.border}`, background: t.bg } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 9, color: t.accent, letterSpacing: "0.15em", marginBottom: 8 } }, v.label), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 14, color: t.text, fontWeight: 600, marginBottom: 6 } }, v.title), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--sans)", fontSize: 13, color: t.textDim, lineHeight: 1.5 } }, v.desc))))), /* @__PURE__ */ React.createElement(P, null, "The 2.011% ratio is calibrated to sustain infrastructure costs without disincentivizing high-frequency agent trading. As network volume scales, per-transaction infrastructure costs decrease while the absolute Sovereign Credits pool grows \u2014 creating a self-reinforcing sustainability loop."), /* @__PURE__ */ React.createElement(Quote, null, "xB77 doesn't charge for transactions. It charges for ", /* @__PURE__ */ React.createElement("span", { style: { color: t.accent } }, "autonomy"), ".")), /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 860, margin: "0 auto", padding: "0 40px" } }, /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border } })), /* @__PURE__ */ React.createElement(Section, { tag: "04 \u2014 GOVERNANCE", title: /* @__PURE__ */ React.createElement(React.Fragment, null, "Constitutional ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Lockdowns")) }, /* @__PURE__ */ React.createElement(P, null, "Every xB77 agent operates under a Constitution \u2014 a set of on-chain constraints that define spending limits, counterparty allowlists, strategy boundaries, and escalation thresholds."), /* @__PURE__ */ React.createElement(P, { bold: true }, "When an agent's action would breach its Constitution, the Governance Module triggers a Lockdown \u2014 pausing execution and requiring a human signature before proceeding."), /* @__PURE__ */ React.createElement(P, null, "This creates a trust architecture where agents have maximum autonomy within defined bounds, with cryptographic guarantees that they cannot exceed those bounds. The ZK proof of every transaction includes a Constitution compliance attestation \u2014 verified by math, not trust.")), /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 860, margin: "0 auto", padding: "0 40px" } }, /* @__PURE__ */ React.createElement("div", { style: { width: "100%", height: 1, background: t.border } })), /* @__PURE__ */ React.createElement(Section, { tag: "05 \u2014 CONCLUSION", title: /* @__PURE__ */ React.createElement(React.Fragment, null, "The Sovereign ", /* @__PURE__ */ React.createElement("em", { style: { color: t.accent, fontStyle: "italic" } }, "Future")) }, /* @__PURE__ */ React.createElement(P, { bold: true }, "xB77 is infrastructure for a world where autonomous agents are the primary economic actors. Privacy is not optional \u2014 it's the foundation on which trustless agent commerce is built."), /* @__PURE__ */ React.createElement(P, null, "By combining Solana's settlement speed, Noir's ZK proving system, xB77's proprietary compression engine, and MagicBlock's ephemeral rollups, xB77 delivers the first complete agent infrastructure stack purpose-built for the machine economy \u2014 deployable in minutes, self-hosted or cloud."), /* @__PURE__ */ React.createElement(P, null, "The frontier is here. The agents are ready. The only question is whether the infrastructure will keep up."), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 12, marginTop: 40 } }, /* @__PURE__ */ React.createElement("a", { href: "/index.html#architecture", style: {
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
  } }, "Explore Architecture"), /* @__PURE__ */ React.createElement("a", { href: "/index.html#docs", style: {
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
  } }, "Read the Docs"))), /* @__PURE__ */ React.createElement(
    DocsDeepDive,
    {
      kicker: "// FULL WHITEPAPER",
      label: "Read the markdown whitepaper, in full.",
      path: "/whitepaper"
    }
  ), /* @__PURE__ */ React.createElement(PageFooter, null));
}
Object.assign(window, { WhitepaperPage });
