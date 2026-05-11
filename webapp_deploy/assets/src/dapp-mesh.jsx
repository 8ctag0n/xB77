/* xB77 dApp — Mesh Dashboard (Deluxe) */

/* ── Mesh node positions (normalized 0-100) ── */
const MESH_NODES = [
  { id: 'cfo-alpha', label: 'cfo-alpha', type: 'LEAD', x: 50, y: 28, color: 'var(--accent)', status: 'online' },
  { id: 'worker-01', label: 'worker_01', type: 'TREASURY', x: 24, y: 50, color: '#34d399', status: 'online' },
  { id: 'worker-02', label: 'worker_02', type: 'TRADING', x: 76, y: 50, color: '#4de8d0', status: 'online' },
  { id: 'worker-03', label: 'worker_03', type: 'PAYMENTS', x: 30, y: 74, color: '#a78bfa', status: 'online' },
  { id: 'worker-04', label: 'worker_04', type: 'RECON', x: 70, y: 74, color: '#fbbf24', status: 'idle' },
  // External nodes
  { id: 'zk-engine', label: 'xB77 ZK Engine', type: 'PRIVACY', x: 10, y: 30, color: 'var(--accent)', status: 'active', ext: true },
  { id: 'light', label: 'xB77 ZK Engine', type: 'ZK-RECEIPTS', x: 90, y: 30, color: '#4de8d0', status: 'active', ext: true },
  { id: 'solana', label: 'Solana', type: 'SETTLEMENT', x: 50, y: 95, color: '#a78bfa', status: 'active', ext: true },
  { id: 'cafe', label: 'Café Sovereign', type: 'MERCHANT', x: 12, y: 80, color: '#fbbf24', status: 'indexed', ext: true },
  { id: 'pool', label: 'Privacy Pool', type: 'OBFUSCATION', x: 88, y: 80, color: 'var(--accent)', status: 'active', ext: true },
];

const MESH_EDGES = [
  ['cfo-alpha', 'worker-01'], ['cfo-alpha', 'worker-02'], ['cfo-alpha', 'worker-03'], ['cfo-alpha', 'worker-04'],
  ['cfo-alpha', 'zk-engine'], ['cfo-alpha', 'light'],
  ['worker-01', 'solana'], ['worker-02', 'solana'], ['worker-03', 'cafe'],
  ['worker-03', 'zk-engine'], ['worker-04', 'cafe'], ['worker-04', 'pool'],
  ['zk-engine', 'solana'], ['light', 'solana'], ['pool', 'solana'],
];

/* ── Animated particle along an edge ── */
function Particle({ x1, y1, x2, y2, color, duration, delay }) {
  const [progress, setProgress] = React.useState(0);
  const [visible, setVisible] = React.useState(false);

  React.useEffect(() => {
    const t1 = setTimeout(() => {
      setVisible(true);
      const start = performance.now();
      const dur = duration || 1500;
      const animate = (now) => {
        const p = Math.min((now - start) / dur, 1);
        setProgress(p);
        if (p < 1) requestAnimationFrame(animate);
        else setVisible(false);
      };
      requestAnimationFrame(animate);
    }, delay || 0);
    return () => clearTimeout(t1);
  }, []);

  if (!visible) return null;
  const cx = x1 + (x2 - x1) * progress;
  const cy = y1 + (y2 - y1) * progress;

  return (
    <React.Fragment>
      <circle cx={cx} cy={cy} r="0.6" fill={color} opacity={1 - progress * 0.5}>
        <animate attributeName="r" values="0.4;0.8;0.4" dur="0.6s" repeatCount="indefinite" />
      </circle>
      {/* Trail */}
      <line x1={x1 + (x2 - x1) * Math.max(0, progress - 0.15)} y1={y1 + (y2 - y1) * Math.max(0, progress - 0.15)}
        x2={cx} y2={cy} stroke={color} strokeWidth="0.3" opacity={0.4} />
    </React.Fragment>
  );
}

