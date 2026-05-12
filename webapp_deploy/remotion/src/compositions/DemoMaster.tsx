import React from "react";
import {
  AbsoluteFill,
  Sequence,
  delayRender,
  continueRender,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { COLORS, FONTS } from "../theme";
import { Wordmark } from "../components/Wordmark";
import { Seal } from "../components/Seal";
import { TerminalReplay, TerminalLine } from "./sections/TerminalReplay";
import { SideBySide } from "./sections/SideBySide";
import { KillSwitch } from "./sections/KillSwitch";
import { SubtitleBand } from "./sections/SubtitleBand";
import { DepthLayer } from "./sections/DepthLayer";
import { ActionClose } from "./sections/ActionClose";

type Capture = {
  section: string;
  title: string;
  subtitle: string;
  duration_ms: number;
  exit_code: number;
  lines: TerminalLine[];
  extracted?: { signature?: string; address?: string; match?: boolean };
};

const FILES = {
  sns:        "captures/01_sns.json",
  brain_shim: "captures/02_brain_shim.json",
  brain_fb:   "captures/03_brain_fallback.json",
  status:     "captures/04_status.json",
  trident:    "captures/05_trident_smoke.json",
  mic_drop:   "captures/10_mic_drop.json",
};

// Section budget at 30fps (total 2700 frames = 90s).
// Adjacent sections overlap by FADE_OVERLAP frames so the cross-fade lives
// across both, producing a seamless join instead of a hard cut.
const FADE_OVERLAP = 14;

const SECTIONS = {
  intro:     { from: 0,    len: 150 },  // 0:00–0:05  Hero
  sns:       { from: 150 - FADE_OVERLAP, len: 450 + FADE_OVERLAP },  // 0:05–0:20
  brainShim: { from: 600 - FADE_OVERLAP, len: 450 + FADE_OVERLAP },  // 0:20–0:35
  brainFb:   { from: 1050 - FADE_OVERLAP, len: 450 + FADE_OVERLAP }, // 0:35–0:50
  trident:   { from: 1500 - FADE_OVERLAP, len: 600 + FADE_OVERLAP }, // 0:50–1:10
  status:    { from: 2100 - FADE_OVERLAP, len: 300 + FADE_OVERLAP }, // 1:10–1:20
  endCard:   { from: 2400 - FADE_OVERLAP, len: 300 + FADE_OVERLAP }, // 1:20–1:30
} as const;

export const DemoMaster: React.FC = () => {
  const [captures, setCaptures] = React.useState<Record<string, Capture> | null>(null);
  const [handle] = React.useState(() => delayRender("loading captures"));

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

  if (!captures) {
    return <AbsoluteFill style={{ background: COLORS.bg }} />;
  }

  return (
    <AbsoluteFill style={{ background: COLORS.bg }}>
      {/* 0:00–0:05  Intro (hero depth) */}
      <Sequence from={SECTIONS.intro.from} durationInFrames={SECTIONS.intro.len}>
        <Fade len={SECTIONS.intro.len}>
          <DepthLayer variant="hero" />
          <IntroPanel />
        </Fade>
      </Sequence>

      {/* 0:05–0:20  SNS Bonfida side-by-side */}
      <Sequence from={SECTIONS.sns.from} durationInFrames={SECTIONS.sns.len}>
        <Fade len={SECTIONS.sns.len}>
          <DepthLayer />
          <SnsSection capture={captures.sns} />
        </Fade>
      </Sequence>

      {/* 0:20–0:35  Brain via shim */}
      <Sequence from={SECTIONS.brainShim.from} durationInFrames={SECTIONS.brainShim.len}>
        <Fade len={SECTIONS.brainShim.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.brain_shim}
            subtitleTitle="On-Device Brain · Active"
            subtitleSub="QVAC shim returns real reasoning"
            terminalTitle="xb77 brain — shim live"
          />
        </Fade>
      </Sequence>

      {/* 0:35–0:50  Brain fallback */}
      <Sequence from={SECTIONS.brainFb.from} durationInFrames={SECTIONS.brainFb.len}>
        <Fade len={SECTIONS.brainFb.len}>
          <DepthLayer />
          <BrainFallbackSection capture={captures.brain_fb} />
        </Fade>
      </Sequence>

      {/* 0:50–1:10  Trident smoke */}
      <Sequence from={SECTIONS.trident.from} durationInFrames={SECTIONS.trident.len}>
        <Fade len={SECTIONS.trident.len}>
          <DepthLayer />
          <TerminalSection
            capture={captures.trident}
            subtitleTitle="Trident · Cross-Service"
            subtitleSub="SNS · QVAC · MagicBlock in one shot"
            terminalTitle="trident-smoke"
          />
        </Fade>
      </Sequence>

      {/* 1:10–1:20  Status dashboard breath */}
      <Sequence from={SECTIONS.status.from} durationInFrames={SECTIONS.status.len}>
        <Fade len={SECTIONS.status.len}>
          <DepthLayer />
          <StatusSection capture={captures.mic_drop} />
        </Fade>
      </Sequence>

      {/* 1:20–1:30  End card with QR + URL */}
      <Sequence from={SECTIONS.endCard.from} durationInFrames={SECTIONS.endCard.len}>
        <Fade len={SECTIONS.endCard.len}>
          <DepthLayer variant="endcard" />
          <ActionClose
            url="xb77-adapter.frontier247hack.workers.dev"
            verb="VERIFY"
            tagline="Five programs. Three sovereign services. One agent."
          />
        </Fade>
      </Sequence>
    </AbsoluteFill>
  );
};

// ── Helpers ──────────────────────────────────────────────────────────

/**
 * Cross-fade wrapper. Adjacent <Sequence>s are positioned with FADE_OVERLAP
 * frames of overlap; this fades the wrapped content in at the start and out
 * at the end so the seam disappears.
 */
const Fade: React.FC<{ len: number; children: React.ReactNode }> = ({ len, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, FADE_OVERLAP, len - FADE_OVERLAP, len],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

// ── Section components ──────────────────────────────────────────────

const IntroPanel: React.FC = () => {
  const frame = useCurrentFrame();
  const sealCycle = (frame % 90) / 90;
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 26 }}>
        <Seal size={260} progress={1} cycle={sealCycle} />
        <Wordmark size={92} />
        <div
          style={{
            fontFamily: FONTS.sans,
            fontSize: 22,
            letterSpacing: "0.32em",
            textTransform: "uppercase",
            color: COLORS.textDim,
          }}
        >
          Autonomous Financial Infrastructure
        </div>
      </div>
      <SubtitleBand title="Five programs. Three services. Zero mocks." position="lower-third" />
    </AbsoluteFill>
  );
};

