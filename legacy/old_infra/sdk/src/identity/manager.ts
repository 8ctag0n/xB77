import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export type IdentityInput = {
  secret: string;
  salt: string;
  orderId: string;
  path: string[];
  merkleIndex: string;
  nullifier?: string;
};

export type IdentityProof = {
  proof: Uint8Array;
  publicWitness: Uint8Array;
  merkleRootHex: string;
  merkleIndex: number;
  orderId: string;
  nullifierHex: string;
};

export type IdentityManagerOptions = {
  proofPath?: string;
  publicWitnessPath?: string;
  metaPath?: string;
  autoGenerate?: boolean;
  inputIndex?: number;
  verifier?: (proof: IdentityProof) => Promise<boolean>;
};

const SDK_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..'
);
const REPO_ROOT = path.resolve(SDK_ROOT, '..');

const DEFAULT_PROOF_PATH = path.join(
  REPO_ROOT,
  'circuits',
  'agent_badge',
  'target',
  'agent_badge.proof'
);
const DEFAULT_WITNESS_PATH = path.join(
  REPO_ROOT,
  'circuits',
  'agent_badge',
  'target',
  'agent_badge.pw'
);
const DEFAULT_META_PATH = path.join(REPO_ROOT, 'sdk', 'target', 'agent_badge.meta.json');

function loadMeta(metaPath: string) {
  const raw = readFileSync(metaPath, 'utf8');
  const meta = JSON.parse(raw) as {
    merkle_root_hex: string;
    merkle_index: string;
    order_id?: string;
    nullifier?: string;
    nullifier_hex?: string;
  };

  return {
    merkleRootHex: meta.merkle_root_hex,
    merkleIndex: Number(meta.merkle_index),
    orderId: meta.order_id ?? '',
    nullifierHex: meta.nullifier_hex ?? (meta.nullifier ? `0x${BigInt(meta.nullifier).toString(16)}` : '')
  };
}

function ensureProofArtifacts(
  proofPath: string,
  witnessPath: string,
  metaPath: string,
  autoGenerate: boolean,
  inputIndex: number
) {
  const missing =
    !existsSync(proofPath) || !existsSync(witnessPath) || !existsSync(metaPath);

  if (!missing) {
    return;
  }

  if (!autoGenerate) {
    throw new Error(
      [
        'Missing identity proof artifacts.',
        `proof: ${proofPath}`,
        `witness: ${witnessPath}`,
        `meta: ${metaPath}`,
        'Generate them with:',
        `  bun run ${path.join('sdk', 'scripts', 'generate_badge_proof.ts')} ${inputIndex}`
      ].join('\n')
    );
  }

  const scriptPath = path.join(SDK_ROOT, 'scripts', 'generate_badge_proof.ts');
  const result = spawnSync('bun', [scriptPath, String(inputIndex)], {
    stdio: 'inherit'
  });
  if (result.status !== 0) {
    throw new Error('Proof generation failed (sunspot).');
  }
}

export class IdentityManager {
  private options: IdentityManagerOptions;

  constructor(options: IdentityManagerOptions = {}) {
    this.options = options;
  }

  async proveAccess(): Promise<IdentityProof> {
    const proofPath = this.options.proofPath ?? DEFAULT_PROOF_PATH;
    const witnessPath = this.options.publicWitnessPath ?? DEFAULT_WITNESS_PATH;
    const metaPath = this.options.metaPath ?? DEFAULT_META_PATH;
    const autoGenerate = this.options.autoGenerate ?? process.env.XB77_IDENTITY_AUTOGEN === 'true';
    const inputIndex =
      this.options.inputIndex ??
      (process.env.XB77_IDENTITY_INPUT_INDEX
        ? Number(process.env.XB77_IDENTITY_INPUT_INDEX)
        : 0);

    ensureProofArtifacts(proofPath, witnessPath, metaPath, autoGenerate, inputIndex);

    const meta = loadMeta(metaPath);
    const proof = new Uint8Array(readFileSync(proofPath));
    const publicWitness = new Uint8Array(readFileSync(witnessPath));

    if (!proof.length || !publicWitness.length) {
      throw new Error('Proof artifacts are empty.');
    }

    return {
      proof,
      publicWitness,
      merkleRootHex: meta.merkleRootHex,
      merkleIndex: meta.merkleIndex,
      orderId: meta.orderId,
      nullifierHex: meta.nullifierHex
    };
  }

  async verify(proof: IdentityProof): Promise<boolean> {
    if (!this.options.verifier) {
      throw new Error(
        'No verifier configured. Use an on-chain verifier program or provide a verifier callback.'
      );
    }
    return await this.options.verifier(proof);
  }
}
