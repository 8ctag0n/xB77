import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Seal } from "../../components/Seal";
import { COLORS, FONTS } from "../../theme";

export type SponsorTransitionProps = {
  label: string;        // "Sponsor: SNS" / "Cloudflare Workers" etc.
  accent?: string;      // optional accent color, default lime
  duration?: number;    // frames — total transition length
};

/**
 * SponsorTransition — 1.2s palate cleanser between sections.
 *
 * Seal scales in from the center, sponsor label types in below, both fade
 * out before the next section's terminal starts.
 */
export const SponsorTransition: React.FC<SponsorTransitionProps> = ({
  label,
  accent = COLORS.lime,
  duration = 36,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const len = duration ?? durationInFrames;

  const enter = spring({ frame, fps, durationInFrames: 14, config: { damping: 16 } });
  const exit  = spring({ frame: frame - (len - 12), fps, durationInFrames: 10, config: { damping: 18 } });
  const opacity = Math.min(enter, 1 - exit);
  const scale   = 0.8 + 0.2 * enter;

  // Type-in effect for the label
  const charsShown = Math.min(label.length, Math.floor(interpolate(frame, [4, len - 16], [0, label.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })));
  const typed = label.slice(0, charsShown);

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: COLORS.bg,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        opacity,
      }}
    >
      <div style={{ transform: `scale(${scale})` }}>
        <Seal size={220} progress={1} cycle={(frame % 60) / 60} />
      </div>
      <div
        style={{
          marginTop: 28,
          fontFamily: FONTS.mono,
          fontSize: 26,
          fontWeight: 700,
          letterSpacing: "0.24em",
          textTransform: "uppercase",
          color: accent,
          minHeight: 32,
        }}
      >
        {typed}
        <span style={{ opacity: Math.floor(frame / 8) % 2 ? 0.9 : 0.2 }}>_</span>
      </div>
    </div>
  );
};
