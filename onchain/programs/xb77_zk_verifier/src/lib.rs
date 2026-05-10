#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::vec::Vec;

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

declare_id!("J2Q44jasMJD8VNGFHkyk6U9uEf5Zt1gj7H5mEfmQ5UoJ");

#[cfg(not(feature = "no-entrypoint"))]
solana_program::entrypoint!(process_instruction);

const MIN_PROOF_LEN: u32 = 64;
const MAX_PROOF_LEN: u32 = 16 * 1024;
const HEADER_LEN: usize = 8; // u32 declared_len + u32 written_len

/// Instruction tags
const TAG_INIT: u8 = 0;
const TAG_WRITE: u8 = 1;
const TAG_VERIFY: u8 = 2;

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    data: &[u8],
) -> ProgramResult {
    if data.is_empty() {
        return Err(ProgramError::InvalidInstructionData);
    }
    match data[0] {
        TAG_INIT => init(program_id, accounts, &data[1..]),
        TAG_WRITE => write(program_id, accounts, &data[1..]),
        TAG_VERIFY => verify(program_id, accounts, &data[1..]),
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

fn buffer_seeds<'a>(payer: &'a Pubkey, salt: &'a [u8; 8]) -> [&'a [u8]; 3] {
    [b"proof_buf", payer.as_ref(), salt.as_ref()]
}

fn init(program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    // data: [salt: u8; 8 | declared_len: u32 LE]
    if data.len() != 12 {
        return Err(ProgramError::InvalidInstructionData);
    }
    let mut salt = [0u8; 8];
    salt.copy_from_slice(&data[..8]);
    let declared_len = u32::from_le_bytes([data[8], data[9], data[10], data[11]]);
    if !(MIN_PROOF_LEN..=MAX_PROOF_LEN).contains(&declared_len) {
        return Err(ProgramError::InvalidInstructionData);
    }

    let it = &mut accounts.iter();
    let payer = next_account_info(it)?;
    let buffer = next_account_info(it)?;
    let system_program = next_account_info(it)?;

    if !payer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let seeds = buffer_seeds(payer.key, &salt);
    let (expected, bump) = Pubkey::find_program_address(&seeds, program_id);
    if expected != *buffer.key {
        return Err(ProgramError::InvalidSeeds);
    }
    let space = HEADER_LEN + declared_len as usize;
    let lamports = Rent::get()?.minimum_balance(space);
    let create_ix = solana_system_interface::instruction::create_account(
        payer.key,
        buffer.key,
        lamports,
        space as u64,
        program_id,
    );
    let signer_seeds: &[&[u8]] = &[b"proof_buf", payer.key.as_ref(), salt.as_ref(), &[bump]];
    invoke_signed(
        &create_ix,
        &[payer.clone(), buffer.clone(), system_program.clone()],
        &[signer_seeds],
    )?;

    let mut buf = buffer.try_borrow_mut_data()?;
    buf[0..4].copy_from_slice(&declared_len.to_le_bytes());
    buf[4..8].copy_from_slice(&0u32.to_le_bytes());
    msg!("[ZK-JUDGE] buffer init: declared {} bytes", declared_len);
    Ok(())
}

fn write(_program_id: &Pubkey, accounts: &[AccountInfo], data: &[u8]) -> ProgramResult {
    // data: [offset: u32 LE | chunk bytes]
    if data.len() < 4 {
        return Err(ProgramError::InvalidInstructionData);
    }
    let offset = u32::from_le_bytes([data[0], data[1], data[2], data[3]]) as usize;
    let chunk = &data[4..];

    let it = &mut accounts.iter();
    let payer = next_account_info(it)?;
    let buffer = next_account_info(it)?;
    if !payer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let mut buf = buffer.try_borrow_mut_data()?;
    if buf.len() < HEADER_LEN {
        return Err(ProgramError::AccountDataTooSmall);
    }
    let declared = u32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]]) as usize;
    let start = HEADER_LEN + offset;
    let end = start + chunk.len();
    if end > HEADER_LEN + declared {
        return Err(ProgramError::InvalidInstructionData);
    }
    buf[start..end].copy_from_slice(chunk);
    let written = (offset + chunk.len()) as u32;
    let prev = u32::from_le_bytes([buf[4], buf[5], buf[6], buf[7]]);
    if written > prev {
        buf[4..8].copy_from_slice(&written.to_le_bytes());
    }
    msg!("[ZK-JUDGE] wrote {} bytes at offset {}", chunk.len(), offset);
    Ok(())
}

fn verify(_program_id: &Pubkey, accounts: &[AccountInfo], _data: &[u8]) -> ProgramResult {
    let it = &mut accounts.iter();
    let _payer = next_account_info(it)?;
    let buffer = next_account_info(it)?;

    let buf = buffer.try_borrow_data()?;
    if buf.len() < HEADER_LEN {
        return Err(ProgramError::AccountDataTooSmall);
    }
    let declared = u32::from_le_bytes([buf[0], buf[1], buf[2], buf[3]]) as usize;
    let written = u32::from_le_bytes([buf[4], buf[5], buf[6], buf[7]]) as usize;
    if written != declared {
        msg!("[ZK-JUDGE] proof incomplete: {}/{}", written, declared);
        return Err(ProgramError::InvalidInstructionData);
    }
    let proof = &buf[HEADER_LEN..HEADER_LEN + declared];
    let nonzero = proof.iter().filter(|b| **b != 0).count();
    if nonzero < declared / 4 {
        msg!("[ZK-JUDGE] proof entropy too low — REJECTED");
        return Err(ProgramError::InvalidInstructionData);
    }

    msg!(
        "[ZK-JUDGE] STUB-VERIFIER accepted proof of {} bytes (entropy={}). NOTE: cryptographic verification NOT performed by this stub.",
        declared,
        nonzero
    );
    msg!("[ZK-JUDGE] verdict: GREEN");
    Ok(())
}
