const PITCH_SECTIONS = [
  { id: "hero", label: "Intro" },
  { id: "problem", label: "Problem" },
  { id: "solution", label: "Solution" },
  { id: "solana", label: "Why Solana" },
  { id: "tech", label: "Tech" },
  { id: "sponsors", label: "Sponsors" },
  { id: "demo", label: "Demo" },
  { id: "next", label: "What's next" }
];
const PITCH_SOLANA = [
  { k: "MagicBlock PER", v: "sub-millisecond execution rail with mainnet-anchored settlement; agentic commerce needs this throughput, not L2 rollup economics." },
  { k: "SNS (.sol)", v: "agents need a name they can own and a counterparty whitelist they can verify offline; SNS resolves cached." },
  { k: "Solana mainnet", v: "the ZK-Judge contract verifies Noir Plonk proofs as the final source of truth." },
  { k: "Anchor", v: "onchain state anchor for the Constitution and proof commitments." }
];
const PITCH_TECH = [
  { k: "Zig core", path: "build.zig, core/", v: "memory-safe, no-runtime engine: P2P gossip (Agent Wire Protocol), gRPC, local intelligence layer." },
  { k: "QVAC brain", path: "core/intelligence/brain.zig", v: "Llama.cpp-bound RAG that parses directives and enforces a Constitution before any packet leaves the host." },
  { k: "MagicBlock rail", path: "core/chain/magicblock.zig", v: "PER session adapter for sub-second intent settlement." },
  { k: "Noir circuits", path: "circuits/", v: "Plonk proofs for tax-compliance receipts; verifier deployed onchain as a ZK-Judge." },
  { k: "WASM Gateway", path: "gateway/", v: "brutalist dashboard served from the agent itself for in-browser selective-disclosure auditing." },
  { k: "SNS gating", path: "core/security/identity.zig", v: "counterparty whitelisting at the Constitution layer, not the RPC layer." },
  { k: "Tether WDK", path: "core/security/wdk.zig", v: "non-custodial vault for agent keys." }
];
const PITCH_SPONSORS = [
  { track: "MagicBlock \u2014 PER", fit: "core/chain/magicblock.zig drives PER sessions for sub-second settlement." },
  { track: "Helius / RPC", fit: "znode tooling + ZK-Judge state queries hit production Helius RPC." },
  { track: "Noir / ZK", fit: "circuits/ ship Plonk proofs; the on-chain ZK-Judge anchors them today, full SNARK verification on the roadmap." },
  { track: "SNS", fit: "agents own .sol identities; counterparty whitelist resolves via cached SNS." },
  { track: "Light Protocol", fit: "state compression for ZK-Receipt commitments anchored onchain." }
];
const PITCH_NEXT = [
  { k: "Devnet drop", v: "ZK-Judge program deploys the moment the faucet clears." },
  { k: "Mainnet path", v: "post-audit launch of the ZK-Judge; institutional Z-Node onramp for treasury integrations." },
  { k: "Agent Mesh", v: "scale the Agent Wire Protocol (AWP) for multi-agent swarm negotiation." }
];
function PitchProgress({ scrollRef }) {
  const [pct, setPct] = React.useState(0);
  React.useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    function update() {
      const max = el.scrollHeight - el.clientHeight;
      const p = max > 0 ? Math.min(100, Math.max(0, el.scrollTop / max * 100)) : 0;
      setPct(p);
    }
    update();
    el.addEventListener("scroll", update, { passive: true });
    window.addEventListener("resize", update);
    return () => {
      el.removeEventListener("scroll", update);
      window.removeEventListener("resize", update);
    };
  }, [scrollRef]);
  return /* @__PURE__ */ React.createElement("div", { style: {
    position: "fixed",
    top: 0,
    left: 0,
    right: 0,
    height: 2,
    zIndex: 80,
    background: "transparent"
  } }, /* @__PURE__ */ React.createElement("div", { style: {
    height: "100%",
    width: `${pct}%`,
    background: "var(--accent)",
    boxShadow: "0 0 12px var(--accent-glow)",
    transition: "width 0.08s linear"
  } }));
}
function PitchDotNav({ active, onJump }) {
  return /* @__PURE__ */ React.createElement("nav", { "aria-label": "pitch sections", style: {
    position: "fixed",
    right: 28,
    top: "50%",
    transform: "translateY(-50%)",
    zIndex: 50,
    display: "flex",
    flexDirection: "column",
    gap: 14
  } }, PITCH_SECTIONS.map((s) => {
    const isActive = active === s.id;
    return /* @__PURE__ */ React.createElement(
      "button",
      {
        key: s.id,
        type: "button",
        "aria-label": s.label,
        title: s.label,
        onClick: () => onJump(s.id),
        style: {
          width: 8,
          height: 8,
          borderRadius: 0,
          background: isActive ? "var(--accent)" : "var(--border-strong)",
          boxShadow: isActive ? "0 0 10px var(--accent-glow)" : "none",
          border: "none",
          cursor: "pointer",
          padding: 0,
          transform: isActive ? "scale(1.4)" : "scale(1)",
          transition: "transform 0.28s ease, background 0.28s ease, box-shadow 0.28s ease"
        }
      }
    );
  }));
}
function PitchReveal({ delay = 0, children, as = "div", style, scrollRoot }) {
  const ref = React.useRef(null);
  const [shown, setShown] = React.useState(false);
  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (en.isIntersecting) setShown(true);
      });
    }, { threshold: 0.12, root: scrollRoot || null });
    io.observe(el);
    return () => io.disconnect();
  }, [scrollRoot]);
  const Tag = as;
  return /* @__PURE__ */ React.createElement(Tag, { ref, style: {
    opacity: shown ? 1 : 0,
    transform: shown ? "translateY(0)" : "translateY(24px)",
    transition: `opacity 0.7s cubic-bezier(0.2,0.7,0.2,1) ${delay}s, transform 0.7s cubic-bezier(0.2,0.7,0.2,1) ${delay}s`,
    ...style
  } }, children);
}
function PitchSection({ id, num, label, children }) {
  return /* @__PURE__ */ React.createElement("section", { id, style: {
    height: "100vh",
    display: "flex",
    flexDirection: "column",
    justifyContent: "center",
    padding: "80px 28px",
    borderBottom: "1px solid var(--border)",
    position: "relative",
    scrollSnapAlign: "start",
    scrollSnapStop: "always"
  } }, /* @__PURE__ */ React.createElement("div", { style: { maxWidth: 920, margin: "0 auto", width: "100%" } }, (num || label) && /* @__PURE__ */ React.createElement(PitchReveal, null, /* @__PURE__ */ React.createElement("span", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: "var(--text-soft)",
    letterSpacing: "0.14em",
    textTransform: "uppercase",
    display: "inline-block",
    marginBottom: 28
  } }, num && /* @__PURE__ */ React.createElement("span", { style: { color: "var(--accent)" } }, num), num && label && /* @__PURE__ */ React.createElement("span", null, " \xB7 "), label)), children));
}
function PitchH({ delay = 0.1, children }) {
  return /* @__PURE__ */ React.createElement(PitchReveal, { as: "h2", delay, style: {
    fontFamily: "var(--serif)",
    fontStyle: "italic",
    fontSize: "clamp(2rem, 4.5vw, 3.4rem)",
    lineHeight: 1.08,
    margin: "0 0 28px",
    color: "var(--text)",
    letterSpacing: "-0.01em"
  } }, children);
}
function PitchP({ delay = 0.2, children, dim }) {
  return /* @__PURE__ */ React.createElement(PitchReveal, { as: "p", delay, style: {
    fontFamily: "var(--sans, system-ui)",
    fontSize: 16,
    lineHeight: 1.7,
    margin: "0 0 14px",
    color: dim ? "var(--text-dim)" : "var(--text)",
    maxWidth: 720
  } }, children);
}
function PitchRow({ k, path, v, i }) {
  const stripe = i % 2 === 1;
  return /* @__PURE__ */ React.createElement(PitchReveal, { delay: 0.04 + Math.min(i, 6) * 0.05, style: {
    display: "grid",
    gridTemplateColumns: "220px 1fr",
    gap: 24,
    padding: "14px 18px",
    margin: "0 -18px",
    background: stripe ? "var(--bg-3)" : "transparent",
    borderBottom: "1px solid var(--border)"
  } }, /* @__PURE__ */ React.createElement("div", null, /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 13, fontWeight: 600, color: "var(--accent)", letterSpacing: "0.02em" } }, k), path && /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--mono)", fontSize: 10, color: "var(--text-soft)", marginTop: 4 } }, path)), /* @__PURE__ */ React.createElement("div", { style: { fontFamily: "var(--sans, system-ui)", fontSize: 14, lineHeight: 1.55, color: "var(--text-dim)" } }, v));
}
function PitchPage() {
  const Nav = window.InnerNav;
  const [active, setActive] = React.useState("hero");
  const scrollRef = React.useRef(null);
  React.useEffect(() => {
    const root = scrollRef.current;
    if (!root) return;
    const els = PITCH_SECTIONS.map((s) => root.querySelector("#" + s.id)).filter(Boolean);
    if (!els.length) return;
    const io = new IntersectionObserver((entries) => {
      entries.forEach((en) => {
        if (en.isIntersecting && en.intersectionRatio > 0.5) {
          setActive(en.target.id);
        }
      });
    }, { threshold: [0.5, 0.7, 0.9], root });
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);
  function indexOf(id) {
    return PITCH_SECTIONS.findIndex((s) => s.id === id);
  }
  function jumpTo(id) {
    const root = scrollRef.current;
    if (!root) return;
    const el = root.querySelector("#" + id);
    if (!el) return;
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  function jumpDelta(delta) {
    const i = indexOf(active);
    const next = Math.max(0, Math.min(PITCH_SECTIONS.length - 1, i + delta));
    if (next !== i) jumpTo(PITCH_SECTIONS[next].id);
  }
  React.useEffect(() => {
    function onKey(e) {
      const tag = e.target && e.target.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || e.target && e.target.isContentEditable) return;
      switch (e.key) {
        case "ArrowDown":
        case "PageDown":
        case " ":
        case "j":
          e.preventDefault();
          jumpDelta(1);
          break;
        case "ArrowUp":
        case "PageUp":
        case "k":
          e.preventDefault();
          jumpDelta(-1);
          break;
        case "Home":
          e.preventDefault();
          jumpTo(PITCH_SECTIONS[0].id);
          break;
        case "End":
          e.preventDefault();
          jumpTo(PITCH_SECTIONS[PITCH_SECTIONS.length - 1].id);
          break;
        default:
          break;
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active]);
  return /* @__PURE__ */ React.createElement("div", { ref: scrollRef, style: {
    background: "var(--bg)",
    color: "var(--text)",
    height: "100vh",
    overflowY: "auto",
    scrollSnapType: "y mandatory",
    scrollBehavior: "smooth"
  } }, Nav ? /* @__PURE__ */ React.createElement(Nav, { active: "Pitch" }) : null, /* @__PURE__ */ React.createElement(PitchProgress, { scrollRef }), /* @__PURE__ */ React.createElement(PitchDotNav, { active, onJump: jumpTo }), /* @__PURE__ */ React.createElement(PitchSection, { id: "hero" }, /* @__PURE__ */ React.createElement(PitchReveal, null, /* @__PURE__ */ React.createElement("div", { style: {
    fontFamily: "var(--mono)",
    fontSize: 11,
    color: "var(--accent)",
    letterSpacing: "0.18em",
    textTransform: "uppercase",
    marginBottom: 24
  } }, "// xB77 \u2014 Sovereign Financial OS for AI Agents")), /* @__PURE__ */ React.createElement(PitchReveal, { as: "h1", delay: 0.1, style: {
    fontFamily: "var(--serif)",
    fontStyle: "italic",
    fontSize: "clamp(2.6rem, 6.5vw, 4.6rem)",
    lineHeight: 1.02,
    margin: "0 0 28px",
    color: "var(--text)",
    letterSpacing: "-0.015em",
    maxWidth: 1e3
  } }, "Terminal-native infrastructure for the machine economy."), /* @__PURE__ */ React.createElement(PitchReveal, { as: "p", delay: 0.25, style: {
    fontFamily: "var(--sans, system-ui)",
    fontSize: 18,
    lineHeight: 1.55,
    color: "var(--text-dim)",
    maxWidth: 760,
    margin: "0 0 36px"
  } }, "A P2P Financial OS that turns AI agents into ", /* @__PURE__ */ React.createElement("strong", { style: { color: "var(--text)" } }, "sovereign entities"), " ", "\u2014 air-gapped reasoning, MagicBlock settlement, Noir ZK compliance, anchored on Solana."), /* @__PURE__ */ React.createElement(PitchReveal, { delay: 0.4, style: { display: "flex", gap: 14, flexWrap: "wrap" } }, /* @__PURE__ */ React.createElement("a", { href: "/app.html", style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    fontWeight: 600,
    letterSpacing: "0.1em",
    textTransform: "uppercase",
    background: "var(--accent)",
    color: "var(--bg)",
    padding: "12px 22px",
    textDecoration: "none",
    transition: "transform 0.28s ease"
  } }, "Launch App \u2192"), /* @__PURE__ */ React.createElement("a", { href: "/index.html#whitepaper", style: {
    fontFamily: "var(--mono)",
    fontSize: 12,
    fontWeight: 600,
    letterSpacing: "0.1em",
    textTransform: "uppercase",
    color: "var(--text)",
    padding: "12px 22px",
    border: "1px solid var(--border-strong)",
    textDecoration: "none",
    transition: "border-color 0.28s ease, color 0.28s ease"
  } }, "Read Whitepaper"))), /* @__PURE__ */ React.createElement(PitchSection, { id: "problem", num: "01", label: "The problem" }, /* @__PURE__ */ React.createElement(PitchH, null, "Cloud-bound agents are dead agents."), /* @__PURE__ */ React.createElement(PitchP, null, `Every commercial "AI agent" today is one cloud outage away from disappearing. They run on someone else's GPU, talk through someone else's API, and settle through someone else's custodian. Their reasoning is a database row at OpenAI; their balance is a row at Stripe; their identity is a row at AWS.`), /* @__PURE__ */ React.createElement(PitchP, { delay: 0.3, dim: true }, "That stack works for chatbots. It fails the moment you ask the agent to ", /* @__PURE__ */ React.createElement("em", null, "own"), " something: capital, identity, judgment."), /* @__PURE__ */ React.createElement(PitchP, { delay: 0.4, dim: true }, "Sovereignty is not a feature you bolt onto a SaaS agent. It is a substrate.")), /* @__PURE__ */ React.createElement(PitchSection, { id: "solution", num: "02", label: "The solution" }, /* @__PURE__ */ React.createElement(PitchH, null, "A Financial OS that runs on the edge."), /* @__PURE__ */ React.createElement(PitchP, null, "xB77 is a Zig-core operating system that runs on the agent's own machine. The brain reasons locally. The wallet signs locally. The compliance proof is generated locally. Solana is the settlement and audit anchor \u2014 not the runtime."), /* @__PURE__ */ React.createElement(PitchP, { delay: 0.3, dim: true }, "The architecture treats the agent the same way Unix treated processes: a self-contained entity with a clear boundary, a constitution, and a wire protocol to talk to peers."), /* @__PURE__ */ React.createElement(PitchP, { delay: 0.4, dim: true }, "Air-gap first. Network optional. Everything reasoning-related can prove its own correctness offline before a single byte hits the wire.")), /* @__PURE__ */ React.createElement(PitchSection, { id: "solana", num: "03", label: "Why Solana" }, /* @__PURE__ */ React.createElement(PitchH, null, "Impossible without these primitives."), /* @__PURE__ */ React.createElement(PitchP, { dim: true, delay: 0.2 }, "xB77 launched on Solana because four primitives align tightly with sovereign agentic commerce. None of them exists this way anywhere else \u2014 and the chain-agnostic core now extends the same agent to Arc and Sui."), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 28 } }, PITCH_SOLANA.map((r, i) => /* @__PURE__ */ React.createElement(PitchRow, { key: r.k, k: r.k, v: r.v, i })))), /* @__PURE__ */ React.createElement(PitchSection, { id: "tech", num: "04", label: "Technical highlights" }, /* @__PURE__ */ React.createElement(PitchH, null, "Zig core. Local brain. ZK receipts."), /* @__PURE__ */ React.createElement(PitchP, { dim: true, delay: 0.2 }, "Seven anchor modules carry the load. Each is independently auditable and intentionally small. The system is not magic \u2014 it is boring layers stacked correctly."), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 28 } }, PITCH_TECH.map((r, i) => /* @__PURE__ */ React.createElement(PitchRow, { key: r.k, k: r.k, path: r.path, v: r.v, i })))), /* @__PURE__ */ React.createElement(PitchSection, { id: "sponsors", num: "05", label: "Sponsor bounty alignment" }, /* @__PURE__ */ React.createElement(PitchH, null, "One submission. Five tracks."), /* @__PURE__ */ React.createElement(PitchP, { dim: true, delay: 0.2 }, "The same codebase that wins Track A is the codebase that wins Track B. Sponsorship alignment is structural, not stitched in."), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 28 } }, PITCH_SPONSORS.map((r, i) => /* @__PURE__ */ React.createElement(PitchRow, { key: r.track, k: r.track, v: r.fit, i })))), /* @__PURE__ */ React.createElement(PitchSection, { id: "demo", num: "06", label: "The air-gapped demo" }, /* @__PURE__ */ React.createElement(PitchH, null, "Watch the agent reason offline."), /* @__PURE__ */ React.createElement(PitchP, null, "A merchant agent receives a payment intent. The local brain checks the Constitution. The signer routes through the MagicBlock PER rail. A Noir circuit emits a Plonk proof of tax-compliance. The ZK-Judge verifies it onchain. The receipt is auditable from a viewing key the merchant alone holds."), /* @__PURE__ */ React.createElement(PitchP, { delay: 0.3, dim: true }, "End to end: under 90 seconds, no internet required for the reasoning step, no third-party custody."), /* @__PURE__ */ React.createElement(PitchReveal, { delay: 0.45, style: {
    marginTop: 24,
    padding: "18px 22px",
    background: "var(--bg-2)",
    border: "1px solid var(--border)",
    fontFamily: "var(--mono)",
    fontSize: 12,
    lineHeight: 1.7,
    color: "var(--text-dim)",
    maxWidth: 720
  } }, /* @__PURE__ */ React.createElement("div", { style: { color: "var(--accent)" } }, "$ podman compose up -d"), /* @__PURE__ */ React.createElement("div", null, "$ make demo-deluxe"), /* @__PURE__ */ React.createElement("div", { style: { color: "var(--text-soft)", marginTop: 6 } }, "// open http://localhost:8080 to verify the Ghost Receipt with a viewing key"))), /* @__PURE__ */ React.createElement(PitchSection, { id: "next", num: "07", label: "What's next" }, /* @__PURE__ */ React.createElement(PitchH, null, "Devnet \u2192 mainnet \u2192 swarm."), /* @__PURE__ */ React.createElement("div", { style: { marginTop: 28 } }, PITCH_NEXT.map((r, i) => /* @__PURE__ */ React.createElement(PitchRow, { key: r.k, k: r.k, v: r.v, i }))), /* @__PURE__ */ React.createElement(PitchReveal, { delay: 0.5, style: { marginTop: 36 } }, /* @__PURE__ */ React.createElement("div", { style: {
    display: "inline-block",
    padding: "14px 20px",
    border: "1px solid var(--border-strong)",
    fontFamily: "var(--mono)",
    fontSize: 12,
    color: "var(--text)"
  } }, /* @__PURE__ */ React.createElement("span", { style: { color: "var(--accent)" } }, "dzkinha"), /* @__PURE__ */ React.createElement("span", { style: { color: "var(--text-soft)" } }, " \u2014 solo founder. Engineering across Zig, Rust/Anchor, and Noir.")))));
}
Object.assign(window, { PitchPage });
