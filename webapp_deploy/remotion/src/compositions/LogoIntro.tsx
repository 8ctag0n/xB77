import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate, Easing } from "remotion";
import { Seal } from "../components/Seal";
import { Wordmark } from "../components/Wordmark";
import { COLORS, FONTS } from "../theme";

/**
 * Launch intro — 3s stamp animation for the pitch video / hackathon submission.
 *
 * Cadence (90 frames @ 30fps):
 *   0  -  6   black hold, bezel dim glow rising
 *   6  - 30   bezel traces in, monogram stamps down
 *   30 - 60   ticks + ZK badge resolve, slight camera settle
 *   60 - 78   wordmark "xB77" slides in from below the seal
 *   78 - 90   hold with subtle shimmer pass
 */
export const LogoIntro: React.FC = () => {
  const frame = useCurrentFrame();
  const { durationInFrames, width, height } = useVideoConfig();

  // Seal progress: drives bezel/mono/ticks/zk/receipt slices (one-shot entrance)
  const sealProgress = interpolate(frame, [0, 36], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  // Agent cycle — starts after the entrance completes, plays one full cycle
  const sealCycle = interpolate(frame, [30, 90], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.linear,
  });

  // Wordmark reveal
  const wordmarkOpacity = interpolate(frame, [60, 78], [0, 1], { extrapolateRight: "clamp" });
  const wordmarkY = interpolate(frame, [60, 78], [40, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const underlineProgress = interpolate(frame, [70, 88], [0, 1], { extrapolateRight: "clamp" });

  // Shimmer band sweeps across after frame 78
  const shimmerX = interpolate(frame, [78, durationInFrames], [-width, width * 0.5], {
    extrapolateRight: "clamp",
  });
  const shimmerOpacity = interpolate(frame, [78, 85, durationInFrames], [0, 0.18, 0.08], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg }}>
      {/* Faint grid background */}
      <svg width={width} height={height} style={{ position: "absolute", inset: 0, opacity: 0.4 }}>
        <defs>
          <pattern id="intro-grid" x="0" y="0" width="48" height="48" patternUnits="userSpaceOnUse">
            <path d="M48 0 L0 0 0 48" fill="none" stroke={COLORS.cyan} strokeWidth="0.5" strokeOpacity="0.06"/>
          </pattern>
        </defs>
        <rect width={width} height={height} fill="url(#intro-grid)"/>
      </svg>

      {/* The seal, centered, scaled large */}
      <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", gap: 40 }}>
        <div style={{ filter: `drop-shadow(0 0 24px ${COLORS.lime}33)` }}>
          <Seal size={420} progress={sealProgress} cycle={sealCycle} idScope="intro"/>
        </div>

        <div style={{ opacity: wordmarkOpacity, transform: `translateY(${wordmarkY}px)` }}>
          <Wordmark size={84} underlineProgress={underlineProgress}/>
          <div style={{
            fontFamily: FONTS.serif,
            fontStyle: "italic",
            fontSize: 28,
            color: COLORS.textHi,
            textAlign: "center",
            marginTop: -12,
            letterSpacing: "-0.3px",
          }}>
            Autonomous Financial Infrastructure
          </div>
        </div>
      </div>

      {/* Shimmer pass at end */}
      <div style={{
        position: "absolute", top: 0, bottom: 0,
        left: shimmerX,
        width: width * 0.5,
        background: `linear-gradient(90deg, transparent 0%, ${COLORS.lime}${Math.round(shimmerOpacity * 255).toString(16).padStart(2,"0")} 50%, transparent 100%)`,
        pointerEvents: "none",
        transform: "skewX(-12deg)",
      }}/>
    </AbsoluteFill>
  );
};
