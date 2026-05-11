/* xB77 Combined — Single-page hash router for standalone export */

/* ── File → hash mapping ── */
const _FILE_HASH = {
  'xB77 v2.html': '#home', 'dApp.html': '#app/agents', 'Explorer.html': '#app/explorer',
  'Architecture.html': '#architecture', 'Docs.html': '#docs',
  'Whitepaper.html': '#whitepaper', 'Why xB77.html': '#why', 'Changelog.html': '#changelog',
};

/* ── Intercept <a href="*.html"> → hash nav ── */
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
    const h = () => setHash(window.location.hash || '');
    window.addEventListener('hashchange', h);
    return () => window.removeEventListener('hashchange', h);
  }, []);
  // `#app/*` collapses into a single `app` route — AppView reads its own sub-hash.
  if (hash.startsWith('#app')) return 'app';
  const map = {
    '': 'home', '#home': 'home',
    '#architecture': 'architecture', '#docs': 'docs', '#whitepaper': 'whitepaper',
    '#why': 'why', '#changelog': 'changelog', '#network': 'network',
  };
  return map[hash] || 'home';
}

/* ═══════════════════════════════════════════════════════════
   LANDING PAGE
   ═══════════════════════════════════════════════════════════ */
function LandingPage() {
  const t = THEMES.obsidian;
  return (
    <div style={{ background: t.bg, minHeight: '100vh' }}>
      <ObsidianVariant theme="obsidian" />
    </div>
  );
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
   COMBINED ROUTER
   ═══════════════════════════════════════════════════════════ */
function CombinedApp() {
  const route = useHashRoute();

  React.useEffect(() => {
    document.body.style.overflow = '';
    document.body.style.height = '';
    document.body.style.overflowX = 'hidden';
    // Only the legacy /app (when first navigating to a tab via hashchange) needs the
    // scroll reset; intra-tab hash flips should not jump.
    if (!window.location.hash.startsWith('#app/')) window.scrollTo(0, 0);
  }, [route]);

  const pages = {
    home: LandingPage, app: AppPage,
    architecture: ArchPage, docs: DocsPage, whitepaper: WhitepaperPage,
    why: WhyPage, changelog: ChangelogPage, network: NetworkPageWrap,
  };
  const Page = pages[route] || LandingPage;
  return <Page key={route} />;
}

ReactDOM.createRoot(document.getElementById('root')).render(<CombinedApp />);
