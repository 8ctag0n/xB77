/* xB77 v2 — Shared utilities + Terminal */

const THEMES = {
  obsidian: {
    name: 'Obsidian',
    bg: '#08080a', bgSecondary: '#101014', bgCard: 'rgba(255,255,255,0.03)',
    accent: '#c8ff2e', accentDim: 'rgba(200,255,46,0.12)',
    text: '#e8e8ec', textDim: '#6e6e7a',
    border: 'rgba(255,255,255,0.06)', navBg: 'rgba(8,8,10,0.85)',
    terminalBg: '#0c0c10', terminalGlow: 'rgba(200,255,46,0.08)',
    patternColor: 'rgba(200,255,46,0.03)',
  },
  deepsignal: {
    name: 'Deep Signal',
    bg: '#060b18', bgSecondary: '#0a1020', bgCard: 'rgba(100,200,255,0.03)',
    accent: '#4de8d0', accentDim: 'rgba(77,232,208,0.1)',
    text: '#dce4f0', textDim: '#5a6a82',
    border: 'rgba(100,200,255,0.06)', navBg: 'rgba(6,11,24,0.88)',
    terminalBg: '#080e1c', terminalGlow: 'rgba(77,232,208,0.06)',
    patternColor: 'rgba(77,232,208,0.025)',
  },
  cipher: {
    name: 'Cipher',
    bg: '#060f0a', bgSecondary: '#0a1810', bgCard: 'rgba(255,200,80,0.03)',
    accent: '#f0b840', accentDim: 'rgba(240,184,64,0.1)',
    text: '#dce8de', textDim: '#5a7062',
    border: 'rgba(255,200,80,0.06)', navBg: 'rgba(6,15,10,0.88)',
    terminalBg: '#081208', terminalGlow: 'rgba(240,184,64,0.06)',
    patternColor: 'rgba(240,184,64,0.025)',
  }
};

const TERMINAL_LINES = [
  { type: 'system', text: '[INIT] PIPELINE_START: AGENT_CFO_ALPHA' },
  { type: 'success', text: '[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)' },
  { type: 'accent', text: '[DEPLOY] AGENT INSTANCE PROVISIONED — SELF-HOSTED' },
  { type: 'dim', text: '[HELIUS] ANALYZING DESTINATION: LOW_RISK' },
  { type: 'accent', text: '[PAY] VIRTUAL_CARD: ****-****-****-7781' },
  { type: 'code', text: 'const xB77 = { privacy: "MAX", compliance: "RANGE", engine: "ZK" };' },
  { type: 'warning', text: '[GOVERNANCE] LOCKDOWN: HUMAN SIGNATURE REQUIRED' },
  { type: 'system', text: '[ZKP] GENERATING SELECTIVE DISCLOSURE...' },
  { type: 'success', text: '[END] RECEIPT COMPRESSED — xB77 ZK ENGINE ✓' },
  { type: 'dim', text: '―――――――――――――――――――――――――' },
  { type: 'system', text: '[INIT] PIPELINE_START: AGENT_CFO_BETA' },
  { type: 'success', text: '[AUTH] NEURAL_KEY_VERIFIED' },
  { type: 'accent', text: '[DEPLOY] AGENT ROUTING THROUGH ZK PRIVACY LAYER...' },
  { type: 'system', text: '[ZKP] PROOF VERIFIED — SELECTIVE DISCLOSURE OK' },
  { type: 'success', text: '[END] TRANSACTION COMPLETE ✓✓' },
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
        setLines(prev => [...prev, TERMINAL_LINES[idx]]);
        i++;
      } else { i = 0; setLines([]); }
      timerId = setTimeout(tick, 600);
    }
    let timerId = setTimeout(tick, 600);
    const cursorId = setInterval(() => { if (!cancelled) setCursor(c => !c); }, 530);
    return () => { cancelled = true; clearTimeout(timerId); clearInterval(cursorId); };
  }, []);

  React.useEffect(() => {
    if (termRef.current) termRef.current.scrollTop = termRef.current.scrollHeight;
  }, [lines]);

  return { lines, cursor, termRef };
}

function TerminalLine({ line, theme }) {
  if (!line) return null;
  const t = THEMES[theme];
  const colors = { system: t.text, success: t.accent, accent: t.accent, dim: t.textDim, code: t.accent, warning: '#ff8844' };
  return (
    <div style={{
      color: colors[line.type] || t.text,
      opacity: line.type === 'dim' ? 0.5 : (line.type === 'code' ? 0.8 : 1),
      animation: 'fadeInLine 0.3s ease',
    }}>{line.text}</div>
  );
}

const FEATURES = [
  { tag: 'EASY_DEPLOY', title: 'One-Click Agent Deploy', desc: 'Deploy autonomous financial agents in minutes. Self-hosted or cloud. No infra expertise needed — like Vercel for AI finance.', icon: '◈' },
  { tag: 'ZK_ENGINE', title: 'Proprietary ZK Engine', desc: 'Built-in zero-knowledge compression and privacy. On-chain receipts compressed 99.7% with selective disclosure by default.', icon: '◇' },
  { tag: 'NEURAL_AUTH', title: 'Autonomous Agents', desc: 'Institutional-grade AI agents manage capital with neural key verification and constitutional governance lockdowns.', icon: '◆' },
];

const ARCH_NODES = [
  { label: 'AI Agent', sub: 'Neural Key Auth', x: 50, y: 12 },
  { label: 'xB77 Core', sub: 'Pipeline Engine', x: 50, y: 38 },
  { label: 'ZK Engine', sub: 'Privacy + Compression', x: 15, y: 65 },
  { label: 'Governance', sub: 'Constitutional Rules', x: 50, y: 65 },
  { label: 'Deploy Layer', sub: 'Self-hosted / Cloud', x: 85, y: 65 },
  { label: 'Solana', sub: 'Settlement Layer', x: 50, y: 92 },
];
const ARCH_CONNS = [[0,1],[1,2],[1,3],[1,4],[2,5],[3,5],[4,5]];

Object.assign(window, { THEMES, TERMINAL_LINES, useTerminal, TerminalLine, FEATURES, ARCH_NODES, ARCH_CONNS });
