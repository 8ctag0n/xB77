# Boot Screen + Fluid Transition — Plan

> Combined design + implementation plan. Design already approved verbally in session 2026-05-11.

**Goal:** Add a theme-aware ASCII boot screen on first visit to the public site, plus a fade-out / fade-in transition between `index.html` and `app.html` instead of the default browser flash.

**Estimated effort:** 1.5–2 hours.

**Branch:** `feat/dapp-public-split` (current).

---

## Design (locked)

### Boot screen
- Fullscreen overlay, mounted **only** on `index.html`.
- Shows ASCII "xB77" logo + 3 status lines:
  ```
  [BOOT] sovereign layer
  [AUTH] zk identity verified
  [READY]
  ```
- Typewriter render, line-by-line, ~400ms per line. Total ~1.8s including a 200ms hold at the end.
- Theme-respect via `var(--bg)` + `var(--accent)` — same component, looks lime-on-obsidian in dark and olive-on-cream in light.
- Dismissed automatically when `sessionStorage.xb77_booted === '1'` so it shows once per session.
- Click anywhere during the boot: skip immediately (set flag, fade out).

### Fluid transition
- Click on `<a href="/app.html">` (or anywhere targeting `/app.html` cross-doc) → prevent default, fade `body` to opacity 0 over 200ms, then `location.assign(...)`.
- Click on `<a href="/index.html...">` from app.html → same pattern.
- Each entry starts with `body { opacity: 0 }`, JS removes/transitions it to 1 when DOMContentLoaded.

## Files

**Create:**
- `webapp_deploy/assets/src/lib/boot.js` — Boot screen + transition controller (vanilla JS, runs before React).

**Modify:**
- `webapp_deploy/assets/css/tokens.css` — Body fade rule + boot overlay styles.
- `webapp_deploy/index.html` — Load `boot.js` after `theme.js`.
- `webapp_deploy/app.html` — Same.

No React component needed — boot runs before React and uses plain DOM. Keeps it simple and avoids any flash from React's mount cycle.

## Task 1: Boot + transition controller

**Files:**
- Create: `webapp_deploy/assets/src/lib/boot.js`

- [ ] **Step 1: Write `boot.js`**

```js
/* xB77 boot screen + cross-entry fluid transition.
   Runs once per HTML load, before React. */

(function bootAndTransition() {
  const root = document.documentElement;
  const isPublic = !document.body || !document.querySelector('script[src*="router-app"]');
  // ^ heuristic that runs deferred; we re-check after DOMContentLoaded

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
    // Only intercept cross-document navigation to /app.html or /index.html.
    const isCross = (href.startsWith('/app.html') && !window.location.pathname.endsWith('/app.html'))
                 || (href.startsWith('/index.html') && !window.location.pathname.endsWith('/index.html')
                                                    && window.location.pathname !== '/');
    if (!isCross) return;
    e.preventDefault();
    document.body.style.transition = 'opacity 0.2s ease';
    document.body.style.opacity = '0';
    setTimeout(() => window.location.assign(href), 200);
  });

  // ── Boot screen: only on the landing path (index.html or root) and only once per session. ──
  const path = window.location.pathname;
  const onPublic = path === '/' || path.endsWith('/index.html');
  const alreadyBooted = sessionStorage.getItem('xb77_booted') === '1';
  if (!onPublic || alreadyBooted) return;

  // Mark immediately so a refresh during boot doesn't replay it.
  sessionStorage.setItem('xb77_booted', '1');

  const overlay = document.createElement('div');
  overlay.id = 'xb77-boot';
  overlay.setAttribute('aria-hidden', 'true');
  overlay.innerHTML = `
<pre id="xb77-boot-logo"></pre>
<div id="xb77-boot-lines"></div>
`;
  // Insert as first body child once body exists.
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
    "[BOOT]  sovereign layer",
    "[AUTH]  zk identity verified",
    "[READY]",
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

    // Show logo immediately (block-paint), then typewriter the lines.
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
      div.className = i === LINES.length - 1 ? 'ready' : '';
      linesEl.appendChild(div);
      i++;
      setTimeout(nextLine, 400);
    }
    setTimeout(nextLine, 200);
  }
})();
```

- [ ] **Step 2: Build and confirm copy**

```bash
./webapp_deploy/build.sh
ls webapp_deploy/assets/js/lib/boot.js
```

Expected: file exists.

