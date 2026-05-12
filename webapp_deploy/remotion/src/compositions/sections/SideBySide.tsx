import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { TerminalReplay, TerminalLine } from "./TerminalReplay";
import { COLORS, FONTS } from "../../theme";

export type SideBySideProps = {
  leftTitle: string;
  rightTitle: string;
  leftLines: TerminalLine[];
  rightLines: TerminalLine[];
  highlight?: string;   // pubkey or signature to pulse in both panels
  matchLabel?: string;  // e.g. "MATCH" or "DIVERGE"
};

/**
 * SideBySide — two TerminalReplay columns with a center "match" indicator.
 *
 * Used for the SNS demo beat: left panel runs the Bonfida API call,
 * right panel runs the native Zig derivation. The shared `highlight` pulses
 * in both — visceral proof that they produced the same bytes.
 */
export const SideBySide: React.FC<SideBySideProps> = ({
  leftTitle,
  rightTitle,
  leftLines,
  rightLines,
  highlight,
  matchLabel = "MATCH",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // MATCH stamp doesn't appear until ~25% into the section, then snaps in.
  // The terminals need to play out their typewriter first; the stamp lands
  // as a payoff, not as the opening beat.
  const stampStartFrame = 120; // ~4s at 30fps
  const stampLocal = frame - stampStartFrame;

  const stampEnter = spring({
    frame: Math.max(stampLocal, 0),
    fps,
    durationInFrames: 22,
    config: { damping: 8, stiffness: 130, mass: 0.9 },
  });
  const stampOpacity = stampLocal < 0 ? 0 : Math.min(stampLocal / 4, 1);
  const stampScale = 0.5 + 0.5 * stampEnter;

  // Breathing pulse after the entrance — sells "alive" without being noisy
  const pulse = stampLocal > 22 ? 1 + 0.04 * Math.sin((stampLocal - 22) / fps * 2.6) : 1;
  const finalScale = stampScale * pulse;

  // Bloom halo behind the stamp, scaled up + heavily blurred
  const bloomOpacity = stampLocal < 0 ? 0 : Math.min(stampLocal / 18, 1) * 0.85;

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        flexDirection: "column",
        padding: "70px 80px 170px 80px",
        gap: 24,
      }}
    >
      <div style={{ flex: 1, display: "flex", gap: 32, alignItems: "stretch", justifyContent: "center" }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <TerminalReplay lines={leftLines} title={leftTitle} highlight={highlight} fontSize={18} />
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            minWidth: 140,
            position: "relative",
          }}
        >
          {/* Bloom halo — radial gradient, no blur (cheap version) */}
          <div
            style={{
              position: "absolute",
              width: 280,
              height: 280,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${COLORS.lime} 0%, rgba(200,255,46,0.3) 30%, transparent 70%)`,
              opacity: bloomOpacity * 0.35,
              transform: `scale(${1.1 + stampEnter * 0.5})`,
            }}
          />

          {/* The MATCH stamp itself */}
          <div
            style={{
              position: "relative",
              fontFamily: FONTS.mono,
              fontSize: 22,
              fontWeight: 900,
              letterSpacing: "0.24em",
              color: COLORS.lime,
              textShadow: `0 0 18px ${COLORS.lime}, 0 0 36px rgba(200,255,46,0.4)`,
              padding: "14px 20px",
              border: `2px solid ${COLORS.lime}`,
              background: "rgba(200,255,46,0.10)",
              opacity: stampOpacity,
              transform: `scale(${finalScale}) rotate(-2deg)`,
              boxShadow: `0 0 0 1px rgba(200,255,46,${0.3 * bloomOpacity}), 0 12px 30px rgba(0,0,0,0.5)`,
            }}
          >
            {matchLabel}
          </div>

          {/* Connector line between panels — appears after stamp lands */}
          <div
            style={{
              marginTop: 16,
              width: 2,
              height: 56,
              background: `linear-gradient(180deg, ${COLORS.lime}, ${COLORS.cyan})`,
              opacity: Math.max(0, Math.min(stampLocal / 30, 0.55)),
            }}
          />
        </div>

        <div style={{ flex: 1, minWidth: 0 }}>
          <TerminalReplay lines={rightLines} title={rightTitle} highlight={highlight} fontSize={18} />
        </div>
      </div>
    </div>
  );
};
