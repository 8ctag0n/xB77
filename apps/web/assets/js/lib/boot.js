/* xB77 boot screen + cross-entry fluid transition.
   Runs once per HTML load, before React. */

(function bootAndTransition() {
  // ── Fade body in on DOMContentLoaded (handles both entries). ──
  function fadeIn() {
    if (!document.body) return;
    requestAnimationFrame(() => {
      document.body.style.transition = 'opacity 0.2s ease';
      document.body.style.opacity = '1';
    });
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', fadeIn);
  } else {
    fadeIn();
  }

  // ── Fade body out + navigate on cross-entry link clicks. ──
  document.addEventListener('click', (e) => {
    const a = e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    if (!href) return;
    const onApp = window.location.pathname.endsWith('/app.html');
    const onPublic = !onApp; // root or /index.html
    const goesToApp = href.startsWith('/app.html');
    const goesToPublic = href.startsWith('/index.html');
    const isCross = (onPublic && goesToApp) || (onApp && goesToPublic);
    if (!isCross) return;
    e.preventDefault();
    document.body.style.transition = 'opacity 0.2s ease';
    document.body.style.opacity = '0';
    setTimeout(() => window.location.assign(href), 200);
  });

  // ── Boot screen: only on the landing path and only once per session. ──
  const path = window.location.pathname;
  const onLanding = path === '/' || path.endsWith('/index.html');
  const alreadyBooted = sessionStorage.getItem('xb77_booted') === '1';
  if (!onLanding || alreadyBooted) return;

  // Mark immediately so a refresh during boot doesn't replay it.
  sessionStorage.setItem('xb77_booted', '1');

  const overlay = document.createElement('div');
  overlay.id = 'xb77-boot';
  overlay.setAttribute('aria-hidden', 'true');
  overlay.innerHTML = '<pre id="xb77-boot-logo"></pre><div id="xb77-boot-lines"></div>';

  function mount() {
    if (!document.body) {
      requestAnimationFrame(mount);
      return;
    }
    document.body.insertBefore(overlay, document.body.firstChild);
    runSequence();
  }
  mount();

  const LOGO = [
    "██╗  ██╗██████╗ ███████╗███████╗",
    "╚██╗██╔╝██╔══██╗╚════██║╚════██║",
    " ╚███╔╝ ██████╔╝    ██╔╝    ██╔╝",
    " ██╔██╗ ██╔══██╗   ██╔╝    ██╔╝",
    "██╔╝ ██╗██████╔╝   ██║     ██║ ",
    "╚═╝  ╚═╝╚═════╝    ╚═╝     ╚═╝ ",
  ].join("\n");

  const LINES = [
    "[BOOT]  LOADING ZIG_KERNEL v2.0.11...",
    "[AUTH]  NEURAL_KEY VERIFIED (0x77...)",
    "[EDGE]  CONNECTED TO CLOUDFLARE_BOS",
    "[STRAT] INJECTING QVAC_CONSTITUTION",
    "[READY] WELCOME TO THE MACHINE ECONOMY",
  ];

  function runSequence() {
    const logoEl = document.getElementById('xb77-boot-logo');
    const linesEl = document.getElementById('xb77-boot-lines');
    if (!logoEl || !linesEl) return;

    let cancelled = false;
    function dismiss() {
      if (cancelled) return;
      cancelled = true;
      overlay.style.transition = 'opacity 0.25s ease';
      overlay.style.opacity = '0';
      setTimeout(() => overlay.remove(), 260);
    }
    overlay.addEventListener('click', dismiss, { once: true });
    document.addEventListener('keydown', dismiss, { once: true });

    logoEl.textContent = LOGO;
    let i = 0;
    function nextLine() {
      if (cancelled) return;
      if (i >= LINES.length) {
        setTimeout(dismiss, 250);
        return;
      }
      const div = document.createElement('div');
      div.textContent = LINES[i];
      if (i === LINES.length - 1) div.className = 'ready';
      linesEl.appendChild(div);
      i++;
      setTimeout(nextLine, 400);
    }
    setTimeout(nextLine, 200);
  }
})();
