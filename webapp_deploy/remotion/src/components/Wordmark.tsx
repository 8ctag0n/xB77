import React from "react";
import { COLORS, FONTS } from "../theme";

export type WordmarkProps = {
  size?: number; // font-size in px
  opacity?: number;
  underlineProgress?: number; // 0..1, how far the rule under the wordmark is drawn
};

export const Wordmark: React.FC<WordmarkProps> = ({
  size = 148,
  opacity = 1,
  underlineProgress = 1,
}) => {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size * 4.3}
      height={size * 1.4}
      viewBox={`0 0 ${size * 4.3} ${size * 1.4}`}
      style={{ display: "block", opacity }}
    >
      <defs>
        <linearGradient id="wm-g" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%"   stopColor={COLORS.lime}/>
          <stop offset="60%"  stopColor={COLORS.midGreen}/>
          <stop offset="100%" stopColor={COLORS.cyan}/>
        </linearGradient>
        <linearGradient id="wm-rule" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%"   stopColor={COLORS.lime} stopOpacity="0"/>
          <stop offset="20%"  stopColor={COLORS.lime} stopOpacity="0.45"/>
          <stop offset="80%"  stopColor={COLORS.cyan} stopOpacity="0.45"/>
          <stop offset="100%" stopColor={COLORS.cyan} stopOpacity="0"/>
        </linearGradient>
      </defs>

      <text
        x="0" y={size * 0.85}
        fontFamily={FONTS.sans}
        fontWeight="700"
        fontSize={size}
        fill="url(#wm-g)"
        letterSpacing="-6"
      >
        xB77
      </text>

      <line
        x1="2"
        y1={size + 16}
        x2={2 + (size * 4.0) * Math.max(0, Math.min(1, underlineProgress))}
        y2={size + 16}
        stroke="url(#wm-rule)"
        strokeWidth="1.4"
      />
    </svg>
  );
};
