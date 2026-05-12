import React from "react";
import {
  AbsoluteFill,
  Sequence,
  delayRender,
  continueRender,
  staticFile,
} from "remotion";
import { COLORS } from "../theme";
import { ActionClose } from "./sections/ActionClose";
import {
  Capture,
  Fade,
  IntroPanel,
  SnsSection,
  TerminalSection,
  BrainFallbackSection,
  StatusSection,
  DepthLayer,
  layoutSchema,
} from "./sections/SharedSections";

const FILES = {
  sns:        "captures/01_sns.json",
  brain_shim: "captures/02_brain_shim.json",
  brain_fb:   "captures/03_brain_fallback.json",
  trident:    "captures/05_trident_smoke.json",
  mic_drop:   "captures/10_mic_drop.json",
};

// Bonfida-focused layout: SNS section gets the biggest slice (30s) because
// it's where the wow lives — native Zig PDA derivation matching Bonfida
// mainnet. Brain + fallback compressed to 10s each. End card swaps to
// "RESOLVE .SOL" verb with the native pubkey.
const LAYOUT = layoutSchema([
  { key: "intro",     baseLen: 150 },  // 0:00–0:05
  { key: "sns",       baseLen: 900 },  // 0:05–0:35   ← extended (was 450)
  { key: "brainShim", baseLen: 300 },  // 0:35–0:45   ← compressed (was 450)
  { key: "brainFb",   baseLen: 300 },  // 0:45–0:55
  { key: "trident",   baseLen: 450 },  // 0:55–1:10   ← compressed (was 600)
  { key: "status",    baseLen: 300 },  // 1:10–1:20
  { key: "endCard",   baseLen: 300 },  // 1:20–1:30
]);
const SEC = Object.fromEntries(LAYOUT.map((s) => [s.key, s])) as Record<string, { from: number; len: number }>;

export const DemoBonfida: React.FC = () => {
  const [captures, setCaptures] = React.useState<Record<string, Capture> | null>(null);
  const [handle] = React.useState(() => delayRender("loading captures for Bonfida"));

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
          <IntroPanel tagline="Sovereign .sol resolution" subtitle="Native Zig matches Bonfida mainnet" />
        </Fade>
      </Sequence>

      {/* SNS — the hero section, 30 seconds of side-by-side proof */}
      <Sequence from={SEC.sns.from} durationInFrames={SEC.sns.len}>
        <Fade len={SEC.sns.len}>
          <DepthLayer />
          <SnsSection
            capture={captures.sns}
            subtitleTitle="Same Address, Different Sovereignty"
            subtitleSub="Bonfida API ↔ Native Zig PDA derivation — byte-for-byte match"
          />
        </Fade>
      </Sequence>

      {/* Brain shim — brief, context */}
      <Sequence from={SEC.brainShim.from} durationInFrames={SEC.brainShim.len}>
        <Fade len={SEC.brainShim.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.brain_shim}
            subtitleTitle="On-Device Brain"
            subtitleSub="Reasoning runs sovereign — identity is just the start"
            terminalTitle="xb77 brain"
            fontSize={18}
          />
        </Fade>
      </Sequence>

      {/* Brain fallback — keep the resilience story */}
      <Sequence from={SEC.brainFb.from} durationInFrames={SEC.brainFb.len}>
        <Fade len={SEC.brainFb.len}>
          <DepthLayer />
          <BrainFallbackSection
            capture={captures.brain_fb}
            subtitleTitle="Network Gone — Identity Holds"
            subtitleSub="SNS resolution is on-device, no roundtrip needed"
          />
        </Fade>
      </Sequence>

      {/* Trident */}
      <Sequence from={SEC.trident.from} durationInFrames={SEC.trident.len}>
        <Fade len={SEC.trident.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.trident}
            subtitleTitle="Trident Integration"
            subtitleSub="Identity + Brain + Settlement, one Zig binary"
            terminalTitle="trident-smoke"
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
            subtitleTitle="Sovereign Identity Active"
            subtitleSub="No external API in the resolve path"
          />
        </Fade>
      </Sequence>

      {/* Bonfida-specific end card */}
      <Sequence from={SEC.endCard.from} durationInFrames={SEC.endCard.len}>
        <Fade len={SEC.endCard.len}>
          <DepthLayer variant="endcard" />
          <ActionClose
            url="xb77-adapter.frontier247hack.workers.dev"
            verb="RESOLVE .SOL"
            tagline="Native PDA derivation in Zig — 100% sovereign, zero API dependency."
          />
        </Fade>
      </Sequence>
    </AbsoluteFill>
  );
};
