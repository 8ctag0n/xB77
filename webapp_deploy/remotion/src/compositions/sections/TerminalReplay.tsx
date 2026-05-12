import React from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
import { COLORS, FONTS } from "../../theme";

export type TerminalLine = {
  stream: "stdout" | "stderr";
  t_ms: number;
  text: string;
  ansi?: string;
};

export type TerminalReplayProps = {
  lines: TerminalLine[];
  title?: string;          // shown in the macOS-style window header
  fontSize?: number;       // px
  width?: number | string;
  height?: number | string;
  speedMultiplier?: number; // 1.0 = play at recorded pace, 2.0 = 2x speed
  highlight?: string;       // substring to render in lime + bold
};

/**
 * TerminalReplay — animated playback of a captured CLI session.
 *
 * Consumes the JSON written by scripts/demo_capture.sh. Each line appears at
 * `t_ms * speedMultiplier` into the section, with a subtle scan-in animation.
 * Strings matching `highlight` (e.g. a pubkey we want to call attention to)
 * pulse lime and bold.
 *
 * The window chrome is a stylized terminal — geist mono, dark plate, lime/cyan
 * accents per the xB77 palette. Not a literal screenshot — keeps cinematic feel.
 */
export const TerminalReplay: React.FC<TerminalReplayProps> = ({
  lines,
  title = "xB77",
  fontSize = 22,
  width = "100%",
  height = "100%",
  speedMultiplier = 1,
  highlight,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const ms = (frame / fps) * 1000 * speedMultiplier;

  const visible = lines.filter((l) => l.t_ms <= ms);

  return (
    <div
      style={{
        width,
        height,
        background: "#0a0a0c",
        border: `1px solid ${COLORS.rule}`,
        boxShadow: `0 0 0 1px rgba(200,255,46,0.08), 0 24px 60px rgba(0,0,0,0.6)`,
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      {/* macOS-style header bar with brand twist */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          padding: "10px 14px",
          background: "#0f0f12",
          borderBottom: `1px solid ${COLORS.rule}`,
        }}
      >
        <div style={{ width: 12, height: 12, borderRadius: 6, background: "#3a3a40" }} />
        <div style={{ width: 12, height: 12, borderRadius: 6, background: "#3a3a40" }} />
        <div style={{ width: 12, height: 12, borderRadius: 6, background: COLORS.lime, opacity: 0.7 }} />
        <div
          style={{
            flex: 1,
            textAlign: "center",
            fontFamily: FONTS.mono,
            fontSize: 13,
            color: COLORS.textDim,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
          }}
        >
          {title}
        </div>
        <div style={{ width: 36 }} />
      </div>

      {/* Body — lines scroll in */}
      <div
        style={{
          flex: 1,
          padding: "18px 22px",
          fontFamily: FONTS.mono,
          fontSize,
          lineHeight: 1.45,
          color: COLORS.textHi,
          overflow: "hidden",
          whiteSpace: "pre",
        }}
      >
        {visible.map((line, i) => {
          const enterMs = Math.max(ms - line.t_ms, 0);
          const opacity = Math.min(enterMs / 80, 1);
          const dx = (1 - opacity) * 8;
          return (
            <Line
              key={i}
              text={line.text}
              opacity={opacity}
              dx={dx}
              highlight={highlight}
              stream={line.stream}
            />
          );
        })}
        {/* Blinking caret on the last visible line */}
        {visible.length > 0 ? (
          <span
            style={{
              display: "inline-block",
              width: fontSize * 0.55,
              height: fontSize,
              background: COLORS.lime,
              verticalAlign: "text-bottom",
              opacity: Math.floor(frame / 12) % 2 === 0 ? 0.9 : 0.2,
            }}
          />
        ) : null}
      </div>
    </div>
  );
};

const Line: React.FC<{
  text: string;
  opacity: number;
  dx: number;
  highlight?: string;
  stream: string;
}> = ({ text, opacity, dx, highlight, stream }) => {
  const baseColor = stream === "stderr" ? "#ff9a3a" : COLORS.textHi;
  const styled = highlight && text.includes(highlight) ? renderHighlighted(text, highlight) : text;
  return (
    <div
      style={{
        opacity,
        transform: `translateX(${dx}px)`,
        color: baseColor,
      }}
    >
      {styled}
    </div>
  );
};

const renderHighlighted = (text: string, h: string): React.ReactNode => {
  const idx = text.indexOf(h);
  if (idx < 0) return text;
  return (
    <>
      {text.slice(0, idx)}
      <span style={{ color: COLORS.lime, fontWeight: 900, textShadow: `0 0 10px ${COLORS.lime}` }}>
        {h}
      </span>
      {text.slice(idx + h.length)}
    </>
  );
};
