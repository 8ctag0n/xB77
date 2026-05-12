import React from "react";
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame } from "remotion";
import { COLORS, FONTS } from "../../theme";
import { Wordmark } from "../../components/Wordmark";
import { Seal } from "../../components/Seal";
import { TerminalReplay, TerminalLine } from "./TerminalReplay";
import { SideBySide } from "./SideBySide";
import { KillSwitch } from "./KillSwitch";
import { SubtitleBand } from "./SubtitleBand";
import { DepthLayer } from "./DepthLayer";

export type Capture = {
  section: string;
  title: string;
  subtitle: string;
  duration_ms: number;
  exit_code: number;
  lines: TerminalLine[];
  extracted?: { signature?: string; address?: string; match?: boolean };
};

export const FADE_OVERLAP = 14;

/**
 * Cross-fade wrapper. Adjacent <Sequence>s are positioned with FADE_OVERLAP
 * frames of overlap; this fades the wrapped content in at the start and out
 * at the end so the seam disappears.
 */
export const Fade: React.FC<{ len: number; children: React.ReactNode }> = ({ len, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, FADE_OVERLAP, len - FADE_OVERLAP, len],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  return <AbsoluteFill style={{ opacity }}>{children}</AbsoluteFill>;
};

export const IntroPanel: React.FC<{ tagline?: string; subtitle?: string }> = ({
  tagline = "Autonomous Financial Infrastructure",
  subtitle = "Five programs. Three services. Zero mocks.",
}) => {
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
          {tagline}
        </div>
      </div>
      <SubtitleBand title={subtitle} position="lower-third" />
    </AbsoluteFill>
  );
};

export const SnsSection: React.FC<{
  capture: Capture;
  subtitleTitle?: string;
  subtitleSub?: string;
}> = ({
  capture,
  subtitleTitle = "Sovereign Identity",
  subtitleSub = "Native .sol resolution matches Bonfida mainnet",
}) => {
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
      <SubtitleBand title={subtitleTitle} subtitle={subtitleSub} />
    </AbsoluteFill>
  );
};

export const TerminalSection: React.FC<{
  capture: Capture;
  subtitleTitle: string;
  subtitleSub: string;
  terminalTitle: string;
  fontSize?: number;
  inset?: string;
}> = ({ capture, subtitleTitle, subtitleSub, terminalTitle, fontSize = 20, inset = "70px 100px 170px 100px" }) => {
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", inset }}>
        <TerminalReplay
          lines={capture.lines}
          title={terminalTitle}
          fontSize={fontSize}
          speedMultiplier={Math.max(1, capture.duration_ms / 12000)}
        />
      </div>
      <SubtitleBand title={subtitleTitle} subtitle={subtitleSub} />
    </AbsoluteFill>
  );
};

export const BrainFallbackSection: React.FC<{
  capture: Capture;
  subtitleTitle?: string;
  subtitleSub?: string;
}> = ({
  capture,
  subtitleTitle = "Sovereign Fallback",
  subtitleSub = "Network gone — agent still reasons",
}) => {
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
      <SubtitleBand title={subtitleTitle} subtitle={subtitleSub} />
    </AbsoluteFill>
  );
};

export const StatusSection: React.FC<{
  capture: Capture;
  subtitleTitle?: string;
  subtitleSub?: string;
}> = ({
  capture,
  subtitleTitle = "Sovereign & Active",
  subtitleSub = "SNS . Brain . MagicBlock — all green",
}) => {
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
      <SubtitleBand title={subtitleTitle} subtitle={subtitleSub} />
    </AbsoluteFill>
  );
};

/**
 * Schema-driven sequencing. Each entry has a frame budget; the layout function
 * computes from/len with adjacent-overlap baked in.
 */
export type SchemaEntry = { key: string; baseLen: number };

export function layoutSchema(entries: SchemaEntry[]): Array<{ key: string; from: number; len: number }> {
  let cursor = 0;
  return entries.map((e, i) => {
    const isFirst = i === 0;
    const from = isFirst ? cursor : cursor - FADE_OVERLAP;
    const len = isFirst ? e.baseLen : e.baseLen + FADE_OVERLAP;
    const out = { key: e.key, from, len };
    cursor += e.baseLen;
    return out;
  });
}

export { TerminalReplay, DepthLayer, SubtitleBand, Sequence };
