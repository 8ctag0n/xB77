<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const slot = ref('284,912,011')
const pressure = ref(91)
const isLive = ref(true)
const statusLabel = ref('SOVEREIGN_SYSTEM_ONLINE')
let interval = null

const ASCII_LOGO = `
    █▀▀█▀▀█ █▀▀▀█ ▀▀█▀▀▀ ▀▀█▀▀▀
      ▄▀▀▄  █   █   █▄▄   █▄▄
    █▄▄█▄▄█ █▄▄▄█   █     █
`

const updateMetrics = async () => {
  try {
    const resp = await fetch('https://gateway.xb77.io/api/v1/network/pulse')
    if (resp.ok) {
      const data = await resp.json()
      if (data.ok && data.data) {
        slot.value = new Intl.NumberFormat().format(data.data.slot)
        pressure.value = Math.floor(60 + Math.random() * 35)
        isLive.value = true
        statusLabel.value = 'SOVEREIGN_SYSTEM_ONLINE'
      }
    }
  } catch (e) {
    isLive.value = false
    statusLabel.value = 'CRITICAL_OFFLINE'
    pressure.value = Math.floor(20 + Math.random() * 10)
  }
}

onMounted(() => {
  updateMetrics()
  interval = setInterval(updateMetrics, 5000)
})

onUnmounted(() => {
  if (interval) clearInterval(interval)
})
</script>

<template>
  <div class="terminal-deluxe vp-doc">
    <div class="terminal-header">
      <div class="header-left">
        <span class="header-dot red"></span>
        <span class="header-dot yellow"></span>
        <span class="header-dot green"></span>
        <span class="header-title">XB77_NODE_MONITOR // v2.0.11</span>
      </div>
      <div class="header-right">
        <span class="status-text" :class="{ 'text-red': !isLive }">[{{ statusLabel }}]</span>
        <span class="pulse-bit" :class="{ 'pulse-offline': !isLive }"></span>
      </div>
    </div>
    <div class="terminal-content">
      <div class="banner-block">
        <pre class="ascii-logo">{{ ASCII_LOGO }}</pre>
        <div class="banner-text">
          <div class="engine-label">SOVEREIGN_FINANCIAL_ENGINE</div>
          <div class="engine-sub">Built for the machine economy.</div>
        </div>
      </div>

      <div class="telemetry-grid">
        <div class="telemetry-item">
          <div class="tel-label">L1_SOLANA_SLOT</div>
          <div class="tel-value text-accent">{{ slot }}</div>
        </div>
        <div class="telemetry-item">
          <div class="tel-label">SWARM_PRESSURE</div>
          <div class="tel-value text-cyan">{{ pressure }}%</div>
          <div class="tel-bar">
            <div class="tel-bar-fill" :style="{ width: pressure + '%' }"></div>
          </div>
        </div>
        <div class="telemetry-item">
          <div class="tel-label">ZK_VERIFIER</div>
          <div class="tel-value" :class="isLive ? 'text-lime' : 'text-red'">{{ isLive ? 'OPERATIONAL' : 'FAULT_DETECTED' }}</div>
        </div>
      </div>

      <div class="log-trace">
        <div class="log-line"><span class="log-ts">[00:00:01]</span> <span class="log-msg">INITIALIZING_ENCRYPTED_VAULT... [OK]</span></div>
        <div class="log-line"><span class="log-ts">[00:00:02]</span> <span class="log-msg">NEURAL_SIGNATURE_VERIFIED: AGENT_CFO_ALPHA</span></div>
        <div class="log-line"><span class="log-ts">[00:00:05]</span> <span class="log-msg text-lime">SOVEREIGN_LEASES_ACTIVE // SYNCED_WITH_GATEWAY</span></div>
      </div>
    </div>
    <div class="terminal-scanline"></div>
  </div>
</template>

<style scoped>
.terminal-deluxe {
  margin: 4rem auto 0;
  max-width: 900px;
  background: #000;
  border: 1px solid #222;
  border-radius: 6px;
  overflow: hidden;
  box-shadow: 0 30px 60px rgba(0,0,0,0.8);
  font-family: var(--vp-font-family-mono);
  position: relative;
}

.terminal-header {
  background: #111;
  padding: 10px 16px;
  border-bottom: 1px solid #222;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-left { display: flex; gap: 6px; align-items: center; }
.header-dot { width: 8px; height: 8px; border-radius: 50%; }
.header-dot.red { background: #ff5f56; }
.header-dot.yellow { background: #ffbd2e; }
.header-dot.green { background: #27c93f; }
.header-title { font-size: 10px; color: #666; margin-left: 8px; letter-spacing: 1px; }

.header-right { display: flex; gap: 10px; align-items: center; }
.status-text { font-size: 10px; color: var(--xb77-accent); font-weight: bold; }
.pulse-bit { width: 6px; height: 6px; background: var(--xb77-accent); animation: blink 1s infinite; box-shadow: 0 0 8px var(--xb77-accent); }
.pulse-offline { background: #ff4e4e; box-shadow: 0 0 8px #ff4e4e; }

.terminal-content { padding: 32px; }

.banner-block { display: flex; gap: 32px; align-items: center; margin-bottom: 40px; }
.ascii-logo { margin: 0; line-height: 1.1; color: var(--xb77-accent); font-size: 12px; }
.engine-label { font-size: 18px; font-weight: bold; color: #fff; letter-spacing: -0.5px; }
.engine-sub { font-size: 12px; color: #666; margin-top: 4px; }

.telemetry-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 40px; }
.telemetry-item { background: #050505; border: 1px solid #111; padding: 16px; }
.tel-label { font-size: 9px; color: #444; margin-bottom: 8px; letter-spacing: 1px; }
.tel-value { font-size: 20px; font-weight: bold; }

.tel-bar { height: 4px; background: #111; margin-top: 12px; border-radius: 2px; overflow: hidden; }
.tel-bar-fill { height: 100%; background: var(--neon-cyan); transition: width 0.5s ease; }

.log-trace { border-top: 1px solid #111; paddingTop: 24px; }
.log-line { font-size: 11px; margin-bottom: 6px; color: #888; }
.log-ts { color: #444; margin-right: 12px; }

.text-accent { color: var(--xb77-accent); }
.text-cyan { color: var(--neon-cyan); }
.text-lime { color: #27c93f; }
.text-red { color: #ff4e4e !important; }

@keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }

.terminal-scanline {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: linear-gradient(to bottom, transparent 50%, rgba(0,0,0,0.1) 51%);
  background-size: 100% 4px;
  pointer-events: none;
  opacity: 0.1;
}
</style>
