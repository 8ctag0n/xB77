import React from "react";
import { COLORS, FONTS } from "../theme";
import { Particles, compressionIntensity } from "./Particles";

/**
 * xB77 receipt seal — the brand mark with living particle agents.
 *
 * Two independent timelines:
 *   `progress` (0→1)  one-shot reveal cadence (bezel traces → monogram stamps → ticks fan → ZK pops)
 *   `cycle`    (0..1) continuous agent cycle: outside → notch → center → emit, loops seamlessly
 *
 * The static mark export captures a frozen frame at cycle=0.72 (mid-compression).
 * The hero loop drives cycle = frame/durationInFrames.
 * The intro plays the reveal, then hands off to cycle for the second half.
 */
export type SealProgress = {
  bezel: number;
  mono: number;
  ticks: number;
  zk: number;
  receipt: number;
};

export type SealProps = {
  size?: number;
  progress?: number;     // 0..1 — one-shot reveal
  cycle?: number;        // 0..1 — looping agent cycle
  slices?: Partial<SealProgress>;
  idScope?: string;
};

const slice = (p: number, from: number, to: number): number => {
  if (p <= from) return 0;
  if (p >= to) return 1;
  return (p - from) / (to - from);
};

const easeOutBack = (t: number, overshoot = 1.2): number => {
  const c1 = overshoot;
  const c3 = c1 + 1;
  return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
};

const easeOutCubic = (t: number): number => 1 - Math.pow(1 - t, 3);

