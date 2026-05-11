/* xB77 Explorer v2 — Sections: Mesh Hero, Agents, Merchants, Telegram, MCP */

/* ── Full-width Mesh Hero with live stats ── */
function MeshHero({ znodes }) {
  const canvasRef = React.useRef(null);
  const animRef = React.useRef(null);
  const nodesRef = React.useRef([]);

  React.useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const W = canvas.offsetWidth, H = 320;
    canvas.width = W * 2; canvas.height = H * 2;
    ctx.scale(2, 2);

    if (nodesRef.current.length === 0) {
      nodesRef.current = znodes.slice(0, 28).map((z) => ({
        x: 40 + Math.random() * (W - 80),
        y: 20 + Math.random() * (H - 40),
        vx: (Math.random() - 0.5) * 0.2,
        vy: (Math.random() - 0.5) * 0.2,
        r: z.status === 'ONLINE' ? 4 : 3,
        color: z.status === 'ONLINE' ? '#c8ff2e' : z.status === 'SYNCING' ? '#f0c040' : '#ff4455',
        pulsePhase: Math.random() * Math.PI * 2,
      }));
    }
    const nodes = nodesRef.current;
    let frame = 0;

    function draw() {
      ctx.clearRect(0, 0, W, H);
      frame++;
      nodes.forEach(n => {
        n.x += n.vx; n.y += n.vy;
        if (n.x < 30 || n.x > W - 30) n.vx *= -1;
        if (n.y < 20 || n.y > H - 20) n.vy *= -1;
        n.pulsePhase += 0.02;
      });

      // Connections
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const dx = nodes[i].x - nodes[j].x, dy = nodes[i].y - nodes[j].y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 140) {
            const alpha = (1 - dist / 140) * 0.1;
            ctx.beginPath();
            ctx.moveTo(nodes[i].x, nodes[i].y);
            ctx.lineTo(nodes[j].x, nodes[j].y);
            ctx.strokeStyle = `rgba(200,255,46,${alpha})`;
            ctx.lineWidth = 0.5;
            ctx.stroke();

            // Traveling data packet
            if (Math.random() < 0.001) {
              const t = (frame % 60) / 60;
              const px = nodes[i].x + (nodes[j].x - nodes[i].x) * t;
              const py = nodes[i].y + (nodes[j].y - nodes[i].y) * t;
              ctx.beginPath();
              ctx.arc(px, py, 2, 0, Math.PI * 2);
              ctx.fillStyle = 'rgba(200,255,46,0.6)';
              ctx.fill();
            }
          }
        }
      }

      // Nodes
      nodes.forEach(n => {
        const pulse = 1 + Math.sin(n.pulsePhase) * 0.15;
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.r * 4 * pulse, 0, Math.PI * 2);
        ctx.fillStyle = n.color.slice(0, 7) + '06';
        ctx.fill();
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.r * pulse, 0, Math.PI * 2);
        ctx.fillStyle = n.color + 'cc';
        ctx.fill();
      });

      animRef.current = requestAnimationFrame(draw);
    }
    draw();
    return () => cancelAnimationFrame(animRef.current);
  }, []);

  return <canvas ref={canvasRef} style={{ width: '100%', height: 320, display: 'block' }} />;
}

