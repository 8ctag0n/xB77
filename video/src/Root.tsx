import React from "react";
import { Composition } from "remotion";
import { XB77Composition } from "./Composition";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="XB77Demo"
        component={XB77Composition}
        durationInFrames={1800}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
