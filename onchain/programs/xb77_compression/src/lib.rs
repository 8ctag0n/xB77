#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::vec::Vec;
use solana_program::{
    account_info::{AccountInfo},
    entrypoint::ProgramResult,
    msg,
    pubkey::Pubkey,
    declare_id,
    keccak,
};
use wincode::{SchemaRead, SchemaWrite};

declare_id!("Comp111111111111111111111111111111111111111");

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct VerifyProofPayload {
    pub root: [u8; 32],
    pub leaf: [u8; 32],
    pub index: u64,
    pub proof: Vec<[u8; 32]>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum CompressionInstruction {
    VerifyProof(VerifyProofPayload),
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
        CompressionInstruction::VerifyProof(payload) => {
            if verify_proof(&payload.root, &payload.leaf, payload.index, &payload.proof) {
                msg!("Compression: Proof Verified successfully.");
                Ok(())
            } else {
                msg!("Compression: Proof Verification FAILED.");
                Err(solana_program::program_error::ProgramError::ArithmeticOverflow) // Dummy error
            }
        }
    }
}

pub fn verify_proof(root: &[u8; 32], leaf: &[u8; 32], index: u64, proof: &[[u8; 32]]) -> bool {
    let mut current = *leaf;
    for (i, sibling) in proof.iter().enumerate() {
        if (index >> i) & 1 == 1 {
            current = keccak::hashv(&[sibling, &current]).to_bytes();
        } else {
            current = keccak::hashv(&[&current, sibling]).to_bytes();
        }
    }
    &current == root
}
