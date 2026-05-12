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
  const justHitHighlight =
    highlight !== undefined &&
    visible.length > 0 &&
    visible[visible.length - 1].text.includes(highlight);
  // Pulse the inner glow for ~12 frames after a highlighted line lands
  const lastHighlightFrame = React.useRef(0);
  if (justHitHighlight) lastHighlightFrame.current = frame;
  const pulseAge = frame - lastHighlightFrame.current;
  const pulseStrength = pulseAge < 18 ? 1 - pulseAge / 18 : 0;

  return (
    <div
      style={{
        width,
        height,
        position: "relative",
        // 3D perspective tilt — barely-there, makes the chrome feel solid
        transform: "perspective(1400px) rotateY(1.2deg) rotateX(0.8deg)",
        transformStyle: "preserve-3d",
      }}
    >
      {/* Outer bloom — radial gradient, no blur filter (cheap-to-render version) */}
      <div
        style={{
          position: "absolute",
          inset: -40,
          background: `radial-gradient(ellipse at 30% 30%, rgba(200,255,46,${0.05 + pulseStrength * 0.12}) 0%, rgba(0,240,255,${0.03 + pulseStrength * 0.06}) 50%, transparent 80%)`,
          pointerEvents: "none",
        }}
      />

      <div
        style={{
          position: "relative",
          width: "100%",
          height: "100%",
          background: "linear-gradient(180deg, #0c0c0f 0%, #08080a 100%)",
          border: `1px solid ${COLORS.rule}`,
          borderRadius: 10,
          // Soft diffused shadow + subtle lime rim that brightens on highlight pulse
          boxShadow: `
            0 0 0 1px rgba(200,255,46,${0.10 + pulseStrength * 0.25}),
            0 40px 80px rgba(0,0,0,0.55),
            0 12px 32px rgba(0,0,0,0.35),
            inset 0 1px 0 rgba(255,255,255,0.04)
          `,
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
          background: "rgba(15,15,18,0.85)",
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

      {/* Body — lines scroll in, then the whole content slides up so latest lines stay visible */}
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
          position: "relative",
        }}
      >
        <TerminalScroller fontSize={fontSize} visible={visible}>
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
        </TerminalScroller>
      </div>
      </div>
    </div>
  );
};

/**
 * TerminalScroller — slides the content up so the newest line is always
 * visible. We can't measure DOM in Remotion (deterministic frame rendering),
 * so the offset is computed from line count × line-height. After
 * VISIBLE_LINES are on screen, every new line shifts the stack up by one
 * lineHeight via a CSS transition.
 */
const TerminalScroller: React.FC<{
  fontSize: number;
  visible: TerminalLine[];
  children: React.ReactNode;
}> = ({ fontSize, visible, children }) => {
  const VISIBLE_LINES = 10;       // 480p body fits ~10 lines comfortably
  const lineHeight = fontSize * 1.45;
  const excess = Math.max(0, visible.length - VISIBLE_LINES);
  const offsetPx = excess * lineHeight;
  return (
    <div
      style={{
        transform: `translateY(-${offsetPx}px)`,
        transition: "transform 240ms ease-out",
      }}
    >
      {children}
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
