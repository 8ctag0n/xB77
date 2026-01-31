
import { array, option, struct, u16, u8, map } from '@coral-xyz/borsh';
import { Buffer } from 'buffer';

const CompressedProofLayout = struct([
  array(u8(), 32, 'a'),
  array(u8(), 64, 'b'),
  array(u8(), 32, 'c'),
]);

// OLD
const ValidityProofLayoutOld = struct([option(CompressedProofLayout, 'proof')]);

// NEW (BTreeMap<u32, CompressedProof>)
// In Borsh, a map is length (u32) then key (u32) then value (CompressedProof)
// But wait, if it's just a struct in Rust it might be different.

function test() {
    const proof = {
        a: new Array(32).fill(1),
        b: new Array(64).fill(2),
        c: new Array(32).fill(3)
    };

    const bufOld = Buffer.alloc(256);
    const lenOld = ValidityProofLayoutOld.encode({ proof }, bufOld);
    console.log("Old (Option):", bufOld.subarray(0, lenOld).toString('hex'));

    // Manual BTreeMap simulation
    const bufMap = Buffer.alloc(256);
    bufMap.writeUInt32LE(1, 0); // length 1
    bufMap.writeUInt32LE(0, 4); // key 0
    Buffer.from(proof.a).copy(bufMap, 8);
    Buffer.from(proof.b).copy(bufMap, 8 + 32);
    Buffer.from(proof.c).copy(bufMap, 8 + 32 + 64);
    const lenMap = 8 + 32 + 64 + 32;
    console.log("New (Map):", bufMap.subarray(0, lenMap).toString('hex'));
}

test();
