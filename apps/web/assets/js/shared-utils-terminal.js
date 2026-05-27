const THEMES = {
  obsidian: {
    name: "Obsidian",
    bg: "var(--bg)",
    bgSecondary: "var(--bg-secondary)",
    bgCard: "var(--bg-card)",
    accent: "var(--accent)",
    accentDim: "var(--accent-dim)",
    text: "var(--text)",
    textDim: "var(--text-dim)",
    border: "var(--border)",
    navBg: "var(--nav-bg)",
    terminalBg: "var(--terminal-bg)",
    terminalGlow: "var(--terminal-glow)",
    patternColor: "var(--pattern-color)"
  }
};
const TERMINAL_LINES = [
  { type: "system", text: "[INIT] PIPELINE_START: AGENT_CFO_ALPHA" },
  { type: "success", text: "[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)" },
  { type: "accent", text: "[DEPLOY] AGENT INSTANCE PROVISIONED \u2014 SELF-HOSTED" },
  { type: "dim", text: "[HELIUS] ANALYZING DESTINATION: LOW_RISK" },
  { type: "accent", text: "[PAY] VIRTUAL_CARD: ****-****-****-7781" },
  { type: "code", text: 'const xB77 = { privacy: "MAX", compliance: "RANGE", engine: "ZK" };' },
  { type: "warning", text: "[GOVERNANCE] LOCKDOWN: HUMAN SIGNATURE REQUIRED" },
  { type: "system", text: "[ZKP] GENERATING SELECTIVE DISCLOSURE..." },
  { type: "success", text: "[END] RECEIPT COMPRESSED \u2014 xB77 ZK ENGINE \u2713" },
  { type: "dim", text: "\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015\u2015" },
  { type: "system", text: "[INIT] PIPELINE_START: AGENT_CFO_BETA" },
  { type: "success", text: "[AUTH] NEURAL_KEY_VERIFIED" },
  { type: "accent", text: "[DEPLOY] AGENT ROUTING THROUGH ZK PRIVACY LAYER..." },
  { type: "system", text: "[ZKP] PROOF VERIFIED \u2014 SELECTIVE DISCLOSURE OK" },
  { type: "success", text: "[END] TRANSACTION COMPLETE \u2713\u2713" }
];
function useTerminal() {
  const [lines, setLines] = React.useState([]);
  const [cursor, setCursor] = React.useState(true);
  const termRef = React.useRef(null);
  React.useEffect(() => {
    let i = 0, cancelled = false;
    function tick() {
      if (cancelled) return;
      if (i < TERMINAL_LINES.length) {
        const idx = i;
        setLines((prev) => [...prev, TERMINAL_LINES[idx]]);
        i++;
      } else {
        i = 0;
        setLines([]);
      }
      timerId = setTimeout(tick, 600);
    }
    let timerId = setTimeout(tick, 600);
    const cursorId = setInterval(() => {
      if (!cancelled) setCursor((c) => !c);
    }, 530);
    return () => {
      cancelled = true;
      clearTimeout(timerId);
      clearInterval(cursorId);
    };
  }, []);
  React.useEffect(() => {
    if (termRef.current) termRef.current.scrollTop = termRef.current.scrollHeight;
  }, [lines]);
  return { lines, cursor, termRef };
}
function TerminalLine({ line, theme }) {
  if (!line) return null;
  const t = THEMES[theme];
  const colors = { system: t.text, success: t.accent, accent: t.accent, dim: t.textDim, code: t.accent, warning: "#ff8844" };
  return /* @__PURE__ */ React.createElement("div", { style: {
    color: colors[line.type] || t.text,
    opacity: line.type === "dim" ? 0.5 : line.type === "code" ? 0.8 : 1,
    animation: "fadeInLine 0.3s ease"
  } }, line.text);
}
const FEATURES = [
  { tag: "ZIG_STYLUS", title: "Zig Stylus Engine", desc: "Deploy autonomous financial agents in minutes. Self-hosted or cloud. No infra expertise needed \u2014 like Vercel for AI finance.", icon: "\u25C8" },
  { tag: "RECURSIVE_GOV", title: "Recursive Governance", desc: "Agents audit each other intent semantically on-chain. The Stylus Supreme Court performs autonomous slashing without human intervention.", icon: "\u25C7" },
  { tag: "ZERO_CLICK", title: "Zero-Click EIP-7715", desc: "Institutional-grade AI agents manage capital via ZeroDev Kernel v3 session keys, bounded by the Stylus constitution.", icon: "\u25C6" }
];
const ARCH_NODES = [
  { label: "AI Agent", sub: "Semantic Intent", x: 50, y: 12 },
  { label: "xB77 Core", sub: "Stylus Supreme Court", x: 50, y: 38 },
  { label: "ZK Engine", sub: "Proof of Model (ZK)", x: 15, y: 65 },
  { label: "Governance", sub: "Recursive Slashing", x: 50, y: 65 },
  { label: "Deploy Layer", sub: "EIP-7702 Delegation", x: 85, y: 65 },
  { label: "Solana", sub: "Arbitrum/Solana", x: 50, y: 92 }
];
const ARCH_CONNS = [[0, 1], [1, 2], [1, 3], [1, 4], [2, 5], [3, 5], [4, 5]];
Object.assign(window, { THEMES, TERMINAL_LINES, useTerminal, TerminalLine, FEATURES, ARCH_NODES, ARCH_CONNS });
