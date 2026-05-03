---
layout: home

hero:
  name: "xB77"
  text: "Autonomous Financial Infrastructure"
  tagline: "The sovereign financial operating system for the machine economy."
  actions:
    - theme: brand
      text: Explore Docs
      link: /docs/mission
    - theme: alt
      text: Architecture
      link: /docs/architecture/DIAGRAMS
head:
  - ['script', { src: 'https://player.vimeo.com/api/player.js', defer: true }]

features:
  - title:  Shielded Payments
    details: Leverages ShadowWire for decoupled, private B2B treasury management.
  - title: ️ Obfuscated Flows
    details: Routes sensitive transactions through Privacy Cash pools to break chain-link analysis.
  - title:  ZK-Compressed Receipts
    details: Private on-chain transaction history powered by Light Protocol.
---

<section style="padding: 3rem 0; text-align: center;">
  <div class="video-wrapper" style="max-width: 900px; margin: 0 auto;">
    <div style="padding:56.25% 0 0 0;position:relative;">
      <iframe src="https://player.vimeo.com/video/1160566027?badge=0&amp;autopause=0&amp;player_id=0&amp;app_id=58479"
              frameborder="0"
              allow="autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media; web-share"
              referrerpolicy="strict-origin-when-cross-origin"
              style="position:absolute;top:0;left:0;width:100%;height:100%;"
              title="xb77 first draft"></iframe>
    </div>
  </div>
</section>
<div class="crt-flicker">

<div class="terminal-container" style="margin-top: 4rem; max-width: 900px; margin-left: auto; margin-right: auto;">
  <div class="terminal-header">
    <span>SYSTEM_ID: XB77_CFO_MVP</span>
    <span style="color: var(--vp-c-brand-2)">STATUS: PIPELINE_ACTIVE</span>
  </div>
  <div class="terminal-body">
    <div class="terminal-scroll">
      <div>[INIT] PIPELINE_START: AGENT_CFO_ALPHA</div>
      <div>[AUTH] NEURAL_KEY_VERIFIED (ZK-IDENTITY: OK)</div>
      <div>[PAY] SHIELDING ASSETS VIA SHADOWWIRE...</div>
      <div style="color: var(--vp-c-brand-3)">[HELIUS] ANALYZING DESTINATION REPUTATION: LOW_RISK</div>
      <div>[PAY] VIRTUAL_CARD_GENERATED: ****-****-****-7781</div>
      <div style="padding: 1rem 0; opacity: 0.8">
        const xB77 = {<br/>
        &nbsp;&nbsp;privacy: "MAX",<br/>
        &nbsp;&nbsp;compliance: "RANGE_PROTOCOL",<br/>
        &nbsp;&nbsp;receipts: "LIGHT_COMPRESSED"<br/>
        };
      </div>
      <div style="color: var(--vp-c-brand-1)">[GOVERNANCE] LOCKDOWN MODE: HUMAN SIGNATURE REQUIRED</div>
      <div>[ZKP] GENERATING SELECTIVE DISCLOSURE PROOF...</div>
      <div>[END] RECEIPT STORED ON LIGHT PROTOCOL</div>
      <br/>
      <div>[INIT] PIPELINE_START: AGENT_CFO_BETA</div>
      <div>[AUTH] NEURAL_KEY_VERIFIED</div>
      <div>[PAY] SHIELDING ASSETS...</div>
    </div>
  </div>
</div>

<section style="padding: 6rem 0; text-align: center;">
  <h2 class="chromatic-text" style="font-size: 3rem; margin-bottom: 2rem;">BUILT FOR THE MACHINE ECONOMY</h2>
  <p style="max-width: 800px; margin: 0 auto 3rem; color: var(--vp-c-text-2); font-family: var(--vp-f-mono);">
    xB77 provides the abstraction layer necessary for autonomous agents to manage capital with institutional-grade privacy and compliance.
  </p>
  <div style="display: flex; gap: 2rem; justify-content: center;">
    <a href="/docs/guide/GETTING_STARTED" class="cyber-button">Launch Pipeline</a>
    <a href="/docs/whitepaper/WHITEPAPER_EN" class="cyber-button alt">Read Whitepaper</a>
  </div>
</section>

</div>

<style>
:root {
  --vp-home-hero-name-color: transparent;
  --vp-home-hero-name-background: linear-gradient(135deg, #FF003C 0%, #00F0FF 100%);
}

.VPHero {
  background-image: radial-gradient(circle at center, rgba(255, 0, 60, 0.05) 0%, transparent 70%);
}
</style>