export const Seal: React.FC<SealProps> = ({
  size = 256,
  progress = 1,
  cycle = 0,
  idScope = "xb-seal",
  slices,
}) => {
  const p = {
    bezel:   slice(progress, slices?.bezel   ?? 0.00, 0.40),
    mono:    slice(progress, slices?.mono    ?? 0.40, 0.60),
    ticks:   slice(progress, slices?.ticks   ?? 0.55, 0.75),
    zk:      slice(progress, slices?.zk      ?? 0.70, 0.88),
    receipt: slice(progress, slices?.receipt ?? 0.80, 1.00),
  };

  const bezelDash = 232 * (1 - easeOutCubic(p.bezel));

  // Monogram entrance
  const monoT = easeOutBack(p.mono, 1.6);
  const monoEntranceOpacity = easeOutCubic(p.mono);

  // Monogram compression — when agents converge at the center, the mono glows
  const compress = compressionIntensity(cycle);
  const monoCompressScale = 1 + compress * 0.05;
  const monoGlow = compress > 0.15
    ? `drop-shadow(0 0 ${compress * 5}px ${COLORS.lime}aa)`
    : "none";

  // Hash strip emit pulse — brightens at the moment of emission
  const emitWindow = (cycle >= 0.78 && cycle <= 1.0)
    ? Math.sin(((cycle - 0.78) / 0.22) * Math.PI)
    : 0;
  const receiptBase = easeOutCubic(p.receipt) * 0.55;
  const receiptOpacity = receiptBase + emitWindow * 0.45;

  // Bezel notch glow — when an agent crosses a notch midpoint, that notch flares
  // For seamless loop, sum contributions from all 12 particles' ingress moments.
  const notchGlow = (() => {
    // 4 entry sides — find brightest per side based on which particles are at their ingress moment
    const sides = [0, 0, 0, 0];
    for (let i = 0; i < 12; i++) {
      const t = (cycle + i / 12) % 1;
      if (t >= 0.50 && t <= 0.62) {
        const strength = Math.sin(((t - 0.50) / 0.12) * Math.PI);
        sides[i % 4] = Math.max(sides[i % 4], strength);
      }
    }
    return sides;
  })();

  const zkT = easeOutBack(p.zk, 1.8);
  const tickXs = [32, 35, 38, 41, 44, 47, 50, 53, 56];

  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 64 64"
      role="img"
      aria-label="xB77 receipt seal"
      style={{ display: "block" }}
    >
      <defs>
        <linearGradient id={`${idScope}-g`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%"   stopColor={COLORS.lime}/>
          <stop offset="55%"  stopColor={COLORS.midGreen}/>
          <stop offset="100%" stopColor={COLORS.cyan}/>
        </linearGradient>
        <radialGradient id={`${idScope}-center-glow`} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0%"   stopColor={COLORS.lime} stopOpacity={compress * 0.35}/>
          <stop offset="60%"  stopColor={COLORS.lime} stopOpacity={compress * 0.10}/>
          <stop offset="100%" stopColor={COLORS.lime} stopOpacity="0"/>
        </radialGradient>
      </defs>

      {/* Plate */}
      <rect width="64" height="64" rx="10" fill={COLORS.bg}/>

      {/* Center halo during compression — a soft radial light blooming from the monogram */}
      {compress > 0.05 && (
        <circle cx="32" cy="36" r="22" fill={`url(#${idScope}-center-glow)`}/>
      )}

      {/* Bezel — chamfered double-rule */}
      <rect
        x="3" y="3" width="58" height="58" rx="7"
        fill="none"
        stroke={`url(#${idScope}-g)`}
        strokeWidth="1.2"
        strokeDasharray="232"
        strokeDashoffset={bezelDash}
        opacity={0.85 * easeOutCubic(Math.min(1, p.bezel * 2))}
      />
      <rect
        x="5.5" y="5.5" width="53" height="53" rx="5.5"
        fill="none"
        stroke={COLORS.cyan}
        strokeWidth="0.4"
        opacity={0.22 * easeOutCubic(p.bezel)}
      />

      {/* Notch glow markers — small bright dots at the 4 ingress points when an agent crosses */}
      {notchGlow[0] > 0.05 && <circle cx="32" cy="3"  r={0.9 + notchGlow[0] * 0.8} fill={COLORS.lime} opacity={notchGlow[0]}/>}
      {notchGlow[1] > 0.05 && <circle cx="61" cy="32" r={0.9 + notchGlow[1] * 0.8} fill={COLORS.lime} opacity={notchGlow[1]}/>}
      {notchGlow[2] > 0.05 && <circle cx="32" cy="61" r={0.9 + notchGlow[2] * 0.8} fill={COLORS.lime} opacity={notchGlow[2]}/>}
      {notchGlow[3] > 0.05 && <circle cx="3"  cy="32" r={0.9 + notchGlow[3] * 0.8} fill={COLORS.lime} opacity={notchGlow[3]}/>}

      {/* Particles — the agent stream. Rendered behind the monogram so the mono sits on top. */}
      <Particles cycle={cycle} idScope={`${idScope}-particles`}/>

      {/* Monogram (with compression glow + entrance scale) */}
      <g
        opacity={monoEntranceOpacity}
        transform={`translate(32 38) scale(${(0.92 + 0.13 * monoT) * monoCompressScale}) translate(-32 -38) translate(0 ${-6 * (1 - monoT)})`}
        style={{ filter: monoGlow } as React.CSSProperties}
      >
        <text
          x="32" y="38"
          textAnchor="middle"
          fontFamily={FONTS.mono}
          fontWeight="900"
          fontSize="18"
          letterSpacing="-1.2"
          fill={`url(#${idScope}-g)`}
        >
          xB77
        </text>
      </g>

      {/* Receipt hash strip — pulses at emit */}
      <text
        x="7.5" y="58.5"
        fontFamily={FONTS.mono}
        fontSize="2.6"
        fill={COLORS.cyan}
        opacity={Math.min(1, receiptOpacity)}
        letterSpacing="0.4"
      >
        0x77b…a9f
      </text>

      {/* Chronograph tick strip */}
      <g
        stroke={COLORS.lime}
        strokeWidth="0.9"
        strokeLinecap="round"
      >
        {tickXs.map((x, i) => {
          const localProg = slice(progress, 0.55 + i * 0.018, 0.55 + i * 0.018 + 0.12);
          const opacity = easeOutCubic(localProg) * (i === 0 ? 0.9 : 0.65);
          const tall = i === 0;
          return (
            <line
              key={x}
              x1={x} y1={tall ? 56.5 : (i % 2 === 0 ? 57.5 : 58.0)}
              x2={x} y2={60.5}
              opacity={opacity}
            />
          );
        })}
      </g>

      {/* ZK ✓ badge */}
      <g
        transform={`translate(44.5 7) scale(${0.6 + 0.45 * zkT}) translate(0 ${-2 * (1 - zkT)})`}
        opacity={easeOutCubic(p.zk)}
        style={{ transformOrigin: "51px 11px", transformBox: "fill-box" } as React.CSSProperties}
      >
        <rect width="13" height="8" rx="1.5"
              fill="none" stroke={COLORS.lime} strokeWidth="0.6" opacity="0.85"/>
        <text x="3.2" y="5.8"
              fontFamily={FONTS.mono}
              fontWeight="700" fontSize="4.2"
              fill={COLORS.lime}>ZK</text>
        <path d="M8.4 4.3 L9.5 5.5 L11.2 3.2"
              stroke={COLORS.lime} strokeWidth="0.8"
              strokeLinecap="round" strokeLinejoin="round" fill="none"/>
      </g>
    </svg>
  );
};
