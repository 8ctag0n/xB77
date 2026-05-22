/* xB77 theme toggle — floating bottom-right, swaps html[data-theme]. */

function ThemeToggle() {
  const [theme, setTheme] = React.useState(
    document.documentElement.dataset.theme || 'dark'
  );

  React.useEffect(() => {
    const onChange = (e) => setTheme(e.detail);
    window.addEventListener('xb77:themechange', onChange);
    return () => window.removeEventListener('xb77:themechange', onChange);
  }, []);

  const next = theme === 'dark' ? 'light' : 'dark';
  const label = next === 'light' ? 'Switch to light' : 'Switch to dark';

  return (
    <button
      type="button"
      onClick={() => window.__xb77Theme && window.__xb77Theme.set(next)}
      aria-label={label}
      title={label}
      style={{
        position: 'fixed', bottom: 20, right: 20, zIndex: 9000,
        width: 36, height: 36, borderRadius: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: 'var(--bg-elevated)',
        border: '1px solid var(--border-strong)',
        backdropFilter: 'blur(12px)',
        color: 'var(--text)',
        cursor: 'pointer',
        transition: 'color 0.15s, border-color 0.15s, background 0.15s',
      }}
    >
      {theme === 'dark' ? (
        /* Sun — shown in dark; click → light */
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M4.93 19.07l1.41-1.41 M17.66 6.34l1.41-1.41" />
        </svg>
      ) : (
        /* Moon — shown in light; click → dark */
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
        </svg>
      )}
    </button>
  );
}

window.ThemeToggle = ThemeToggle;
