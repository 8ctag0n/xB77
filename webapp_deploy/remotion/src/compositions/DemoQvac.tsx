import React from "react";
import {
  AbsoluteFill,
  Sequence,
  delayRender,
  continueRender,
  staticFile,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { COLORS, FONTS } from "../theme";
import { ActionClose } from "./sections/ActionClose";
import {
  Capture,
  Fade,
  IntroPanel,
  TerminalSection,
  BrainFallbackSection,
  StatusSection,
  DepthLayer,
  layoutSchema,
} from "./sections/SharedSections";

const FILES = {
  brain_shim: "captures/02_brain_shim.json",
  brain_fb:   "captures/03_brain_fallback.json",
  trident:    "captures/05_trident_smoke.json",
  mic_drop:   "captures/10_mic_drop.json",
};

// QVAC-focused: brain_shim → KillSwitch transition → brain_fallback is the
// hero arc (35s combined). Constitution flag card lands as the "decision"
// punchline.
const LAYOUT = layoutSchema([
  { key: "intro",         baseLen: 150 },  // 0:00–0:05
  { key: "brainShim",     baseLen: 600 },  // 0:05–0:25  ← extended hero
  { key: "brainFb",       baseLen: 600 },  // 0:25–0:45  ← extended hero (KillSwitch lives here)
  { key: "constitution",  baseLen: 300 },  // 0:45–0:55  ← new sovereign-decision card
  { key: "trident",       baseLen: 450 },  // 0:55–1:10
  { key: "status",        baseLen: 300 },  // 1:10–1:20
  { key: "endCard",       baseLen: 300 },  // 1:20–1:30
]);
const SEC = Object.fromEntries(LAYOUT.map((s) => [s.key, s])) as Record<string, { from: number; len: number }>;

export const DemoQvac: React.FC = () => {
  const [captures, setCaptures] = React.useState<Record<string, Capture> | null>(null);
  const [handle] = React.useState(() => delayRender("loading captures for QVAC"));

  React.useEffect(() => {
    (async () => {
      const entries = await Promise.all(
        Object.entries(FILES).map(async ([key, path]) => {
          const res = await fetch(staticFile(path));
          const json: Capture = await res.json();
          return [key, json] as const;
        }),
      );
      setCaptures(Object.fromEntries(entries));
      continueRender(handle);
    })();
  }, [handle]);

  if (!captures) return <AbsoluteFill style={{ background: COLORS.bg }} />;

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      {/* Intro */}
      <Sequence from={SEC.intro.from} durationInFrames={SEC.intro.len}>
        <Fade len={SEC.intro.len}>
          <DepthLayer variant="hero" />
          <IntroPanel
            tagline="On-Device Sovereign Reasoning"
            subtitle="QVAC brain — local first, no cloud roundtrip"
          />
        </Fade>
      </Sequence>

      {/* Brain shim active — long enough to read the full BrainInsight */}
      <Sequence from={SEC.brainShim.from} durationInFrames={SEC.brainShim.len}>
        <Fade len={SEC.brainShim.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.brain_shim}
            subtitleTitle="QVAC Shim Live"
            subtitleSub="Structured insight: intent · risk · mission hash · zk proof tag"
            terminalTitle="xb77 brain — shim active"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      {/* The kill-switch moment — same command, network dies, same quality output */}
      <Sequence from={SEC.brainFb.from} durationInFrames={SEC.brainFb.len}>
        <Fade len={SEC.brainFb.len}>
          <DepthLayer />
          <BrainFallbackSection
            capture={captures.brain_fb}
            subtitleTitle="Network Killed, Reasoning Continues"
            subtitleSub="Heuristic engine in pure Zig — zero-network path"
          />
        </Fade>
      </Sequence>

      {/* Constitution flag card — the architectural punchline */}
      <Sequence from={SEC.constitution.from} durationInFrames={SEC.constitution.len}>
        <Fade len={SEC.constitution.len}>
          <DepthLayer />
          <ConstitutionCard />
        </Fade>
      </Sequence>

      {/* Trident context */}
      <Sequence from={SEC.trident.from} durationInFrames={SEC.trident.len}>
        <Fade len={SEC.trident.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.trident}
            subtitleTitle="Brain in the Trident"
            subtitleSub="Reasoning routes payments to the right rail — locally"
            terminalTitle="trident-smoke — brain decisions"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      {/* Status breath */}
      <Sequence from={SEC.status.from} durationInFrames={SEC.status.len}>
        <Fade len={SEC.status.len}>
          <DepthLayer />
          <StatusSection
            capture={captures.mic_drop}
            subtitleTitle="Sovereign Brain Active"
            subtitleSub="Inference path: 100% on-device"
          />
        </Fade>
      </Sequence>

      {/* QVAC end card */}
      <Sequence from={SEC.endCard.from} durationInFrames={SEC.endCard.len}>
        <Fade len={SEC.endCard.len}>
          <DepthLayer variant="endcard" />
          <ActionClose
            url="xb77-adapter.frontier247hack.workers.dev"
            verb="REASON SOVEREIGN"
            tagline="Gemma-ready architecture. No model, no problem — heuristic fallback always on."
          />
        </Fade>
      </Sequence>
    </AbsoluteFill>
  );
};