const SnsSection: React.FC<{ capture: Capture }> = ({ capture }) => {
  const lines = capture.lines;
  const splitIdx = lines.findIndex((l) => l.text.includes("Natively"));
  const leftLines = splitIdx > 0 ? lines.slice(0, splitIdx) : lines.slice(0, Math.ceil(lines.length / 2));
  const rightLines = splitIdx > 0 ? lines.slice(splitIdx) : lines.slice(Math.ceil(lines.length / 2));
  const address = capture.extracted?.address || "Fw1ETanDZafof7xEULsnq9UY6o71Tpds89tNwPkWLb1v";

  return (
    <AbsoluteFill>
      <SideBySide
        leftTitle="Bonfida API"
        rightTitle="Native Zig"
        leftLines={leftLines}
        rightLines={rightLines}
        highlight={address.slice(0, 16)}
        matchLabel={capture.extracted?.match === false ? "DIVERGE" : "MATCH"}
      />
      <SubtitleBand title="Sovereign Identity" subtitle="Native .sol resolution matches Bonfida mainnet" />
    </AbsoluteFill>
  );
};

const TerminalSection: React.FC<{
  capture: Capture;
  subtitleTitle: string;
  subtitleSub: string;
  terminalTitle: string;
}> = ({ capture, subtitleTitle, subtitleSub, terminalTitle }) => {
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", inset: "70px 100px 170px 100px" }}>
        <TerminalReplay
          lines={capture.lines}
          title={terminalTitle}
          fontSize={20}
          speedMultiplier={Math.max(1, capture.duration_ms / 12000)}
        />
      </div>
      <SubtitleBand title={subtitleTitle} subtitle={subtitleSub} />
    </AbsoluteFill>
  );
};

const BrainFallbackSection: React.FC<{ capture: Capture }> = ({ capture }) => {
  const killLineIdx = capture.lines.findIndex((l) => /Unreachable|ConnectionRefused/.test(l.text));
  const killAtMs = killLineIdx >= 0 ? capture.lines[killLineIdx].t_ms : 200;
  const killAtFrame = Math.max(6, Math.round((killAtMs / 1000) * 30 * Math.max(1, capture.duration_ms / 12000) - 6));

  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", inset: "70px 100px 170px 100px" }}>
        <TerminalReplay
          lines={capture.lines}
          title="xb77 brain — shim killed mid-call"
          fontSize={20}
          speedMultiplier={Math.max(1, capture.duration_ms / 12000)}
        />
      </div>
      <KillSwitch killAt={killAtFrame} label="Shim :8088 · live" />
      <SubtitleBand title="Sovereign Fallback" subtitle="Network gone — agent still reasons" />
    </AbsoluteFill>
  );
};

const StatusSection: React.FC<{ capture: Capture }> = ({ capture }) => {
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", inset: "70px 100px 170px 100px" }}>
        <TerminalReplay
          lines={capture.lines}
          title="xb77 status — sovereign trident"
          fontSize={22}
          speedMultiplier={Math.max(1, capture.duration_ms / 8000)}
        />
      </div>
      <SubtitleBand title="Sovereign & Active" subtitle="SNS . Brain . MagicBlock — all green" />
    </AbsoluteFill>
  );
};
