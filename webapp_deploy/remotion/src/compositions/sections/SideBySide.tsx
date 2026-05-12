import React from "react";
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
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        flexDirection: "column",
        padding: "60px 80px 160px 80px",
        gap: 24,
      }}
    >
      <div style={{ flex: 1, display: "flex", gap: 24, alignItems: "stretch", justifyContent: "center" }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <TerminalReplay lines={leftLines} title={leftTitle} highlight={highlight} fontSize={18} />
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            minWidth: 120,
          }}
        >
          <div
            style={{
              fontFamily: FONTS.mono,
              fontSize: 18,
              fontWeight: 900,
              letterSpacing: "0.2em",
              color: COLORS.lime,
              textShadow: `0 0 14px ${COLORS.lime}`,
              padding: "10px 14px",
              border: `1px solid ${COLORS.lime}`,
              background: "rgba(200,255,46,0.06)",
            }}
          >
            {matchLabel}
          </div>
          <div
            style={{
              marginTop: 12,
              width: 2,
              height: 60,
              background: `linear-gradient(180deg, ${COLORS.lime}, ${COLORS.cyan})`,
              opacity: 0.5,
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
