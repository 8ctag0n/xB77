/* xB77 theme controller — runs synchronously in <head> before paint.
   Sets html[data-theme] from localStorage or prefers-color-scheme.
   Exposes window.__xb77Theme for the toggle widget. */

(function initTheme() {
  const KEY = 'xb77_theme';
  const root = document.documentElement;
  const mql = window.matchMedia('(prefers-color-scheme: light)');

  function pick() {
    const saved = localStorage.getItem(KEY);
    if (saved === 'light' || saved === 'dark') return saved;
    return mql.matches ? 'light' : 'dark';
  }

  root.dataset.theme = pick();

  window.__xb77Theme = {
    get current() { return root.dataset.theme; },
    set(t) {
      if (t !== 'light' && t !== 'dark') return;
      root.dataset.theme = t;
      localStorage.setItem(KEY, t);
      window.dispatchEvent(new CustomEvent('xb77:themechange', { detail: t }));
    },
    clear() {
      localStorage.removeItem(KEY);
      root.dataset.theme = pick();
      window.dispatchEvent(new CustomEvent('xb77:themechange', { detail: root.dataset.theme }));
    },
  };

  // Follow OS only when the user hasn't pinned a choice.
  mql.addEventListener('change', () => {
    if (!localStorage.getItem(KEY)) {
      root.dataset.theme = mql.matches ? 'light' : 'dark';
      window.dispatchEvent(new CustomEvent('xb77:themechange', { detail: root.dataset.theme }));
    }
  });
})();
