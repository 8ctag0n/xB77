use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    instruction::Instruction,
    msg,
    program::invoke,
    program_error::ProgramError,
    program::invoke_signed,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::Sysvar,
    system_instruction,
    system_program,
};
use alloc::vec::Vec;
use alloc::format;
use alloc::vec;

use crate::error::GatewayError;
use crate::instruction::{GatewayInstruction, InitGatewayPayload, UpdateGatewayPayload};
use crate::state::{GatewayConfig, GATEWAY_STATE_SEED, NULLIFIER_SEED};

const MERKLE_DEPTH: u32 = 3;
const MAX_LEAVES: u32 = 1 << MERKLE_DEPTH;
const ZERO_PUBKEY: [u8; 32] = [0u8; 32];

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
        GatewayInstruction::SubmitPrivateOrder(payload) => {
            process_submit_private_order(_program_id, _accounts, payload)
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
    let zk_verifier = next_account_info(&mut accounts_iter)
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

    if payload.public_witness.is_empty() {
        return Err(GatewayError::EmptyPublicWitness.into());
    }

    // Skip CPI when verifier is not configured (all-zero pubkey).
    if config.zk_verifier != ZERO_PUBKEY {
        if zk_verifier.key.to_bytes() != config.zk_verifier {
            return Err(GatewayError::InvalidZkVerifier.into());
        }

        let mut verifier_data =
            Vec::with_capacity(payload.proof.len() + payload.public_witness.len());
        verifier_data.extend_from_slice(&payload.proof);
        verifier_data.extend_from_slice(&payload.public_witness);

        let verify_ix = Instruction {
            program_id: *zk_verifier.key,
            accounts: vec![],
            data: verifier_data,
        };
        invoke(&verify_ix, &[])?;
    }

    msg!("verify_badge: gateway_state seed={:?}", GATEWAY_STATE_SEED);
    msg!("verify_badge: proof bytes={}", payload.proof.len());
    msg!("verify_badge: merkle index={}", payload.merkle_index);
    msg!("verify_badge: merkle root matches config");
    Ok(())
}

fn process_submit_private_order(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: crate::instruction::SubmitPrivateOrderPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let gateway_state = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let nullifier_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let system_program_account = next_account_info(&mut accounts_iter)
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

    if system_program_account.key != &system_program::ID {
        return Err(GatewayError::InvalidSystemProgram.into());
    }

    if payload.order_id == 0 {
        return Err(GatewayError::InvalidOrderId.into());
    }

    if payload.amount == 0 {
        return Err(GatewayError::InvalidAmount.into());
    }

    if payload.token == ZERO_PUBKEY {
        return Err(GatewayError::InvalidToken.into());
    }

    if payload.recipient == ZERO_PUBKEY {
        return Err(GatewayError::InvalidRecipient.into());
    }

    if payload.nullifier == [0u8; 32] {
        return Err(GatewayError::InvalidNullifier.into());
    }

    let (expected_nullifier, bump) = Pubkey::find_program_address(
        &[NULLIFIER_SEED, &payload.nullifier],
        program_id,
    );
    if nullifier_account.key != &expected_nullifier {
        return Err(GatewayError::InvalidNullifierPda.into());
    }

    if nullifier_account.owner != &system_program::ID
        && nullifier_account.owner != program_id
    {
        return Err(GatewayError::InvalidNullifierPda.into());
    }

    if nullifier_account.lamports() > 0 || !nullifier_account.data_is_empty() {
        return Err(GatewayError::NullifierAlreadyUsed.into());
    }

    let space = 1usize;
    let rent = Rent::get()?;
    let lamports = rent.minimum_balance(space);
    let create_ix = system_instruction::create_account(
        payer.key,
        nullifier_account.key,
        lamports,
        space as u64,
        program_id,
    );
    invoke_signed(
        &create_ix,
        &[
            payer.clone(),
            nullifier_account.clone(),
            system_program_account.clone(),
        ],
        &[&[NULLIFIER_SEED, &payload.nullifier, &[bump]]],
    )?;
    nullifier_account.data.borrow_mut()[0] = 1;

    msg!("submit_private_order: order_id={}", payload.order_id);
    msg!("submit_private_order: amount={}", payload.amount);
    msg!(
        "submit_private_order: token={}",
        Pubkey::new_from_array(payload.token)
    );
    msg!(
        "submit_private_order: recipient={}",
        Pubkey::new_from_array(payload.recipient)
    );
    msg!(
        "submit_private_order: nullifier_prefix={:?}",
        &payload.nullifier[..8]
    );
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
        zk_verifier: payload.zk_verifier,
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
