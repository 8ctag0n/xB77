use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    program::{invoke_signed},
    pubkey::Pubkey,
    rent::Rent,
    system_instruction,
    system_program,
};

use crate::error::GatewayError;
use crate::instruction::{GatewayInstruction, InitGatewayPayload, UpdateGatewayPayload};
use crate::state::{GatewayConfig, GATEWAY_STATE_SEED};

const MERKLE_DEPTH: u32 = 3;
const MAX_LEAVES: u32 = 1 << MERKLE_DEPTH;

pub fn process_instruction(
    _program_id: &Pubkey,
    _accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction: GatewayInstruction = wincode::deserialize(instruction_data)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    match instruction {
        GatewayInstruction::InitGateway(payload) => {
            process_init_gateway(_program_id, _accounts, payload)
        }
        GatewayInstruction::UpdateGateway(payload) => {
            process_update_gateway(_program_id, _accounts, payload)
        }
        GatewayInstruction::VerifyBadge(payload) => {
            process_verify_badge(_program_id, _accounts, payload)
        }
        GatewayInstruction::ExecuteConfidentialTransfer { amount } => {
            msg!("execute_confidential_transfer: amount={}", amount);
            Ok(())
        }
        GatewayInstruction::RecordReceipt { receipt_hash: _ } => {
            msg!("record_receipt: stub");
            Ok(())
        }
    }
}

fn process_verify_badge(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: crate::instruction::ProofPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let gateway_state = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    let (expected_pda, _bump) = Pubkey::find_program_address(&[GATEWAY_STATE_SEED], program_id);
    if gateway_state.key != &expected_pda {
        return Err(GatewayError::InvalidGatewayStatePda.into());
    }

    if gateway_state.owner != program_id {
        return Err(GatewayError::InvalidGatewayStateOwner.into());
    }

    let config: GatewayConfig = wincode::deserialize(&gateway_state.data.borrow())
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    if payload.merkle_index >= MAX_LEAVES {
        return Err(GatewayError::InvalidMerkleIndex.into());
    }

    if payload.root != config.merkle_root {
        return Err(GatewayError::InvalidMerkleRoot.into());
    }

    if payload.proof.is_empty() {
        return Err(GatewayError::EmptyProof.into());
    }

    if payload.public_inputs.len() != 1 || payload.public_inputs[0] != payload.root {
        return Err(GatewayError::InvalidPublicInputs.into());
    }

    msg!("verify_badge: gateway_state seed={:?}", GATEWAY_STATE_SEED);
    msg!("verify_badge: proof bytes={}", payload.proof.len());
    msg!("verify_badge: merkle index={}", payload.merkle_index);
    msg!("verify_badge: merkle root matches config");
    Ok(())
}

fn process_update_gateway(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: UpdateGatewayPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let admin = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let gateway_state = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;

    if !admin.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    if !gateway_state.is_writable {
        return Err(GatewayError::GatewayStateNotWritable.into());
    }

    let (expected_pda, _bump) = Pubkey::find_program_address(&[GATEWAY_STATE_SEED], program_id);
    if gateway_state.key != &expected_pda {
        return Err(GatewayError::InvalidGatewayStatePda.into());
    }

    if gateway_state.owner != program_id {
        return Err(GatewayError::InvalidGatewayStateOwner.into());
    }

    let mut config: GatewayConfig = wincode::deserialize(&gateway_state.data.borrow())
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    if admin.key.to_bytes() != config.admin {
        return Err(GatewayError::InvalidGatewayAdmin.into());
    }

    config.merkle_root = payload.merkle_root;

    let serialized = wincode::serialize(&config)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;
    gateway_state
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("update_gateway: merkle root updated");
    Ok(())
}

fn process_init_gateway(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: InitGatewayPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let gateway_state = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let system_program_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    if !gateway_state.is_writable {
        return Err(GatewayError::GatewayStateNotWritable.into());
    }

    if system_program_account.key != &system_program::ID {
        return Err(GatewayError::InvalidSystemProgram.into());
    }

    let (expected_pda, bump) = Pubkey::find_program_address(&[GATEWAY_STATE_SEED], program_id);
    if gateway_state.key != &expected_pda {
        return Err(GatewayError::InvalidGatewayStatePda.into());
    }

    if gateway_state.owner == program_id && !gateway_state.data_is_empty() {
        return Err(GatewayError::GatewayStateAlreadyInitialized.into());
    }

    let config = GatewayConfig {
        admin: payload.admin,
        merkle_root: payload.merkle_root,
        bump,
    };
    let serialized = wincode::serialize(&config)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;
    let space = serialized.len();
    let rent = Rent::get()?;
    let lamports = rent.minimum_balance(space);

    if gateway_state.owner != program_id {
        let create_ix = system_instruction::create_account(
            payer.key,
            gateway_state.key,
            lamports,
            space as u64,
            program_id,
        );
        invoke_signed(
            &create_ix,
            &[payer.clone(), gateway_state.clone(), system_program_account.clone()],
            &[&[GATEWAY_STATE_SEED, &[bump]]],
        )?;
    }

    gateway_state
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("init_gateway: configured root and admin");
    Ok(())
}
