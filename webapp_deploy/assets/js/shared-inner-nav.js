const INNER_NAV_LINKS = [
  { label: "Home", href: "xB77 v2.html" },
  { label: "Why xB77", href: "Why xB77.html" },
  { label: "Architecture", href: "Architecture.html" },
  { label: "Whitepaper", href: "Whitepaper.html" },
  { label: "Docs", href: "Docs.html" },
  { label: "Explorer", href: "Explorer.html" },
  { label: "Changelog", href: "Changelog.html" }
];
function InnerNav({ active }) {
  const t = THEMES.obsidian;
  return /* @__PURE__ */ React.createElement("nav", { style: {
    position: "sticky",
    top: 0,
    zIndex: 100,
    background: "rgba(8,8,10,0.88)",
    backdropFilter: "blur(20px)",
    borderBottom: `1px solid ${t.border}`,
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "0 40px",
    height: 56
  } }, /* @__PURE__ */ React.createElement("div", { style: { display: "flex", alignItems: "center", gap: 32 } }, /* @__PURE__ */ React.createElement("a", { href: "xB77 v2.html", style: {
    fontFamily: "var(--mono)",
    fontWeight: 700,
    fontSize: 20,
    color: t.accent,
    letterSpacing: "0.08em",
    textDecoration: "none"
  } }, "xB77"), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 24 } }, INNER_NAV_LINKS.filter((l) => l.label !== "Home").map((l) => /* @__PURE__ */ React.createElement(
    "a",
    {
      key: l.label,
      href: l.href,
      style: {
        fontFamily: "var(--mono)",
        fontSize: 11,
        letterSpacing: "0.1em",
        textTransform: "uppercase",
        textDecoration: "none",
        cursor: "pointer",
        color: l.label === active ? t.accent : t.textDim,
        borderBottom: l.label === active ? `1px solid ${t.accent}` : "1px solid transparent",
        paddingBottom: 2,
        transition: "color 0.2s"
      },
      onMouseEnter: (e) => {
        if (l.label !== active) e.target.style.color = t.text;
      },
      onMouseLeave: (e) => {
        if (l.label !== active) e.target.style.color = t.textDim;
      }
    },
    l.label
  )))), /* @__PURE__ */ React.createElement("a", { href: "dApp.html", style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: t.bg,
    background: t.accent,
    border: "none",
    padding: "8px 16px",
    letterSpacing: "0.08em",
    cursor: "pointer",
    fontWeight: 600,
    textTransform: "uppercase",
    textDecoration: "none"
  } }, "Launch dApp"));
}
function PageFooter() {
  const t = THEMES.obsidian;
  return /* @__PURE__ */ React.createElement("footer", { style: {
    background: t.bgSecondary,
    borderTop: `1px solid ${t.border}`,
    padding: "48px 40px"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    maxWidth: 1100,
    margin: "0 auto",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center"
  } }, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontWeight: 700, fontSize: 16, color: t.accent, letterSpacing: "0.05em" } }, "xB77"), /* @__PURE__ */ React.createElement("div", { style: { display: "flex", gap: 24 } }, INNER_NAV_LINKS.map((l) => /* @__PURE__ */ React.createElement(
    "a",
    {
      key: l.label,
      href: l.href,
      style: {
        fontFamily: "var(--mono)",
        fontSize: 10,
        color: t.textDim,
        letterSpacing: "0.1em",
        textTransform: "uppercase",
        textDecoration: "none",
        transition: "color 0.2s"
      },
      onMouseEnter: (e) => e.target.style.color = t.accent,
      onMouseLeave: (e) => e.target.style.color = t.textDim
    },
    l.label
  )))), /* @__PURE__ */ React.createElement("div", { style: {
    maxWidth: 1100,
    margin: "16px auto 0",
    fontFamily: "var(--mono)",
    fontSize: 10,
    color: t.textDim,
    opacity: 0.4,
    letterSpacing: "0.1em"
  } }, "\xA9 2026 xB77 Labs \u2014 Solana Privacy Hackathon"));
}
Object.assign(window, { InnerNav, PageFooter, INNER_NAV_LINKS });
