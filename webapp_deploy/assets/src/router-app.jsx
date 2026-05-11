/* xB77 App — Hash router for the application (app.html). */

const _PUBLIC_ONLY_HASHES = new Set([
  '#home', '#architecture', '#docs', '#whitepaper', '#why', '#changelog',
]);

/* ── Cross-entry redirect: public-only hashes belong to /index.html.
 *    Empty hash stays on app and falls through to the default tab. ── */
(function redirectPublicHashes() {
  const h = window.location.hash || '';
  if (_PUBLIC_ONLY_HASHES.has(h)) {
    window.location.replace('/index.html' + h);
  }
})();

/* ── File → hash mapping (app pages only) ── */
const _FILE_HASH = {
  'dApp.html': '#app/agents', 'Explorer.html': '#app/explorer',
};

/* ── Intercept <a href="*.html"> → hash nav for app pages only ── */
document.addEventListener('click', (e) => {
  const a = e.target.closest('a[href]');
  if (!a) return;
  const href = a.getAttribute('href');
  if (href && _FILE_HASH[href]) {
    e.preventDefault();
    window.location.hash = _FILE_HASH[href];
    window.scrollTo(0, 0);
  }
});

/* ── Stub DemoTour (cross-page tour disabled in standalone) ── */
function DemoTour() { return null; }
window.DemoTour = DemoTour;

/* ── Hash router hook ── */
function useHashRoute() {
  const [hash, setHash] = React.useState(window.location.hash || '');
  React.useEffect(() => {
    const h = () => {
      const next = window.location.hash || '';
      if (_PUBLIC_ONLY_HASHES.has(next)) {
        window.location.replace('/index.html' + next);
        return;
      }
      setHash(next);
    };
    window.addEventListener('hashchange', h);
    return () => window.removeEventListener('hashchange', h);
  }, []);
  if (hash.startsWith('#app')) return 'app';
  if (hash === '#network') return 'network';
  return 'app';
}

/* ═══════════════════════════════════════════════════════════
   APP PAGE — fused /dapp + /explorer (tabs live in app-tabs.jsx)
   ═══════════════════════════════════════════════════════════ */
function AppPage() {
  const View = window._AppView;
  if (!View) {
    return <div style={{padding:80, fontFamily:'var(--mono)', color:'#9a9aaa'}}>// app shell missing (app-tabs.js not loaded)</div>;
  }
  return <View />;
}

function NetworkPageWrap() {
  const V = window.NetworkPage;
  if (!V) {
    return <div style={{padding:80, fontFamily:'var(--mono)', color:'#9a9aaa'}}>// network shell missing (page-network.js not loaded)</div>;
  }
  return <V />;
}

/* ═══════════════════════════════════════════════════════════
   APP ROUTER
   ═══════════════════════════════════════════════════════════ */
function AppShell() {
  const route = useHashRoute();

  React.useEffect(() => {
    document.body.style.overflow = '';
    document.body.style.height = '';
    document.body.style.overflowX = 'hidden';
    // Intra-tab hash flips inside #app/* should not jump.
    if (!window.location.hash.startsWith('#app/')) window.scrollTo(0, 0);
  }, [route]);

  const pages = {
    app: AppPage,
    network: NetworkPageWrap,
  };
  const Page = pages[route] || AppPage;
  const Toggle = window.ThemeToggle;
  return (
    <React.Fragment>
      <Page key={route} />
      {Toggle ? <Toggle /> : null}
    </React.Fragment>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<AppShell />);
