import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildPoseidonReference } from "circomlibjs";

type Fixture = {
  inputs: Array<{
    secret: string;
    salt: string;
    path: string[];
    merkleIndex: string;
  }>;
};

function run(command: string, args: string[], cwd: string): void {
  const result = spawnSync(command, args, { cwd, stdio: "inherit" });
  if (result.status !== 0) {
    throw new Error(`Command failed: ${command} ${args.join(" ")}`);
  }
}

async function main() {
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  const rootDir = path.resolve(scriptDir, "../..");
  const circuitDir = path.join(rootDir, "circuits/agent_badge");
  const targetDir = path.join(circuitDir, "target");
  const outputDir = path.join(rootDir, "sdk/target");
  const fixturePath = path.join(rootDir, "sdk/fixtures/agent_badge_inputs.json");
  const proverTomlPath = path.join(circuitDir, "Prover.toml");

  const fixture = JSON.parse(readFileSync(fixturePath, "utf8")) as Fixture;
  const indexArg = process.env.INPUT_INDEX ?? process.argv[2] ?? "0";
  const inputIndex = Number(indexArg);
  if (!Number.isInteger(inputIndex) || inputIndex < 0 || inputIndex >= fixture.inputs.length) {
    throw new Error(`Invalid input index: ${indexArg}`);
  }

  const input = fixture.inputs[inputIndex];
  const poseidon = await buildPoseidonReference();
  const field = poseidon.F;
  const depth = 3;

  const secret = BigInt(input.secret);
  const salt = BigInt(input.salt);
  const pathValues = input.path.map((value) => BigInt(value));
  const merkleIndex = BigInt(input.merkleIndex);

  let current = poseidon([secret, salt]);
  for (let i = 0; i < depth; i += 1) {
    const bit = (merkleIndex >> BigInt(i)) & 1n;
    const sibling = pathValues[i];
    current = bit === 0n ? poseidon([current, sibling]) : poseidon([sibling, current]);
  }
  const root = field.toString(current);

  const tomlLines = [
    `root = "${root}"`,
    `agent_secret = "${input.secret}"`,
    `agent_salt = "${input.salt}"`,
    `merkle_path = [${input.path.map((value) => `"${value}"`).join(", ")}]`,
    `merkle_index = "${input.merkleIndex}"`,
  ];
  writeFileSync(proverTomlPath, `${tomlLines.join("\n")}\n`);

  console.log("Compiling circuit in container...");
  run(path.join(rootDir, "scripts/build-noir-artifacts.sh"), [], rootDir);

  console.log("Generating witness in container...");
  run(path.join(rootDir, "scripts/noir-execute.sh"), [], rootDir);

  const acirPath = path.join(targetDir, "agent_badge.json");
  const witnessPath = path.join(targetDir, "agent_badge.gz");
  const ccsPath = path.join(targetDir, "agent_badge.ccs");
  const pkPath = path.join(targetDir, "agent_badge.pk");
  const vkPath = path.join(targetDir, "agent_badge.vk");
  const proofPath = path.join(targetDir, "agent_badge.proof");
  const witnessPublicPath = path.join(targetDir, "agent_badge.pw");

  const sunspotScript = path.join(rootDir, "scripts/sunspot.sh");
  if (!existsSync(sunspotScript)) {
    throw new Error("Missing scripts/sunspot.sh.");
  }

  if (!existsSync(ccsPath)) {
    run(sunspotScript, ["compile", acirPath, ccsPath], rootDir);
  }
  if (!existsSync(pkPath) || !existsSync(vkPath)) {
    run(sunspotScript, ["setup", ccsPath, pkPath, vkPath], rootDir);
  }

  console.log("Generating Groth16 proof with Sunspot...");
  run(sunspotScript, ["prove", acirPath, witnessPath, ccsPath, pkPath], rootDir);

  const proof = readFileSync(proofPath);
  const publicWitness = readFileSync(witnessPublicPath);
  const instructionData = Buffer.concat([proof, publicWitness]);

  mkdirSync(outputDir, { recursive: true });
  const outputBin = path.join(outputDir, "agent_badge.instruction.bin");
  const outputB64 = path.join(outputDir, "agent_badge.instruction.b64");

  writeFileSync(outputBin, instructionData);
  writeFileSync(outputB64, instructionData.toString("base64"));

  console.log(`Proof bytes: ${proof.length}`);
  console.log(`Public witness bytes: ${publicWitness.length}`);
  console.log(`Instruction data bytes: ${instructionData.length}`);
  console.log(`Wrote ${outputBin}`);
  console.log(`Wrote ${outputB64}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
