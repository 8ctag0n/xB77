/* xB77 /network — Deluxe. Pulse + Audit + Fleet + Pipelines Feed.
 *
 * Hash-mount bootstrap at bottom: takes over when location.hash === '#network',
 * yields back to the original router on any other hash. Does NOT touch
 * router.jsx (W1-owned).
 *
 * Sections:
 *   1. Network Pulse       — 4 big numbers + sparklines + count-up
 *   2. Ghost Audit Portal  — input + sample chips + chunk strip + verdict card
 *   3. Agent Fleet         — 5 agent cards (consumes DataSource.agents)
 *   4. Recent Pipelines    — live feed (consumes DataSource.pipelinesRecent)
 *
 * Theme: D constants from dapp-shared.js. Magenta is local.
 */

const NET_MAGENTA = '#e94da4';
const NET_SAMPLE_HASHES = [
  { label: 'VALID',   hash: '5K3sP9Rb2vQfNm8jX1pT4hY7wL9aE6cZ0gA' },
  { label: 'INVALID', hash: '8mP4xR9nQ2vW6kL5sH3jY1cT7bF0aE2gZd' },
  { label: 'PENDING', hash: '3T7nB1xR9mQ4vL8kP2sH5jY6cW0aE3gZbf' },
];

/* ── helpers ─────────────────────────────────────────────────────── */
function _netSourceColor(source) {
  if (source === 'live') return D.accent;
  if (source === 'cached') return NET_MAGENTA;
  return D.muted;
}
function _netSourceLabel(payload) {
  if (!payload) return '// …';
  if (payload._source === 'live') return '// LIVE';
  if (payload._source === 'cached') {
    const s = Math.round((payload._ageMs || 0) / 1000);
    return `// CACHED ${s}s`;
  }
  return '// SNAPSHOT';
}

/* Count-up hook: smoothly tween a number toward target. */
function useCountUp(target, durMs = 600) {
  const [val, setVal] = React.useState(target ?? 0);
  const fromRef = React.useRef(target ?? 0);
  React.useEffect(() => {
    if (target == null) return;
    const start = performance.now();
    const from = fromRef.current;
    const delta = target - from;
    let raf;
    const tick = (t) => {
      const k = Math.min(1, (t - start) / durMs);
      const eased = 1 - Math.pow(1 - k, 3);
      setVal(from + delta * eased);
      if (k < 1) raf = requestAnimationFrame(tick);
      else fromRef.current = target;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, durMs]);
  return val;
}

/* Rolling history hook: keeps last N samples for sparkline. */
function useHistory(value, max = 30) {
  const [hist, setHist] = React.useState([]);
  React.useEffect(() => {
    if (value == null) return;
    setHist((h) => {
      const next = h.concat([value]);
      return next.length > max ? next.slice(next.length - max) : next;
    });
  }, [value]);
  return hist;
}

/* ── sparkline (SVG path) ─────────────────────────────────────────── */
function NetSparkline({ data, color, height = 28 }) {
  if (!data || data.length < 2) {
    return <div style={{ height }} />;
  }
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const w = 100;
  const h = height;
  const points = data.map((v, i) => {
    const x = (i / (data.length - 1)) * w;
    const y = h - ((v - min) / range) * (h - 2) - 1;
    return `${x.toFixed(2)},${y.toFixed(2)}`;
  });
  const path = `M ${points.join(' L ')}`;
  const area = `${path} L ${w},${h} L 0,${h} Z`;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" style={{ width: '100%', height, display: 'block' }}>
      <defs>
        <linearGradient id={`spark-${color.replace('#','')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.35" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={area} fill={`url(#spark-${color.replace('#','')})`} />
      <path d={path} fill="none" stroke={color} strokeWidth="1" />
    </svg>
  );
}

/* ── Big number tile with sparkline ───────────────────────────────── */
function NetBigStat({ label, value, hint, history, color }) {
  const c = color || D.accent;
  const animated = useCountUp(typeof value === 'number' ? value : null);
  const display = typeof value === 'number'
    ? Math.round(animated).toLocaleString('en-US')
    : '—';
  return (
    <div style={{
      flex: 1, minWidth: 180,
      padding: '22px 22px 18px',
      background: D.bg2,
      border: `1px solid ${D.border}`,
      position: 'relative', overflow: 'hidden',
    }}>
      <DM size={9}>{label}</DM>
      <div style={{
        fontFamily: 'var(--serif)',
        fontSize: 44, fontStyle: 'italic', color: D.text,
        marginTop: 12, lineHeight: 1,
        letterSpacing: '-0.02em',
        fontVariantNumeric: 'tabular-nums',
      }}>{display}</div>
      <div style={{ marginTop: 14, marginLeft: -2, marginRight: -2 }}>
        <NetSparkline data={history} color={c} height={24} />
      </div>
      {hint && (
        <div style={{
          fontFamily: 'var(--mono)', fontSize: 9, color: D.dim,
          marginTop: 6, letterSpacing: '0.1em',
        }}>{hint}</div>
      )}
    </div>
  );
}

/* ── Status pill ─────────────────────────────────────────────────── */
function NetStatusPill({ payload }) {
  const color = _netSourceColor(payload?._source);
  const label = _netSourceLabel(payload);
  const blink = payload?._source === 'cached';
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      padding: '6px 12px',
      border: `1px solid ${D.border}`,
      background: D.bg2,
    }}>
      <span style={{
        width: 7, height: 7, borderRadius: '50%',
        background: color, flexShrink: 0,
        animation: blink ? 'livePulse 1.4s ease infinite' : 'none',
        boxShadow: payload?._source === 'live' ? `0 0 8px ${color}` : 'none',
      }} />
      <span style={{
        fontFamily: 'var(--mono)', fontSize: 10, fontWeight: 600,
        letterSpacing: '0.14em', color,
      }}>{label}</span>
    </div>
  );
}

