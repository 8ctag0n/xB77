<template>
  <div class="terminal-deluxe vp-doc">
    <div class="terminal-scanline"></div>
    <div class="terminal-badge">
      <span class="pulse"></span>
      <span class="terminal-badge-label">[VIBE_LEVEL: DELUXE]</span>
    </div>
    <div class="terminal-body">
      <div class="term-line line-1 tone-accent">[SYSTEM] INITIALIZING_XB77_PROTOCOL_V2...</div>
      <div class="term-line line-2 tone-cyan">&gt; AUTHENTICATING SOVEREIGN AGENT... [OK]</div>
      <div class="term-line line-3 tone-accent dim">[NOTICE] HIGH_FLOW_DETECTION: LIME_MODE_ACTIVE</div>
      <div class="term-line line-4 ghost-block">
        <div class="ghost-title">GHOST_AUDIT_STREAM</div>
        <div class="ghost-meta">Merkle Path: Validated [L1 Slot: 284,912,011]</div>
        <div class="ghost-meta tone-cyan">Encryption: ZK-STARK / Noir-Bound</div>
      </div>
      <div class="term-line line-5 metric-row">
        <div class="metric-cell">
          <div class="metric-label">FLOW_PRESSURE</div>
          <div class="metric-value tone-accent">[||||||||||||||--] 91%</div>
        </div>
        <div class="metric-cell">
          <div class="metric-label">ZK_ORACLE</div>
          <div class="metric-value tone-cyan">ACTIVE</div>
        </div>
        <div class="terminal-cursor"></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.terminal-deluxe {
  margin: 4rem auto 0;
  max-width: 900px;
  position: relative;
  border: 1px solid var(--xb77-accent);
  background: #000;
  padding: 1.5rem;
  font-family: var(--vp-font-family-mono);
  font-size: 0.85rem;
  color: #fff;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.5), 0 0 30px rgba(200, 255, 46, 0.08);
  border-radius: 4px;
  overflow: hidden;
}

.terminal-badge {
  position: absolute;
  top: 1rem;
  right: 1.5rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  z-index: 2;
}

.pulse {
  width: 8px;
  height: 8px;
  background: var(--xb77-accent);
  display: inline-block;
  box-shadow: 0 0 10px var(--xb77-accent);
  animation: pulse 1s infinite;
}

.terminal-badge-label {
  font-size: 10px;
  color: var(--xb77-accent);
  font-weight: bold;
  letter-spacing: 2px;
}

.terminal-body { position: relative; z-index: 1; }

.tone-accent { color: var(--xb77-accent); }
.tone-cyan { color: var(--neon-cyan); }
.dim { opacity: 0.8; margin: 0.5rem 0; }

.ghost-block {
  border-left: 2px solid var(--xb77-accent);
  padding-left: 1rem;
  margin: 1rem 0;
  background: rgba(200, 255, 46, 0.05);
}
.ghost-title { font-weight: bold; color: var(--xb77-accent); }
.ghost-meta { opacity: 0.75; font-size: 11px; }

.metric-row {
  display: flex;
  gap: 1rem;
  margin-top: 1rem;
  flex-wrap: wrap;
  align-items: center;
}
.metric-cell {
  border: 1px solid #2a2a2a;
  padding: 0.5rem 1rem;
  background: #050505;
}
.metric-label { font-size: 10px; color: #666; }
.metric-value { font-weight: bold; }

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.3; }
  100% { opacity: 1; }
}
</style>
