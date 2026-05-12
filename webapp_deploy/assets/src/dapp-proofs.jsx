/* xB77 dApp — Proofs View
 *
 * Lists recent xb77_zk_verifier transactions surfaced by the watch daemon
 * (kind = "zk"). Read-only for now — generating the actual proof requires the
 * `xb77-zk` podman container; the demo flow is:
 *
 *   1. Run `xb77 zk prove --upload` in another terminal (or `xb77 zk upload`
 *      if a proof file already exists).
 *   2. Watch this tab refresh — the new init/write/verify sigs show up
 *      within one watch tick (~5s).
 *
 * The verifier program is `J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ`;
 * its stub `verify()` returns GREEN if proof entropy is sufficient.
 */

const VERIFIER_PROGRAM_ID = 'J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ';
const POLL_INTERVAL_MS = 5000;

function ProofsView() {
  const [items, setItems] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [err, setErr] = React.useState(null);
  const [lastFetched, setLastFetched] = React.useState(null);

  const refresh = React.useCallback(async () => {
    setLoading(true);
    try {
      const base = window.XB77_GATEWAY || 'http://127.0.0.1:8787';
      const r = await fetch(`${base}/api/v1/pipelines/recent?limit=50`);
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const data = await r.json();
      const zkOnly = (data.pipelines || []).filter(p => p.kind === 'zk');
      setItems(zkOnly);
      setLastFetched(Date.now());
      setErr(null);
    } catch (e) {
      setErr(e.message || 'fetch failed');
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => {
    refresh();
    const id = setInterval(refresh, POLL_INTERVAL_MS);
    return () => clearInterval(id);
  }, [refresh]);

  // Group consecutive sigs by likely "upload session" — a heuristic.
  // For now, just list them.

  return (
    <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
      {/* Header + actions */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '16px 20px', borderBottom: `1px solid ${D.border}`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <DS size={20} italic>Proofs</DS>
            <div style={{ marginTop: 4, fontFamily: 'var(--mono)', fontSize: 10, color: D.faint }}>
              xb77_zk_verifier · {VERIFIER_PROGRAM_ID.slice(0, 12)}…
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            {lastFetched && (
              <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: D.faint }}>
                {Math.floor((Date.now() - lastFetched) / 1000)}s ago
              </span>
            )}
            <DBtn small onClick={refresh} disabled={loading}>
              {loading ? '…REFRESHING' : '↻ REFRESH'}
            </DBtn>
          </div>
        </div>

        {err && (
          <div style={{ padding: '6px 20px', background: `${D.red}18`, borderBottom: `1px solid ${D.border}`, fontFamily: 'var(--mono)', fontSize: 10, color: D.red }}>
            {err}
          </div>
        )}

        {/* Demo hint */}
        <div style={{ padding: '12px 20px', borderBottom: `1px solid ${D.border}`, background: 'transparent' }}>
          <DM size={9} color={D.faint}>
            // To generate a new proof from this machine, run in another terminal:
          </DM>
          <pre style={{
            margin: '6px 0 0', padding: '8px 10px',
            background: D.bg2, border: `1px solid ${D.border}`,
            color: D.text, fontFamily: 'var(--mono)', fontSize: 10,
            overflow: 'auto', whiteSpace: 'pre',
          }}>{`./zig-out/bin/xb77 -p myagent zk prove --upload`}</pre>
        </div>

        {/* Proof list */}
        <div style={{ flex: 1, overflowY: 'auto' }}>
          {items.length === 0 && !loading && !err && (
            <div style={{ padding: '60px 20px', textAlign: 'center', color: D.faint }}>
              <div style={{ fontSize: 32, marginBottom: 12 }}>📜</div>
              <DM size={10}>No verifier transactions yet.</DM>
              <DM size={9} color={D.faint}>The watch daemon polls every 5 seconds.</DM>
            </div>
          )}
          {items.map((p, idx) => {
            const sig = p.signature || (p.id || '').replace(/^pipe:/, '');
            const verdictColor = p.verdict === 'VALID' ? (D.green || '#7fbf3f') : D.red;
            return (
              <div key={sig + ':' + idx} style={{
                padding: '14px 20px',
                borderBottom: `1px solid ${D.border}`,
                display: 'flex', gap: 16, alignItems: 'center', justifyContent: 'space-between',
              }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0, flex: 1 }}>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                    <Badge color={verdictColor} bg={`${verdictColor}18`}>{p.verdict || 'PENDING'}</Badge>
                    <span style={{ fontFamily: 'var(--mono)', fontSize: 11, color: D.text, fontWeight: 600 }}>
                      {sig.slice(0, 16)}…{sig.slice(-8)}
                    </span>
                  </div>
                  <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                    <DM size={9}>slot {p.slot ?? '—'}</DM>
                    <DM size={9}>agent {(p.agent || 'onchain').slice(0, 14)}…</DM>
                    {p.duration_ms != null && <DM size={9}>{Math.floor(p.duration_ms / 1000)}s</DM>}
                  </div>
                </div>
                <div style={{ flexShrink: 0 }}>
                  <a
                    href={`https://solscan.io/tx/${sig}?cluster=custom&customUrl=http%3A%2F%2F127.0.0.1%3A8899`}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      fontFamily: 'var(--mono)', fontSize: 9, color: D.accent,
                      textDecoration: 'none', whiteSpace: 'nowrap',
                    }}>
                    explorer ↗
                  </a>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function ProofsTab() {
  return (
    <div style={{
      border: `1px solid ${D.border}`,
      background: D.bg2,
      borderRadius: 4,
      overflow: 'hidden',
      minHeight: 600,
      display: 'flex', flexDirection: 'column',
    }}>
      <ProofsView />
    </div>
  );
}

Object.assign(window, { ProofsView, ProofsTab });