/* ── Section: Network Pulse ───────────────────────────────────────── */
function NetworkPulseSection() {
  const [pulse, setPulse] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe('networkPulse', setPulse, 3000);
  }, []);

  const slotHist   = useHistory(pulse?.slot);
  const heightHist = useHistory(pulse?.blockHeight);
  const agentsHist = useHistory(pulse?.agentsOnline);
  const proofsHist = useHistory(pulse?.proofsVerified24h);

  return (
    <section style={{ padding: '40px 0', borderBottom: `1px solid ${D.border}` }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: 24, flexWrap: 'wrap', gap: 12,
      }}>
        <div>
          <DM>Network Pulse</DM>
          <div style={{ marginTop: 8 }}>
            <DS size={32} italic>Live network state.</DS>
          </div>
        </div>
        <NetStatusPill payload={pulse} />
      </div>

      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
        <NetBigStat label="Slot"                value={pulse?.slot}              hint="solana validator"      history={slotHist}   color={D.accent} />
        <NetBigStat label="Block Height"        value={pulse?.blockHeight}       hint="finalized"             history={heightHist} color={D.cyan}   />
        <NetBigStat label="Agents Online"       value={pulse?.agentsOnline}      hint="autonomous CFO mesh"   history={agentsHist} color={D.purple} />
        <NetBigStat label="Proofs Verified 24h" value={pulse?.proofsVerified24h} hint="zk-pipeline throughput" history={proofsHist} color={NET_MAGENTA} />
      </div>
    </section>
  );
}

/* ── Chunk strip for proof viz ────────────────────────────────────── */
function ChunkStrip({ chunks, verdict, animate }) {
  const n = chunks || 8;
  const color = verdict === 'VALID' ? D.accent
    : verdict === 'INVALID' ? NET_MAGENTA
    : verdict === 'PENDING' ? D.cyan
    : D.dim;
  return (
    <div style={{ display: 'flex', gap: 4, marginTop: 14 }}>
      {Array.from({ length: n }).map((_, i) => (
        <div key={i} style={{
          flex: 1, height: 8,
          background: color,
          opacity: 0.35 + ((i + 1) / n) * 0.65,
          animation: animate ? `chunkPulse 1.4s ${i * 0.08}s ease-in-out infinite` : 'none',
        }} />
      ))}
    </div>
  );
}

/* ── Section: Ghost Audit Portal ──────────────────────────────────── */
const VERDICT_COLOR = {
  VALID:   D.accent,
  INVALID: NET_MAGENTA,
  PENDING: D.cyan,
};

