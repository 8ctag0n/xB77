(function redirectAppHashes() {
  const h = window.location.hash || "";
  if (h.startsWith("#app") || h === "#network") {
    window.location.replace("/app.html" + h);
  }
})();
const _FILE_HASH = {
  "xB77 v2.html": "#home",
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
    const h = () => {
      const next = window.location.hash || "";
      if (next.startsWith("#app") || next === "#network") {
        window.location.replace("/app.html" + next);
        return;
      }
      setHash(next);
    };
    window.addEventListener("hashchange", h);
    return () => window.removeEventListener("hashchange", h);
  }, []);
  const map = {
    "": "home",
    "#home": "home",
    "#architecture": "architecture",
    "#docs": "docs",
    "#whitepaper": "whitepaper",
    "#why": "why",
    "#changelog": "changelog"
  };
  return map[hash] || "home";
}
function LandingPage() {
  const t = THEMES.obsidian;
  return /* @__PURE__ */ React.createElement("div", { style: { background: t.bg, minHeight: "100vh" } }, /* @__PURE__ */ React.createElement(ObsidianVariant, { theme: "obsidian" }));
}
function PublicApp() {
  const route = useHashRoute();
  React.useEffect(() => {
    document.body.style.overflow = "";
    document.body.style.height = "";
    document.body.style.overflowX = "hidden";
    window.scrollTo(0, 0);
  }, [route]);
  const pages = {
    home: LandingPage,
    architecture: ArchPage,
    docs: DocsPage,
    whitepaper: WhitepaperPage,
    why: WhyPage,
    changelog: ChangelogPage
  };
  const Page = pages[route] || LandingPage;
  const Toggle = window.ThemeToggle;
  return /* @__PURE__ */ React.createElement(React.Fragment, null, /* @__PURE__ */ React.createElement(Page, { key: route }), Toggle ? /* @__PURE__ */ React.createElement(Toggle, null) : null);
}
ReactDOM.createRoot(document.getElementById("root")).render(/* @__PURE__ */ React.createElement(PublicApp, null));
