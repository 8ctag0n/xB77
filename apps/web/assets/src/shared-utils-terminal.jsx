/* xB77 v2 — Shared utilities + Terminal */

const THEMES = {
  obsidian: {
    name: 'Obsidian',
    bg: 'var(--bg)', bgSecondary: 'var(--bg-secondary)', bgCard: 'var(--bg-card)',
    accent: 'var(--accent)', accentDim: 'var(--accent-dim)',
    text: 'var(--text)', textDim: 'var(--text-dim)',
    border: 'var(--border)', navBg: 'var(--nav-bg)',
    terminalBg: 'var(--terminal-bg)', terminalGlow: 'var(--terminal-glow)',
    patternColor: 'var(--pattern-color)',
  },
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
  const [agentId, setAgentId] = React.useState(null);

  React.useEffect(() => {
    const onConn = (e) => setAgentId(e.detail?.agent_id || window.XB77Actions?.keystore?.agentId);
    window.addEventListener('xb77:connected', onConn);
    return () => window.removeEventListener('xb77:connected', onConn);
  }, []);

  React.useEffect(() => {
    const onIncome = (e) => {
      setLines(prev => [...prev.slice(-40), { type: 'success', text: `[INCOME] Received $${e.detail.amount} deposit. Re-balancing strategy...` }]);
    };
    window.addEventListener('xb77:income', onIncome);
    return () => window.removeEventListener('xb77:income', onIncome);
  }, []);

  React.useEffect(() => {
    let i = 0, cancelled = false;
    async function tick() {
      if (cancelled) return;
      
      const currentAgent = agentId || window.XB77Actions?.keystore?.agentId;
      const strategy = localStorage.getItem('xb77_last_intent') || 'Sovereign Core';
      const isPaused = document.body.innerText.includes('RESUME AGENT'); // Simple DOM check for paused state
      
      if (isPaused) {
        setLines(prev => [...prev.slice(-40), { type: 'warning', text: `[HALT] Agent ${currentAgent || ''} is PAUSED by user.` }]);
        timerId = setTimeout(tick, 2000);
        return;
      }
      
      if (i < TERMINAL_LINES.length) {
        let line = { ...TERMINAL_LINES[i] };
        if (currentAgent) {
           line.text = line.text.replace('AGENT_CFO_ALPHA', currentAgent);
           // Dynamic logic based on strategy
           if (strategy.includes('Yield')) {
             line.text = line.text.replace('[PAY]', '[YIELD]').replace('VIRTUAL_CARD', 'LIQUIDITY_POOL');
           } else if (strategy.includes('Rebalancer')) {
             line.text = line.text.replace('[PAY]', '[BRIDGE]').replace('VIRTUAL_CARD', 'SUI_PTB_FLOW');
           }
        }
        setLines(prev => [...prev.slice(-40), line]);
        i++;
      } else { 
        i = 0; 
        if (currentAgent) {
           setLines(prev => [...prev, { type: 'dim', text: `--- RE-RUNNING ${strategy.toUpperCase()} LOOP ---` }]);
        }
      }
      timerId = setTimeout(tick, 800);
    }
    let timerId = setTimeout(tick, 800);
    const cursorId = setInterval(() => { if (!cancelled) setCursor(c => !c); }, 530);
    return () => { cancelled = true; clearTimeout(timerId); clearInterval(cursorId); };
  }, [agentId]);

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