## Task 2: CSS for the boot overlay and body fade

**Files:**
- Modify: `webapp_deploy/assets/css/tokens.css`

- [ ] **Step 1: Append boot overlay + body fade rules**

Add this block to the bottom of `tokens.css`:

```css
/* ── Initial body fade-in (boot.js promotes opacity to 1 on DOMContentLoaded) ── */
body {
  opacity: 0;
}

/* ── Boot overlay (only injected on index.html, first visit per session) ── */
#xb77-boot {
  position: fixed;
  inset: 0;
  z-index: 99999;
  background: var(--bg);
  color: var(--accent);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 28px;
  font-family: var(--mono, 'JetBrains Mono', monospace);
  opacity: 1;
}
#xb77-boot-logo {
  margin: 0;
  font-size: 12px;
  line-height: 1.1;
  white-space: pre;
  letter-spacing: 0;
  color: var(--accent);
  text-shadow: 0 0 12px var(--accent-glow);
}
#xb77-boot-lines {
  font-size: 11px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--text-dim);
  text-align: left;
  min-width: 260px;
}
#xb77-boot-lines div {
  padding: 2px 0;
}
#xb77-boot-lines div.ready {
  color: var(--accent);
}
@media (max-width: 480px) {
  #xb77-boot-logo { font-size: 9px; }
}
```

- [ ] **Step 2: Build verify**

```bash
./webapp_deploy/build.sh
```

Expected: clean.

## Task 3: Load boot.js in both HTMLs

**Files:**
- Modify: `webapp_deploy/index.html`
- Modify: `webapp_deploy/app.html`

- [ ] **Step 1: Add `<script>` after theme.js in `index.html`**

Find the `theme.js` line in `<head>`. Add right after:

```html
<script src="assets/js/lib/boot.js"></script>
```

- [ ] **Step 2: Same in `app.html`**

Identical addition.

- [ ] **Step 3: Visual test**

Recargá `http://localhost:8080/` con sessionStorage limpio:
- DevTools → Application → Session Storage → clear.
- Reload.
- Expected: pantalla negra (o cream si light), logo xB77 ASCII, 3 líneas typewriter, fade out después de ~1.8s, página entra con fade-in.

Click durante el boot → skip + fade out inmediato.

Click "Launch App" en el público → fade out → `app.html` carga con fade-in. Sin boot screen (porque sessionStorage tiene flag).

Click "← xb77.io" desde app → fade out → `index.html` carga con fade-in. Sin boot (flag).

Limpiar sessionStorage → recargar `index.html` → boot vuelve a aparecer.

- [ ] **Step 4: Commit**

```bash
git add webapp_deploy/assets/src/lib/boot.js webapp_deploy/assets/js/lib/boot.js webapp_deploy/assets/css/tokens.css webapp_deploy/index.html webapp_deploy/app.html
git commit -m "feat(webapp): ASCII boot screen + fluid cross-entry transition"
```

## Risk register

- **Body starting at opacity 0 looks like a broken page** if `boot.js` fails to load. Mitigation: `boot.js` is small and inline-loaded; if missing, the user will at least see content after first interaction (FOUC). Could mitigate further with a `<noscript>` rule or by setting `body { opacity: 1 }` and having JS reverse it before paint — but adds complexity for an unlikely failure.
- **Skip-on-click activating accidentally** during fade-in if the user clicks too fast. Mitigation: the boot click listener uses `{ once: true }` and once boot is dismissed, the listener is gone.
- **Browser caching `boot.js`** preventing the sessionStorage flag from being honored if the script's behavior changes. Standard cache; refresh fixes.
- **Logo ASCII width vs mobile** at narrow viewports. Mitigation: `@media (max-width: 480px)` shrinks font-size; if still too wide, can swap to a 3-line condensed version later.
- **Pre-React paint flash on app.html** if React mounts before `body` opacity completes. Mitigation: body fades in via JS-promoted opacity transition; React mounts on top of an already-fading body, no flash.

## Success criteria

1. First visit to `http://localhost:8080/` with cleared sessionStorage shows boot, then content.
2. Second visit (or after reload) shows content directly with only the body fade-in (~200ms), no boot.
3. Click "Launch App" → smooth fade between entries, no flash.
4. Click "← xb77.io" → smooth fade back.
5. Skipping the boot via click/key cuts it short cleanly.
6. Boot palette adapts: lime on obsidian under dark theme, olive on cream under light.
