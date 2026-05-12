import React from "react";
import { AbsoluteFill } from "remotion";
import { Seal } from "../components/Seal";
import { Wordmark } from "../components/Wordmark";
import { COLORS, FONTS } from "../theme";

/**
 * OG card / press kit — 1200x630, single frame.
 * Renders to webapp_deploy/assets/logo-og.svg's PNG equivalent for og:image meta.
 */
export const WordmarkOG: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg, color: COLORS.textHi, fontFamily: FONTS.sans }}>
      {/* Grid background */}
      <svg width={1200} height={630} style={{ position: "absolute", inset: 0 }}>
        <defs>
          <pattern id="og-grid" x="0" y="0" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M40 0 L0 0 0 40" fill="none" stroke={COLORS.cyan} strokeWidth="0.5" strokeOpacity="0.06"/>
          </pattern>
        </defs>
        <rect width={1200} height={630} fill="url(#og-grid)"/>
      </svg>

      {/* Corner crops */}
      <svg width={1200} height={630} style={{ position: "absolute", inset: 0 }}>
        <defs>
          <linearGradient id="og-corner" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor={COLORS.lime}/>
            <stop offset="100%" stopColor={COLORS.cyan}/>
          </linearGradient>
        </defs>
        <g stroke="url(#og-corner)" strokeWidth="1.4" fill="none" opacity="0.6">
          <path d="M40 40 L100 40 M40 40 L40 100"/>
          <path d="M1160 40 L1100 40 M1160 40 L1160 100"/>
          <path d="M40 590 L100 590 M40 590 L40 530"/>
          <path d="M1160 590 L1100 590 M1160 590 L1160 530"/>
        </g>
      </svg>

      {/* Content */}
      <div style={{ position: "absolute", left: 110, top: 195, width: 240, height: 240 }}>
        <Seal size={240} progress={1} cycle={0.72} idScope="og"/>
      </div>

      <div style={{ position: "absolute", left: 410, top: 200, right: 80 }}>
        <Wordmark size={148} underlineProgress={1}/>

        <div style={{
          fontFamily: FONTS.serif,
          fontStyle: "italic",
          fontSize: 44,
          color: COLORS.textHi,
          letterSpacing: "-0.5px",
          marginTop: 20,
        }}>
          Autonomous Financial Infrastructure
        </div>

        <div style={{
          fontFamily: FONTS.mono,
          fontSize: 18,
          color: COLORS.cyan,
          opacity: 0.85,
          letterSpacing: "0.5px",
          marginTop: 36,
          lineHeight: 1.55,
          whiteSpace: "nowrap",
        }}>
          shielded payments <span style={{ color: COLORS.rule }}>·</span> zk-compressed receipts <span style={{ color: COLORS.rule }}>·</span> agents on solana
        </div>
      </div>

      {/* Footer */}
      <div style={{ position: "absolute", left: 40, bottom: 28, right: 40 }}>
        <svg width="100%" height="2" style={{ display: "block", marginBottom: 18 }}>
          <defs>
            <linearGradient id="og-rule" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%"   stopColor={COLORS.lime} stopOpacity="0"/>
              <stop offset="20%"  stopColor={COLORS.lime} stopOpacity="0.45"/>
              <stop offset="80%"  stopColor={COLORS.cyan} stopOpacity="0.45"/>
              <stop offset="100%" stopColor={COLORS.cyan} stopOpacity="0"/>
            </linearGradient>
          </defs>
          <line x1="0" y1="1" x2="100%" y2="1" stroke="url(#og-rule)" strokeWidth="0.8"/>
        </svg>
        <div style={{ display: "flex", justifyContent: "space-between", fontFamily: FONTS.mono, fontSize: 16, color: COLORS.textDim, letterSpacing: "2px" }}>
          <span>SOLANA PRIVACY HACKATHON · 2026</span>
          <span>xb77.network</span>
        </div>
      </div>
    </AbsoluteFill>
  );
};
