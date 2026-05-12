import React from "react";
import { spring, useCurrentFrame, useVideoConfig } from "remotion";
import { COLORS, FONTS } from "../../theme";

export type SubtitleBandProps = {
  title: string;
  subtitle?: string;
  position?: "lower-third" | "top" | "center";
};

export const SubtitleBand: React.FC<SubtitleBandProps> = ({
  title,
  subtitle,
  position = "lower-third",
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames, width } = useVideoConfig();

  const inProgress = spring({ frame, fps, durationInFrames: 18, config: { damping: 16, stiffness: 180 } });
  const outProgress = spring({
    frame: frame - (durationInFrames - 20),
    fps,
    durationInFrames: 16,
    config: { damping: 18, stiffness: 200 },
  });
  const opacity = Math.min(inProgress, 1 - outProgress);
  const slide = (1 - inProgress) * 24;

  const top =
    position === "lower-third" ? "78%" :
    position === "top"         ? "12%" :
                                 "46%";

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top,
        transform: `translateY(${slide}px)`,
        opacity,
        textAlign: "center",
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          display: "inline-block",
          padding: "14px 28px",
          background: "rgba(8,8,10,0.74)",
          borderTop: `1px solid ${COLORS.lime}`,
          borderBottom: `1px solid ${COLORS.cyan}`,
          backdropFilter: "blur(8px)",
          minWidth: Math.min(width * 0.5, 720),
        }}
      >
        <div
          style={{
            fontFamily: FONTS.mono,
            fontSize: 32,
            fontWeight: 900,
            color: COLORS.lime,
            letterSpacing: "0.12em",
            textTransform: "uppercase",
            lineHeight: 1.1,
          }}
        >
          {title}
        </div>
        {subtitle ? (
          <div
            style={{
              marginTop: 6,
              fontFamily: FONTS.sans,
              fontSize: 20,
              color: COLORS.textDim,
              letterSpacing: "0.02em",
            }}
          >
            {subtitle}
          </div>
        ) : null}
      </div>
    </div>
  );
};