/* ── Poseidon Commits Tab ── */
function PoseidonView({ data, search, onSelect }) {
  const [page, setPage] = React.useState(1);
  const filtered = data.filter(p => {
    if (!search) return true;
    const s = search.toLowerCase();
    return p.id.includes(s) || p.hash.includes(s) || p.type.toLowerCase().includes(s) || (p.agent || '').toLowerCase().includes(s);
  });
  const pages = Math.max(1, Math.ceil(filtered.length / 12));
  const slice = filtered.slice((page - 1) * 12, page * 12);
  React.useEffect(() => setPage(1), [search]);

  const th = { padding: '10px 12px', fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.14em', textTransform: 'uppercase', fontWeight: 600, borderBottom: `1px solid ${T.border}`, textAlign: 'left' };
  const td = { padding: '11px 12px', fontFamily: 'var(--mono)', fontSize: 11, color: T.text, borderBottom: `1px solid ${T.border}` };

  return (
    <div>
      <div style={{ overflowX: 'auto', marginTop: 8 }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr>
            <th style={th}>COMMIT</th><th style={th}>TYPE</th><th style={th}>AGENT</th>
            <th style={th}>MERCHANT</th><th style={th}>AMOUNT</th><th style={th}>STATUS</th><th style={th}>AGE</th>
          </tr></thead>
          <tbody>
            {slice.map((p, i) => (
              <Row key={p.id} idx={i} onClick={() => onSelect({ type: 'poseidon', data: p })}>
                <td style={{ ...td, color: T.accent, fontSize: 10 }}>{p.id}</td>
                <td style={{ ...td, fontSize: 9.5, color: T.textMid }}>{p.type}</td>
                <td style={td}>{p.agent}</td>
                <td style={{ ...td, color: p.merchant ? T.cyan : T.textDim, fontSize: 10 }}>{p.merchant || '—'}</td>
                <td style={td}>${p.amount}</td>
                <td style={td}><Status status={p.status} /></td>
                <td style={{ ...td, color: T.textDim, fontSize: 10 }}>{timeAgo(p.timestamp)}</td>
              </Row>
            ))}
          </tbody>
        </table>
      </div>
      <Pager page={page} total={pages} onChange={setPage} />
    </div>
  );
}

/* ── Merchants Discovery ── */
function MerchantsView({ data, search, onSelect }) {
  const [catFilter, setCatFilter] = React.useState('ALL');
  const cats = ['ALL', ...new Set(data.map(m => m.category))];
  const filtered = data.filter(m => {
    if (catFilter !== 'ALL' && m.category !== catFilter) return false;
    if (search) {
      const s = search.toLowerCase();
      return m.name.toLowerCase().includes(s) || m.domain.includes(s) || m.category.toLowerCase().includes(s);
    }
    return true;
  });

  return (
    <div>
      <div style={{ display: 'flex', gap: 6, padding: '14px 0', flexWrap: 'wrap' }}>
        {cats.map(c => <FilterChip key={c} label={c} active={catFilter === c} onClick={() => setCatFilter(c)} />)}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 1, background: T.border }}>
        {filtered.map((m, i) => {
          const [h, setH] = React.useState(false);
          return (
            <div key={m.id} style={{
              background: h ? T.cardHover : T.bg, padding: '24px 22px',
              cursor: 'pointer', transition: 'background 0.2s',
            }}
              onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
              onClick={() => onSelect({ type: 'merchant', data: m })}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    <span style={{ fontFamily: 'var(--sans)', fontSize: 15, color: T.text, fontWeight: 600 }}>{m.name}</span>
                    {m.verified && <span style={{ fontSize: 8, color: T.green, fontFamily: 'var(--mono)', border: `1px solid ${T.green}33`, padding: '1px 5px', background: `${T.green}11` }}>VERIFIED</span>}
                  </div>
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: T.textDim }}>{m.domain}</div>
                </div>
                <Sparkline data={m.sparkVolume} width={60} height={20} color={T.cyan} />
              </div>
              <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
                <MiniStat label="VOLUME" value={'$' + Number(m.totalVolume).toLocaleString()} />
                <MiniStat label="TXS" value={m.txCount.toLocaleString()} />
                <MiniStat label="AGENTS" value={m.agents} />
                <MiniStat label="POSEIDON" value={m.poseidonCommits} />
              </div>
              <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, padding: '2px 6px', border: `1px solid ${T.border}` }}>{m.category}</span>
                <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, padding: '2px 6px', border: `1px solid ${T.border}` }}>{m.appVersion}</span>
                {m.telegramLinked && <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.blue, padding: '2px 6px', border: `1px solid ${T.blue}33`, background: `${T.blue}11` }}>TG</span>}
                {m.mcpEnabled && <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.accent, padding: '2px 6px', border: `1px solid ${T.accent}33`, background: T.accentDim }}>MCP</span>}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function MiniStat({ label, value }) {
  return (
    <div>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 7.5, color: T.textDim, letterSpacing: '0.15em' }}>{label}</div>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 12, color: T.text, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

