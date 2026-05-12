import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from "remotion";
import { COLORS } from "../../theme";

export type DepthLayerProps = {
  variant?: "default" | "hero" | "endcard";
  /** Slight horizontal drift on the radial center, in % per second. */
  drift?: number;
};

/**
 * DepthLayer — the background depth treatment that lifts every frame above
 * "flat dark plate" into something cinematic.
 *
 * Three layers stacked:
 *   1. Radial gradient (lighter slightly off-center, darker at edges)
 *   2. SVG-generated noise overlay at low opacity — kills the digital-flat look
 *   3. Vignette (corners darkened) — focuses attention to center
 *
 * Hero variant adds a subtle mesh-gradient pulse for opening / closing.
 * Endcard adds a wider lime+cyan halo for the seal.
 */
export const DepthLayer: React.FC<DepthLayerProps> = ({ variant = "default", drift = 0.4 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const t = frame / fps;
  // Slow horizontal drift on the radial center — keeps frames from feeling static
  const cx = 50 + Math.sin(t * drift) * 2; // ±2%
  const cy = 50 + Math.cos(t * drift * 0.7) * 1.5; // ±1.5%

  const haloOpacity =
    variant === "hero"     ? 0.32 :
    variant === "endcard"  ? 0.40 :
                             0.22;

  const haloRadius =
    variant === "hero"     ? 60 :
    variant === "endcard"  ? 55 :
                             70;

  return (
    <AbsoluteFill style={{ pointerEvents: "none", overflow: "hidden" }}>
      {/* Base radial gradient */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `radial-gradient(circle at ${cx}% ${cy}%, rgba(200,255,46,${haloOpacity * 0.06}) 0%, ${COLORS.bg} ${haloRadius}%, #050507 100%)`,
        }}
      />

      {/* Secondary cyan glow for hero / endcard */}
      {variant !== "default" ? (
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: `radial-gradient(ellipse at 70% 30%, rgba(0,240,255,${haloOpacity * 0.05}) 0%, transparent 60%)`,
            mixBlendMode: "screen",
          }}
        />
      ) : null}

      {/* Vignette — corners darkened ~12% */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.4) 100%)",
        }}
      />
    </AbsoluteFill>
  );
};
