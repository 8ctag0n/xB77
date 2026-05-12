import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import { COLORS, FONTS } from "../../theme";

export type KillSwitchProps = {
  /** Frame at which the kill effect fires (within the parent sequence). */
  killAt: number;
  /** Label shown next to the icon. */
  label?: string;
  /** Where on the screen to draw the indicator. */
  position?: { top?: number | string; right?: number | string; bottom?: number | string; left?: number | string };
};

/**
 * KillSwitch — corner overlay that visualizes the network/shim dying.
 *
 * Before `killAt`: cyan wifi arcs pulsing, "Shim :8088" label.
 * After `killAt`:  arcs collapse, red X stamps across, label flips to
 *                  "Network gone — sovereign mode". Used over the brain
 *                  fallback section to sell the resilience story without
 *                  taking a full section beat.
 */
export const KillSwitch: React.FC<KillSwitchProps> = ({
  killAt,
  label = "Shim :8088",
  position = { top: 60, right: 60 },
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const dead = frame >= killAt;
  const sinceKill = Math.max(frame - killAt, 0);

  const arcOpacity = dead
    ? Math.max(0, 1 - sinceKill / 8)
    : 0.6 + 0.4 * Math.sin((frame / fps) * 3);
  const xScale = dead ? Math.min(sinceKill / 6, 1) : 0;

  return (
    <div
      style={{
        position: "absolute",
        ...position,
        display: "flex",
        alignItems: "center",
        gap: 14,
        padding: "10px 16px",
        background: "rgba(8,8,10,0.78)",
        border: `1px solid ${dead ? "#ff4757" : COLORS.cyan}`,
        backdropFilter: "blur(6px)",
        pointerEvents: "none",
      }}
    >
      <svg width={48} height={48} viewBox="0 0 48 48">
        {/* Wifi arcs — visible until killed */}
        <g style={{ opacity: arcOpacity }}>
          <path d="M 24 36 a 4 4 0 1 0 0.001 0" fill={COLORS.cyan} />
          <path d="M 12 28 q 12 -12 24 0" stroke={COLORS.cyan} strokeWidth="2.6" fill="none" strokeLinecap="round" />
          <path d="M 6 20 q 18 -18 36 0" stroke={COLORS.cyan} strokeWidth="2.6" fill="none" strokeLinecap="round" />
        </g>
        {/* Red X — stamps in after kill */}
        {dead ? (
          <g style={{ transform: `scale(${xScale})`, transformOrigin: "24px 24px" }}>
            <line x1="10" y1="10" x2="38" y2="38" stroke="#ff4757" strokeWidth="4" strokeLinecap="round" />
            <line x1="38" y1="10" x2="10" y2="38" stroke="#ff4757" strokeWidth="4" strokeLinecap="round" />
          </g>
        ) : null}
      </svg>

      <div
        style={{
          fontFamily: FONTS.mono,
          fontSize: 14,
          letterSpacing: "0.12em",
          textTransform: "uppercase",
          color: dead ? "#ff4757" : COLORS.cyan,
          minWidth: 240,
        }}
      >
        {dead ? "Network gone — sovereign mode" : label}
      </div>
    </div>
  );
};
