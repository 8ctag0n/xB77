const _PUBLIC_ONLY_HASHES = /* @__PURE__ */ new Set([
  "#home",
  "#architecture",
  "#docs",
  "#whitepaper",
  "#why",
  "#changelog"
]);
(function redirectPublicHashes() {
  const h = window.location.hash || "";
  if (h === "" || _PUBLIC_ONLY_HASHES.has(h)) {
    window.location.replace("/index.html" + h);
  }
})();
const _FILE_HASH = {
  "dApp.html": "#app/agents",
  "Explorer.html": "#app/explorer"
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
      if (next === "" || _PUBLIC_ONLY_HASHES.has(next)) {
        window.location.replace("/index.html" + next);
        return;
      }
      setHash(next);
    };
    window.addEventListener("hashchange", h);
    return () => window.removeEventListener("hashchange", h);
  }, []);
  if (hash.startsWith("#app")) return "app";
  if (hash === "#network") return "network";
  return "app";
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
function AppShell() {
  const route = useHashRoute();
  React.useEffect(() => {
    document.body.style.overflow = "";
    document.body.style.height = "";
    document.body.style.overflowX = "hidden";
    if (!window.location.hash.startsWith("#app/")) window.scrollTo(0, 0);
  }, [route]);
  const pages = {
    app: AppPage,
    network: NetworkPageWrap
  };
  const Page = pages[route] || AppPage;
  return /* @__PURE__ */ React.createElement(Page, { key: route });
}
ReactDOM.createRoot(document.getElementById("root")).render(/* @__PURE__ */ React.createElement(AppShell, null));
