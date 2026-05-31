/* xB77 dApp — Keystore modal (generate / import + password).
 * Wire schema 1.1 — real Web Crypto Ed25519 via window.XB77Keystore.
 * Sealed blob = AES-GCM(PBKDF2(pw)) over PKCS8 private key. */

const _ksHooks = { useState: React.useState, useEffect: React.useEffect, useRef: React.useRef };

function KeystoreModal() {
  const [open, setOpen] = _ksHooks.useState(false);
  const [step, setStep] = _ksHooks.useState('choose'); // choose | generate | import | working | done
  const [password, setPassword] = _ksHooks.useState('');
  const [confirmPw, setConfirmPw] = _ksHooks.useState('');
  const [intent, setIntent] = _ksHooks.useState('USDC Yield Optimizer');
  const STRATEGIES = [
    { id: 'yield', label: 'USDC Yield Optimizer', desc: 'Auto-allocates to Kamino/Jito for max risk-adjusted APY.' },
    { id: 'payments', label: 'Private Merchant Settler', desc: 'Handles atomic B2B settlements with ZK-privacy.' },
    { id: 'liquidity', label: 'Cross-chain Rebalancer', desc: 'Balances treasury between Solana and Sui automatically.' },
  ];
  const [importBlob, setImportBlob] = _ksHooks.useState('');
  const [error, setError] = _ksHooks.useState(null);
  const [result, setResult] = _ksHooks.useState(null);
  const fileRef = _ksHooks.useRef(null);

  _ksHooks.useEffect(() => {
    const onOpen = () => { setOpen(true); reset(); };
    const onClose = () => setOpen(false);
    window.addEventListener('xb77:open-keystore', onOpen);
    window.addEventListener('xb77:close-keystore', onClose);
    return () => {
      window.removeEventListener('xb77:open-keystore', onOpen);
      window.removeEventListener('xb77:close-keystore', onClose);
    };
  }, []);

  function reset() {
    setStep('choose');
    setPassword(''); setConfirmPw(''); setImportBlob(''); setError(null); setResult(null);
  }

  async function finalize(pubkey, sealedBlob) {
    setStep('working');
    setError(null);
    try {
      localStorage.setItem('xb77_last_intent', intent);
      window.XB77Actions.keystore.saveSealedBlob(sealedBlob);
      const data = await window.XB77Actions.registerAgent(pubkey, intent);
      // Self-airdrop SOL on localhost so the agent can pay onchain fees later.
      // Silent on failure — wire-1.1 still works without it.
      try {
        const ad = await window.XB77Actions.selfAirdrop();
        if (ad && ad.ok) console.info('[xB77] self-airdrop:', ad.signature);
      } catch (e2) {
        console.warn('[xB77] self-airdrop failed (non-fatal):', e2.message);
      }
      setResult({ agent_id: data.agent_id, tier: data.tier, credits: data.credits });
      setStep('done');
      window.dispatchEvent(new CustomEvent('xb77:connected', { detail: { agent_id: data.agent_id } }));
    } catch (e) {
      setError(e.message || 'register failed');
      setStep('choose');
    }
  }

  async function handleGenerate() {
    if (!password || password.length < 4) return setError('password too short (min 4)');
    if (password !== confirmPw) return setError('passwords don\'t match');
    setError(null);
    try {
      const r = await window.XB77Keystore.generate(password);
      finalize(r.pubkeyHex, r.sealedBlob);
    } catch (e) {
      setError(e.message || 'keystore generate failed');
    }
  }

  async function handleImport() {
    if (!password) return setError('enter password');
    if (!importBlob) return setError('pick a keystore file');
    setError(null);
    try {
      const r = await window.XB77Keystore.import(importBlob, password);
      finalize(r.pubkeyHex, r.sealedBlob);
    } catch (e) {
      setError(/invalid_password/.test(e.message) ? 'wrong password' : (e.message || 'import failed'));
    }
  }

  function onFile(e) {
    const f = e.target.files && e.target.files[0];
    if (!f) return;
    const r = new FileReader();
    r.onload = () => setImportBlob(String(r.result || '').trim());
    r.readAsText(f);
  }

  function handleDownload() {
    const blob = window.XB77Actions.keystore.getSealedBlob();
    if (!blob) return;
    const file = new Blob([blob], { type: 'text/plain' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(file);
    a.download = `xb77-keystore-${result?.agent_id || 'backup'}.json`;
    a.click();
  }

  if (!open) return null;

  const overlay = {
    position: 'fixed', inset: 0, zIndex: 9998,
    background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(2px)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20,
  };
  const panel = {
    width: 'min(440px, 100%)', background: 'var(--bg-elevated, #131313)',
    border: '1px solid var(--border-strong, #333)', boxShadow: '0 20px 60px rgba(0,0,0,0.45)',
    fontFamily: 'var(--mono, ui-monospace, monospace)', color: 'var(--text, #ddd)',
  };
  const header = {
    padding: '14px 18px', borderBottom: '1px solid var(--border-soft, #2a2a2a)',
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--text-soft, #888)',
  };
  const body = { padding: '18px 18px 6px' };
  const label = { fontSize: 9, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--text-soft, #888)', marginBottom: 6, display: 'block' };
  const input = {
    width: '100%', padding: '10px 12px', background: 'var(--bg, #08080a)',
    border: '1px solid var(--border-soft, #2a2a2a)', color: 'var(--text, #ddd)',
    fontFamily: 'var(--mono)', fontSize: 12, outline: 'none', marginBottom: 12,
  };
  const btn = (primary) => ({
    flex: 1, padding: '10px 14px',
    background: primary ? 'var(--accent, #c97a3a)' : 'transparent',
    color: primary ? 'var(--bg, #08080a)' : 'var(--text, #ddd)',
    border: primary ? 'none' : '1px solid var(--border-strong, #333)',
    fontFamily: 'var(--mono)', fontSize: 10, letterSpacing: '0.1em',
    textTransform: 'uppercase', fontWeight: 600, cursor: 'pointer',
  });

  return (
    <div style={overlay} onClick={() => setOpen(false)}>
      <div style={panel} onClick={(e) => e.stopPropagation()}>
        <div style={header}>
          <span>// keystore · {step}</span>
          <button onClick={() => setOpen(false)} style={{
            background: 'transparent', border: 'none', color: 'inherit',
            fontFamily: 'var(--mono)', fontSize: 14, cursor: 'pointer', padding: 0,
          }}>×</button>
        </div>

        <div style={body}>
          {step === 'choose' && (
            <>
              <p style={{ fontSize: 11, color: 'var(--text-soft)', margin: '0 0 16px' }}>
                Connect an agent identity. Keystore stays in this browser; private key never leaves the session.
              </p>
              <div style={{ display: 'flex', gap: 10 }}>
                <button style={btn(true)} onClick={() => { setError(null); setStep('generate'); }}>Generate new</button>
                <button style={btn(false)} onClick={() => { setError(null); setStep('import'); }}>Import existing</button>
              </div>
              <p style={{ fontSize: 9, color: 'var(--text-soft)', marginTop: 18, opacity: 0.7 }}>
                wire 1.1 · Ed25519 via Web Crypto · AES-GCM at rest
              </p>
            </>
          )}

          {step === 'generate' && (
            <>
              <label style={label}>Select Strategy</label>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 16 }}>
                {STRATEGIES.map(s => (
                  <div key={s.id} 
                    onClick={() => setIntent(s.label)}
                    style={{
                      padding: '10px 12px', background: intent === s.label ? 'var(--accent-dim, #332211)' : 'var(--bg, #08080a)',
                      border: `1px solid ${intent === s.label ? 'var(--accent)' : 'var(--border-soft)'}`,
                      cursor: 'pointer', transition: 'all 0.2s ease',
                    }}>
                    <div style={{ fontSize: 11, fontWeight: 600, color: intent === s.label ? 'var(--accent)' : 'var(--text)' }}>{s.label}</div>
                    <div style={{ fontSize: 9, color: 'var(--text-soft)', marginTop: 4 }}>{s.desc}</div>
                  </div>
                ))}
              </div>
              <label style={label}>Bunker Password</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={input} placeholder="Min 4 chars" autoFocus />
              <label style={label}>Confirm</label>
              <input type="password" value={confirmPw} onChange={(e) => setConfirmPw(e.target.value)} style={input} />
              <div style={{ display: 'flex', gap: 10 }}>
                <button style={btn(false)} onClick={() => setStep('choose')}>← Back</button>
                <button style={btn(true)} onClick={handleGenerate}>Deploy Agent</button>
              </div>
            </>
          )}

          {step === 'import' && (
            <>
              <label style={label}>Keystore file</label>
              <input ref={fileRef} type="file" accept=".json,.txt,application/json,text/plain" onChange={onFile} style={{ ...input, padding: 8 }} />
              {importBlob && <div style={{ fontSize: 9, color: 'var(--text-soft)', marginTop: -8, marginBottom: 12 }}>blob loaded · {importBlob.length} chars</div>}
              <label style={label}>Password</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={input} />
              <div style={{ display: 'flex', gap: 10 }}>
                <button style={btn(false)} onClick={() => setStep('choose')}>← Back</button>
                <button style={btn(true)} onClick={handleImport}>Import</button>
              </div>
            </>
          )}

          {step === 'working' && (
            <div style={{ padding: '24px 0', textAlign: 'center', color: 'var(--text-soft)', fontSize: 11 }}>
              registering agent…
            </div>
          )}

          {step === 'done' && result && (
            <>
              <div style={{ padding: '16px 0' }}>
                <div style={{ fontSize: 10, color: 'var(--text-soft)', marginBottom: 6 }}>// agent registered</div>
                <div style={{ fontSize: 14, color: 'var(--accent, #c97a3a)', marginBottom: 10 }}>{result.agent_id}</div>
                <div style={{ fontSize: 11, color: 'var(--text)' }}>tier: <b>{result.tier}</b> · credits: <b>{result.credits}</b></div>
              </div>
              <div style={{ display: 'flex', gap: 10 }}>
                <button style={btn(false)} onClick={handleDownload}>Download Backup 💾</button>
                <button style={btn(true)} onClick={() => setOpen(false)}>Continue</button>
              </div>
            </>
          )}

          {error && (
            <div style={{
              marginTop: 8, padding: '8px 10px', fontSize: 10,
              background: 'rgba(248,113,113,0.12)', border: '1px solid rgba(248,113,113,0.4)',
              color: 'var(--red, #f87171)',
            }}>{error}</div>
          )}
        </div>

        <div style={{ padding: '10px 18px 14px', fontSize: 9, color: 'var(--text-soft)', opacity: 0.6, borderTop: '1px solid var(--border-soft)' }}>
          esc / click outside to dismiss
        </div>
      </div>
    </div>
  );
}

window.KeystoreModal = KeystoreModal;
