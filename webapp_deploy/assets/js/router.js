const _FILE_HASH = {
  "xB77 v2.html": "#home",
  "dApp.html": "#app/agents",
  "Explorer.html": "#app/explorer",
  "Architecture.html": "#architecture",
  "Docs.html": "#docs",
  "Whitepaper.html": "#whitepaper",
  "Why xB77.html": "#why",
  "Changelog.html": "#changelog"
};
document.addEventListener("click", (e) => {
  const a = e.target.closest("a[href]");
  if (!a) return;
  const href = a.getAttribute("href");
  if (href && _FILE_HASH[href]) {
    e.preventDefault();
    window.location.hash = _FILE_HASH[href];
    window.scrollTo(0, 0);
  }
});
function DemoTour() {
  return null;
}
window.DemoTour = DemoTour;
function useHashRoute() {
  const [hash, setHash] = React.useState(window.location.hash || "");
  React.useEffect(() => {
    const h = () => setHash(window.location.hash || "");
    window.addEventListener("hashchange", h);
    return () => window.removeEventListener("hashchange", h);
  }, []);
  if (hash.startsWith("#app")) return "app";
  const map = {
    "": "home",
    "#home": "home",
    "#architecture": "architecture",
    "#docs": "docs",
    "#whitepaper": "whitepaper",
    "#why": "why",
    "#changelog": "changelog",
    "#network": "network"
  };
  return map[hash] || "home";
}
function LandingPage() {
  const t = THEMES.obsidian;
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh" } }, /* @__PURE__ */ React.createElement(ObsidianVariant, { theme: "obsidian" }));
}
function AppPage() {
  const View = window._AppView;
  if (!View) {
    return /* @__PURE__ */ React.createElement("div", { style: { padding: 80, fontFamily: "var(--mono)", color: "#9a9aaa" } }, "// app shell missing (app-tabs.js not loaded)");
  }
  return /* @__PURE__ */ React.createElement(View, null);
}
function NetworkPageWrap() {
  const V = window.NetworkPage;
  if (!V) {
    return /* @__PURE__ */ React.createElement("div", { style: { padding: 80, fontFamily: "var(--mono)", color: "#9a9aaa" } }, "// network shell missing (page-network.js not loaded)");
  }
  return /* @__PURE__ */ React.createElement(V, null);
}
function CombinedApp() {
  const route = useHashRoute();
  React.useEffect(() => {
    document.body.style.overflow = "";
    document.body.style.height = "";
    document.body.style.overflowX = "hidden";
    if (!window.location.hash.startsWith("#app/")) window.scrollTo(0, 0);
  }, [route]);
  const pages = {
    home: LandingPage,
    app: AppPage,
    architecture: ArchPage,
    docs: DocsPage,
    whitepaper: WhitepaperPage,
    why: WhyPage,
    changelog: ChangelogPage,
    network: NetworkPageWrap
  };
  const Page = pages[route] || LandingPage;
  return /* @__PURE__ */ React.createElement(Page, { key: route });
}
ReactDOM.createRoot(document.getElementById("root")).render(/* @__PURE__ */ React.createElement(CombinedApp, null));
