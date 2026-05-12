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

// Solana-focused: leads with the 5-program flyby, then dives into trident
// + SNS as evidence of integration. The 5 programs ARE the story.
const LAYOUT = layoutSchema([
  { key: "intro",       baseLen: 150 },  // 0:00–0:05
  { key: "fivePrograms",baseLen: 600 },  // 0:05–0:25  ← hero
  { key: "trident",     baseLen: 600 },  // 0:25–0:45  ← cross-program proof
  { key: "sns",         baseLen: 300 },  // 0:45–0:55
  { key: "brainShim",   baseLen: 300 },  // 0:55–1:05
  { key: "status",      baseLen: 450 },  // 1:05–1:20
  { key: "endCard",     baseLen: 300 },  // 1:20–1:30
]);
const SEC = Object.fromEntries(LAYOUT.map((s) => [s.key, s])) as Record<string, { from: number; len: number }>;

export const DemoSolana: React.FC = () => {
  const [captures, setCaptures] = React.useState<Record<string, Capture> | null>(null);
  const [handle] = React.useState(() => delayRender("loading captures for Solana"));

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
      <Sequence from={SEC.intro.from} durationInFrames={SEC.intro.len}>
        <Fade len={SEC.intro.len}>
          <DepthLayer variant="hero" />
          <IntroPanel
            tagline="Five Programs · One Agent"
            subtitle="Sovereign infrastructure built on Solana"
          />
        </Fade>
      </Sequence>

      {/* HERO: the 5 programs as the centerpiece */}
      <Sequence from={SEC.fivePrograms.from} durationInFrames={SEC.fivePrograms.len}>
        <Fade len={SEC.fivePrograms.len}>
          <DepthLayer />
          <FiveProgramsCard />
        </Fade>
      </Sequence>

      {/* Trident — proof of integration across programs */}
      <Sequence from={SEC.trident.from} durationInFrames={SEC.trident.len}>
        <Fade len={SEC.trident.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.trident}
            subtitleTitle="Cross-Program Integration"
            subtitleSub="One Zig binary drives all five programs"
            terminalTitle="trident-smoke — cross-service"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      <Sequence from={SEC.sns.from} durationInFrames={SEC.sns.len}>
        <Fade len={SEC.sns.len}>
          <DepthLayer />
          <SnsSection
            capture={captures.sns}
            subtitleTitle="Native to Solana"
            subtitleSub="SNS resolution in Zig — no SDK roundtrip"
          />
        </Fade>
      </Sequence>

      <Sequence from={SEC.brainShim.from} durationInFrames={SEC.brainShim.len}>
        <Fade len={SEC.brainShim.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.brain_shim}
            subtitleTitle="Agent Reasoning"
            subtitleSub="On-device brain decides which program to call"
            terminalTitle="xb77 brain"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      <Sequence from={SEC.status.from} durationInFrames={SEC.status.len}>
        <Fade len={SEC.status.len}>
          <DepthLayer />
          <StatusSection
            capture={captures.mic_drop}
            subtitleTitle="Five Programs Online"
            subtitleSub="All deployed devnet · all integrated end-to-end"
          />
        </Fade>
      </Sequence>

      <Sequence from={SEC.endCard.from} durationInFrames={SEC.endCard.len}>
        <Fade len={SEC.endCard.len}>
          <DepthLayer variant="endcard" />
          <ActionClose
            url="xb77-adapter.frontier247hack.workers.dev"
            verb="VERIFY ONCHAIN"
            tagline="Five programs. End-to-end. Devnet-live."
          />
        </Fade>
      </Sequence>
    </AbsoluteFill>
  );
};

/**
 * FiveProgramsCard — animated grid of the 5 deployed programs with their
 * Solana addresses. Each card fades+slides in staggered. The grid is the
 * Solana-track hero — visual evidence that this is 5 real programs, not a
 * mockup.
 */
const FiveProgramsCard: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const programs = [
    { name: "xb77_core",         id: "73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3", role: "agent + credit line" },
    { name: "xb77_gateway",      id: "83nPgEhrzKaDSXCoWQCkYau66KUnVeFSQF32LPfyL3s4", role: "SubmitPrivateOrder · verify_badge" },
    { name: "xb77_registry",     id: "HxjcLS4gkccTWD3VeM9Vc4NkQ4rjxtDHR2Lwby6NL6b1", role: "merchant registry + catalog" },
    { name: "xb77_compression",  id: "6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN", role: "Poseidon state anchors" },
    { name: "xb77_zk_verifier",  id: "J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ", role: "chunked proof buffer + verify" },
  ];

  const cardEnter = (offset: number) =>
    spring({
      frame: Math.max(frame - offset, 0),
      fps,
      durationInFrames: 22,
      config: { damping: 14, stiffness: 110 },
    });

  return (
    <AbsoluteFill style={{ padding: "70px 80px 170px 80px" }}>
      <div
        style={{
          fontFamily: FONTS.mono,
          fontSize: 14,
          letterSpacing: "0.22em",
          color: COLORS.textDim,
          textTransform: "uppercase",
          marginBottom: 22,
          textAlign: "center",
          opacity: cardEnter(0),
        }}
      >
        Five Solana programs · Devnet · Verifiable
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {programs.map((p, i) => {
          const e = cardEnter(8 + i * 8);
          return (
            <div
              key={p.name}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 18,
                padding: "12px 18px",
                background: "linear-gradient(90deg, rgba(200,255,46,0.06) 0%, rgba(8,8,10,0.4) 60%)",
                border: `1px solid ${COLORS.rule}`,
                borderLeft: `3px solid ${COLORS.lime}`,
                borderRadius: 6,
                opacity: e,
                transform: `translateX(${(1 - e) * -24}px)`,
                boxShadow: `0 8px 22px rgba(0,0,0,0.4)`,
              }}
            >
              <div
                style={{
                  width: 200,
                  fontFamily: FONTS.mono,
                  fontSize: 18,
                  fontWeight: 900,
                  color: COLORS.lime,
                  letterSpacing: "0.04em",
                  textShadow: `0 0 12px rgba(200,255,46,0.4)`,
                }}
              >
                {p.name}
              </div>
              <div
                style={{
                  flex: 1,
                  fontFamily: FONTS.mono,
                  fontSize: 13,
                  color: COLORS.textHi,
                  letterSpacing: "0.02em",
                  wordBreak: "break-all",
                }}
              >
                {p.id}
              </div>
              <div
                style={{
                  width: 220,
                  fontFamily: FONTS.sans,
                  fontSize: 13,
                  color: COLORS.textDim,
                  textAlign: "right",
                  letterSpacing: "0.02em",
                }}
              >
                {p.role}
              </div>
            </div>
          );
        })}
      </div>

      <div
        style={{
          marginTop: 22,
          textAlign: "center",
          fontFamily: FONTS.mono,
          fontSize: 13,
          color: COLORS.cyan,
          letterSpacing: "0.18em",
          opacity: interpolate(frame, [60, 90], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}
      >
        explorer.solana.com/address/&lt;program-id&gt;?cluster=devnet
      </div>
    </AbsoluteFill>
  );
};
