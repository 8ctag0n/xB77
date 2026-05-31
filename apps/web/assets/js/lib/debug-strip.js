// Dev rate-limit telemetry strip. Activated by ?debug=1. Reads window.__xb77RateLimit.
(function () {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  if (new URLSearchParams(location.search).get("debug") !== "1") return;
  if (document.getElementById("xb77-debug-strip")) return;

  const el = document.createElement("div");
  el.id = "xb77-debug-strip";
  el.setAttribute("role", "status");
  el.style.cssText = `position:fixed;right:10px;bottom:10px;z-index:9999;
    font:11px/1.4 var(--font-mono,ui-monospace,monospace);padding:6px 10px;
    background:var(--bg-elevated,#1a1a1a);color:var(--fg-secondary,#aaa);
    border:1px solid var(--border-strong,#333);pointer-events:none;
    user-select:none;white-space:nowrap;box-shadow:0 4px 16px rgba(0,0,0,.25)`;

  const fmtReset = (r) => {
    if (!r) return "—";
    const dt = r - Math.floor(Date.now() / 1000);
    if (dt <= 0) return "0s";
    return dt < 60 ? `${dt}s` : `${(dt / 60) | 0}m${dt % 60}s`;
  };

  const render = () => {
    const rl = window.__xb77RateLimit || {};
    const stale = rl.lastUpdatedAt ? `${((Date.now() - rl.lastUpdatedAt) / 1000) | 0}s ago` : "no data";
    el.textContent = `tier:${rl.tier ?? "—"} · ${rl.remaining ?? "—"}/${rl.limit ?? "—"} · reset ${fmtReset(rl.reset)} · ${stale}`;
  };

  document.body.appendChild(el);
  render();
  setInterval(render, 1000);
})();