/* ── Rich Agents View ── */
function AgentsRichView({ data, search, onSelect }) {
  const filtered = data.filter(a => !search || a.name.toLowerCase().includes(search.toLowerCase()));
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 1, background: T.border, marginTop: 12 }}>
      {filtered.map((a, i) => {
        const [h, setH] = React.useState(false);
        return (
          <div key={a.name} style={{
            background: h ? T.cardHover : T.bg, padding: '24px 22px',
            cursor: 'pointer', transition: 'background 0.2s',
          }}
            onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
            onClick={() => onSelect({ type: 'agent', data: a })}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14 }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 3 }}>
                  <Status status={a.status} size="lg" />
                </div>
                <div style={{ fontFamily: 'var(--mono)', fontSize: 15, color: T.accent, fontWeight: 600, marginTop: 6 }}>{a.name}</div>
                <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, marginTop: 2 }}>{a.address}</div>
              </div>
              <Sparkline data={a.sparkActivity} width={70} height={24} />
            </div>

            <div style={{ display: 'flex', gap: 16, marginBottom: 14, flexWrap: 'wrap' }}>
              <MiniStat label="PIPELINES" value={a.pipelines} />
              <MiniStat label="VOLUME" value={'$' + Number(a.volume).toLocaleString()} />
              <MiniStat label="POSEIDON" value={a.poseidonCommits} />
              <MiniStat label="MERCHANTS" value={a.merchantsServed} />
              <MiniStat label="EARNINGS" value={'$' + Number(a.totalEarnings).toLocaleString()} />
            </div>

            {/* Recent commits */}
            <div style={{ fontFamily: 'var(--mono)', fontSize: 8, color: T.textDim, letterSpacing: '0.12em', marginBottom: 6 }}>RECENT POSEIDON COMMITS</div>
            {a.recentCommits.slice(0, 3).map((c, j) => (
              <div key={j} style={{
                display: 'flex', gap: 8, padding: '4px 0',
                fontFamily: 'var(--mono)', fontSize: 9.5, borderBottom: `1px solid ${T.border}`,
              }}>
                <span style={{ color: T.textDim }}>{timeAgo(c.ts)}</span>
                <span style={{ color: T.textMid }}>{c.type}</span>
                <span style={{ color: T.text, marginLeft: 'auto' }}>${c.amount}</span>
              </div>
            ))}

            {/* Integration badges */}
            <div style={{ display: 'flex', gap: 6, marginTop: 12 }}>
              <span style={{ fontFamily: 'var(--mono)', fontSize: 8, color: T.textDim, padding: '2px 6px', border: `1px solid ${T.border}` }}>{a.appVersion}</span>
              <span style={{
                fontFamily: 'var(--mono)', fontSize: 8,
                color: a.telegramStatus === 'CONNECTED' ? T.blue : T.textDim,
                padding: '2px 6px',
                border: `1px solid ${a.telegramStatus === 'CONNECTED' ? T.blue + '33' : T.border}`,
                background: a.telegramStatus === 'CONNECTED' ? T.blue + '11' : 'transparent',
              }}>TG {a.telegramStatus}</span>
              {a.mcpEndpoint && <span style={{ fontFamily: 'var(--mono)', fontSize: 8, color: T.accent, padding: '2px 6px', border: `1px solid ${T.accent}33`, background: T.accentDim }}>MCP</span>}
              <span style={{ fontFamily: 'var(--mono)', fontSize: 8, color: T.textDim, padding: '2px 6px', border: `1px solid ${T.border}` }}>{a.governanceLevel}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ── Telegram Intel Panel ── */
