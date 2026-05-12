import React from "react";
import { Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Seal } from "../../components/Seal";
import { Wordmark } from "../../components/Wordmark";
import { COLORS, FONTS } from "../../theme";

export type ActionCloseProps = {
  /** URL displayed prominently. */
  url: string;
  /** Verb in the lower-left (e.g. "VERIFY", "SCAN", "INSPECT"). */
  verb?: string;
  /** Tagline below the wordmark. */
  tagline?: string;
};

/**
 * ActionClose — end card following the "action close" archetype.
 *
 * Left 60%: brand seal + wordmark + tagline (vertical stack)
 * Right 40%: QR code + verb + URL (call to action)
 *
 * Hold 90+ frames per the skill checklist. The seal continues its agent-cycle
 * idle so the frame still feels alive while held.
 */
export const ActionClose: React.FC<ActionCloseProps> = ({
  url,
  verb = "VERIFY",
  tagline = "Autonomous Financial Infrastructure",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const sealEnter = spring({ frame, fps, durationInFrames: 28, config: { damping: 14, stiffness: 120 } });
  const wordmarkEnter = spring({ frame: frame - 10, fps, durationInFrames: 24, config: { damping: 16 } });
  const taglineEnter = interpolate(frame, [20, 36], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const qrEnter = spring({ frame: frame - 28, fps, durationInFrames: 22, config: { damping: 14 } });
  const verbEnter = interpolate(frame, [42, 58], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const urlEnter = interpolate(frame, [52, 76], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", padding: "80px 100px" }}>
      {/* LEFT 60% — brand stack */}
      <div style={{ flex: 6, display: "flex", flexDirection: "column", justifyContent: "center", gap: 22 }}>
        <div style={{ transform: `scale(${0.75 + sealEnter * 0.25})`, transformOrigin: "left center", opacity: sealEnter }}>
          <Seal size={200} progress={1} cycle={(frame % 90) / 90} />
        </div>
        <div style={{ opacity: wordmarkEnter, transform: `translateY(${(1 - wordmarkEnter) * 10}px)` }}>
          <Wordmark size={64} />
        </div>
        <div
          style={{
            fontFamily: FONTS.sans,
            fontSize: 26,
            color: COLORS.textDim,
            letterSpacing: "0.04em",
            opacity: taglineEnter,
            maxWidth: 540,
            lineHeight: 1.25,
          }}
        >
          {tagline}
        </div>
      </div>

      {/* RIGHT 40% — call to action */}
      <div style={{ flex: 4, display: "flex", flexDirection: "column", justifyContent: "center", gap: 28, alignItems: "flex-end" }}>
        {/* QR */}
        <div
          style={{
            padding: 14,
            background: "#fff",
            borderRadius: 12,
            boxShadow: `0 0 0 1px rgba(200,255,46,0.25), 0 24px 60px rgba(0,0,0,0.55)`,
            opacity: qrEnter,
            transform: `scale(${0.85 + qrEnter * 0.15})`,
          }}
        >
          <Img src={staticFile("qr.png")} style={{ width: 220, height: 220, display: "block", imageRendering: "pixelated" }} />
        </div>

        {/* Verb — kinetic emphasis */}
        <div
          style={{
            fontFamily: FONTS.mono,
            fontSize: 56,
            fontWeight: 900,
            letterSpacing: "0.18em",
            color: COLORS.lime,
            textShadow: `0 0 22px ${COLORS.lime}, 0 0 44px rgba(200,255,46,0.35)`,
            opacity: verbEnter,
            transform: `translateY(${(1 - verbEnter) * 14}px)`,
          }}
        >
          {verb}
        </div>

        {/* URL */}
        <div
          style={{
            fontFamily: FONTS.mono,
            fontSize: 24,
            color: COLORS.textHi,
            letterSpacing: "0.04em",
            opacity: urlEnter,
            transform: `translateY(${(1 - urlEnter) * 8}px)`,
            textAlign: "right",
            maxWidth: 520,
            wordBreak: "break-all",
          }}
        >
          {url}
        </div>
      </div>
    </div>
  );
};