function GhostAuditSection() {
  const [hash, setHash] = React.useState('');
  const [result, setResult] = React.useState(null);
  const [loading, setLoading] = React.useState(false);
  const [statusLine, setStatusLine] = React.useState('');

  async function runAudit(h) {
    const target = (h ?? hash).trim();
    if (!target || !window.DataSource) return;
    setHash(target);
    setLoading(true);
    setResult(null);

    const steps = [
      'querying zk verifier…',
      'reconstructing proof witness…',
      'verifying chunks…',
      'finalizing verdict…',
    ];
    let i = 0;
    setStatusLine(steps[0]);
    const iv = setInterval(() => {
      i = (i + 1) % steps.length;
      setStatusLine(steps[i]);
    }, 420);

    try {
      const minWait = new Promise((r) => setTimeout(r, 900));
      const [r] = await Promise.all([window.DataSource.auditTx(target), minWait]);
      setResult(r);
    } finally {
      clearInterval(iv);
      setStatusLine('');
      setLoading(false);
    }
  }

  const verdictColor = result ? (VERDICT_COLOR[result.verdict] || D.text) : D.text;

  return (
    <section style={{ padding: '40px 0', borderBottom: `1px solid ${D.border}` }}>
      <div style={{ marginBottom: 24 }}>
        <DM>Ghost Audit Portal</DM>
        <div style={{ marginTop: 8 }}>
          <DS size={32} italic>Verify any transaction.</DS>
        </div>
        <div style={{
          fontFamily: 'var(--sans)', fontSize: 13, color: D.dim, marginTop: 8,
          maxWidth: 560, lineHeight: 1.6,
        }}>
          Paste a tx hash. The portal queries the zk verifier on-chain and returns
          the verdict, proof ID, and the agent that signed the pipeline.
        </div>
      </div>

      {/* Sample chips */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 14 }}>
        <span style={{
          fontFamily: 'var(--mono)', fontSize: 9, color: D.dim,
          letterSpacing: '0.14em', alignSelf: 'center', marginRight: 4,
        }}>try:</span>
        {NET_SAMPLE_HASHES.map((s) => (
          <button key={s.label} onClick={() => runAudit(s.hash)} style={{
            fontFamily: 'var(--mono)', fontSize: 9, fontWeight: 600,
            letterSpacing: '0.16em', textTransform: 'uppercase',
            background: 'transparent',
            color: VERDICT_COLOR[s.label] || D.text,
            border: `1px solid ${VERDICT_COLOR[s.label] || D.border}`,
            padding: '5px 12px', cursor: 'pointer',
            transition: 'all 0.28s ease',
          }}>{s.label}</button>
        ))}
      </div>

      {/* Input bar */}
      <div style={{ display: 'flex', gap: 0, marginBottom: 20, maxWidth: 720 }}>
        <input
          type="text"
          value={hash}
          onChange={(e) => setHash(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') runAudit(); }}
          placeholder="tx hash (e.g. 5K3sP9...)"
          style={{
            flex: 1,
            fontFamily: 'var(--mono)', fontSize: 12,
            background: D.bg2, color: D.text,
            border: `1px solid ${D.border}`,
            borderRight: 'none',
            padding: '14px 16px',
            outline: 'none',
            letterSpacing: '0.04em',
          }}
        />
        <button
          onClick={() => runAudit()}
          disabled={loading || !hash.trim()}
          style={{
            fontFamily: 'var(--mono)', fontSize: 11, fontWeight: 600,
            letterSpacing: '0.18em', textTransform: 'uppercase',
            background: loading ? D.bg3 : D.accent,
            color: loading ? D.dim : D.bg,
            border: `1px solid ${D.accent}`,
            padding: '0 28px',
            cursor: loading || !hash.trim() ? 'not-allowed' : 'pointer',
            transition: 'all 0.28s ease',
          }}
        >{loading ? 'auditing…' : 'audit'}</button>
      </div>

      {/* Loading state */}
      {loading && (
        <div style={{
          padding: '20px 24px',
          background: D.bg2,
          border: `1px solid ${D.border}`,
          borderLeft: `3px solid ${D.cyan}`,
          maxWidth: 720,
        }}>
          <div style={{
            fontFamily: 'var(--mono)', fontSize: 11, color: D.cyan,
            letterSpacing: '0.14em', textTransform: 'uppercase',
          }}>{statusLine || '…'}</div>
          <ChunkStrip chunks={8} verdict="PENDING" animate />
        </div>
      )}

      {/* Result card */}
      {result && !loading && (
        <div style={{
          padding: '24px 28px',
          background: D.bg2,
          border: `1px solid ${D.border}`,
          borderLeft: `3px solid ${verdictColor}`,
          maxWidth: 720,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
            <div style={{
              fontFamily: 'var(--mono)', fontSize: 22, fontWeight: 700,
              letterSpacing: '0.18em', color: verdictColor,
            }}>{result.verdict}</div>
            <NetStatusPill payload={result} />
          </div>

          <ChunkStrip chunks={result.chunks} verdict={result.verdict} />

          <div style={{
            display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 18, marginTop: 22,
          }}>
            <div>
              <DM size={8}>Proof ID</DM>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 12, color: D.text, marginTop: 6, wordBreak: 'break-all' }}>
                {result.proofId}
              </div>
            </div>
            <div>
              <DM size={8}>Agent</DM>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 12, color: D.accent, marginTop: 6 }}>
                {result.agent}
              </div>
            </div>
            <div>
              <DM size={8}>Chunks</DM>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 12, color: D.text, marginTop: 6 }}>
                {result.chunks}
              </div>
            </div>
            <div>
              <DM size={8}>Timestamp</DM>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 12, color: D.text, marginTop: 6 }}>
                {result.timestamp ? new Date(result.timestamp).toISOString().replace('T', ' ').slice(0, 19) : '—'}
              </div>
            </div>
          </div>

          <div style={{
            marginTop: 20, paddingTop: 16,
            borderTop: `1px solid ${D.border}`,
            fontFamily: 'var(--mono)', fontSize: 10, color: D.dim,
            letterSpacing: '0.04em', wordBreak: 'break-all',
          }}>
            tx: {result.txhash}
          </div>
        </div>
      )}
    </section>
  );
}

