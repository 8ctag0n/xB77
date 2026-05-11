function useFadeIn(threshold = 0.15) {
  const ref = React.useRef(null);
  const [visible, setVisible] = React.useState(false);
  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const obs = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setVisible(true);
        obs.unobserve(el);
      }
    }, { threshold });
    obs.observe(el);
    return () => obs.disconnect();
  }, []);
  return [ref, visible];
}
function FadeIn({ children, delay = 0, direction = "up", style = {}, ...props }) {
  const [ref, visible] = useFadeIn(0.1);
  const dirs = { up: [0, 24], down: [0, -24], left: [24, 0], right: [-24, 0], none: [0, 0] };
  const [dx, dy] = dirs[direction] || dirs.up;
  return /* @__PURE__ */ React.createElement("div", { ref, style: {
    ...style,
    opacity: visible ? 1 : 0,
    transform: visible ? "translate(0, 0)" : `translate(${dx}px, ${dy}px)`,
    transition: `opacity 0.7s ease ${delay}s, transform 0.7s ease ${delay}s`
  }, ...props }, children);
}
function Stagger({ children, baseDelay = 0, step = 0.1, direction = "up", style = {} }) {
  return /* @__PURE__ */ React.createElement("div", { style }, React.Children.map(children, (child, i) => /* @__PURE__ */ React.createElement(FadeIn, { delay: baseDelay + i * step, direction }, child)));
}
function useBreakpoint() {
  const [w, setW] = React.useState(window.innerWidth);
  React.useEffect(() => {
    const h = () => setW(window.innerWidth);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);
  return { mobile: w < 768, tablet: w >= 768 && w < 1024, desktop: w >= 1024, w };
}
function AnimatedCounter({ target, duration = 2e3, prefix = "", suffix = "" }) {
  const [ref, visible] = useFadeIn(0.1);
  const [val, setVal] = React.useState(0);
  React.useEffect(() => {
    if (!visible) return;
    const start = Date.now();
    const tick = () => {
      const elapsed = Date.now() - start;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setVal(Math.round(target * eased));
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }, [visible, target, duration]);
  return /* @__PURE__ */ React.createElement("span", { ref }, prefix, val.toLocaleString(), suffix);
}
function SyntaxHighlight({ code, theme }) {
  const t = THEMES[theme || "obsidian"];
  const keywords = /\b(const|let|var|function|async|await|import|from|export|return|if|else|new|typeof|use|pub|fn|let|mut|println|struct)\b/g;
  const strings = /(["'`])(?:(?!\1)[^\\]|\\.)*?\1/g;
  const comments = /(\/\/.*$|\/\*[\s\S]*?\*\/|#.*$)/gm;
  const numbers = /\b(\d+\.?\d*)\b/g;
  const types = /\b(Client|Network|NeuralKey|IntentBuilder|Currency|Privacy|Urgency|Pipeline|XB77Client)\b/g;
  const specials = /(\$|→|✓|✗)/g;
  const codeStr = typeof code === "string" ? code : String(code);
  const lines = codeStr.split("\n");
  return /* @__PURE__ */ React.createElement("pre", { style: {
    background: t.terminalBg,
    border: `1px solid ${t.border}`,
    padding: "20px 24px",
    margin: "16px 0 24px",
    overflowX: "auto",
    fontFamily: "var(--mono)",
    fontSize: 12.5,
    lineHeight: 1.8,
    color: t.textDim
  } }, lines.map((line, i) => {
    let html = line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(comments, `<span style="color:${t.textDim};opacity:0.5">$&</span>`).replace(strings, `<span style="color:#a8d8a0">$&</span>`).replace(keywords, `<span style="color:${t.accent}">$&</span>`).replace(types, `<span style="color:#8888ff">$&</span>`).replace(numbers, `<span style="color:#ffaa44">$&</span>`).replace(specials, `<span style="color:${t.accent}">$&</span>`);
    return /* @__PURE__ */ React.createElement("div", { key: i, dangerouslySetInnerHTML: { __html: html } });
  }));
}
Object.assign(window, { useFadeIn, FadeIn, Stagger, useBreakpoint, AnimatedCounter, SyntaxHighlight });
