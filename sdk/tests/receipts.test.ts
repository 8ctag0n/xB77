import { test, expect } from 'bun:test';
import {
  buildReceiptInstructionData,
  serializeCompressedAccountMeta,
  serializeValidityProof,
} from '../src/economy/receipts';

test('buildReceiptInstructionData prefixes discriminator', () => {
  const payload = new Uint8Array([1, 2, 3]);
  const data = buildReceiptInstructionData('create', payload);

  expect(data[0]).toBe(0);
  expect(Array.from(data.slice(1))).toEqual([1, 2, 3]);
});

test('serializeValidityProof handles null proof', () => {
  const bytes = serializeValidityProof(null);
  expect(bytes.length).toBeGreaterThan(0);
});

test('serializeCompressedAccountMeta rejects wrong address length', () => {
  const meta = {
    treeInfo: {
      rootIndex: 0,
      proveByIndex: false,
      merkleTreePubkeyIndex: 0,
      queuePubkeyIndex: 0,
      leafIndex: 0,
    },
    address: new Uint8Array(31),
    outputStateTreeIndex: 0,
  };

  expect(() => serializeCompressedAccountMeta(meta as any)).toThrow(
    'CompressedAccountMeta.address must be 32 bytes'
  );
});
