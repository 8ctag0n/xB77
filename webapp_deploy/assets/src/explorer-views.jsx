/* xB77 Explorer v2 — Tab content + Detail + Live Feed + Mesh Canvas */

const PAGE_SIZE = 12;

/* ── Mesh Network Canvas (deluxe: nodes + edges + pulse rings + packet trails) ── */
function MeshCanvas({ znodes }) {
  const canvasRef = React.useRef(null);
  const animRef = React.useRef(null);
  const stateRef = React.useRef(null);

  React.useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const W = 320, H = 240;
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.scale(dpr, dpr);

    if (!stateRef.current) {
      const nodes = znodes.slice(0, 24).map((z) => ({
        x: 30 + Math.random() * (W - 60),
        y: 20 + Math.random() * (H - 40),
        vx: (Math.random() - 0.5) * 0.18,
        vy: (Math.random() - 0.5) * 0.18,
        r: z.status === 'ONLINE' ? 3.5 : 2.5,
        color: z.status === 'ONLINE' ? '#c8ff2e' : z.status === 'SYNCING' ? '#f0c040' : '#ff4455',
        status: z.status,
        ring: Math.random() * Math.PI * 2,        // ring phase
        ringRate: 0.018 + Math.random() * 0.012,  // ring breathing speed
      }));
      stateRef.current = { nodes, packets: [], lastPacket: 0 };
    }
    const { nodes } = stateRef.current;

    function spawnPacket(now) {
      // Pick a random active edge (between two ONLINE nodes within range)
      const active = nodes.filter(n => n.status === 'ONLINE');
      if (active.length < 2) return;
      const a = active[Math.floor(Math.random() * active.length)];
      const within = active.filter(b => b !== a && Math.hypot(a.x - b.x, a.y - b.y) < 95);
      if (!within.length) return;
      const b = within[Math.floor(Math.random() * within.length)];
      stateRef.current.packets.push({ from: a, to: b, t: 0, born: now });
    }

    function draw(now) {
      ctx.clearRect(0, 0, W, H);

      // Move nodes
      nodes.forEach(n => {
        n.x += n.vx; n.y += n.vy;
        if (n.x < 20 || n.x > W - 20) n.vx *= -1;
        if (n.y < 15 || n.y > H - 15) n.vy *= -1;
        n.ring += n.ringRate;
      });

      // Edges
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const dx = nodes[i].x - nodes[j].x, dy = nodes[i].y - nodes[j].y;
          const dist = Math.hypot(dx, dy);
          if (dist < 100) {
            const alpha = (1 - dist / 100) * 0.14;
            ctx.beginPath();
            ctx.moveTo(nodes[i].x, nodes[i].y);
            ctx.lineTo(nodes[j].x, nodes[j].y);
            ctx.strokeStyle = `rgba(200,255,46,${alpha})`;
            ctx.lineWidth = 0.5;
            ctx.stroke();
          }
        }
      }

      // Spawn packets every ~250ms
      if (!stateRef.current.lastPacket || now - stateRef.current.lastPacket > 250) {
        spawnPacket(now);
        stateRef.current.lastPacket = now;
      }

      // Draw packets travelling along their edges
      stateRef.current.packets = stateRef.current.packets.filter(p => {
        p.t += 0.018;
        if (p.t >= 1) return false;
        const x = p.from.x + (p.to.x - p.from.x) * p.t;
        const y = p.from.y + (p.to.y - p.from.y) * p.t;
        // trail
        const tx = p.from.x + (p.to.x - p.from.x) * Math.max(0, p.t - 0.18);
        const ty = p.from.y + (p.to.y - p.from.y) * Math.max(0, p.t - 0.18);
        const grad = ctx.createLinearGradient(tx, ty, x, y);
        grad.addColorStop(0, 'rgba(0,240,255,0)');
        grad.addColorStop(1, 'rgba(0,240,255,0.9)');
        ctx.beginPath();
        ctx.moveTo(tx, ty); ctx.lineTo(x, y);
        ctx.strokeStyle = grad; ctx.lineWidth = 1.4; ctx.stroke();
        // head
        ctx.beginPath();
        ctx.arc(x, y, 1.6, 0, Math.PI * 2);
        ctx.fillStyle = 'rgba(0,240,255,0.95)';
        ctx.fill();
        return true;
      });

      // Nodes
      nodes.forEach(n => {
        // Outer glow halo
        const glow = ctx.createRadialGradient(n.x, n.y, 0, n.x, n.y, n.r * 4);
        glow.addColorStop(0, n.color + '40');
        glow.addColorStop(1, n.color + '00');
        ctx.fillStyle = glow;
        ctx.beginPath(); ctx.arc(n.x, n.y, n.r * 4, 0, Math.PI * 2); ctx.fill();

        // Pulse ring on ONLINE nodes (breathing)
        if (n.status === 'ONLINE') {
          const phase = (Math.sin(n.ring) + 1) / 2; // 0..1
          ctx.beginPath();
          ctx.arc(n.x, n.y, n.r + 2 + phase * 6, 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(200,255,46,${0.22 - phase * 0.18})`;
          ctx.lineWidth = 0.7;
          ctx.stroke();
        }

        // Core
        ctx.beginPath(); ctx.arc(n.x, n.y, n.r, 0, Math.PI * 2);
        ctx.fillStyle = n.color + 'dd'; ctx.fill();
      });

      animRef.current = requestAnimationFrame(draw);
    }
    draw(performance.now());
    return () => cancelAnimationFrame(animRef.current);
  }, []);

  return (
    <canvas ref={canvasRef} style={{ width: '100%', height: 240, display: 'block' }} />
  );
}

/* ── Pipelines Tab ── */
function PipelinesView({ data, search, onSelect }) {
  const [page, setPage] = React.useState(1);
  const [statusF, setStatusF] = React.useState('ALL');

  const filtered = data.filter(p => {
    if (statusF !== 'ALL' && p.status !== statusF) return false;
    if (search) {
      const s = search.toLowerCase();
      return p.id.includes(s) || p.agent.toLowerCase().includes(s) || p.type.toLowerCase().includes(s);
    }
    return true;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageData = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  React.useEffect(() => setPage(1), [search, statusF]);

  const th = { padding: '10px 12px', fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: 'left' };
  const td = { padding: '11px 12px', fontFamily: 'var(--mono)', fontSize: 11.5, color: T.text, borderBottom: `1px solid ${T.border}` };

  return (
    <div>
      <div style={{ display: 'flex', gap: 6, padding: '14px 0', flexWrap: 'wrap', alignItems: 'center' }}>
        {['ALL', 'COMPLETED', 'IN_PROGRESS', 'PENDING', 'FAILED'].map(s => (
          <FilterChip key={s} label={s} active={statusF === s} onClick={() => setStatusF(s)} />
        ))}
        <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: T.textDim, marginLeft: 'auto' }}>{filtered.length} results</span>
      </div>
      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr>
            <th style={th}>PIPELINE</th><th style={th}>TYPE</th><th style={th}>AGENT</th>
            <th style={th}>AMOUNT</th><th style={th}>ZNODE</th><th style={th}>STATUS</th><th style={th}>AGE</th>
          </tr></thead>
          <tbody>
            {pageData.map((p, i) => (
              <Row key={p.id} idx={i} onClick={() => onSelect({ type: 'pipeline', data: p })}>
                <td style={{ ...td, color: T.accent, cursor: 'pointer' }}><span className="xb-row-id" style={{ display: 'inline-block' }}>{p.id}</span></td>
                <td style={{ ...td, fontSize: 9.5, color: T.textMid }}>{p.type}</td>
                <td style={td}>{p.agent}</td>
                <td style={td}><span style={{ color: T.text }}>{p.amount}</span> <span style={{ color: T.textDim, fontSize: 10 }}>{p.currency}</span></td>
                <td style={{ ...td, fontSize: 10, color: T.textMid }}>{p.znode}</td>
                <td style={td}><Status status={p.status} /></td>
                <td style={{ ...td, color: T.textDim, fontSize: 10 }}>{timeAgo(p.timestamp)}</td>
              </Row>
            ))}
          </tbody>
        </table>
      </div>
      <Pager page={page} total={totalPages} onChange={setPage} />
    </div>
  );
}

/* ── Znodes Tab ── */
function ZnodesView({ data, search, onSelect }) {
  const filtered = data.filter(z => !search || z.id.includes(search.toLowerCase()) || z.region.toLowerCase().includes(search.toLowerCase()));
  const th = { padding: '10px 12px', fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: 'left' };
  const td = { padding: '11px 12px', fontFamily: 'var(--mono)', fontSize: 11.5, color: T.text, borderBottom: `1px solid ${T.border}` };

  return (
    <div style={{ overflowX: 'auto', marginTop: 12 }}>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr>
          <th style={th}>ZNODE</th><th style={th}>REGION</th><th style={th}>STATUS</th>
          <th style={th}>PEERS</th><th style={th}>LATENCY</th><th style={th}>UPTIME</th>
          <th style={th}>PIPELINES</th><th style={th}>STAKE</th>
        </tr></thead>
        <tbody>
          {filtered.map((z, i) => (
            <Row key={z.id} idx={i} onClick={() => onSelect({ type: 'znode', data: z })}>
              <td style={{ ...td, color: T.accent }}><span className="xb-row-id" style={{ display: 'inline-block' }}>{z.id}</span></td>
              <td style={td}>{z.region}</td>
              <td style={td}><Status status={z.status} /></td>
              <td style={td}>{z.peers}</td>
              <td style={td}>{z.latency}<span style={{ color: T.textDim, fontSize: 9 }}>ms</span></td>
              <td style={td}>{(z.uptime * 100).toFixed(1)}%</td>
              <td style={td}>{z.pipelines.toLocaleString()}</td>
              <td style={td}>{Number(z.stake).toLocaleString()} <span style={{ color: T.textDim, fontSize: 9 }}>SOL</span></td>
            </Row>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* ── Agents Tab ── */
function AgentsView({ data, search, onSelect }) {
  const filtered = data.filter(a => !search || a.name.toLowerCase().includes(search.toLowerCase()) || a.address.includes(search.toLowerCase()));
  const th = { padding: '10px 12px', fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: 'left' };
  const td = { padding: '11px 12px', fontFamily: 'var(--mono)', fontSize: 11.5, color: T.text, borderBottom: `1px solid ${T.border}` };

  return (
    <div style={{ overflowX: 'auto', marginTop: 12 }}>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead><tr>
          <th style={th}>AGENT</th><th style={th}>ADDRESS</th><th style={th}>STATUS</th>
          <th style={th}>PIPELINES</th><th style={th}>VOLUME</th><th style={th}>GOVERNANCE</th><th style={th}>LAST SEEN</th>
        </tr></thead>
        <tbody>
          {filtered.map((a, i) => (
            <Row key={a.name} idx={i} onClick={() => onSelect({ type: 'agent', data: a })}>
              <td style={{ ...td, color: T.accent }}><span className="xb-row-id" style={{ display: 'inline-block' }}>{a.name}</span></td>
              <td style={{ ...td, fontSize: 10, color: T.textMid }}>{a.address}</td>
              <td style={td}><Status status={a.status} /></td>
              <td style={td}>{a.pipelines}</td>
              <td style={td}>${Number(a.volume).toLocaleString()}</td>
              <td style={td}><Status status={a.governanceLevel} /></td>
              <td style={{ ...td, color: T.textDim, fontSize: 10 }}>{timeAgo(a.lastActive)}</td>
            </Row>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* ── Detail Panel ── */
function DetailSlide({ sel, onClose }) {
  if (!sel) return null;
  const { type, data } = sel;

  let _fieldIdx = 0;
  const field = (label, value, accent) => {
    const i = _fieldIdx++;
    return (
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '10px 0', borderBottom: `1px solid ${T.border}`,
        opacity: 0, animation: 'fadeInLine 0.32s ease forwards',
        animationDelay: `${0.04 + Math.min(i, 18) * 0.035}s`,
      }}>
        <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.12em' }}>{label}</span>
        <span style={{ fontFamily: 'var(--mono)', fontSize: 11.5, color: accent ? T.accent : T.text, textAlign: 'right', maxWidth: '60%', wordBreak: 'break-all' }}>{value}</span>
      </div>
    );
  };

  return (
    <>
      <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 299, backdropFilter: 'blur(4px)' }} onClick={onClose}></div>
      <div style={{
        position: 'fixed', top: 0, right: 0, bottom: 0, width: 520,
        background: T.bg2, borderLeft: `1px solid ${T.border}`,
        zIndex: 300, overflowY: 'auto',
        boxShadow: '-30px 0 80px rgba(0,0,0,0.6)',
        animation: 'slideInRight 0.2s ease',
      }}>
        {/* Header */}
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '18px 28px', borderBottom: `1px solid ${T.border}`,
          position: 'sticky', top: 0, background: T.bg2, zIndex: 1,
        }}>
          <div>
            <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.15em', marginBottom: 4 }}>
              {type.toUpperCase()} DETAIL
            </div>
            <div style={{ fontFamily: 'var(--mono)', fontSize: 14, color: T.accent, fontWeight: 600 }}>
              {type === 'pipeline' ? data.id : type === 'znode' ? data.id : data.name}
            </div>
          </div>
          <button onClick={onClose} style={{
            background: T.card, border: `1px solid ${T.border}`, color: T.textMid,
            width: 32, height: 32, cursor: 'pointer', fontFamily: 'var(--mono)', fontSize: 14,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'border-color 0.2s',
          }}
            onMouseEnter={e => e.target.style.borderColor = T.accent + '44'}
            onMouseLeave={e => e.target.style.borderColor = T.border}
          >✕</button>
        </div>

        <div style={{ padding: '20px 28px' }}>
          {/* Status banner */}
          <div style={{
            background: T.card, border: `1px solid ${T.border}`,
            padding: '14px 18px', marginBottom: 24,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <Status status={type === 'pipeline' ? data.status : type === 'znode' ? data.status : data.status} size="lg" />
            {type === 'pipeline' && <span style={{ fontFamily: 'var(--mono)', fontSize: 10, color: T.textDim }}>{data.type}</span>}
          </div>

          {type === 'pipeline' && <>
            {field('AGENT', data.agent, true)}
            {field('AMOUNT', `${data.amount} ${data.currency}`)}
            {field('FROM', data.from)}
            {field('TO', data.to)}
            {field('ZNODE', data.znode, true)}
            {field('BLOCK HEIGHT', data.blockHeight.toLocaleString())}
            {field('FEE', `${data.fee} SOL`)}
            {field('ZK PROOF', data.zkProof)}
            {field('COMPRESSED STATE', data.compressedState)}
            {field('TIMESTAMP', new Date(data.timestamp).toLocaleString())}

            <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.15em', margin: '28px 0 14px' }}>PIPELINE EXECUTION</div>
            <div style={{ position: 'relative', paddingLeft: 20 }}>
              {/* Vertical line */}
              <div style={{ position: 'absolute', left: 3, top: 4, bottom: 4, width: 1, background: T.border }}></div>
              {data.steps.map((step, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '10px 0', position: 'relative' }}>
                  <div style={{
                    width: 8, height: 8, borderRadius: '50%', flexShrink: 0,
                    background: step.status === 'done' ? T.green : T.yellow,
                    boxShadow: `0 0 8px ${step.status === 'done' ? T.green : T.yellow}44`,
                    position: 'absolute', left: -20,
                  }}></div>
                  <span style={{ fontFamily: 'var(--mono)', fontSize: 11, color: T.text }}>{step.label}</span>
                  <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, marginLeft: 'auto' }}>
                    {step.status === 'done' ? '✓ DONE' : '⧗ PENDING'}
                  </span>
                </div>
              ))}
            </div>
          </>}

          {type === 'znode' && <>
            {field('REGION', data.region)}
            {field('PEERS', data.peers)}
            {field('LATENCY', `${data.latency}ms`)}
            {field('UPTIME', `${(data.uptime * 100).toFixed(2)}%`)}
            {field('PIPELINES', data.pipelines.toLocaleString())}
            {field('STAKE', `${Number(data.stake).toLocaleString()} SOL`)}
            {field('VERSION', data.version)}
          </>}

          {type === 'agent' && <>
            {field('ADDRESS', data.address)}
            {field('ZK IDENTITY', data.zkIdentity)}
            {field('PIPELINES', data.pipelines.toLocaleString())}
            {field('VOLUME', `$${Number(data.volume).toLocaleString()}`)}
            {field('GOVERNANCE', data.governanceLevel)}
            {field('LAST ACTIVE', timeAgo(data.lastActive) + ' ago')}
          </>}
        </div>
      </div>
    </>
  );
}

/* ── Live Feed ── */
function LiveFeed2() {
  const [events, setEvents] = React.useState([]);
  React.useEffect(() => {
    let cancelled = false;
    function add() {
      if (cancelled) return;
      const types = ['PIPELINE_COMPLETE', 'ZK_VERIFIED', 'AGENT_AUTH', 'SETTLEMENT', 'SHIELDING', 'STATE_COMPRESSED', 'ZNODE_SYNC'];
      const agents = ['CFO_ALPHA', 'CFO_BETA', 'TREASURY_01', 'YIELD_HUNTER', 'RISK_MGMT', 'LIQUIDITY'];
      const colors = [T.green, T.cyan, T.accent, T.green, T.yellow, T.blue, T.accent];
      const idx = Math.floor(Math.random() * types.length);
      setEvents(prev => [{
        id: Math.random().toString(36).slice(2, 8),
        type: types[idx], agent: agents[Math.floor(Math.random() * agents.length)],
        color: colors[idx], ts: Date.now(),
      }, ...prev].slice(0, 30));
      timerId = setTimeout(add, 1200 + Math.random() * 2500);
    }
    let timerId = setTimeout(add, 500);
    return () => { cancelled = true; clearTimeout(timerId); };
  }, []);

  return (
    <div style={{ border: `1px solid ${T.border}`, background: T.bg2, flex: 1, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '10px 16px', borderBottom: `1px solid ${T.border}`,
        fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.12em',
        flexShrink: 0,
      }}>
        <span style={{ width: 6, height: 6, borderRadius: '50%', background: T.green, animation: 'livePulse 2s ease infinite' }}></span>
        LIVE ACTIVITY
      </div>
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {events.map(e => (
          <div key={e.id} style={{
            display: 'flex', gap: 8, padding: '7px 16px',
            borderBottom: `1px solid ${T.border}`,
            fontFamily: 'var(--mono)', fontSize: 10,
            animation: 'fadeInLine 0.25s ease',
          }}>
            <span style={{ color: T.textDim, flexShrink: 0, width: 55 }}>{new Date(e.ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
            <span style={{ color: e.color, flex: 1 }}>{e.type}</span>
            <span style={{ color: T.textDim }}>{e.agent}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { MeshCanvas, PipelinesView, ZnodesView, AgentsView, DetailSlide, LiveFeed2 });
