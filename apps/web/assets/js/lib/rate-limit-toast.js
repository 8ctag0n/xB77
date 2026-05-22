// Toast for gateway 429s. Listens to window 'xb77:rate-limited' from data-source.js.
(function () {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  const ID = "xb77-rate-toast";
  let timer = null, endsAt = 0;

  const ensure = () => {
    let el = document.getElementById(ID);
    if (el) return el;
    el = document.createElement("div");
    el.id = ID;
    el.setAttribute("role", "alert");
    el.style.cssText = `position:fixed;top:14px;right:14px;z-index:10000;
      font:12px/1.4 var(--font-mono,ui-monospace,monospace);padding:10px 14px;
      background:var(--bg-elevated,#1f1410);color:var(--fg-primary,#f3e4c8);
      border:1px solid var(--accent,#c97a3a);letter-spacing:.02em;
      box-shadow:0 6px 20px rgba(0,0,0,.35);opacity:0;transform:translateY(-6px);
      transition:opacity 200ms ease,transform 200ms ease;pointer-events:none`;
    document.body.appendChild(el);
    return el;
  };

  const tick = () => {
    const el = document.getElementById(ID);
    if (!el) return;
    const s = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));
    if (s <= 0) {
      el.style.opacity = "0";
      el.style.transform = "translateY(-6px)";
      clearInterval(timer); timer = null;
      return;
    }
    el.textContent = `Rate limited — retry in ${s}s`;
  };

  window.addEventListener("xb77:rate-limited", (ev) => {
    const ms = Number(ev?.detail?.retryAfterMs) || 5000;
    endsAt = Date.now() + ms;
    const el = ensure();
    el.textContent = `Rate limited — retry in ${Math.ceil(ms / 1000)}s`;
    requestAnimationFrame(() => {
      el.style.opacity = "1";
      el.style.transform = "translateY(0)";
    });
    if (timer) clearInterval(timer);
    timer = setInterval(tick, 500);
  });
})();
