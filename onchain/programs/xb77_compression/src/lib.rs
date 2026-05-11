#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::vec::Vec;
use solana_program::{
    account_info::AccountInfo,
    entrypoint::ProgramResult,
    msg,
    pubkey::Pubkey,
    declare_id,
};
use wincode::{SchemaRead, SchemaWrite};
use solana_poseidon::{hashv, Endianness, Parameters};

declare_id!("6ZN4omyZdzbfmqSKacCUjVpTnLhYmUhabUu2jzo4EknN");

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct VerifyTransitionPayload {
    pub old_root: [u8; 32],
    pub new_root: [u8; 32],
    pub index: u64,
    pub siblings: Vec<[u8; 32]>,
    pub leaf_preimage_amount: u64,
    pub leaf_preimage_type: u8,
    pub leaf_preimage_tx_hash: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum CompressionInstruction {
    /// Verify a state transition by recomputing the leaf via Poseidon BN254 (circomlib t=3)
    /// and walking the Merkle proof up to `new_root`.
    VerifyTransition(VerifyTransitionPayload),
}

#[cfg(not(feature = "no-entrypoint"))]
use solana_program::entrypoint;
#[cfg(not(feature = "no-entrypoint"))]
entrypoint!(process_instruction);

pub fn process_instruction(
    _program_id: &Pubkey,
    _accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction: CompressionInstruction = wincode::deserialize(instruction_data)
        .map_err(|_| solana_program::program_error::ProgramError::InvalidInstructionData)?;

    match instruction {
        CompressionInstruction::VerifyTransition(payload) => {
            if verify_transition(&payload) {
                msg!("Compression: Transition Verified via Poseidon BN254 (syscall).");
                Ok(())
            } else {
                msg!("Compression: Transition Verification FAILED.");
                Err(solana_program::program_error::ProgramError::ArithmeticOverflow)
            }
        }
    }
}

/// 32-byte big-endian field element from a u128 (zero-padded high bytes).
fn u128_to_be32(v: u128) -> [u8; 32] {
    let mut out = [0u8; 32];
    out[16..32].copy_from_slice(&v.to_be_bytes());
    out
}

pub fn verify_transition(payload: &VerifyTransitionPayload) -> bool {
    // 1. Leaf = Poseidon([(amount<<8) | type, tx_hash])
    let amount_combined = ((payload.leaf_preimage_amount as u128) << 8)
        | (payload.leaf_preimage_type as u128);
    let amt_bytes = u128_to_be32(amount_combined);

    let leaf = match hashv(
        Parameters::Bn254X5,
        Endianness::BigEndian,
        &[&amt_bytes, &payload.leaf_preimage_tx_hash],
    ) {
        Ok(h) => h.to_bytes(),
        Err(_) => return false,
    };

    // 2. Merkle climb to new_root.
    let mut current: [u8; 32] = leaf;
    for (i, sibling) in payload.siblings.iter().enumerate() {
        let node_is_right = (payload.index >> i) & 1 == 1;
        let next = if node_is_right {
            hashv(
                Parameters::Bn254X5,
                Endianness::BigEndian,
                &[&sibling[..], &current[..]],
            )
        } else {
            hashv(
                Parameters::Bn254X5,
                Endianness::BigEndian,
                &[&current[..], &sibling[..]],
            )
        };
        current = match next {
            Ok(h) => h.to_bytes(),
            Err(_) => return false,
        };
    }

    current == payload.new_root
}
