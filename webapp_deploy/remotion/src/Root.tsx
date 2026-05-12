import React from "react";
import { Composition } from "remotion";
import { MarkStatic } from "./compositions/MarkStatic";
import { WordmarkOG } from "./compositions/WordmarkOG";
import { HeroLoop } from "./compositions/HeroLoop";
import { LogoIntro } from "./compositions/LogoIntro";
import { DemoMaster } from "./compositions/DemoMaster";
import { FPS } from "./theme";

/**
 * Remotion entry — registers every composition the brand emits.
 *
 *   MarkStatic   square seal at 512x512, single frame → favicon / nav mark PNG
 *   WordmarkOG   social preview 1200x630, single frame → og:image PNG
 *   HeroLoop     6s seamless loop 800x300 → web hero animation
 *   LogoIntro    3s stamp animation 1920x1080 → pitch / hackathon intro MP4
 *
 * Run `npm run studio` to design, or `npm run render:all` to export everything.
 */
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="MarkStatic"
        component={MarkStatic}
        durationInFrames={1}
        fps={FPS}
        width={512}
        height={512}
      />

      <Composition
        id="WordmarkOG"
        component={WordmarkOG}
        durationInFrames={1}
        fps={FPS}
        width={1200}
        height={630}
      />

      <Composition
        id="HeroLoop"
        component={HeroLoop}
        durationInFrames={180}
        fps={FPS}
        width={800}
        height={300}
      />

      <Composition
        id="LogoIntro"
        component={LogoIntro}
        durationInFrames={90}
        fps={FPS}
        width={1920}
        height={1080}
      />

      <Composition
        id="DemoMaster"
        component={DemoMaster}
        durationInFrames={2700}
        fps={FPS}
        width={854}
        height={480}
      />
    </>
  );
};
