import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing } from "remotion";
import { Seal } from "../components/Seal";
import { COLORS, FONTS } from "../theme";

/**
 * Hero loop — 6s seamless breath for the website hero strip.
 *
 * One full agent cycle plays per loop: 12 particles flow in through the bezel
 * notches, converge on the monogram, the receipt strip pulses at emit, then
 * the next particles are already mid-approach so the loop is seamless.
 */
export const HeroLoop: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames, width } = useVideoConfig();

  // One full agent cycle across the loop
  const cycle = (frame / durationInFrames) % 1;

  // Shimmer sweep — softer, slower than the agent cycle so the layers don't clash
  const shimmerX = interpolate(frame, [0, durationInFrames], [-width * 0.4, width * 1.1], {
    easing: Easing.inOut(Easing.cubic),
  });
  const shimmerOpacity = interpolate(
    frame,
    [0, durationInFrames * 0.4, durationInFrames * 0.6, durationInFrames],
    [0, 0.10, 0.10, 0]
  );

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg, alignItems: "center", justifyContent: "center" }}>
      <div style={{
        display: "flex",
        alignItems: "center",
        gap: 32,
        filter: `drop-shadow(0 0 16px ${COLORS.lime}22)`,
      }}>
        <div>
          <Seal size={220} progress={1} cycle={cycle} idScope="hero"/>
        </div>

        <div>
          <div style={{
            fontFamily: FONTS.sans,
            fontSize: 64,
            fontWeight: 700,
            color: COLORS.textHi,
            letterSpacing: "-2px",
            background: `linear-gradient(90deg, ${COLORS.lime}, ${COLORS.cyan})`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
            backgroundClip: "text",
          }}>
            xB77
          </div>
          <div style={{
            fontFamily: FONTS.mono,
            fontSize: 13,
            color: COLORS.cyan,
            opacity: 0.7,
            letterSpacing: "1.5px",
            marginTop: 2,
          }}>
            AUTONOMOUS FINANCIAL INFRASTRUCTURE
          </div>
        </div>
      </div>

      <div style={{
        position: "absolute", top: 0, bottom: 0,
        left: shimmerX,
        width: width * 0.3,
        background: `linear-gradient(90deg, transparent, ${COLORS.lime}${Math.round(shimmerOpacity * 255).toString(16).padStart(2,"0")}, transparent)`,
        transform: "skewX(-14deg)",
        pointerEvents: "none",
      }}/>
    </AbsoluteFill>
  );
};