/* ── Section: Agent Fleet ─────────────────────────────────────────── */
function AgentFleetSection() {
  const [data, setData] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe('agents', setData, 10_000);
  }, []);

  const agents = data?.agents || [];

  return (
    <section style={{ padding: '40px 0', borderBottom: `1px solid ${D.border}` }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: 24, flexWrap: 'wrap', gap: 12,
      }}>
        <div>
          <DM>Agent Fleet</DM>
          <div style={{ marginTop: 8 }}>
            <DS size={32} italic>Five autonomous CFOs.</DS>
          </div>
        </div>
        <NetStatusPill payload={data} />
      </div>

      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
        gap: 12,
      }}>
        {agents.map((a) => {
          const online = a.status === 'online';
          const idle = a.status === 'idle';
          const dotColor = online ? D.accent : idle ? D.amber : D.muted;
          return (
            <div key={a.id} style={{
              padding: '18px 18px 16px',
              background: D.bg2,
              border: `1px solid ${D.border}`,
              borderLeft: `2px solid ${dotColor}`,
              position: 'relative',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{
                  fontFamily: 'var(--mono)', fontWeight: 700, fontSize: 14,
                  color: D.text, letterSpacing: '0.06em', textTransform: 'uppercase',
                }}>{a.id}</div>
                <span style={{
                  width: 6, height: 6, borderRadius: '50%',
                  background: dotColor,
                  boxShadow: online ? `0 0 6px ${dotColor}` : 'none',
                  animation: online ? 'livePulse 2.2s ease infinite' : 'none',
                }} />
              </div>
              <div style={{
                fontFamily: 'var(--mono)', fontSize: 10, color: D.dim,
                marginTop: 4, letterSpacing: '0.04em',
              }}>{a.pubkey}</div>

              <div style={{
                display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
                marginTop: 16, gap: 12,
              }}>
                <div>
                  <DM size={8}>pipelines</DM>
                  <div style={{ fontFamily: 'var(--serif)', fontStyle: 'italic', fontSize: 22, color: D.text, lineHeight: 1, marginTop: 4 }}>
                    {a.pipelines}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <DM size={8}>uptime</DM>
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 13, color: online ? D.accent : D.dim, marginTop: 6 }}>
                    {(a.uptime * 100).toFixed(1)}%
                  </div>
                </div>
              </div>

              <div style={{
                marginTop: 12,
                fontFamily: 'var(--mono)', fontSize: 9, color: dotColor,
                letterSpacing: '0.18em', textTransform: 'uppercase',
              }}>{a.status}</div>
            </div>
          );
        })}
      </div>
    </section>
  );
}

