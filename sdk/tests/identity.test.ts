import { test, expect } from 'bun:test';
import { IdentityManager } from '../src/identity/manager';

test('IdentityManager proveAccess returns true', async () => {
  const manager = new IdentityManager();
  await expect(manager.proveAccess()).resolves.toBe(true);
});

test('IdentityManager verify returns true', async () => {
  const manager = new IdentityManager();
  await expect(manager.verify({})).resolves.toBe(true);
});
