/* Whitepaper page — Web editorial, long scroll, visual */

function WhitepaperPage() {
  const t = THEMES.obsidian;

  const Section = ({ tag, title, children }) => (
    <section style={{ padding: '100px 40px', maxWidth: 860, margin: '0 auto' }}>
      <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.2em', marginBottom: 12, textTransform: 'uppercase' }}>{tag}</div>
      <h2 style={{
        fontFamily: 'var(--serif)', fontSize: 'clamp(28px, 4vw, 48px)',
        fontWeight: 400, color: t.text, margin: '0 0 32px', lineHeight: 1.1,
      }}>{title}</h2>
      {children}
    </section>
  );

  const P = ({ children, bold }) => (
    <p style={{
      fontFamily: 'var(--sans)', fontSize: 16, color: bold ? t.text : t.textDim,
      lineHeight: 1.8, margin: '0 0 20px', fontWeight: bold ? 500 : 400,
    }}>{children}</p>
  );

  const Quote = ({ children }) => (
    <div style={{
      borderLeft: `3px solid ${t.accent}`, padding: '20px 28px', margin: '36px 0',
      background: t.accentDim,
    }}>
      <p style={{
        fontFamily: 'var(--serif)', fontSize: 22, fontStyle: 'italic',
        color: t.text, margin: 0, lineHeight: 1.5,
      }}>{children}</p>
    </div>
  );

  const Diagram = ({ label, children }) => (
    <div style={{
      margin: '40px 0', border: `1px solid ${t.border}`, background: t.terminalBg,
    }}>
      <div style={{
        padding: '8px 16px', borderBottom: `1px solid ${t.border}`,
        fontFamily: 'var(--mono)', fontSize: 9, color: t.textDim, letterSpacing: '0.12em',
      }}>{label}</div>
      <div style={{ padding: '28px 24px' }}>{children}</div>
    </div>
  );

  const flowNodes = ['Agent Intent', 'AWP Negotiation', 'xB77 ZK Engine', 'Noir ZK Proof', 'Solana L1', 'Compressed Receipt'];

  return (
    <div style={{ background: t.bg, minHeight: '100vh', color: t.text }}>
      <InnerNav active="Whitepaper" />

      {/* Hero */}
      <section style={{ padding: '120px 40px 60px', maxWidth: 860, margin: '0 auto' }}>
        <div style={{
          fontFamily: 'var(--mono)', fontSize: 10, color: t.accent,
          letterSpacing: '0.2em', marginBottom: 16, textTransform: 'uppercase',
        }}>WHITEPAPER v0.1 — MAY 2026</div>
        <h1 style={{
          fontFamily: 'var(--serif)', fontSize: 'clamp(44px, 6vw, 76px)',
          fontWeight: 400, color: t.text, lineHeight: 1.0, margin: '0 0 24px',
        }}>
          xB77: Autonomous Financial<br />
          <em style={{ color: t.accent, fontStyle: 'italic' }}>Infrastructure</em>
        </h1>
        <p style={{
          fontFamily: 'var(--sans)', fontSize: 18, color: t.textDim, lineHeight: 1.7,
          maxWidth: 600,
        }}>
          A privacy-first operating system for machine-to-machine capital management — chain-agnostic core, settling on Solana, Arc &amp; Sui.
        </p>
        <div style={{
          display: 'flex', gap: 24, marginTop: 32,
          fontFamily: 'var(--mono)', fontSize: 11, color: t.textDim, letterSpacing: '0.06em',
        }}>
          <span>Authors: xB77 Labs</span>
          <span style={{ opacity: 0.3 }}>|</span>
          <span>Solana Privacy Hackathon 2026</span>
        </div>
        <div style={{ width: '100%', height: 1, background: t.border, margin: '48px 0 0' }}></div>
      </section>

      {/* Abstract */}
      <Section tag="00 — ABSTRACT" title="Abstract">
        <P bold>The machine economy is here. Autonomous agents manage capital, procure resources, and settle obligations at machine speed. Yet they operate on transparent rails where every transaction is visible to adversaries, competitors, and front-runners.</P>
        <P>xB77 introduces a sovereign financial operating system that gives autonomous agents the same privacy guarantees humans expect from traditional finance — without sacrificing auditability, compliance, or settlement finality.</P>
        <P>Built on a chain-agnostic core — a proprietary ZK engine for compressed receipts, Noir for zero-knowledge proofs, and pluggable settlement adapters (Solana via MagicBlock, Arc, Sui) — xB77 enables private agent transactions, autonomous governance, and easy deployment — self-hosted or cloud.</P>
      </Section>

      <div style={{ maxWidth: 860, margin: '0 auto', padding: '0 40px' }}>
        <div style={{ width: '100%', height: 1, background: t.border }}></div>
      </div>

      {/* Problem */}
      <Section tag="01 — PROBLEM" title={<>The Transparency <em style={{ color: t.accent, fontStyle: 'italic' }}>Trap</em></>}>
        <P>Public blockchains are adversarial environments. Every transaction, every balance, every counterparty relationship is visible to anyone with a block explorer. For autonomous agents managing institutional capital, this transparency is a critical vulnerability.</P>
        <P bold>Three failure modes emerge:</P>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, margin: '24px 0 24px' }}>
          {[
            { n: '01', title: 'Strategy Leakage', desc: 'Competitors observe agent behavior and reverse-engineer trading strategies in real-time.' },
            { n: '02', title: 'Front-Running', desc: 'MEV bots detect large agent transactions in the mempool and extract value before settlement.' },
            { n: '03', title: 'Identity Correlation', desc: 'Chain analysis links agent wallets to institutional identities, exposing portfolio positions.' },
          ].map(f => (
            <div key={f.n} style={{ display: 'grid', gridTemplateColumns: '48px 1fr', gap: 16, padding: '16px 20px', border: `1px solid ${t.border}`, background: t.bgCard }}>
              <div style={{ fontFamily: 'var(--mono)', fontSize: 20, color: t.accent, fontWeight: 600 }}>{f.n}</div>
              <div>
                <div style={{ fontFamily: 'var(--mono)', fontSize: 13, color: t.text, fontWeight: 600, marginBottom: 4 }}>{f.title}</div>
                <div style={{ fontFamily: 'var(--sans)', fontSize: 14, color: t.textDim, lineHeight: 1.6 }}>{f.desc}</div>
              </div>
            </div>
          ))}
        </div>
        <Quote>Privacy isn't a feature — it's the minimum bar for serious autonomous capital.</Quote>
      </Section>

      <div style={{ maxWidth: 860, margin: '0 auto', padding: '0 40px' }}>
        <div style={{ width: '100%', height: 1, background: t.border }}></div>
      </div>

      {/* Solution */}
      <Section tag="02 — SOLUTION" title={<>The xB77 <em style={{ color: t.accent, fontStyle: 'italic' }}>Stack</em></>}>
        <P>xB77 is a four-layer architecture that separates agent logic, privacy, and settlement into composable modules.</P>

        <Diagram label="TRANSACTION PIPELINE">
          <div style={{ display: 'flex', alignItems: 'center', gap: 0, overflowX: 'auto', padding: '8px 0' }}>
            {flowNodes.map((node, i) => (
              <React.Fragment key={i}>
                <div style={{
                  border: `1px solid ${t.border}`, padding: '14px 18px',
                  background: t.bg, flexShrink: 0, textAlign: 'center',
                  transition: 'border-color 0.2s',
                }}
                  onMouseEnter={e => e.currentTarget.style.borderColor = t.accent}
                  onMouseLeave={e => e.currentTarget.style.borderColor = t.border}
                >
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 10, color: t.accent, letterSpacing: '0.08em', marginBottom: 4 }}>{String(i + 1).padStart(2, '0')}</div>
                  <div style={{ fontFamily: 'var(--mono)', fontSize: 11, color: t.text, fontWeight: 600, whiteSpace: 'nowrap' }}>{node}</div>
                </div>
                {i < flowNodes.length - 1 && (
                  <div style={{ width: 28, height: 1, background: t.border, flexShrink: 0, position: 'relative' }}>
                    <div style={{ position: 'absolute', right: -2, top: -3, width: 0, height: 0, borderTop: '3px solid transparent', borderBottom: '3px solid transparent', borderLeft: `5px solid ${t.textDim}` }}></div>
                  </div>
                )}
              </React.Fragment>
            ))}
          </div>
        </Diagram>

        <P><strong style={{ color: t.text }}>xB77 ZK Engine</strong> is a proprietary privacy and compression layer. Transactions are shielded at the protocol level — no third-party dependencies, no external mixers, no trust assumptions.</P>
        <P><strong style={{ color: t.text }}>Noir ZK Prover</strong> generates Ghost Receipts — zero-knowledge proofs that verify transaction validity (amounts, compliance, governance) without revealing the agent's internal strategy or counterparty details.</P>
        <P><strong style={{ color: t.text }}>ZK Compression</strong> reduces on-chain storage by 99.7%. Ten thousand agent transactions collapse into a single 32-byte ZK proof anchored on Solana L1.</P>
      </Section>

      <div style={{ maxWidth: 860, margin: '0 auto', padding: '0 40px' }}>
        <div style={{ width: '100%', height: 1, background: t.border }}></div>
      </div>

      {/* Tokenomics */}
      <Section tag="03 — ECONOMICS" title={<>The 2.011% <em style={{ color: t.accent, fontStyle: 'italic' }}>Engine</em></>}>
        <P bold>xB77 does not issue a token. The protocol sustains itself through infrastructure usage — a 2.011% levy on every autonomous transaction, collected on-chain at settlement.</P>

        <Diagram label="VALUE FLOW">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            {[
              { label: 'INPUT', title: '2.011% Infra Tax', desc: 'Deducted automatically by the xB77 smart contract when Ghost Receipts settle on Solana L1.' },
              { label: 'OUTPUT', title: 'Sovereign Credits', desc: 'Funds RPC infrastructure, IPFS storage, and ZK proof generation for all agents in the network.' },
            ].map((v, i) => (
              <div key={i} style={{ padding: '20px', border: `1px solid ${t.border}`, background: t.bg }}>
                <div style={{ fontFamily: 'var(--mono)', fontSize: 9, color: t.accent, letterSpacing: '0.15em', marginBottom: 8 }}>{v.label}</div>
                <div style={{ fontFamily: 'var(--mono)', fontSize: 14, color: t.text, fontWeight: 600, marginBottom: 6 }}>{v.title}</div>
                <div style={{ fontFamily: 'var(--sans)', fontSize: 13, color: t.textDim, lineHeight: 1.5 }}>{v.desc}</div>
              </div>
            ))}
          </div>
        </Diagram>

        <P>The 2.011% ratio is calibrated to sustain infrastructure costs without disincentivizing high-frequency agent trading. As network volume scales, per-transaction infrastructure costs decrease while the absolute Sovereign Credits pool grows — creating a self-reinforcing sustainability loop.</P>
        <Quote>xB77 doesn't charge for transactions. It charges for <span style={{ color: t.accent }}>autonomy</span>.</Quote>
      </Section>

      <div style={{ maxWidth: 860, margin: '0 auto', padding: '0 40px' }}>
        <div style={{ width: '100%', height: 1, background: t.border }}></div>
      </div>

      {/* Governance */}
      <Section tag="04 — GOVERNANCE" title={<>Constitutional <em style={{ color: t.accent, fontStyle: 'italic' }}>Lockdowns</em></>}>
        <P>Every xB77 agent operates under a Constitution — a set of on-chain constraints that define spending limits, counterparty allowlists, strategy boundaries, and escalation thresholds.</P>
        <P bold>When an agent's action would breach its Constitution, the Governance Module triggers a Lockdown — pausing execution and requiring a human signature before proceeding.</P>
        <P>This creates a trust architecture where agents have maximum autonomy within defined bounds, with cryptographic guarantees that they cannot exceed those bounds. The ZK proof of every transaction includes a Constitution compliance attestation — verified by math, not trust.</P>
      </Section>

      <div style={{ maxWidth: 860, margin: '0 auto', padding: '0 40px' }}>
        <div style={{ width: '100%', height: 1, background: t.border }}></div>
      </div>

      {/* Conclusion */}
      <Section tag="05 — CONCLUSION" title={<>The Sovereign <em style={{ color: t.accent, fontStyle: 'italic' }}>Future</em></>}>
        <P bold>xB77 is infrastructure for a world where autonomous agents are the primary economic actors. Privacy is not optional — it's the foundation on which trustless agent commerce is built.</P>
        <P>By combining Solana's settlement speed, Noir's ZK proving system, xB77's proprietary compression engine, and MagicBlock's ephemeral rollups, xB77 delivers the first complete agent infrastructure stack purpose-built for the machine economy — deployable in minutes, self-hosted or cloud.</P>
        <P>The frontier is here. The agents are ready. The only question is whether the infrastructure will keep up.</P>

        <div style={{ display: 'flex', gap: 12, marginTop: 40 }}>
          <a href="/index.html#architecture" style={{
            fontFamily: 'var(--mono)', fontSize: 12, background: t.accent, color: t.bg,
            border: 'none', padding: '14px 28px', fontWeight: 600, letterSpacing: '0.06em',
            textTransform: 'uppercase', textDecoration: 'none', cursor: 'pointer',
          }}>Explore Architecture</a>
          <a href="/index.html#docs" style={{
            fontFamily: 'var(--mono)', fontSize: 12, background: 'transparent', color: t.text,
            border: `1px solid ${t.border}`, padding: '14px 28px', fontWeight: 500,
            letterSpacing: '0.06em', textTransform: 'uppercase', textDecoration: 'none', cursor: 'pointer',
          }}>Read the Docs</a>
        </div>
      </Section>

      <DocsDeepDive
        kicker="// FULL WHITEPAPER"
        label="Read the markdown whitepaper, in full."
        path="/whitepaper"
      />

      <PageFooter />
    </div>
  );
}

Object.assign(window, { WhitepaperPage });
