/* xB77 — Explorer as a tab inside /app
   Extracted from router.jsx so it can be rendered by AppView via window.ExplorerTab.
   Reuses Explorer reusables exposed on window: MeshHero, StatCard, SearchBar, Tabs,
   ExPipelinesView, PoseidonView, AgentsRichView, MerchantsView, ZnodesView,
   MCPPanel, TelegramPanel, DetailSlide, plus MOCK_* data. */

const _expSparkTVL  = Array.from({ length: 20 }, (_, i) => 10 + Math.sin(i * 0.4) * 3 + Math.random() * 2);
const _expSparkPipe = Array.from({ length: 20 }, (_, i) => 300 + i * 20 + Math.random() * 60);
const _expSparkLat  = Array.from({ length: 20 }, (_, i) => 30 + Math.sin(i * 0.6) * 10 + Math.random() * 5);
const _expSparkPos  = Array.from({ length: 20 }, (_, i) => 50 + i * 8 + Math.random() * 30);

/* Explorer-specific views were overwritten by dApp scripts (PipelinesView, AgentsView).
   They are saved on window._ExPipelinesView / window._ExAgentsView by index.html
   between explorer-sections.js and dapp-*.js. */
const ExPipelinesView = window._ExPipelinesView;

function ExplorerTab() {
  const [search, setSearch] = React.useState('');
  const [tab, setTab] = React.useState('pipelines');
  const [sel, setSel] = React.useState(null);
  const tabs = [
    { id: 'pipelines', label: 'Pipelines', count: MOCK_PIPELINES.length },
    { id: 'poseidon',  label: 'Poseidon',  count: MOCK_POSEIDON.length },
    { id: 'agents',    label: 'Agents',    count: MOCK_AGENTS_V2.length },
    { id: 'merchants', label: 'Merchants', count: MOCK_MERCHANTS.length },
    { id: 'znodes',    label: 'Znodes',    count: MOCK_ZNODES.length },
  ];

  return (
    <div style={{
      display:'flex', flexDirection:'column',
      border:'1px solid rgba(245,245,247,0.08)',
      background:'#08080a', overflow:'hidden',
    }}>
      {/* Mesh hero with stat bar */}
      <div style={{ position: 'relative', borderBottom: `1px solid ${T.border}`, flexShrink: 0 }}>
        <MeshHero znodes={MOCK_ZNODES} />
        <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 1, background: 'rgba(8,8,10,0.85)', backdropFilter: 'blur(12px)', borderTop: `1px solid ${T.border}` }}>
          {[
            { label: 'TVL',              value: '$12.4M',  change: '+2.3%', spark: _expSparkTVL },
            { label: 'PIPELINES',        value: '48,291',  change: '+847',  spark: _expSparkPipe },
            { label: 'POSEIDON COMMITS', value: '14,820',  change: '+312',  spark: _expSparkPos, color: T.cyan },
            { label: 'ZNODES',           value: '28 / 32' },
            { label: 'AVG LATENCY',      value: '34ms',    change: '-3ms',  spark: _expSparkLat, color: T.cyan },
            { label: 'MERCHANTS',        value: '12',      change: '+2' },
          ].map((s, i) => (
            <div key={i} style={{ borderRight: i < 5 ? `1px solid ${T.border}` : 'none' }}>
              <StatCard {...s} sparkData={s.spark} />
            </div>
          ))}
        </div>
        <div style={{ position: 'absolute', top: 20, left: 28, pointerEvents: 'none' }}>
          <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: T.textDim, letterSpacing: '0.2em', marginBottom: 6 }}>MESH TOPOLOGY</div>
          <div style={{ fontFamily: 'var(--serif)', fontSize: 24, color: T.text, fontStyle: 'italic', opacity: 0.6 }}>Live Network</div>
        </div>
      </div>

      {/* Body: main list + side panels */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', minHeight: 560 }}>
        <div style={{ borderRight: `1px solid ${T.border}`, display: 'flex', flexDirection: 'column', minHeight: 0 }}>
          <div style={{ padding: '16px 24px 0', flexShrink: 0 }}>
            <SearchBar value={search} onChange={setSearch} />
            <div style={{ marginTop: 14 }}><Tabs tabs={tabs} active={tab} onChange={setTab} /></div>
          </div>
          <div style={{ flex: 1, overflowY: 'auto', padding: '0 24px 24px' }}>
            {tab === 'pipelines' && <ExPipelinesView data={MOCK_PIPELINES} search={search} onSelect={setSel} />}
            {tab === 'poseidon'  && <PoseidonView    data={MOCK_POSEIDON}   search={search} onSelect={setSel} />}
            {tab === 'agents'    && <AgentsRichView  data={MOCK_AGENTS_V2}  search={search} onSelect={setSel} />}
            {tab === 'merchants' && <MerchantsView   data={MOCK_MERCHANTS}  search={search} onSelect={setSel} />}
            {tab === 'znodes'    && <ZnodesView      data={MOCK_ZNODES}     search={search} onSelect={setSel} />}
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', padding: '16px', gap: 12, minHeight: 0 }}>
          <MCPPanel />
          <TelegramPanel />
        </div>
      </div>
      <DetailSlide sel={sel} onClose={() => setSel(null)} />
    </div>
  );
}

window.ExplorerTab = ExplorerTab;
