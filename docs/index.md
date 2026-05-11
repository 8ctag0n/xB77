---
layout: home

hero:
  name: "docs"
  text: "Product Deluxe Edition"
  tagline: "High-fidelity commerce layer for sovereign agents."
  actions:
    - theme: brand
      text: 01 // INITIALIZE MISSION
      link: /guide/deploy
    - theme: alt
      text: 02 // BROWSE SPECS
      link: /reference/brief

features:
  - title: 0x01 // MISSION CONTROL
    details: Real-time event stream via xb77 watch. SNS identity resolution and ZK-Batch pressure monitoring.
  - title: 0x02 // BLINK DELUXE
    details: Spec-compliant Solana Actions. Dynamic metadata and seamless agentic payment flows.
  - title: 0x03 // GHOST AUDIT
    details: Mathematical verification portal. Validate private transaction paths against L1 state anchors.
---
<div class="video-container">
  <div style="padding:56.25% 0 0 0;position:relative;"><iframe src="https://player.vimeo.com/video/1191004935?badge=0&amp;autopause=0&amp;player_id=0&amp;app_id=58479" frameborder="0" allow="autoplay; fullscreen; picture-in-picture; clipboard-write; encrypted-media; web-share" referrerpolicy="strict-origin-when-cross-origin" style="position:absolute;top:0;left:0;width:100%;height:100%;" title="sovereign-demo"></iframe></div>
</div>

<div class="terminal-deluxe vp-doc" style="margin-top: 4rem; max-width: 900px; margin-left: auto; margin-right: auto;">
  <div class="terminal-scanline"></div>
  <div style="position: absolute; top: 1rem; right: 1.5rem; display: flex; align-items: center; gap: 0.5rem;">
    <span class="pulse" style="width: 8px; height: 8px; background: #FF003C; display: inline-block;"></span>
    <span style="font-size: 10px; color: #FF003C; font-weight: bold;">[VIBE_LEVEL: DELUXE]</span>
  </div>
  
  <div style="color: #00FF41;">
    <div class="term-line line-1" style="margin-bottom: 0.5rem;">[XB77_WATCH] INGESTING_LEDGER_FEED...</div>
    <div class="term-line line-2" style="color: #00F0FF;">> tx_sig: 5Xy9...zk4 verified via SNS (agent.sol)</div>
    <div class="term-line line-3" style="color: #FCEE0A; margin: 0.5rem 0;">[BLINK] METADATA_GENERATED: "Autonomous Compute Lease"</div>
    
    <div class="term-line line-4" style="border-left: 2px solid #FF003C; padding-left: 1rem; margin: 1rem 0;">
      <div style="font-weight: bold; color: #fff;">GHOST_AUDIT_LOG</div>
      <div style="opacity: 0.7;">Merkle Path: Validated [L1 Slot: 284,912,011]</div>
      <div style="color: #00FF41;">Status: VERIFIED_SOVEREIGN</div>
    </div>

    <div class="term-line line-5" style="display: flex; gap: 1rem; margin-top: 1rem;">
      <div style="border: 1px solid #333; padding: 0.5rem 1rem; background: #111;">
        <div style="font-size: 10px; color: #666;">BATCH_PRESSURE</div>
        <div style="font-weight: bold;">[||||||||||||||--] 84%</div>
      </div>
      <div style="border: 1px solid #333; padding: 0.5rem 1rem; background: #111;">
        <div style="font-size: 10px; color: #666;">GAS_ORACLE</div>
        <div style="font-weight: bold; color: #FCEE0A;">11 GWEI</div>
      </div>
      <div class="terminal-cursor"></div>
    </div>
  </div>
</div>

<style>
@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.3; }
  100% { opacity: 1; }
}
.pulse {
  animation: pulse 1s infinite;
}
.VPHero {
  padding-bottom: 2rem !important;
}
</style>