/**
 * ConstitutionCard — shows the force_hft_rail constitutional flag as a
 * styled code snippet. Sells the architectural insight: reasoning isn't
 * a chat loop, it's a constitutional decision gating routing.
 */
const ConstitutionCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const cardEnter = spring({ frame, fps, durationInFrames: 22, config: { damping: 14 } });
  const linesIn = (n: number) =>
    interpolate(frame, [12 + n * 6, 24 + n * 6], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  const codeLines = [
    { text: "// core/security/constitution.zig",       color: COLORS.textDim },
    { text: "pub const Constitution = struct {",        color: COLORS.textHi },
    { text: "    force_hft_rail: bool = false,",        color: COLORS.lime, bold: true },
    { text: "    privacy_floor: u8 = 80,",              color: COLORS.textHi },
    { text: "    max_autonomous_lamports: u64 = 5e9,",  color: COLORS.textHi },
    { text: "};",                                        color: COLORS.textHi },
    { text: "",                                          color: COLORS.textHi },
    { text: "// brain.zig consults this BEFORE every payment.",  color: COLORS.textDim },
    { text: "// Reasoning is constitutional, not conversational.", color: COLORS.cyan },
  ];

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", padding: "60px 100px" }}>
      <div
        style={{
          fontFamily: FONTS.mono,
          fontSize: 13,
          letterSpacing: "0.2em",
          color: COLORS.textDim,
          textTransform: "uppercase",
          marginBottom: 24,
          opacity: cardEnter,
        }}
      >
        Sovereign decision · constitutional flag
      </div>

      <div
        style={{
          width: "100%",
          maxWidth: 720,
          background: "linear-gradient(180deg, #0c0c0f 0%, #08080a 100%)",
          border: `1px solid ${COLORS.rule}`,
          borderRadius: 10,
          padding: "24px 28px",
          fontFamily: FONTS.mono,
          fontSize: 20,
          lineHeight: 1.5,
          boxShadow: `0 0 0 1px rgba(200,255,46,0.12), 0 40px 80px rgba(0,0,0,0.55)`,
          opacity: cardEnter,
          transform: `translateY(${(1 - cardEnter) * 12}px)`,
        }}
      >
        {codeLines.map((ln, i) => (
          <div
            key={i}
            style={{
              color: ln.color,
              fontWeight: ln.bold ? 900 : 400,
              opacity: linesIn(i),
              textShadow: ln.bold ? `0 0 14px rgba(200,255,46,0.4)` : "none",
            }}
          >
            {ln.text || " "}
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};
