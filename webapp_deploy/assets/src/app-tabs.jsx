/* xB77 — Unified /app shell (fusiona /dapp + /explorer en tabs) */

const { useState: _appUseState, useEffect: _appUseEffect } = React;

const _APP_TABS = [
  { id: 'wallet',    label: 'Wallet'    },
  { id: 'agents',    label: 'Agents'    },
  { id: 'pipelines', label: 'Pipelines' },
  { id: 'proofs',    label: 'Proofs'    },
  { id: 'mesh',      label: 'Mesh'      },
  { id: 'explorer',  label: 'Explorer'  },
];

function _appParseHash() {
  const m = (window.location.hash || '').match(/^#app(?:\/([\w-]+))?/);
  if (!m) return null;
  const tab = m[1];
  if (tab && _APP_TABS.find(t => t.id === tab)) return tab;
  return 'agents';
}

function ConnectionPill() {
  const [agentId, setAgentId] = _appUseState(() => (window.XB77Actions?.keystore.agentId) || null);
  _appUseEffect(() => {
    const onConn = (ev) => setAgentId(ev?.detail?.agent_id || window.XB77Actions?.keystore.agentId || null);
    window.addEventListener('xb77:connected', onConn);
    return () => window.removeEventListener('xb77:connected', onConn);
  }, []);
  const open = () => window.dispatchEvent(new CustomEvent('xb77:open-keystore'));
  const connected = !!agentId;
  return (
    <button onClick={open} title={connected ? 'Manage keystore' : 'Connect agent'} style={{
      fontFamily: 'var(--mono)', fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase',
      padding: '6px 12px',
      background: connected ? 'rgba(127,191,63,0.12)' : 'transparent',
      color: connected ? 'var(--green, #7fbf3f)' : 'var(--accent, #c97a3a)',
      border: `1px solid ${connected ? 'rgba(127,191,63,0.4)' : 'var(--accent, #c97a3a)'}`,
      cursor: 'pointer', whiteSpace: 'nowrap',
    }}>
      {connected ? `● ${agentId.slice(0, 14)}…` : '○ Connect'}
    </button>
  );
}

function AppView() {
  const [active, setActive] = _appUseState(_appParseHash() || 'agents');

  _appUseEffect(() => {
    const onHash = () => {
      const t = _appParseHash();
      if (t && t !== active) setActive(t);
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, [active]);

  _appUseEffect(() => {
    if (window.XB77Actions && !window.XB77Actions.keystore.hasAgent()) {
      const t = setTimeout(() => window.dispatchEvent(new CustomEvent('xb77:open-keystore')), 600);
      return () => clearTimeout(t);
    }
  }, []);

  const setTab = (id) => {
    if (id === active) return;
    window.location.hash = `#app/${id}`;
    setActive(id);
  };

  const renderTab = () => {
    const map = {
      wallet:    window.WalletTab,
      agents:    window.AgentsTab,
      pipelines: window.PipelinesTab,
      proofs:    window.ProofsTab,
      mesh:      window.MeshTab,
      explorer:  window.ExplorerTab,
    };
    const Cmp = map[active];
    if (!Cmp) {
      return (
        <div style={{padding:'48px 0', color:'var(--text-soft)', fontFamily:'var(--mono)', fontSize:12}}>
          // tab "{active}" not loaded
        </div>
      );
    }
    return <Cmp />;
  };

  return (
    <div className="xb-app-shell" style={{minHeight:'100vh', padding:'20px 24px 32px', background:'var(--bg, #08080a)'}}>
      <div style={{maxWidth:1280, margin:'0 auto'}}>
        <a href="/index.html#home" style={{
          display:'inline-block', marginBottom:10,
          fontFamily:'var(--mono)', fontSize:11,
          color:'var(--text-soft)', letterSpacing:'0.08em',
          textDecoration:'none', textTransform:'uppercase',
          transition:'color 0.25s ease',
        }}
          onMouseEnter={e => { e.target.style.color = 'var(--accent)'; }}
          onMouseLeave={e => { e.target.style.color = 'var(--text-soft)'; }}
        >← xb77.io</a>
        <div style={{marginBottom:18, display:'flex', alignItems:'flex-start', justifyContent:'space-between', gap:16}}>
          <div>
            <div style={{fontFamily:'var(--mono)', fontSize:11, color:'var(--text-soft)', letterSpacing:'0.1em', marginBottom:4}}>// APP</div>
            <h1 style={{fontFamily:'var(--serif)', fontSize:'clamp(1.5rem,3.5vw,2.4rem)', margin:0, color:'var(--text)', lineHeight:1.1, fontStyle:'italic'}}>
              Sovereign commerce surface.
            </h1>
            <p style={{color:'var(--text-soft)', marginTop:6, fontFamily:'var(--mono)', fontSize:11, letterSpacing:'0.04em'}}>
              wallet / agents / pipelines / mesh / explorer — one origin.
            </p>
          </div>
          <ConnectionPill />
        </div>

        <div role="tablist" aria-label="App sections" style={{
          display:'flex', gap:0,
          borderBottom:'1px solid var(--border-soft)',
          marginBottom:24, overflowX:'auto',
        }}>
          {_APP_TABS.map(t => {
            const isActive = active === t.id;
            return (
              <button
                key={t.id}
                role="tab"
                aria-selected={isActive}
                onClick={() => setTab(t.id)}
                style={{
                  padding:'12px 18px',
                  background:'transparent',
                  border:'none',
                  color: isActive ? 'var(--accent)' : 'var(--text-soft)',
                  fontFamily:'var(--mono)',
                  fontSize:11,
                  fontWeight: 600,
                  letterSpacing:'0.1em',
                  textTransform:'uppercase',
                  borderBottom: isActive ? '2px solid var(--accent)' : '2px solid transparent',
                  marginBottom:'-1px',
                  cursor:'pointer',
                  whiteSpace:'nowrap',
                  transition:'color 0.28s ease, border-color 0.28s ease',
                }}>
                {t.label}
              </button>
            );
          })}
        </div>

        <div role="tabpanel" style={{position:'relative'}}>
          {renderTab()}
        </div>
      </div>
      {window.KeystoreModal ? React.createElement(window.KeystoreModal) : null}
    </div>
  );
}

window._AppView = AppView;
