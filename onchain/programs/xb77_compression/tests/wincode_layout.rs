// Validates the exact byte layout of CompressionInstruction::VerifyTransition
// when serialized via wincode. The Zig client (compression-e2e) must produce
// identical bytes. Run with: cargo test --test wincode_layout -- --nocapture
//
// This test also prints the precomputed Poseidon hash for the minimal payload
// (siblings=[]), which Zig will hardcode as `new_root` to make the program
// accept the proof.

use xb77_compression::{CompressionInstruction, VerifyTransitionPayload};
use solana_poseidon::{hashv, Endianness, Parameters};

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{:02x}", b)).collect::<Vec<_>>().join("")
}

fn u128_to_be32(v: u128) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[16..32].copy_from_slice(&v.to_be_bytes());
    out
}

#[test]
fn dump_minimal_verify_transition_bytes() {
    // Minimal payload: 1 leaf, no siblings → new_root == leaf hash.
    let amount: u64 = 1;
    let ty: u8 = 0;
    let tx_hash = [0u8; 32];

    // Precompute new_leaf = Poseidon([(amount<<8)|type, tx_hash])  via syscall
    let amount_combined: u128 = ((amount as u128) << 8) | (ty as u128);
    let amt_bytes = u128_to_be32(amount_combined);
    let new_leaf_bytes: [u8; 32] = hashv(
        Parameters::Bn254X5,
        Endianness::BigEndian,
        &[&amt_bytes, &tx_hash],
    )
    .expect("poseidon hashv")
    .to_bytes();

    let payload = VerifyTransitionPayload {
        old_root: [0u8; 32], // verify_transition does NOT check old_root
        new_root: new_leaf_bytes,
        index: 0,
        siblings: Vec::new(),
        leaf_preimage_amount: amount,
        leaf_preimage_type: ty,
        leaf_preimage_tx_hash: tx_hash,
    };

    // Sanity check: the program's verifier accepts this payload
    assert!(
        xb77_compression::verify_transition(&payload),
        "verify_transition rejected our hand-crafted minimal payload"
    );

    let ix = CompressionInstruction::VerifyTransition(payload);
    let bytes = wincode::serialize(&ix).expect("wincode serialize");

    println!();
    println!("==== VerifyTransition (minimal) wincode bytes ====");
    println!("hex_len = {}", bytes.len());
    println!("hex     = {}", hex(&bytes));
    println!("new_leaf= {}", hex(&new_leaf_bytes));
    println!("---- offsets ----");
    let mut off = 0;
    let slice = |from: usize, to: usize| hex(&bytes[from..to]);
    println!("  [{:3}..{:3}] discriminant  = {}", off, off+1, slice(off, off+1)); off += 1;
    println!("  [{:3}..{:3}] old_root[32]  = {}", off, off+32, slice(off, off+32)); off += 32;
    println!("  [{:3}..{:3}] new_root[32]  = {}", off, off+32, slice(off, off+32)); off += 32;
    println!("  [{:3}..{:3}] index u64 LE  = {}", off, off+8, slice(off, off+8)); off += 8;
    // siblings: unknown length prefix. Print next 8 bytes to see what's there.
    let lookahead_end = (off + 8).min(bytes.len());
    println!("  [{:3}..{:3}] siblings??    = {} (peek)", off, lookahead_end, slice(off, lookahead_end));
    // Try compact-u16 (1 byte: 0x00 → 0 entries)
    let cu16_ok = bytes[off] == 0x00 && bytes[off+1] == 0x01;
    // Try u32 LE (4 bytes: 00 00 00 00)
    let u32_ok = &bytes[off..off+4] == &[0,0,0,0] && bytes[off+4] == 0x01;
    // Try u64 LE (8 bytes: 00 00 00 00 00 00 00 00)
    let u64_ok = &bytes[off..off+8] == &[0,0,0,0,0,0,0,0] && bytes[off+8] == 0x01;
    println!("  cu16 match? {}  u32 match? {}  u64 match? {}", cu16_ok, u32_ok, u64_ok);
    let prefix_len = if cu16_ok { 1 } else if u32_ok { 4 } else if u64_ok { 8 } else { 0 };
    println!("  siblings_prefix_len = {} bytes", prefix_len);
    off += prefix_len;
    println!("  [{:3}..{:3}] amount u64 LE = {}", off, off+8, slice(off, off+8)); off += 8;
    println!("  [{:3}..{:3}] type u8       = {}", off, off+1, slice(off, off+1)); off += 1;
    println!("  [{:3}..{:3}] tx_hash[32]   = {}", off, off+32, slice(off, off+32)); off += 32;
    println!("  total consumed = {} / {}", off, bytes.len());
    println!("==================================================");
}
