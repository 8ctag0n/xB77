#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::format;

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    declare_id,
    entrypoint::ProgramResult,
    msg,
    program::invoke_signed,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
};

use verifier_lib::{proof::Groth16Proof, verifier::Groth16Verifier, witness::Groth16Witness};

pub mod vk;
use vk::VK;

declare_id!("J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ");

#[cfg(not(feature = "no-entrypoint"))]
use solana_program::entrypoint;
#[cfg(not(feature = "no-entrypoint"))]
entrypoint!(process_instruction);

/// Buffer Header layout: [declared_len (4), written_len (4)]
const HEADER_LEN: usize = 8;

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.is_empty() {
        return Err(ProgramError::InvalidInstructionData);
    }

    let tag = instruction_data[0];
    match tag {
        0 => init(program_id, accounts, &instruction_data[1..]),
        1 => write(program_id, accounts, &instruction_data[1..]),
        2 => verify(program_id, accounts),
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

fn init(program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)?;
    let buffer = next_account_info(&mut accounts_iter)?;
    let system_program = next_account_info(&mut accounts_iter)?;

    if data.len() < 12 {
        return Err(ProgramError::InvalidInstructionData);
    }

    let salt = &data[0..8];
    let declared_len = u32::from_le_bytes(data[8..12].try_into().unwrap());

    let seeds: &[&[u8]] = &[b"proof_buf", payer.key.as_ref(), salt];
    let (expected_pda, bump) = Pubkey::find_program_address(seeds, program_id);
    if expected_pda != *buffer.key {
        return Err(ProgramError::InvalidSeeds);
    }

    let space = HEADER_LEN + declared_len as usize;
    let lamports = Rent::get()?.minimum_balance(space);

    msg!("[ZK-REAL] Creating buffer account for {} bytes", declared_len);
    
    invoke_signed(
        &solana_program::system_instruction::create_account(
            payer.key,
            buffer.key,
            lamports,
            space as u64,
            program_id,
        ),
        &[payer.clone(), buffer.clone(), system_program.clone()],
        &[&[b"proof_buf", payer.key.as_ref(), salt, &[bump]]],
    )?;
    
    let mut buf_data = buffer.data.borrow_mut();
    buf_data[0..4].copy_from_slice(&declared_len.to_le_bytes());
    buf_data[4..8].copy_from_slice(&0u32.to_le_bytes());

    Ok(())
}

fn write(_program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let _payer = next_account_info(&mut accounts_iter)?;
    let buffer = next_account_info(&mut accounts_iter)?;

    if data.len() < 4 {
        return Err(ProgramError::InvalidInstructionData);
    }

    let offset = u32::from_le_bytes(data[0..4].try_into().unwrap()) as usize;
    let chunk = &data[4..];

    let mut buf_data = buffer.data.borrow_mut();
    let declared_len = u32::from_le_bytes(buf_data[0..4].try_into().unwrap()) as usize;
    
    if offset + chunk.len() > declared_len {
        return Err(ProgramError::InvalidInstructionData);
    }

    let proof_start = HEADER_LEN + offset;
    buf_data[proof_start..proof_start + chunk.len()].copy_from_slice(chunk);
    
    let current_written = u32::from_le_bytes(buf_data[4..8].try_into().unwrap()) as usize;
    let new_written = core::cmp::max(current_written, offset + chunk.len());
    buf_data[4..8].copy_from_slice(&(new_written as u32).to_le_bytes());

    Ok(())
}

fn verify(_program_id: &Pubkey, accounts: &[AccountInfo]) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let _payer = next_account_info(&mut accounts_iter)?;
    let buffer = next_account_info(&mut accounts_iter)?;

    let buf_data = buffer.data.borrow();
    if buf_data.len() < HEADER_LEN {
        return Err(ProgramError::AccountDataTooSmall);
    }

    let declared_len = u32::from_le_bytes(buf_data[0..4].try_into().unwrap()) as usize;
    let written_len = u32::from_le_bytes(buf_data[4..8].try_into().unwrap()) as usize;

    if written_len < declared_len {
        msg!("[ZK-REAL] Error: Proof incomplete ({} / {} bytes)", written_len, declared_len);
        return Err(ProgramError::InvalidInstructionData);
    }

    let mut proof_bytes = &buf_data[HEADER_LEN..HEADER_LEN + declared_len];
    
    // --- REAL CRYPTOGRAPHIC VERIFICATION ---
    msg!("[ZK-REAL] Starting Groth16 verification...");
    msg!("[ZK-REAL] Total bytes received: {}", proof_bytes.len());

    // 1. Barretenberg Header Detection (4 bytes for num_inputs)
    // If it starts with [0, 0, 0, nr_pubinputs], it's a standard bb proof file.
    if proof_bytes.len() >= 4 && proof_bytes[0..4] == (VK.nr_pubinputs as u32).to_be_bytes() {
        msg!("[ZK-REAL] Detected Barretenberg header (4 bytes), skipping...");
        proof_bytes = &proof_bytes[4..];
    }

    let witness_size = VK.nr_pubinputs as usize * 32;
    let proof_size = 256; 

    // 2. Proof & Witness extraction
    // Barretenberg layout is typically [Witness] [Proof]
    // Sunspot legacy might have used [Proof] [Witness]
    let (proof, witness) = if proof_bytes.len() >= witness_size + proof_size {
        // Try Barretenberg layout: [Witness (32*N)] [Proof (256)]
        msg!("[ZK-REAL] Attempting Barretenberg layout [Witness][Proof]");
        let w = Groth16Witness::from_bytes(&proof_bytes[0..witness_size]).map_err(|_| {
            msg!("[ZK-REAL] Failed to parse Groth16Witness (BB-style)");
            ProgramError::InvalidInstructionData
        })?;
        let p = Groth16Proof::from_bytes(&proof_bytes[witness_size..witness_size + proof_size]).map_err(|_| {
            msg!("[ZK-REAL] Failed to parse Groth16Proof (BB-style)");
            ProgramError::InvalidInstructionData
        })?;
        (p, w)
    } else if proof_bytes.len() >= proof_size {
        // Fallback to Legacy layout: [Proof (256)] [Witness (...)]
        msg!("[ZK-REAL] Attempting Legacy layout [Proof][Witness]");
        let p = Groth16Proof::from_bytes(&proof_bytes[0..proof_size]).map_err(|_| {
            msg!("[ZK-REAL] Failed to parse Groth16Proof (Legacy)");
            ProgramError::InvalidInstructionData
        })?;
        let w = Groth16Witness::from_bytes(&proof_bytes[proof_size..]).map_err(|_| {
            msg!("[ZK-REAL] Failed to parse Groth16Witness (Legacy)");
            ProgramError::InvalidInstructionData
        })?;
        (p, w)
    } else {
        msg!("[ZK-REAL] Error: Proof bytes too short (expected at least 256)");
        return Err(ProgramError::InvalidInstructionData);
    };

    let mut verifier: Groth16Verifier<1> = Groth16Verifier::new(&VK);
    
    match verifier.verify(proof, witness) {
        Ok(_) => {
            msg!("[ZK-REAL] VERDICT: GREEN (Verified Cryptographically)");
            Ok(())
        },
        Err(_) => {
            msg!("[ZK-REAL] VERDICT: RED (Verification Failed)");
            Err(ProgramError::InvalidInstructionData)
        }
    }
}
