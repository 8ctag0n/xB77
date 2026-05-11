/* xB77 /network — Network Pulse + Ghost Audit Portal.
 *
 * Mounted via hash route '#network'. Exposed as window.NetworkPage so the
 * router (W1-owned) can wire it in with a one-line case at merge time.
 *
 * Sections:
 *   1. Network Pulse — 4 big numbers, polled every 3s. Status dot color
 *      reflects window.DataSource _source (live/cached/snapshot).
 *   2. Ghost Audit Portal — input tx hash + AUDIT button → verdict card.
 *
 * Theme: reuses D constants from dapp-shared.js. Magenta is local —
 * 'cached' / 'invalid' state in the dim red-violet end of the palette.
 */

const NET_MAGENTA = '#e94da4';

function _netSourceColor(source) {
  if (source === 'live') return D.accent;
  if (source === 'cached') return NET_MAGENTA;
  return D.muted; // snapshot
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

/* ── Big number tile ─────────────────────────────────────────────── */
function NetBigStat({ label, value, hint }) {
  return (
    <div style={{
      flex: 1, minWidth: 180,
      padding: '24px 22px',
      background: D.bg2,
      border: `1px solid ${D.border}`,
    }}>
      <DM size={9}>{label}</DM>
      <div style={{
        fontFamily: 'var(--serif)',
        fontSize: 44, fontStyle: 'italic', color: D.text,
        marginTop: 12, lineHeight: 1,
        letterSpacing: '-0.02em',
      }}>{value}</div>
      {hint && (
        <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: D.dim, marginTop: 10, letterSpacing: '0.1em' }}>
          {hint}
        </div>
      )}
    </div>
  );
}

/* ── Status pill: dot + label ────────────────────────────────────── */
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

/* ── Network Pulse section ──────────────────────────────────────── */
function NetworkPulseSection() {
  const [pulse, setPulse] = React.useState(null);

  React.useEffect(() => {
    if (!window.DataSource) return;
    const off = window.DataSource.subscribe('networkPulse', setPulse, 3000);
    return off;
  }, []);

  const fmt = (n) => (typeof n === 'number' ? n.toLocaleString('en-US') : '—');

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
        <NetBigStat label="Slot"               value={fmt(pulse?.slot)}               hint="solana validator" />
        <NetBigStat label="Block Height"       value={fmt(pulse?.blockHeight)}        hint="finalized" />
        <NetBigStat label="Agents Online"      value={fmt(pulse?.agentsOnline)}       hint="autonomous CFO mesh" />
        <NetBigStat label="Proofs Verified 24h" value={fmt(pulse?.proofsVerified24h)} hint="zk-pipeline throughput" />
      </div>
    </section>
  );
}

/* ── Ghost Audit Portal ─────────────────────────────────────────── */
const VERDICT_COLOR = {
  VALID:   D.accent,
  INVALID: NET_MAGENTA,
  PENDING: D.cyan,
};

function GhostAuditSection() {
  const [hash, setHash] = React.useState('');
  const [result, setResult] = React.useState(null);
  const [loading, setLoading] = React.useState(false);

  async function runAudit() {
    if (!hash.trim() || !window.DataSource) return;
    setLoading(true);
    try {
      const r = await window.DataSource.auditTx(hash.trim());
      setResult(r);
    } finally {
      setLoading(false);
    }
  }

  const verdictColor = result ? (VERDICT_COLOR[result.verdict] || D.text) : D.text;

  return (
    <section style={{ padding: '40px 0' }}>
      <div style={{ marginBottom: 24 }}>
        <DM>Ghost Audit Portal</DM>
        <div style={{ marginTop: 8 }}>
          <DS size={32} italic>Verify any transaction.</DS>
        </div>
        <div style={{
          fontFamily: 'var(--sans)', fontSize: 13, color: D.dim, marginTop: 8,
          maxWidth: 560, lineHeight: 1.6,
        }}>
          Paste a transaction hash. The portal queries the zk verifier on-chain and
          returns the verdict, proof ID, and the agent that signed the pipeline.
        </div>
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
          onClick={runAudit}
          disabled={loading || !hash.trim()}
          style={{
            fontFamily: 'var(--mono)', fontSize: 11, fontWeight: 600,
            letterSpacing: '0.18em', textTransform: 'uppercase',
            background: loading ? D.bg3 : D.accent,
            color: loading ? D.dim : D.bg,
            border: `1px solid ${D.accent}`,
            padding: '0 28px',
            cursor: loading || !hash.trim() ? 'not-allowed' : 'pointer',
            transition: 'all 0.15s',
          }}
        >{loading ? 'auditing…' : 'audit'}</button>
      </div>

      {/* Result card */}
      {result && (
        <div style={{
          padding: '24px 28px',
          background: D.bg2,
          border: `1px solid ${D.border}`,
          borderLeft: `3px solid ${verdictColor}`,
          maxWidth: 720,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
            <div style={{
              fontFamily: 'var(--mono)', fontSize: 22, fontWeight: 700,
              letterSpacing: '0.18em', color: verdictColor,
            }}>{result.verdict}</div>
            <NetStatusPill payload={result} />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 18 }}>
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

/* ── Page shell ─────────────────────────────────────────────────── */
function NetworkPage() {
  return (
    <div style={{ background: D.bg, minHeight: '100vh', color: D.text }}>
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
            agent fleet, and a public audit portal for any verified transaction.
          </div>
        </div>

        <NetworkPulseSection />
        <GhostAuditSection />
      </div>
    </div>
  );
}

window.NetworkPage = NetworkPage;
