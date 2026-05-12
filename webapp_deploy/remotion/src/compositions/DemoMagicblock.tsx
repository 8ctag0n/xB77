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
import { TerminalReplay } from "./sections/TerminalReplay";
import { SubtitleBand } from "./sections/SubtitleBand";
import {
  Capture,
  Fade,
  IntroPanel,
  TerminalSection,
  StatusSection,
  SnsSection,
  DepthLayer,
  layoutSchema,
} from "./sections/SharedSections";

const FILES = {
  sns:        "captures/01_sns.json",
  brain_shim: "captures/02_brain_shim.json",
  trident:    "captures/05_trident_smoke.json",
  mic_drop:   "captures/10_mic_drop.json",
};

// MagicBlock-focused layout: trident_smoke is the hero because it contains
// the actual PER lifecycle output (dispatchEphemeral + commitToSolana).
// SNS + brain compressed; status + end card with MagicBlock-specific copy.
const LAYOUT = layoutSchema([
  { key: "intro",       baseLen: 150 },  // 0:00–0:05
  { key: "trident",     baseLen: 900 },  // 0:05–0:35  ← hero PER lifecycle
  { key: "sns",         baseLen: 300 },  // 0:35–0:45  ← compressed
  { key: "brainShim",   baseLen: 300 },  // 0:45–0:55
  { key: "status",      baseLen: 450 },  // 0:55–1:10
  { key: "perSession",  baseLen: 300 },  // 1:10–1:20  ← new MagicBlock-specific card
  { key: "endCard",     baseLen: 300 },  // 1:20–1:30
]);
const SEC = Object.fromEntries(LAYOUT.map((s) => [s.key, s])) as Record<string, { from: number; len: number }>;

export const DemoMagicblock: React.FC = () => {
  const [captures, setCaptures] = React.useState<Record<string, Capture> | null>(null);
  const [handle] = React.useState(() => delayRender("loading captures for MagicBlock"));

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
            tagline="Persistent Ephemeral Rollup"
            subtitle="Sovereign HFT rail via MagicBlock PER"
          />
        </Fade>
      </Sequence>

      {/* HERO: trident_smoke shows PER lifecycle (open → dispatch → commit) */}
      <Sequence from={SEC.trident.from} durationInFrames={SEC.trident.len}>
        <Fade len={SEC.trident.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.trident}
            subtitleTitle="PER Session Lifecycle"
            subtitleSub="openSession → dispatchEphemeral → commitToSolana"
            terminalTitle="zig build trident-smoke — PER live"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      {/* SNS context (identity layer) */}
      <Sequence from={SEC.sns.from} durationInFrames={SEC.sns.len}>
        <Fade len={SEC.sns.len}>
          <DepthLayer />
          <SnsSection
            capture={captures.sns}
            subtitleTitle="Identity Plane"
            subtitleSub="Agent identity resolves before any session opens"
          />
        </Fade>
      </Sequence>

      {/* Brain — the decision to take PER lane */}
      <Sequence from={SEC.brainShim.from} durationInFrames={SEC.brainShim.len}>
        <Fade len={SEC.brainShim.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.brain_shim}
            subtitleTitle="Brain Picks the Rail"
            subtitleSub="force_hft_rail constitutional flag → PER lane"
            terminalTitle="xb77 brain — sovereign decision"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      {/* Status — trident dashboard with HFT rail active */}
      <Sequence from={SEC.status.from} durationInFrames={SEC.status.len}>
        <Fade len={SEC.status.len}>
          <DepthLayer />
          <StatusSection
            capture={captures.mic_drop}
            subtitleTitle="HFT Rail Live"
            subtitleSub="MagicBlock sequencer engaged, L1 anchor ready"
          />
        </Fade>
      </Sequence>

      {/* MagicBlock-specific session card */}
      <Sequence from={SEC.perSession.from} durationInFrames={SEC.perSession.len}>
        <Fade len={SEC.perSession.len}>
          <DepthLayer />
          <PerSessionCard />
        </Fade>
      </Sequence>

      {/* MagicBlock end card */}
      <Sequence from={SEC.endCard.from} durationInFrames={SEC.endCard.len}>
        <Fade len={SEC.endCard.len}>
          <DepthLayer variant="endcard" />
          <ActionClose
            url="xb77-adapter.frontier247hack.workers.dev"
            verb="OPEN PER SESSION"
            tagline="Ephemeral velocity, settled atomically on Solana L1."
          />
        </Fade>
      </Sequence>
    </AbsoluteFill>
  );
};

/**
 * PerSessionCard — animated card showing the MagicBlock session lifecycle.
 * Three pills (OPEN, DISPATCH, COMMIT) light up in sequence, each with a
 * connecting line drawing in. Ends with a ClosePerSession program ID badge.
 */
const PerSessionCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const pillEnter = (offset: number) =>
    spring({
      frame: Math.max(frame - offset, 0),
      fps,
      durationInFrames: 18,
      config: { damping: 14, stiffness: 120 },
    });

  const stages = [
    { label: "OPEN",     sub: "session_id: e9978198a700c38f",                 offset: 8 },
    { label: "DISPATCH", sub: "ephemeral tx → sequencer @ devnet.magicblock", offset: 32 },
    { label: "COMMIT",   sub: "ClosePerSession → xb77_gateway · Solana L1",   offset: 56 },
  ];

  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", padding: "60px 100px" }}>
      <div style={{ fontFamily: FONTS.mono, fontSize: 14, letterSpacing: "0.2em", color: COLORS.textDim, textTransform: "uppercase", marginBottom: 28 }}>
        Persistent Ephemeral Rollup · session walkthrough
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 16, width: "100%", maxWidth: 720 }}>
        {stages.map((s, i) => {
          const enter = pillEnter(s.offset);
          return (
            <div
              key={i}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 24,
                opacity: enter,
                transform: `translateX(${(1 - enter) * -30}px)`,
              }}
            >
              <div
                style={{
                  width: 130,
                  textAlign: "center",
                  padding: "14px 0",
                  border: `2px solid ${COLORS.lime}`,
                  background: "rgba(200,255,46,0.08)",
                  fontFamily: FONTS.mono,
                  fontSize: 18,
                  fontWeight: 900,
                  letterSpacing: "0.18em",
                  color: COLORS.lime,
                  textShadow: `0 0 14px ${COLORS.lime}`,
                  boxShadow: `0 0 0 1px rgba(200,255,46,${0.2 * enter}), 0 12px 28px rgba(0,0,0,0.5)`,
                }}
              >
                {s.label}
              </div>
              <div style={{ flex: 1, fontFamily: FONTS.mono, fontSize: 18, color: COLORS.textHi, letterSpacing: "0.02em" }}>
                {s.sub}
              </div>
            </div>
          );
        })}
      </div>

      <div
        style={{
          marginTop: 36,
          padding: "12px 22px",
          border: `1px solid ${COLORS.cyan}`,
          background: "rgba(0,240,255,0.05)",
          fontFamily: FONTS.mono,
          fontSize: 14,
          color: COLORS.cyan,
          letterSpacing: "0.12em",
          opacity: interpolate(frame, [70, 100], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        xb77_gateway · 83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4
      </div>
    </AbsoluteFill>
  );
};
