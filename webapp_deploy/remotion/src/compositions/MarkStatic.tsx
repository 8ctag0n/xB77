import React from "react";
import { AbsoluteFill } from "remotion";
import { Seal } from "../components/Seal";
import { COLORS } from "../theme";

/** Single-frame composition. Used as the static export source for logo-deluxe.svg / favicon-scale PNG. */
export const MarkStatic: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.bg, alignItems: "center", justifyContent: "center" }}>
      <Seal size={512} progress={1} cycle={0.72} idScope="mark-static"/>
    </AbsoluteFill>
  );
};