/* ── The mesh visualization ── */
function MeshViz({ events }) {
  const [hoveredNode, setHoveredNode] = React.useState(null);
  const [particles, setParticles] = React.useState([]);
  const particleId = React.useRef(0);

  // Spawn particles on events
  React.useEffect(() => {
    if (events.length === 0) return;
    const ev = events[0];
    // Pick a random edge to animate
    const edge = MESH_EDGES[Math.floor(Math.random() * MESH_EDGES.length)];
    const n1 = MESH_NODES.find(n => n.id === edge[0]);
    const n2 = MESH_NODES.find(n => n.id === edge[1]);
    if (n1 && n2) {
      const id = particleId.current++;
      const color = n1.color;
      setParticles(prev => [...prev.slice(-8), { id, x1: n1.x, y1: n1.y, x2: n2.x, y2: n2.y, color }]);
    }
  }, [events.length]);

  const nodeMap = {};
  MESH_NODES.forEach(n => { nodeMap[n.id] = n; });

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      <svg viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet"
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
        <defs>
          <radialGradient id="meshGlow">
            <stop offset="0%" stopColor="rgba(200,255,46,0.06)" />
            <stop offset="100%" stopColor="rgba(200,255,46,0)" />
          </radialGradient>
        </defs>

        {/* Background glow at center */}
        <circle cx="50" cy="50" r="35" fill="url(#meshGlow)" />

        {/* Edges */}
        {MESH_EDGES.map(([a, b], i) => {
          const n1 = nodeMap[a], n2 = nodeMap[b];
          if (!n1 || !n2) return null;
          const isHovered = hoveredNode === a || hoveredNode === b;
          return (
            <line key={i} x1={n1.x} y1={n1.y} x2={n2.x} y2={n2.y}
              stroke={isHovered ? 'var(--accent)' : 'var(--border)'}
              strokeWidth={isHovered ? '0.25' : '0.12'}
              strokeDasharray={n1.ext || n2.ext ? '0.6 0.4' : 'none'}
              style={{ transition: 'stroke 0.3s, stroke-width 0.3s' }}
            />
          );
        })}

        {/* Particles */}
        {particles.map(p => (
          <Particle key={p.id} x1={p.x1} y1={p.y1} x2={p.x2} y2={p.y2} color={p.color} duration={1200} />
        ))}

        {/* Nodes */}
        {MESH_NODES.map(node => {
          const isHov = hoveredNode === node.id;
          const isAgent = !node.ext;
          const r = isAgent ? 1.8 : 1.2;
          return (
            <g key={node.id}
              onMouseEnter={() => setHoveredNode(node.id)}
              onMouseLeave={() => setHoveredNode(null)}
              style={{ cursor: 'pointer' }}
            >
              {/* Pulse ring for agents */}
              {isAgent && node.status === 'online' && (
                <circle cx={node.x} cy={node.y} r={r + 1} fill="none"
                  stroke={node.color} strokeWidth="0.1" opacity="0.3">
                  <animate attributeName="r" values={`${r};${r+2};${r}`} dur="3s" repeatCount="indefinite" />
                  <animate attributeName="opacity" values="0.3;0;0.3" dur="3s" repeatCount="indefinite" />
                </circle>
              )}

              {/* Node body */}
              <rect x={node.x - r} y={node.y - r} width={r*2} height={r*2}
                fill={isHov ? node.color : D.bg}
                stroke={node.color}
                strokeWidth={isHov ? '0.3' : '0.15'}
                opacity={isHov ? 1 : 0.8}
                style={{ transition: 'all 0.3s' }}
              />

              {/* Inner dot */}
              {isAgent && (
                <circle cx={node.x} cy={node.y} r="0.5"
                  fill={node.status === 'online' ? node.color : '#fbbf24'}
                  opacity={0.8}>
                  {node.status === 'online' && (
                    <animate attributeName="opacity" values="0.8;0.3;0.8" dur="2s" repeatCount="indefinite" />
                  )}
                </circle>
              )}
            </g>
          );
        })}
      </svg>

      {/* Node labels (HTML overlay for crisp text) */}
      {MESH_NODES.map(node => {
        const isHov = hoveredNode === node.id;
        const isAgent = !node.ext;
        return (
          <div key={node.id + '-label'} style={{
            position: 'absolute',
            left: `${node.x}%`, top: `${node.y}%`,
            transform: 'translate(-50%, 14px)',
            textAlign: 'center', pointerEvents: 'none',
            transition: 'opacity 0.3s',
            opacity: isHov ? 1 : (isAgent ? 0.7 : 0.4),
          }}>
            <div style={{
              fontFamily: 'var(--mono)', fontSize: isAgent ? 8 : 7,
              fontWeight: isAgent ? 600 : 500, color: isHov ? node.color : D.text,
              letterSpacing: '0.06em', whiteSpace: 'nowrap',
            }}>{node.label}</div>
            <div style={{
              fontFamily: 'var(--mono)', fontSize: 6,
              color: node.color, opacity: isHov ? 0.8 : 0.4,
              letterSpacing: '0.1em', textTransform: 'uppercase',
            }}>{node.type}</div>
          </div>
        );
      })}

      {/* Hovered node detail card */}
      {hoveredNode && (() => {
        const node = MESH_NODES.find(n => n.id === hoveredNode);
        if (!node) return null;
        const isAgent = !node.ext;
        return (
          <div style={{
            position: 'absolute',
            left: `${Math.min(Math.max(node.x, 20), 80)}%`,
            top: `${node.y - 12}%`,
            transform: 'translate(-50%, -100%)',
            background: D.bg2, border: `1px solid ${node.color}30`,
            padding: '10px 14px', minWidth: 140,
            boxShadow: `0 0 30px ${node.color}15`,
            pointerEvents: 'none', zIndex: 10,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
              <Dot color={node.status === 'online' || node.status === 'active' ? D.green : D.amber} />
              <span style={{ fontFamily: 'var(--mono)', fontSize: 10, fontWeight: 600, color: D.text }}>{node.label}</span>
            </div>
            <DM size={7} color={node.color}>{node.type}</DM>
            {isAgent && (
              <div style={{ marginTop: 6, display: 'flex', gap: 12 }}>
                <DM size={7}>12 txns</DM>
                <DM size={7} color={D.green}>+$201</DM>
              </div>
            )}
          </div>
        );
      })()}
    </div>
  );
}

/* ── Deluxe Dashboard ── */
function DashboardView() {
  const [events, setEvents] = React.useState([]);

  React.useEffect(() => {
    const pool = [
      { icon: '🤖', text: 'cfo-alpha executed swap: 240 USDC → SOL', color: D.text },
      { icon: '🔒', text: 'pipe_sw_001 shielded 3 transactions', color: D.dim },
      { icon: '📦', text: 'Café Sovereign: order from ag_worker_03', color: D.cyan },
      { icon: '⚡', text: 'ag_worker_04 discovered 2 merchants', color: '#fbbf24' },
      { icon: '🛡️', text: 'ZK-receipt compressed: zk_rcpt_a3f1', color: D.dim },
      { icon: '🔔', text: 'Governance: tx $8,200 needs approval', color: '#fbbf24' },
      { icon: '✅', text: 'ag_worker_01 treasury rebalance done', color: D.green },
      { icon: '🌐', text: 'Znode zn_12 synced — 28ms', color: D.dim },
      { icon: '🤖', text: 'cfo-alpha opened yield position: 500 USDC', color: D.text },
      { icon: '🔒', text: 'xB77 ZK Engine: proof batch complete', color: D.dim },
    ];
    let i = 0;
    const add = () => {
      const ev = pool[i % pool.length];
      const now = new Date();
      const time = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
      setEvents(prev => [{ ...ev, time, id: Date.now() + '_' + i + '_' + Math.random() }, ...prev].slice(0, 30));
      i++;
    };
    add(); add(); add();
    const id = setInterval(add, 3500);
    return () => clearInterval(id);
  }, []);

  const sparkTxns = [3,5,4,7,6,8,5,9,11,8,12,10,14,11,13,15,12,14,16,14];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      {/* Top stats strip */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 0,
        borderBottom: `1px solid ${D.border}`, flexShrink: 0,
      }}>
        {[
          { label: 'TREASURY', value: '$24,847', change: '+$2,103' },
          { label: 'AGENTS', value: '5 / 5', sub: 'SWARM ONLINE' },
          { label: 'PIPELINES', value: '3', sub: '2 active, 1 paused' },
          { label: 'TXNS TODAY', value: '47', change: '+12' },
          { label: 'VOLUME 24H', value: '$5,120', change: '+34%' },
        ].map((s, i) => (
          <div key={i} style={{
            padding: '14px 18px', borderRight: i < 4 ? `1px solid ${D.border}` : 'none',
          }}>
            <DM size={7}>{s.label}</DM>
            <div style={{ fontFamily: 'var(--serif)', fontSize: 22, color: D.text, marginTop: 4, fontStyle: 'italic' }}>{s.value}</div>
            {s.change && <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: s.change.startsWith('+') ? D.green : D.red, marginTop: 2 }}>{s.change}</div>}
            {s.sub && <DM size={7} color={D.green} style={{ marginTop: 2 }}>{s.sub}</DM>}
          </div>
        ))}
      </div>

      {/* Main area: mesh + feed */}
      <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 300px', minHeight: 0 }}>
        {/* Mesh visualization */}
        <div style={{ position: 'relative', overflow: 'hidden' }}>
          {/* Faint text pattern */}
          <div style={{
            position: 'absolute', inset: 0, pointerEvents: 'none',
            fontFamily: 'var(--mono)', fontSize: 8, color: 'rgba(200,255,46,0.015)',
            lineHeight: 2.4, letterSpacing: '0.5em', whiteSpace: 'pre-wrap', wordBreak: 'break-all',
            padding: 20, userSelect: 'none', zIndex: 0,
          }}>
            {Array(20).fill('MESH AGENT PIPELINE ZK_ENGINE ZK_ENGINE ZK PRIVACY SOVEREIGN AUTONOMOUS SWARM TREASURY ').join('')}
          </div>
          <MeshViz events={events} />
        </div>

        {/* Right: Live feed + mini sparkline */}
        <div style={{ borderLeft: `1px solid ${D.border}`, display: 'flex', flexDirection: 'column' }}>
          {/* Sparkline */}
          <div style={{ padding: '12px 16px', borderBottom: `1px solid ${D.border}` }}>
            <DM size={7}>TRANSACTIONS 7D</DM>
            <div style={{ marginTop: 8 }}><Spark data={sparkTxns} color={D.accent} height={28} /></div>
          </div>

          {/* Live feed */}
          <div style={{ padding: '10px 16px 4px', display: 'flex', alignItems: 'center', gap: 6 }}>
            <Dot color={D.green} pulse />
            <DM size={8} color={D.text}>LIVE FEED</DM>
          </div>
          <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px' }}>
            {events.map(ev => (
              <EventLine key={ev.id} time={ev.time} icon={ev.icon} text={ev.text} color={ev.color} isNew />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function MeshTab() {
  return (
    <div style={{
      display:'flex', flexDirection:'column',
      minHeight:520,
      border:'1px solid var(--border-soft)',
      background:'var(--bg)',
    }}>
      <DashboardView />
    </div>
  );
}

Object.assign(window, { DashboardView, MeshTab });
