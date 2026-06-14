import React from "react";
import { useCurrentFrame, AbsoluteFill, interpolate, spring } from "remotion";
import type { AnchorEvent } from "../data/parseEvents";
import { theme } from "../styles/theme";

interface AnchorProps {
  events: AnchorEvent[];
}

const HexRing: React.FC<{ radius: number; color: string; opacity: number; rotate: number }> = ({
  radius, color, opacity, rotate,
}) => {
  const N = 6;
  const points = Array.from({ length: N }, (_, i) => {
    const a = (Math.PI / 3) * i + rotate;
    return `${radius * Math.cos(a)},${radius * Math.sin(a)}`;
  }).join(" ");
  return <polygon points={points} fill="none" stroke={color} strokeWidth={1.5} opacity={opacity} />;
};

export const Anchor: React.FC<AnchorProps> = ({ events }) => {
  const frame = useCurrentFrame();
  const fps = 30;

  const rbhEv = events.find((e) => e.chain === "robinhood");
  const arbEv = events.find((e) => e.chain === "arbitrum_sepolia" || e.chain === "arbitrum");

  const titleOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });

  // Phase timeline
  const RBH_ANCHOR_START = 20;
  const ARB_ANCHOR_START = 140;
  const FINAL_START = 300;

  const rbhScale = spring({ frame: Math.max(0, frame - RBH_ANCHOR_START), fps, config: { damping: 8, stiffness: 60 } });
  const arbScale = spring({ frame: Math.max(0, frame - ARB_ANCHOR_START), fps, config: { damping: 8, stiffness: 60 } });
  const finalScale = spring({ frame: Math.max(0, frame - FINAL_START), fps, config: { damping: 6, stiffness: 40 } });

  const rotate = (frame / fps) * 0.4;
  const rotate2 = -(frame / fps) * 0.25;

  const root = rbhEv?.root ?? "0x4a3f21c88d0f92e0b3a1c0d5f7e2a9b4c6d3e1f0a8b2c4d6e8f0a2b4c6d8e0f2";

  return (
    <AbsoluteFill style={{ background: theme.bg, fontFamily: theme.font }}>
      {/* Animated center orb */}
      <svg style={{ position: "absolute", inset: 0, width: 1920, height: 1080 }}>
        <g transform="translate(960, 580)">
          {/* Outer hex rings */}
          {[200, 260, 320].map((r, i) => (
            <HexRing
              key={i}
              radius={r}
              color={i % 2 === 0 ? "#00ff88" : "#00ffff"}
              opacity={0.08 + Math.sin(frame / 20 + i) * 0.03}
              rotate={rotate * (i % 2 === 0 ? 1 : -1)}
            />
          ))}

          {/* Core glow */}
          <circle cx={0} cy={0} r={80}
            fill="#00ff88" opacity={0.06 + Math.sin(frame / 15) * 0.02}
            style={{ filter: "blur(20px)" }} />
          <circle cx={0} cy={0} r={48}
            fill="#0a0a0a" stroke="#00ff88" strokeWidth={2}
            style={{ filter: "drop-shadow(0 0 16px #00ff88)" }} />
          <text x={0} y={6} textAnchor="middle" fill="#00ff88" fontSize={12} fontWeight={700} letterSpacing={3}>
            ROOT
          </text>
        </g>
      </svg>

      {/* Title area */}
      <div style={{ position: "absolute", top: 60, left: 120, opacity: titleOpacity }}>
        <div style={{ color: theme.green, fontSize: 13, letterSpacing: 6, marginBottom: 12 }}>
          STATE ANCHOR PROTOCOL
        </div>
        <div style={{ color: "#ffffff", fontSize: 48, fontWeight: 700, letterSpacing: 2 }}>
          On-Chain Root Commitment
        </div>
        <div style={{ color: theme.dim, fontSize: 18, marginTop: 8 }}>
          Merkle root anchored immutably on both chains
        </div>
      </div>

      {/* Root hash display */}
      <div style={{
        position: "absolute",
        top: 220,
        left: 120,
        right: 120,
        opacity: interpolate(frame, [10, 30], [0, 1], { extrapolateRight: "clamp" }),
      }}>
        <div style={{ color: theme.dim, fontSize: 11, letterSpacing: 4, marginBottom: 8 }}>STATE ROOT</div>
        <div style={{
          color: theme.green,
          fontSize: 16,
          fontFamily: theme.font,
          letterSpacing: 1.5,
          wordBreak: "break-all",
          textShadow: `0 0 10px ${theme.green}`,
        }}>
          {root}
        </div>
      </div>

      {/* Anchor cards */}
      <div style={{ position: "absolute", bottom: 100, left: 120, right: 120, display: "flex", gap: 40 }}>
        {/* Robinhood anchor */}
        <div style={{
          flex: 1,
          background: "#060606",
          border: `1px solid ${frame >= RBH_ANCHOR_START ? "#ff4444" : "#1a1a1a"}`,
          borderRadius: 8,
          padding: "28px 32px",
          transform: `scale(${rbhScale})`,
          transformOrigin: "bottom center",
          boxShadow: frame >= RBH_ANCHOR_START ? "0 0 30px #ff444430" : "none",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
            <div style={{ width: 10, height: 10, borderRadius: "50%", background: "#ff4444", boxShadow: "0 0 8px #ff4444" }} />
            <div style={{ color: "#ff4444", fontSize: 12, letterSpacing: 4 }}>ROBINHOOD TESTNET</div>
          </div>
          <div style={{ color: theme.dim, fontSize: 11, letterSpacing: 2, marginBottom: 10 }}>TX HASH</div>
          <div style={{ color: "#ffffff", fontSize: 13, wordBreak: "break-all", lineHeight: 1.5 }}>
            {rbhEv?.tx ?? "0x21cc1b8f..."}
          </div>
          <div style={{ marginTop: 16, color: theme.green, fontSize: 24, fontWeight: 900, letterSpacing: 4, textShadow: `0 0 16px ${theme.green}` }}>
            ⊕ ANCHORED
          </div>
          {rbhEv?.block && (
            <div style={{ color: theme.dim, fontSize: 11, marginTop: 8 }}>
              block #{rbhEv.block}
            </div>
          )}
        </div>

        {/* Arbitrum anchor */}
        <div style={{
          flex: 1,
          background: "#060606",
          border: `1px solid ${frame >= ARB_ANCHOR_START ? "#4488ff" : "#1a1a1a"}`,
          borderRadius: 8,
          padding: "28px 32px",
          transform: `scale(${arbScale})`,
          transformOrigin: "bottom center",
          boxShadow: frame >= ARB_ANCHOR_START ? "0 0 30px #4488ff30" : "none",
          opacity: interpolate(frame, [ARB_ANCHOR_START - 20, ARB_ANCHOR_START], [0, 1], { extrapolateRight: "clamp" }),
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16 }}>
            <div style={{ width: 10, height: 10, borderRadius: "50%", background: "#4488ff", boxShadow: "0 0 8px #4488ff" }} />
            <div style={{ color: "#4488ff", fontSize: 12, letterSpacing: 4 }}>ARBITRUM SEPOLIA</div>
          </div>
          <div style={{ color: theme.dim, fontSize: 11, letterSpacing: 2, marginBottom: 10 }}>TX HASH</div>
          <div style={{ color: "#ffffff", fontSize: 13, wordBreak: "break-all", lineHeight: 1.5 }}>
            {arbEv?.tx ?? "0x5eefda08..."}
          </div>
          <div style={{ marginTop: 16, color: theme.green, fontSize: 24, fontWeight: 900, letterSpacing: 4, textShadow: `0 0 16px ${theme.green}` }}>
            ⊕ ANCHORED
          </div>
          {arbEv?.block && (
            <div style={{ color: theme.dim, fontSize: 11, marginTop: 8 }}>
              block #{arbEv.block}
            </div>
          )}
        </div>
      </div>

      {/* Final banner */}
      {frame >= FINAL_START && (
        <div style={{
          position: "absolute",
          top: "40%",
          left: 0,
          right: 0,
          textAlign: "center",
          transform: `scale(${finalScale})`,
          opacity: interpolate(frame, [FINAL_START, FINAL_START + 20], [0, 1], { extrapolateRight: "clamp" }),
        }}>
          <div style={{
            color: theme.green,
            fontSize: 52,
            fontWeight: 900,
            letterSpacing: 8,
            textShadow: `0 0 40px ${theme.green}, 0 0 80px ${theme.green}60`,
          }}>
            SOVEREIGN STATE PROVEN
          </div>
          <div style={{ color: theme.dim, fontSize: 18, marginTop: 16, letterSpacing: 4 }}>
            xB77 · Cross-Chain ZK Settlement · Arbitrum Hackathon 2026
          </div>
        </div>
      )}
    </AbsoluteFill>
  );
};
