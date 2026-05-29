/* xB77 dApp — Wallet/Treasury View */

const _WALLET_SEED_BALANCES = [
  { currency: 'USDC', amount: '—', usd: '—', change: '', pct: '', color: D.accent, rawAmount: 0 },
  { currency: 'SOL',  amount: '—', usd: '—', change: '', pct: '', color: D.purple, rawAmount: 0 },
  { currency: 'EURC', amount: '—', usd: '—', change: '', pct: '', color: D.cyan,   rawAmount: 0 },
];

const _WALLET_ALLOC_PLACEHOLDER = [
  { agent: 'cfo-alpha',    amount: '—', pct: '40%', color: D.accent },
  { agent: 'ag_worker_01', amount: '—', pct: '20%', color: D.green },
  { agent: 'ag_worker_02', amount: '—', pct: '10%', color: D.cyan },
  { agent: 'ag_worker_03', amount: '—', pct: '8%',  color: D.purple },
  { agent: 'Unallocated',  amount: '—', pct: '22%', color: D.faint },
];

function WalletView() {
  const [credits, setCredits] = React.useState(0);
  const [tier, setTier] = React.useState('unauth');
  const [claiming, setClaiming] = React.useState(false);
  const [claimError, setClaimError] = React.useState(null);
  const [creditsPulse, setCreditsPulse] = React.useState(false);

  const [balances, setBalances] = React.useState(_WALLET_SEED_BALANCES);
  const [recentTx, setRecentTx] = React.useState([]);
  const [source, setSource] = React.useState('idle'); // idle | live | cached | snapshot
  const [agentId, setAgentId] = React.useState(() => (window.XB77Actions?.keystore.agentId) || null);

  React.useEffect(() => {
    const onConn = () => setAgentId(window.XB77Actions?.keystore.agentId || null);
    window.addEventListener('xb77:connected', onConn);
    return () => window.removeEventListener('xb77:connected', onConn);
  }, []);

  React.useEffect(() => {
    if (!agentId || !window.SolanaRpc) return;
    let cancelled = false;
    async function fetchOnchain() {
      try {
        const isProd = typeof window !== "undefined" && (window.location.hostname.endsWith(".workers.dev") || window.location.hostname.includes("xb77.io"));
        const RPC_URL = isProd ? "https://api.devnet.solana.com" : "http://127.0.0.1:8899";
        const rpc = window.SolanaRpc.create(RPC_URL);
        
        // Get agent pubkey from keystore
        const pubkey = window.XB77Actions.keystore.pubkeyBase58();
        if (!pubkey) return;

        const lamports = await rpc.getBalance(pubkey);
        if (cancelled) return;
        
        const solAmount = lamports / 1_000_000_000;
        
        // Notify terminal of income if balance increased
        setBalances(prev => {
          const oldSol = prev.find(b => b.currency === 'SOL')?.rawAmount || 0;
          if (solAmount * 160 > oldSol + 0.1) { // If increased by > $0.1
            window.dispatchEvent(new CustomEvent('xb77:income', { detail: { amount: (solAmount * 160 - oldSol).toFixed(2) } }));
          }
          return prev.map(b => 
            b.currency === 'SOL' ? { ...b, amount: solAmount.toFixed(3), usd: `$${(solAmount * 160).toFixed(2)}`, rawAmount: solAmount * 160 } : b
          );
        });
      } catch (e) {
        console.warn('[Wallet] Failed to fetch onchain balance:', e.message);
      }
    }
    fetchOnchain();
    const id = setInterval(fetchOnchain, 15_000);
    return () => { cancelled = true; clearInterval(id); };
  }, [agentId]);

  async function handleClaim() {
    if (claiming) return;
    setClaiming(true); setClaimError(null);
    const proof = 'proof-stub-' + Date.now().toString(36);
    try {
      const data = await window.XB77Actions.claimCredits(proof);
      setCredits(data.credits_after ?? credits);
      if (data.new_tier) setTier(data.new_tier);
      setCreditsPulse(true);
      setTimeout(() => setCreditsPulse(false), 900);
    } catch (e) {
      setClaimError(e.message || 'claim failed');
    } finally {
      setClaiming(false);
    }
  }

  const [isPaused, setIsPaused] = React.useState(false);
  const [funding, setFunding] = React.useState(false);

  async function handleFund() {
    if (!agentId || funding) return;
    setFunding(true);
    try {
      const res = await window.XB77Actions.selfAirdrop();
      if (res.ok) {
        alert("1 SOL Airdropped to Agent Pubkey: " + res.pubkey);
      } else {
        alert("Airdrop failed: " + (res.error || "Rate limited"));
      }
    } finally {
      setFunding(false);
    }
  }

  const allocations = _WALLET_ALLOC_PLACEHOLDER;

  const totalUsd = balances.reduce((acc, b) => acc + (Number(b.rawAmount) || 0), 0);
  const totalLabel = totalUsd > 0
    ? '$' + totalUsd.toLocaleString(undefined, { maximumFractionDigits: 2 })
    : '$ —';

  return (
    <div style={{ padding: 24, overflowY: 'auto', flex: 1 }}>
      {/* Gateway credits row (CONTRACT v1) */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 14, marginBottom: 12,
        padding: '10px 16px', background: D.bg2, border: `1px solid ${D.border}`,
      }}>
        <DM size={8} color={D.accent}>// CREDITS</DM>
        <span style={{
          fontFamily: 'var(--mono)', fontSize: 14, fontWeight: 600,
          color: creditsPulse ? D.green : D.text,
          transition: 'color .6s ease, transform .25s ease',
          transform: creditsPulse ? 'scale(1.08)' : 'scale(1)', transformOrigin: 'left',
        }}>{credits.toLocaleString()}</span>
        <DM size={8}>tier</DM>
        <Badge color={tier === 'unauth' ? D.dim : tier === 'free' ? D.cyan : tier === 'paid' ? D.green : D.accent}
          bg={tier === 'unauth' ? `${D.dim}18` : tier === 'free' ? `${D.cyan}18` : tier === 'paid' ? `${D.green}18` : `${D.accent}18`}>
          {tier}
        </Badge>
        {claimError && (
          <span style={{ fontFamily: 'var(--mono)', fontSize: 9, color: D.red, marginLeft: 8 }}>
            claim: {claimError}
          </span>
        )}
        <span style={{ flex: 1 }} />
        <DBtn small primary onClick={handleClaim} disabled={claiming}>
          {claiming ? '…CLAIMING' : 'CLAIM CREDITS'}
        </DBtn>
      </div>

      {/* Total balance */}
      <div style={{ marginBottom: 24, padding: '28px 32px', background: D.bg2, border: `1px solid ${D.border}` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <DM size={9}>TOTAL TREASURY</DM>
          {source !== 'idle' && (
            <Badge color={source === 'live' ? D.green : source === 'cached' ? D.amber : D.dim}
              bg={source === 'live' ? `${D.green}18` : source === 'cached' ? `${D.amber}18` : `${D.dim}18`}>
              {source}
            </Badge>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginTop: 10 }}>
          <span style={{ fontFamily: 'var(--serif)', fontSize: 48, fontWeight: 400, color: D.text, fontStyle: 'italic' }}>{totalLabel}</span>
          {!agentId && (
            <span style={{ fontFamily: 'var(--mono)', fontSize: 11, color: D.faint }}>connect an agent to load</span>
          )}
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 16 }}>
          <DBtn small primary onClick={handleFund} disabled={funding || !agentId}>
            {funding ? '…FUNDING' : 'DEPOSIT (AIRDROP)'}
          </DBtn>
          <DBtn small onClick={() => setIsPaused(!isPaused)}>
            {isPaused ? 'RESUME AGENT' : 'PAUSE AGENT'}
          </DBtn>
          <DBtn small onClick={() => {
            const pk = window.XB77Actions.keystore.pubkeyBase58();
            if (pk) { navigator.clipboard.writeText(pk); alert("Pubkey copied: " + pk); }
          }}>COPY PUBKEY</DBtn>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 24 }}>
        {/* Balances by currency */}
        <div>
          <SectionHead title="Balances" />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {balances.map((b, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 14,
                padding: '14px 18px', background: D.bg2, border: `1px solid ${D.border}`,
              }}>
                <div style={{
                  width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: `${b.color}18`, border: `1px solid ${b.color}30`,
                  fontFamily: 'var(--mono)', fontSize: 10, fontWeight: 700, color: b.color,
                }}>{b.currency.slice(0, 2)}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 13, fontWeight: 600, color: D.text }}>{b.currency}</div>
                  <DM size={8}>{b.amount}</DM>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 13, color: D.text }}>{b.usd}</div>
                  {b.change && b.pct && (
                    <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: String(b.change).startsWith('+') ? D.green : D.red }}>{b.change} ({b.pct})</div>
                  )}
                  {b.chain && !b.change && (
                    <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: D.faint }}>on {b.chain}</div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Allocation by agent */}
        <div>
          <SectionHead title="Allocation" />
          <div style={{ background: D.bg2, border: `1px solid ${D.border}`, padding: 18 }}>
            {/* Visual bar */}
            <div style={{ display: 'flex', height: 8, marginBottom: 18, gap: 2 }}>
              {allocations.map((a, i) => (
                <div key={i} style={{
                  flex: parseInt(a.pct), background: a.color,
                  opacity: a.agent === 'Unallocated' ? 0.2 : 0.7,
                }}></div>
              ))}
            </div>
            {allocations.map((a, i) => (
              <div key={i} style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '8px 0', borderBottom: i < allocations.length - 1 ? `1px solid ${D.border}` : 'none',
              }}>
                <div style={{ width: 8, height: 8, background: a.color, opacity: a.agent === 'Unallocated' ? 0.3 : 1 }}></div>
                <span style={{
                  fontFamily: 'var(--mono)', fontSize: 11, color: a.agent === 'Unallocated' ? D.dim : D.text, flex: 1,
                }}>{a.agent}</span>
                <span style={{ fontFamily: 'var(--mono)', fontSize: 11, color: D.text }}>{a.amount}</span>
                <DM size={8} color={D.faint}>{a.pct}</DM>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Recent transactions */}
      <SectionHead title="Recent Transactions" />
      <div style={{ background: D.bg2, border: `1px solid ${D.border}` }}>
        <div style={{ display: 'grid', gridTemplateColumns: '60px 1fr 100px 80px', padding: '0 16px', borderBottom: `1px solid ${D.border}`, background: D.bg3 }}>
          {['TIME', 'DESCRIPTION', 'AMOUNT', 'TYPE'].map(h => (
            <div key={h} style={{ padding: '8px 0' }}><DM size={7}>{h}</DM></div>
          ))}
        </div>
        {recentTx.length === 0 && (
          <div style={{ padding: '20px 16px', textAlign: 'center', fontFamily: 'var(--mono)', fontSize: 10, color: D.faint }}>
            {agentId ? 'no transactions yet' : 'connect an agent to load transactions'}
          </div>
        )}
        {recentTx.map((tx, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '60px 1fr 100px 80px', padding: '0 16px',
            borderBottom: i < recentTx.length - 1 ? `1px solid ${D.border}` : 'none',
            background: i % 2 === 1 ? D.bg3 : 'transparent',
            transition: 'background 0.28s ease',
          }}
            onMouseEnter={e => e.currentTarget.style.background = D.bg4}
            onMouseLeave={e => e.currentTarget.style.background = i % 2 === 1 ? D.bg3 : 'transparent'}
          >
            <div style={{ padding: '10px 0', fontFamily: 'var(--mono)', fontSize: 11, color: D.faint }}>{tx.time}</div>
            <div style={{ padding: '10px 0', fontFamily: 'var(--sans)', fontSize: 12, color: D.text }}>{tx.desc}</div>
            <div style={{ padding: '10px 0', fontFamily: 'var(--mono)', fontSize: 11, color: tx.amount.startsWith('+') ? D.green : D.text }}>{tx.amount}</div>
            <div style={{ padding: '10px 0' }}>
              <Badge
                color={tx.type === 'IN' ? D.green : tx.type === 'SWAP' ? D.cyan : D.dim}
                bg={tx.type === 'IN' ? `${D.green}18` : tx.type === 'SWAP' ? `${D.cyan}18` : `${D.dim}18`}
              >{tx.type}</Badge>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function WalletTab() {
  return (
    <div style={{
      display:'flex', flexDirection:'column',
      minHeight:520,
      border:'1px solid var(--border-soft)',
      background:'var(--bg)',
    }}>
      <WalletView />
    </div>
  );
}

Object.assign(window, { WalletView, WalletTab });
