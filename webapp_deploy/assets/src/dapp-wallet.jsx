/* xB77 dApp — Wallet/Treasury View */

function WalletView() {
  const balances = [
    { currency: 'USDC', amount: '14,240.00', usd: '$14,240.00', change: '+$820', pct: '+6.1%', color: D.accent },
    { currency: 'SOL', amount: '48.72', usd: '$8,107.20', change: '+$412', pct: '+5.3%', color: D.purple },
    { currency: 'EURC', amount: '2,500.00', usd: '$2,750.00', change: '-$50', pct: '-1.8%', color: D.cyan },
  ];

  const allocations = [
    { agent: 'cfo-alpha', amount: '$8,240', pct: '33%', color: D.accent },
    { agent: 'ag_worker_01', amount: '$4,100', pct: '16%', color: D.green },
    { agent: 'ag_worker_02', amount: '$2,400', pct: '10%', color: D.cyan },
    { agent: 'ag_worker_03', amount: '$1,850', pct: '7%', color: D.purple },
    { agent: 'Unallocated', amount: '$8,507', pct: '34%', color: D.faint },
  ];

  const recentTx = [
    { time: '14:23', desc: 'Payment to Café Sovereign', amount: '-$47.80', type: 'OUT' },
    { time: '14:18', desc: 'Swap USDC → SOL', amount: '-$240.00', type: 'SWAP' },
    { time: '14:05', desc: 'Privacy pool deposit', amount: '-$1,200.00', type: 'OUT' },
    { time: '13:40', desc: 'Yield return', amount: '+$87.20', type: 'IN' },
    { time: '13:15', desc: 'Trading profit', amount: '+$201.50', type: 'IN' },
    { time: '12:50', desc: 'Deposit from external', amount: '+$5,000.00', type: 'IN' },
  ];

  return (
    <div style={{ padding: 24, overflowY: 'auto', flex: 1 }}>
      {/* Total balance */}
      <div style={{ marginBottom: 24, padding: '28px 32px', background: D.bg2, border: `1px solid ${D.border}` }}>
        <DM size={9}>TOTAL TREASURY</DM>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 16, marginTop: 10 }}>
          <span style={{ fontFamily: 'var(--serif)', fontSize: 48, fontWeight: 400, color: D.text, fontStyle: 'italic' }}>$25,097</span>
          <span style={{ fontFamily: 'var(--mono)', fontSize: 13, color: D.green }}>+$1,182 today (+4.9%)</span>
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 16 }}>
          <DBtn small primary>DEPOSIT</DBtn>
          <DBtn small>WITHDRAW</DBtn>
          <DBtn small>ALLOCATE</DBtn>
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
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: b.change.startsWith('+') ? D.green : D.red }}>{b.change} ({b.pct})</div>
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
        <div style={{ display: 'grid', gridTemplateColumns: '60px 1fr 100px 80px', padding: '0 16px', borderBottom: `1px solid ${D.border}` }}>
          {['TIME', 'DESCRIPTION', 'AMOUNT', 'TYPE'].map(h => (
            <div key={h} style={{ padding: '8px 0' }}><DM size={7}>{h}</DM></div>
          ))}
        </div>
        {recentTx.map((tx, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '60px 1fr 100px 80px', padding: '0 16px',
            borderBottom: i < recentTx.length - 1 ? `1px solid ${D.border}` : 'none',
            transition: 'background 0.15s',
          }}
            onMouseEnter={e => e.currentTarget.style.background = D.bg3}
            onMouseLeave={e => e.currentTarget.style.background = ''}
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
