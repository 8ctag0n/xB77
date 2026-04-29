import { test, expect } from 'bun:test';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { IdentityManager } from '../src/identity/manager';

const SDK_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REPO_ROOT = path.resolve(SDK_ROOT, '..');

const proofPath = path.join(
  REPO_ROOT,
  'circuits',
  'agent_badge',
  'target',
  'agent_badge.proof'
);
const witnessPath = path.join(
  REPO_ROOT,
  'circuits',
  'agent_badge',
  'target',
  'agent_badge.pw'
);
const metaPath = path.join(REPO_ROOT, 'sdk', 'target', 'agent_badge.meta.json');

test('IdentityManager proveAccess returns proof artifacts when present', async () => {
  const manager = new IdentityManager({ autoGenerate: false });
  const hasArtifacts = existsSync(proofPath) && existsSync(witnessPath) && existsSync(metaPath);

  if (!hasArtifacts) {
    await expect(manager.proveAccess()).rejects.toThrow('Missing identity proof artifacts');
    return;
  }

  const proof = await manager.proveAccess();
  expect(proof.proof.length).toBeGreaterThan(0);
  expect(proof.publicWitness.length).toBeGreaterThan(0);
  expect(proof.merkleRootHex.length).toBeGreaterThan(0);
});

test('IdentityManager verify requires a verifier', async () => {
  const manager = new IdentityManager();
  const dummy = {
    proof: new Uint8Array([1]),
    publicWitness: new Uint8Array([1]),
    merkleRootHex: '0x' + '00'.repeat(32),
    merkleIndex: 0,
    orderId: '0',
    nullifierHex: '0x' + '00'.repeat(32),
  };
  await expect(manager.verify(dummy)).rejects.toThrow('No verifier configured');
});
