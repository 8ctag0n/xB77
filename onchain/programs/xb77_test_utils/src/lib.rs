#![allow(unexpected_cfgs)]

use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint,
    entrypoint::ProgramResult,
    keccak,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
};

entrypoint!(process_instruction);

// Instruction layout:
// - If data is 33 bytes and data[0] == 1, treat as SetSwProof.
//   data[1..33] is the nullifier (32 bytes).
// - Otherwise, this program acts as a no-op verifier/MXE/receipt stub and returns Ok.

pub fn process_instruction(
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() == 33 && instruction_data[0] == 1 {
        return set_sw_proof(accounts, &instruction_data[1..33]);
    }

    msg!("xb77_test_utils: noop (verifier/mxe/receipt stub)");
    Ok(())
}

fn set_sw_proof(accounts: &[AccountInfo], nullifier: &[u8]) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let signer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::NotEnoughAccountKeys)?;
    let sw_proof_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::NotEnoughAccountKeys)?;

    if !signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    if !sw_proof_account.is_writable {
        return Err(ProgramError::InvalidAccountData);
    }

    let mut data = sw_proof_account.try_borrow_mut_data()?;
    if data.len() < 88 {
        msg!("xb77_test_utils: sw_proof account too small");
        return Err(ProgramError::InvalidAccountData);
    }

    let hash = keccak::hash(nullifier);
    let mut nonce_bytes = [0u8; 8];
    nonce_bytes.copy_from_slice(&hash.to_bytes()[0..8]);

    data[80..88].copy_from_slice(&nonce_bytes);

    msg!("xb77_test_utils: sw_proof nonce written");
    Ok(())
}
