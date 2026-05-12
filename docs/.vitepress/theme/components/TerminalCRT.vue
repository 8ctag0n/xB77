<template>
  <div class="crt-flicker">
    <div class="terminal-container">
      <div class="terminal-header">
        <span>SYSTEM_ID: XB77_CFO_MVP</span>
        <span class="status">STATUS: PIPELINE_ACTIVE</span>
      </div>
      <div class="terminal-body">
        <div class="terminal-scroll">
          <!-- block 1 -->
          <div>[INIT] PIPELINE_START: AGENT_CFO_ALPHA</div>
          <div>[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)</div>
          <div>[PAY]  SHIELDING ASSETS VIA SHADOWWIRE...</div>
          <div class="info">[HELIUS] ANALYZING DESTINATION REPUTATION: LOW_RISK</div>
          <div>[PAY]  VIRTUAL_CARD_GENERATED: ****-****-****-7781</div>
          <pre class="code-block">const xB77 = {
  privacy:    "MAX",
  compliance: "RANGE_PROTOCOL",
  receipts:   "LIGHT_COMPRESSED"
};</pre>
          <div class="warn">[GOVERNANCE] LOCKDOWN MODE: HUMAN SIGNATURE REQUIRED</div>
          <div>[ZKP]  GENERATING SELECTIVE DISCLOSURE PROOF...</div>
          <div>[END]  RECEIPT STORED ON LIGHT PROTOCOL</div>
          <div class="spacer"></div>
          <div>[INIT] PIPELINE_START: AGENT_CFO_BETA</div>
          <div>[AUTH] NEURAL_KEY_VERIFIED</div>
          <div>[PAY]  SHIELDING ASSETS...</div>
          <div class="info">[HELIUS] DESTINATION: TRUSTED_VENDOR</div>
          <div>[PAY]  VIRTUAL_CARD_GENERATED: ****-****-****-3326</div>
          <div class="warn">[GOVERNANCE] AUTO-APPROVED &lt; THRESHOLD</div>
          <div>[ZKP]  PROOF_BUNDLE_COMPRESSED → 99.7%</div>
          <div>[END]  RECEIPT STORED ON LIGHT PROTOCOL</div>
          <div class="spacer"></div>
          <!-- block 2 (duplicate so vertical scroll loops seamlessly) -->
          <div>[INIT] PIPELINE_START: AGENT_CFO_ALPHA</div>
          <div>[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)</div>
          <div>[PAY]  SHIELDING ASSETS VIA SHADOWWIRE...</div>
          <div class="info">[HELIUS] ANALYZING DESTINATION REPUTATION: LOW_RISK</div>
          <div>[PAY]  VIRTUAL_CARD_GENERATED: ****-****-****-7781</div>
          <pre class="code-block">const xB77 = {
  privacy:    "MAX",
  compliance: "RANGE_PROTOCOL",
  receipts:   "LIGHT_COMPRESSED"
};</pre>
          <div class="warn">[GOVERNANCE] LOCKDOWN MODE: HUMAN SIGNATURE REQUIRED</div>
          <div>[ZKP]  GENERATING SELECTIVE DISCLOSURE PROOF...</div>
          <div>[END]  RECEIPT STORED ON LIGHT PROTOCOL</div>
          <div class="spacer"></div>
          <div>[INIT] PIPELINE_START: AGENT_CFO_BETA</div>
          <div>[AUTH] NEURAL_KEY_VERIFIED</div>
          <div>[PAY]  SHIELDING ASSETS...</div>
          <div class="info">[HELIUS] DESTINATION: TRUSTED_VENDOR</div>
          <div>[PAY]  VIRTUAL_CARD_GENERATED: ****-****-****-3326</div>
          <div class="warn">[GOVERNANCE] AUTO-APPROVED &lt; THRESHOLD</div>
          <div>[ZKP]  PROOF_BUNDLE_COMPRESSED → 99.7%</div>
          <div>[END]  RECEIPT STORED ON LIGHT PROTOCOL</div>
        </div>
      </div>
    </div>

    <section class="legacy-cta">
      <h2 class="chromatic-text">BUILT FOR THE MACHINE ECONOMY</h2>
      <p>
        xB77 provides the abstraction layer necessary for autonomous agents to manage capital with institutional-grade privacy and compliance.
      </p>
      <div class="cta-row">
        <a href="/v1/docs/guide/GETTING_STARTED" class="cyber-button">Launch Pipeline</a>
        <a href="/v1/docs/whitepaper/WHITEPAPER_EN" class="cyber-button alt">Read Whitepaper</a>
      </div>
    </section>
  </div>
</template>

<style scoped>
.terminal-container {
  margin: 4rem auto 0;
  max-width: 900px;
  background: #000;
  border: 1px solid #333;
  padding: 2rem;
  position: relative;
  font-family: 'Fira Code', 'Share Tech Mono', ui-monospace, monospace;
  overflow: hidden;
}

.terminal-header {
  border-bottom: 1px solid #333;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  display: flex;
  justify-content: space-between;
  font-size: 0.8rem;
  color: #666;
  letter-spacing: 0.06em;
}
.status { color: var(--legacy-cyan); }

.terminal-body {
  height: 300px;
  overflow: hidden;
  color: var(--legacy-matrix);
  font-size: 0.9rem;
  line-height: 1.7;
}

.terminal-scroll {
  animation: terminal-scroll-vertical 30s linear infinite;
}

.info { color: var(--legacy-yellow); }
.warn { color: var(--legacy-red); }
.spacer { height: 1.2rem; }

.code-block {
  padding: 0.75rem 0;
  margin: 0.5rem 0;
  opacity: 0.85;
  font-family: 'Fira Code', 'Share Tech Mono', ui-monospace, monospace;
  color: var(--legacy-matrix);
  white-space: pre;
  font-size: 0.84rem;
}

.legacy-cta {
  padding: 6rem 0;
  text-align: center;
}
.legacy-cta p {
  max-width: 800px;
  margin: 0 auto 3rem;
  color: #a0a0a0;
  font-family: 'Fira Code', ui-monospace, monospace;
  font-size: 0.95rem;
  line-height: 1.7;
}
.cta-row { display: flex; gap: 2rem; justify-content: center; flex-wrap: wrap; }

.chromatic-text {
  font-size: 3rem;
  margin-bottom: 2rem;
  color: #ffffff;
  text-shadow: -2px 0 var(--legacy-red), 2px 0 var(--legacy-cyan);
  font-family: 'Rajdhani', sans-serif;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  font-weight: 700;
}

.cyber-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 1rem 2rem;
  font-family: 'Rajdhani', sans-serif;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  transition: all 0.3s;
  cursor: pointer;
  border: none;
  background: var(--legacy-red);
  color: black;
  clip-path: polygon(0 0, 100% 0, 100% calc(100% - 15px), calc(100% - 15px) 100%, 0 100%);
  text-decoration: none !important;
}
.cyber-button:hover { background: #fff; color: #000; }
.cyber-button.alt {
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.2);
  color: #fff;
}
.cyber-button.alt:hover { background: rgba(255, 255, 255, 0.1); color: #fff; }
</style>
