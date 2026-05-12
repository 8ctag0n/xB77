import React from "react";
import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { COLORS, FONTS } from "../../theme";

export type SolscanLinkProps = {
  signature: string;
  network?: "mainnet" | "devnet" | "localnet";
  programId?: string;
  instruction?: string;
  ts?: string;       // ISO timestamp displayed on the card
};

/**
 * SolscanLink — animated "tx landed onchain" card. Not a real Solscan
 * screenshot, but a stylized explorer card mirroring its layout so the eye
 * recognizes the pattern. The signature is the load-bearing element.
 */
export const SolscanLink: React.FC<SolscanLinkProps> = ({
  signature,
  network = "devnet",
  programId,
  instruction,
  ts,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const enter = spring({ frame, fps, durationInFrames: 18, config: { damping: 14 } });
  const stampScale = spring({ frame: frame - 24, fps, durationInFrames: 16, config: { damping: 12 } });

  const sigShort =
    signature.length > 20
      ? `${signature.slice(0, 12)}…${signature.slice(-8)}`
      : signature;
  const charsShown = Math.min(
    signature.length,
    Math.floor(interpolate(frame, [10, 60], [0, signature.length], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }))
  );
  const sigTyped = signature.slice(0, charsShown);

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        opacity: enter,
        gap: 24,
      }}
    >
      {/* CONFIRMED stamp */}
      <div
        style={{
          transform: `scale(${stampScale}) rotate(-3deg)`,
          padding: "8px 20px",
          border: `3px solid ${COLORS.lime}`,
          color: COLORS.lime,
          fontFamily: FONTS.mono,
          fontSize: 22,
          fontWeight: 900,
          letterSpacing: "0.2em",
          textShadow: `0 0 12px ${COLORS.lime}`,
          background: "rgba(200,255,46,0.06)",
        }}
      >
        CONFIRMED · {network.toUpperCase()}
      </div>

      {/* Card */}
      <div
        style={{
          width: 1100,
          background: "#0c0c0f",
          border: `1px solid ${COLORS.rule}`,
          padding: "28px 32px",
          fontFamily: FONTS.mono,
          color: COLORS.textHi,
          boxShadow: `0 30px 80px rgba(0,0,0,0.6), 0 0 0 1px rgba(0,240,255,0.08)`,
        }}
      >
        <Row label="Signature" value={sigTyped || "—"} mono large highlight />
        {programId ? <Row label="Program" value={programId} mono /> : null}
        {instruction ? <Row label="Instruction" value={instruction} mono /> : null}
        {ts ? <Row label="Timestamp" value={ts} /> : null}
        <div
          style={{
            marginTop: 18,
            paddingTop: 14,
            borderTop: `1px dashed ${COLORS.rule}`,
            fontSize: 16,
            color: COLORS.textDim,
            letterSpacing: "0.08em",
          }}
        >
          solscan.io/tx/{sigShort}?cluster={network}
        </div>
      </div>
    </div>
  );
};

const Row: React.FC<{
  label: string;
  value: string;
  mono?: boolean;
  large?: boolean;
  highlight?: boolean;
}> = ({ label, value, mono, large, highlight }) => (
  <div style={{ display: "flex", gap: 24, padding: "8px 0", alignItems: "baseline" }}>
    <div
      style={{
        width: 160,
        color: COLORS.textDim,
        fontFamily: FONTS.sans,
        fontSize: 14,
        letterSpacing: "0.12em",
        textTransform: "uppercase",
      }}
    >
      {label}
    </div>
    <div
      style={{
        flex: 1,
        fontFamily: mono ? FONTS.mono : FONTS.sans,
        fontSize: large ? 24 : 18,
        color: highlight ? COLORS.lime : COLORS.textHi,
        wordBreak: "break-all",
        textShadow: highlight ? `0 0 12px rgba(200,255,46,0.4)` : "none",
      }}
    >
      {value}
    </div>
  </div>
);
