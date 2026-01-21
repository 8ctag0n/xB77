import { test, expect } from 'bun:test';
import {
  buildReceiptInstructionData,
  serializeValidityProof,
} from '../src/economy/receipts_light';

test('buildReceiptInstructionData prefixes discriminator', () => {
  const payload = new Uint8Array([1, 2, 3]);
  const data = buildReceiptInstructionData('record', payload);

  expect(data[0]).toBe(0);
  expect(Array.from(data.slice(1))).toEqual([1, 2, 3]);
});

test('serializeValidityProof handles null proof', () => {
  const bytes = serializeValidityProof(null);
  expect(bytes.length).toBeGreaterThan(0);
});