/* ── Section: Recent Pipelines ────────────────────────────────────── */
function RecentPipelinesSection() {
  const [data, setData] = React.useState(null);
  React.useEffect(() => {
    if (!window.DataSource) return;
    return window.DataSource.subscribe('pipelinesRecent', setData, 5_000);
  }, []);

  const pipelines = data?.pipelines || [];

  function fmtAge(ts) {
    if (!ts) return '—';
    const s = Math.max(0, Math.floor((Date.now() - ts) / 1000));
    if (s < 60) return `${s}s ago`;
    return `${Math.floor(s / 60)}m ${s % 60}s ago`;
  }
  function fmtDur(ms) {
    if (ms == null) return '—';
    return `${(ms / 1000).toFixed(2)}s`;
  }

  return (
    <section style={{ padding: '40px 0' }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        marginBottom: 24, flexWrap: 'wrap', gap: 12,
      }}>
        <div>
          <DM>Recent Pipelines</DM>
          <div style={{ marginTop: 8 }}>
            <DS size={32} italic>The mesh in motion.</DS>
          </div>
        </div>
        <NetStatusPill payload={data} />
      </div>

      <div style={{
        background: D.bg2,
        border: `1px solid ${D.border}`,
      }}>
        {/* header */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1.5fr 1fr 0.6fr 1fr 0.8fr 0.8fr',
          padding: '10px 18px',
          borderBottom: `1px solid ${D.border}`,
          background: D.bg3,
          fontFamily: 'var(--mono)', fontSize: 9, color: D.dim,
          letterSpacing: '0.14em', textTransform: 'uppercase',
        }}>
          <div>Pipeline</div><div>Agent</div><div>Chunks</div>
          <div>Status</div><div>Duration</div><div style={{ textAlign: 'right' }}>Started</div>
        </div>

        {pipelines.map((p) => {
          const running = p.status === 'running';
          const verdictColor = p.verdict === 'VALID' ? D.accent
            : p.verdict === 'INVALID' ? NET_MAGENTA
            : running ? D.cyan : D.dim;
          return (
            <div key={p.id} style={{
              display: 'grid',
              gridTemplateColumns: '1.5fr 1fr 0.6fr 1fr 0.8fr 0.8fr',
              padding: '14px 18px',
              borderBottom: `1px solid ${D.border}`,
              alignItems: 'center',
              fontFamily: 'var(--mono)', fontSize: 11, color: D.text,
            }}>
              <div style={{ color: D.dim, wordBreak: 'break-all', paddingRight: 12 }}>
                {p.id}
              </div>
              <div style={{ color: D.accent }}>{p.agent}</div>
              <div>{p.chunks}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{
                  width: 6, height: 6, borderRadius: '50%',
                  background: verdictColor,
                  animation: running ? 'livePulse 1.2s ease infinite' : 'none',
                  boxShadow: running ? `0 0 5px ${verdictColor}` : 'none',
                  flexShrink: 0,
                }} />
                <span style={{
                  color: verdictColor, fontSize: 10, fontWeight: 600,
                  letterSpacing: '0.14em', textTransform: 'uppercase',
                }}>{running ? 'running' : p.verdict || p.status}</span>
              </div>
              <div style={{ color: D.text }}>{fmtDur(p.duration)}</div>
              <div style={{ color: D.dim, textAlign: 'right' }}>{fmtAge(p.startedAt)}</div>
            </div>
          );
        })}

        {pipelines.length === 0 && (
          <div style={{ padding: '24px 18px', fontFamily: 'var(--mono)', fontSize: 11, color: D.dim }}>
            waiting for pipelines…
          </div>
        )}
      </div>
    </section>
  );
}

/* ── Page shell ──────────────────────────────────────────────────── */
function NetworkPage() {
  return (
    <div style={{ background: D.bg, minHeight: '100vh', color: D.text }}>
      <style>{`
        @keyframes chunkPulse {
          0%, 100% { opacity: 0.35; }
          50%      { opacity: 1; }
        }
      `}</style>
      {window.InnerNav && <InnerNav active="Network" />}
      <div style={{ maxWidth: 1200, margin: '0 auto', padding: '60px 32px 80px' }}>
        <div style={{ marginBottom: 32 }}>
          <DM>// xB77 · Network</DM>
          <div style={{ marginTop: 12 }}>
            <DS size={48} italic>The mesh, observed.</DS>
          </div>
          <div style={{
            fontFamily: 'var(--sans)', fontSize: 14, color: D.dim,
            maxWidth: 640, marginTop: 12, lineHeight: 1.6,
          }}>
            Real-time view of the xB77 zk-pipeline network. Slot, block height,
            agent fleet, audit portal, and the live pipeline feed.
          </div>
        </div>

        <NetworkPulseSection />
        <GhostAuditSection />
        <AgentFleetSection />
        <RecentPipelinesSection />
      </div>
      {window.DocsDeepDive && (
        <DocsDeepDive
          kicker="// FULL DATA-INFRA REFERENCE"
          label="Endpoints, fallback chain, DataSource API."
          path="/reference/data-infra"
        />
      )}
      {window.PageFooter && <PageFooter />}
    </div>
  );
}

window.NetworkPage = NetworkPage;
