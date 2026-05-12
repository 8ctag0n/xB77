import React from "react";
import {
  AbsoluteFill,
  Audio,
  Sequence,
  Series,
  delayRender,
  continueRender,
  staticFile,
  useVideoConfig,
} from "remotion";
import { COLORS, FONTS } from "../theme";
import { Wordmark } from "../components/Wordmark";
import { Seal } from "../components/Seal";
import { TerminalReplay, TerminalLine } from "./sections/TerminalReplay";
import { SideBySide } from "./sections/SideBySide";
import { KillSwitch } from "./sections/KillSwitch";
import { SubtitleBand } from "./sections/SubtitleBand";

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
  sns:           "captures/01_sns.json",
  brain_shim:    "captures/02_brain_shim.json",
  brain_fb:      "captures/03_brain_fallback.json",
  status:        "captures/04_status.json",
  trident:       "captures/05_trident_smoke.json",
  mic_drop:      "captures/10_mic_drop.json",
};

// Section budget at 30fps (total 2700 frames = 90s)
const SECTIONS = {
  intro:     { from: 0,    len: 150 }, // 5s
  sns:       { from: 150,  len: 450 }, // 15s
  brainShim: { from: 600,  len: 450 }, // 15s
  brainFb:   { from: 1050, len: 450 }, // 15s, KillSwitch fires at 1200
  trident:   { from: 1500, len: 600 }, // 20s
  micDrop:   { from: 2100, len: 600 }, // 20s
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
      {/* Background drone audio (optional — drop a file at public/audio/drone.mp3 to enable) */}
      {/* <Audio src={staticFile("audio/drone.mp3")} volume={0.18} /> */}

      {/* 0:00–0:05  Intro */}
      <Sequence from={SECTIONS.intro.from} durationInFrames={SECTIONS.intro.len}>
        <IntroPanel />
      </Sequence>

      {/* 0:05–0:20  SNS Bonfida side-by-side */}
      <Sequence from={SECTIONS.sns.from} durationInFrames={SECTIONS.sns.len}>
        <SnsSection capture={captures.sns} />
      </Sequence>

      {/* 0:20–0:35  Brain via shim (active reasoning) */}
      <Sequence from={SECTIONS.brainShim.from} durationInFrames={SECTIONS.brainShim.len}>
        <TerminalSection
          capture={captures.brain_shim}
          subtitleTitle="On-Device Brain · Active"
          subtitleSub="QVAC shim returns real reasoning"
          terminalTitle="xb77 brain — shim live"
        />
      </Sequence>

      {/* 0:35–0:50  Brain fallback with KillSwitch overlay */}
      <Sequence from={SECTIONS.brainFb.from} durationInFrames={SECTIONS.brainFb.len}>
        <BrainFallbackSection capture={captures.brain_fb} />
      </Sequence>

      {/* 0:50–1:10  Trident cross-service smoke */}
      <Sequence from={SECTIONS.trident.from} durationInFrames={SECTIONS.trident.len}>
        <TerminalSection
          capture={captures.trident}
          subtitleTitle="Trident · Cross-Service"
          subtitleSub="SNS · QVAC · MagicBlock in one shot"
          terminalTitle="trident-smoke"
        />
      </Sequence>

      {/* 1:10–1:30  Mic drop status */}
      <Sequence from={SECTIONS.micDrop.from} durationInFrames={SECTIONS.micDrop.len}>
        <MicDropSection capture={captures.mic_drop} />
      </Sequence>
    </AbsoluteFill>
  );
};

// ── Section components ────────────────────────────────────────────────

const IntroPanel: React.FC = () => {
  return (
    <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", background: COLORS.bg }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 28 }}>
        <Seal size={260} progress={1} cycle={0.72} />
        <Wordmark size={92} />
        <div
          style={{
            fontFamily: FONTS.mono,
            fontSize: 18,
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
  // Split the captured terminal into the two halves the binary prints:
  // API resolution lines on the left, native PDA derivation lines on the right.
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
      <div style={{ position: "absolute", inset: "60px 80px 160px 80px" }}>
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
  // Compute when in this section the "Shim Unreachable" line lands — fire the
  // KillSwitch just before, so the icon dies in the same beat the terminal
  // prints the message.
  const killLineIdx = capture.lines.findIndex((l) => /Unreachable|ConnectionRefused/.test(l.text));
  const killAtMs = killLineIdx >= 0 ? capture.lines[killLineIdx].t_ms : 200;
  const killAtFrame = Math.max(6, Math.round((killAtMs / 1000) * 30 * Math.max(1, capture.duration_ms / 12000) - 6));

  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", inset: "60px 80px 160px 80px" }}>
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

const MicDropSection: React.FC<{ capture: Capture }> = ({ capture }) => {
  const { fps } = useVideoConfig();
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", inset: "60px 80px 220px 80px" }}>
        <TerminalReplay
          lines={capture.lines}
          title="xb77 status — sovereign trident"
          fontSize={22}
          speedMultiplier={Math.max(1, capture.duration_ms / 15000)}
        />
      </div>
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          bottom: 60,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 10,
        }}
      >
        <Wordmark size={48} />
        <div
          style={{
            fontFamily: FONTS.mono,
            fontSize: 16,
            letterSpacing: "0.32em",
            textTransform: "uppercase",
            color: COLORS.lime,
          }}
        >
          xB77 · Sovereign & Active
        </div>
      </div>
    </AbsoluteFill>
  );
};
