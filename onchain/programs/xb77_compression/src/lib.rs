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
use light_poseidon::{Poseidon, PoseidonHasher, bn254::FieldElement};

declare_id!("Comp111111111111111111111111111111111111111");

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
    /// Verify a state transition from Root A to Root B using Poseidon
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
                msg!("Compression: Transition Verified via Poseidon BN254.");
                Ok(())
            } else {
                msg!("Compression: Transition Verification FAILED.");
                Err(solana_program::program_error::ProgramError::ArithmeticOverflow)
            }
        }
    }
}

pub fn verify_transition(payload: &VerifyTransitionPayload) -> bool {
    // 1. Reconstruir el leaf nuevo usando Poseidon (misma lógica que store.zig)
    // amount_combined = (amount << 8) | type
    let amount_combined = ((payload.leaf_preimage_amount as u128) << 8) | (payload.leaf_preimage_type as u128);
    
    let mut hasher = Poseidon::new_v1();
    
    // Hash2: [amount_combined, tx_hash]
    let input = [
        FieldElement::from_u128(amount_combined),
        FieldElement::from_be_bytes_mod_order(&payload.leaf_preimage_tx_hash),
    ];
    
    let new_leaf = match hasher.hash(&input) {
        Ok(h) => h.to_be_bytes(),
        Err(_) => return false,
    };

    // 2. Verificar Merkle Proof
    let mut current = new_leaf;
    for (i, sibling) in payload.siblings.iter().enumerate() {
        let node_is_right = (payload.index >> i) & 1 == 1;
        
        let left = if node_is_right { sibling } else { &current };
        let right = if node_is_right { &current } else { sibling };
        
        let hash_input = [
            FieldElement::from_be_bytes_mod_order(left),
            FieldElement::from_be_bytes_mod_order(right),
        ];
        
        current = match hasher.hash(&hash_input) {
            Ok(h) => h.to_be_bytes(),
            Err(_) => return false,
        };
    }
    
    current == payload.new_root
}