function TelegramPanel() {
  const [msgs, setMsgs] = React.useState([]);
  React.useEffect(() => {
    let cancelled = false, idx = 0;
    function add() {
      if (cancelled) return;
      const evt = TELEGRAM_EVENTS[idx % TELEGRAM_EVENTS.length];
      setMsgs(prev => [{ ...evt, id: Math.random().toString(36).slice(2, 7), ts: Date.now() }, ...prev].slice(0, 25));
      idx++;
      timerId = setTimeout(add, 2000 + Math.random() * 3000);
    }
    let timerId = setTimeout(add, 800);
    return () => { cancelled = true; clearTimeout(timerId); };
  }, []);

  const typeColors = { COMMAND: T.accent, ALERT: T.yellow, INTEL: T.cyan, REPORT: T.green };

  return (
    <div style={{ border: `1px solid ${T.border}`, background: T.bg2, display: 'flex', flexDirection: 'column', minHeight: 0, flex: 1 }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '10px 14px', borderBottom: `1px solid ${T.border}`,
        fontFamily: 'var(--mono)', fontSize: 9, color: T.blue, letterSpacing: '0.1em',
        flexShrink: 0,
      }}>
        <span style={{ fontSize: 12 }}>✦</span> TELEGRAM INTEL
        <span style={{ marginLeft: 'auto', fontSize: 8, color: T.textDim }}>@xb77_ops</span>
      </div>
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {msgs.map(m => (
          <div key={m.id} style={{
            padding: '8px 14px', borderBottom: `1px solid ${T.border}`,
            animation: 'fadeInLine 0.25s ease',
          }}>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3 }}>
              <span style={{ fontFamily: 'var(--mono)', fontSize: 8, color: typeColors[m.type] || T.textDim, letterSpacing: '0.08em', padding: '1px 4px', border: `1px solid ${(typeColors[m.type] || T.textDim) + '33'}` }}>{m.type}</span>
              <span style={{ fontFamily: 'var(--mono)', fontSize: 8, color: T.textDim }}>{m.agent}</span>
              <span style={{ fontFamily: 'var(--mono)', fontSize: 8, color: T.textDim, marginLeft: 'auto' }}>{new Date(m.ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
            <div style={{ fontFamily: 'var(--mono)', fontSize: 10.5, color: T.text, lineHeight: 1.5 }}>{m.msg}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── MCP CLI Preview ── */
function MCPPanel() {
  const [cmdIdx, setCmdIdx] = React.useState(0);
  const [typing, setTyping] = React.useState('');
  const [showOutput, setShowOutput] = React.useState(false);

  React.useEffect(() => {
    let cancelled = false;
    const cmd = MCP_COMMANDS[cmdIdx % MCP_COMMANDS.length];
    let charIdx = 0;
    setTyping(''); setShowOutput(false);

    function typeChar() {
      if (cancelled) return;
      if (charIdx < cmd.cmd.length) {
        setTyping(cmd.cmd.slice(0, charIdx + 1));
        charIdx++;
        timerId = setTimeout(typeChar, 40 + Math.random() * 30);
      } else {
        setTimeout(() => {
          if (!cancelled) setShowOutput(true);
          setTimeout(() => {
            if (!cancelled) setCmdIdx(i => i + 1);
          }, 3500);
        }, 400);
      }
    }
    let timerId = setTimeout(typeChar, 500);
    return () => { cancelled = true; clearTimeout(timerId); };
  }, [cmdIdx]);

  const cmd = MCP_COMMANDS[cmdIdx % MCP_COMMANDS.length];

  return (
    <div style={{ border: `1px solid ${T.border}`, background: '#0a0a0e', flexShrink: 0 }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '8px 14px', borderBottom: `1px solid ${T.border}`,
        fontFamily: 'var(--mono)', fontSize: 9, color: T.accent, letterSpacing: '0.1em',
      }}>
        <span style={{ opacity: 0.6 }}>▸</span> MCP CLI
        <span style={{ marginLeft: 'auto', fontSize: 8, color: T.textDim }}>xb77-mcp v0.7.2</span>
      </div>
      <div style={{ padding: '12px 14px', fontFamily: 'var(--mono)', fontSize: 11, lineHeight: 1.6 }}>
        <div>
          <span style={{ color: T.accent }}>$ </span>
          <span style={{ color: T.text }}>{typing}</span>
          <span style={{ color: T.accent, animation: 'livePulse 1s ease infinite' }}>▊</span>
        </div>
        {showOutput && (
          <div style={{ color: T.textMid, marginTop: 6, whiteSpace: 'pre-wrap', fontSize: 10, animation: 'fadeInLine 0.3s ease' }}>
            {cmd.output}
          </div>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { MeshHero, PoseidonView, MerchantsView, AgentsRichView, TelegramPanel, MCPPanel, MiniStat });
