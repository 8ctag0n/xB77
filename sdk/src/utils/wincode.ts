import { PublicKey } from '@solana/web3.js';
import { Buffer } from 'buffer';
import * as borsh from '@coral-xyz/borsh';

export class WincodeSerializer {
  private buffer: Buffer;
  private offset: number;

  constructor(size: number = 1024) {
    this.buffer = Buffer.alloc(size);
    this.offset = 0;
  }

  get data(): Buffer {
    return this.buffer.slice(0, this.offset);
  }

  private grow(needed: number) {
    if (this.offset + needed > this.buffer.length) {
      const newSize = Math.max(this.buffer.length * 2, this.offset + needed);
      const newBuffer = Buffer.alloc(newSize);
      this.buffer.copy(newBuffer);
      this.buffer = newBuffer;
    }
  }

  writeU8(val: number) {
    this.grow(1);
    this.buffer.writeUInt8(val, this.offset);
    this.offset += 1;
  }

  writeU16(val: number) {
    this.grow(2);
    this.buffer.writeUInt16LE(val, this.offset);
    this.offset += 2;
  }

  writeU32(val: number) {
    this.grow(4);
    this.buffer.writeUInt32LE(val, this.offset);
    this.offset += 4;
  }

  writeU64(val: bigint | number) {
    this.grow(8);
    this.buffer.writeBigUInt64LE(BigInt(val), this.offset);
    this.offset += 8;
  }

  writeI64(val: bigint | number) {
    this.grow(8);
    this.buffer.writeBigInt64LE(BigInt(val), this.offset);
    this.offset += 8;
  }

  writeBool(val: boolean) {
    this.writeU8(val ? 1 : 0);
  }

  writeBuffer(buf: Buffer) {
    this.grow(buf.length);
    buf.copy(this.buffer, this.offset);
    this.offset += buf.length;
  }

  writeFixedArray(buf: Buffer | number[], length: number) {
    const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
    if (b.length !== length) {
      throw new Error(`Expected fixed array of length ${length}, got ${b.length}`);
    }
    this.writeBuffer(b);
  }

  // Wincode (Bincode) default uses u64 for lengths
  writeLength(len: number) {
    this.writeU64(len);
  }

  writeVec(buf: Buffer) {
    this.writeLength(buf.length);
    this.writeBuffer(buf);
  }

  writeString(str: string) {
    const buf = Buffer.from(str, 'utf8');
    this.writeVec(buf);
  }

  writeOption<T>(val: T | null | undefined, writer: (v: T) => void) {
    if (val !== null && val !== undefined) {
      this.writeU8(1);
      writer(val);
    } else {
      this.writeU8(0);
    }
  }

  writePubkey(pk: PublicKey) {
    this.writeFixedArray(pk.toBuffer(), 32);
  }
}

// Helper to match wincode's enum serialization
// Enum variant is likely u8 in wincode for small enums, checking strictness later.
// But mostly u32 is safer for bincode compat?
// NOTE: wincode doc said "bincode compatible". Standard bincode uses u32 for enum variants!
// BUT `borsh` uses u8.
// Since `solana-short-vec` is used, maybe it attempts to be compact.
// Let's assume u32 for Enums unless we find evidence otherwise.
// WAIT. If I check `xb77_gateway` -> `check_badge_verified`, I might find offsets.
// Actually, in `xb77_receipts` (Borsh), it's u8.
// In `xb77_core` (Wincode), let's assume `u32` because bincode default is `u32`.
// I will start with `u32` for variants. If it fails, I'll switch to `u8`.

export function serializeEnumVariant(variant: number): Buffer {
    const buf = Buffer.alloc(4);
    buf.writeUInt32LE(variant, 0);
    return buf;
}

// Actually, `wincode` might use `u8` if `#[derive(SchemaWrite)]` optimizes.
// Let's search if `wincode` supports `u8` enums.
// For now, I'll use `writeU32` for discriminators in the generated code.

