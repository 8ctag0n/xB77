use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::{clock::Clock, Sysvar},
};
extern crate alloc;
use alloc::format;

use crate::{
    error::CoreError,
    instruction::{CoreInstruction, InitCorePayload, RegisterAgentPayload, RequestPaymentPayload, VerifyAndCreditPayload},
    state::{CoreConfig, CreditLine},
};

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction: CoreInstruction = wincode::deserialize(instruction_data)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    match instruction {
        CoreInstruction::InitCore(payload) => process_init_core(program_id, accounts, payload),
        CoreInstruction::RegisterAgent(payload) => process_register_agent(program_id, accounts, payload),
        CoreInstruction::VerifyAndCredit(payload) => process_verify_and_credit(program_id, accounts, payload),
        CoreInstruction::RequestPayment(payload) => process_request_payment(program_id, accounts, payload),
    }
}

fn process_init_core(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: InitCorePayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let config_account = next_account_info(account_info_iter)?;
    let admin_signer = next_account_info(account_info_iter)?;

    if !admin_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // Determine expected PDA
    let (pda, _bump) = Pubkey::find_program_address(&[b"config"], program_id);
    if pda != *config_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    let config = CoreConfig {
        admin: payload.admin,
        gateway_program: payload.gateway_program,
        receipts_program: payload.receipts_program,
        treasury_mint: payload.treasury_mint,
    };

    let mut data = config_account.try_borrow_mut_data()?;
    let bytes = wincode::serialize(&config).map_err(|_| ProgramError::AccountDataTooSmall)?;
    
    // Simple copy, assume account is pre-allocated with enough space
    if data.len() < bytes.len() {
        return Err(ProgramError::AccountDataTooSmall);
    }
    data[..bytes.len()].copy_from_slice(&bytes);

    msg!("Core Config Initialized");
    Ok(())
}

fn process_register_agent(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: RegisterAgentPayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let config_account = next_account_info(account_info_iter)?;
    let credit_line_account = next_account_info(account_info_iter)?;
    let admin_signer = next_account_info(account_info_iter)?;

    // Validate Config
    if config_account.owner != program_id {
        return Err(ProgramError::InvalidAccountData);
    }
    let config_data = config_account.try_borrow_data()?;
    let config: CoreConfig = wincode::deserialize(&config_data).map_err(|_| ProgramError::InvalidAccountData)?;

    // Only Admin can register agents in Phase 1
    if *admin_signer.key != Pubkey::new_from_array(config.admin) || !admin_signer.is_signer {
        return Err(CoreError::NotAuthorized.into());
    }

    // Validate Credit Line PDA
    let agent_pubkey = Pubkey::new_from_array(payload.agent_id);
    let (pda, _bump) = Pubkey::find_program_address(
        &[b"credit_line", agent_pubkey.as_ref()], 
        program_id
    );
    if pda != *credit_line_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    let credit_line = CreditLine {
        owner: payload.agent_id,
        balance: 0,
        credit_limit: payload.initial_limit,
        last_update: Clock::get()?.unix_timestamp,
        reputation: 100, // Start with perfect rep
    };

    let mut data = credit_line_account.try_borrow_mut_data()?;
    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    
    if data.len() < bytes.len() {
        return Err(ProgramError::AccountDataTooSmall);
    }
    data[..bytes.len()].copy_from_slice(&bytes);

    msg!("Agent Registered: {:?}", agent_pubkey);
    Ok(())
}

fn process_verify_and_credit(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: VerifyAndCreditPayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let config_account = next_account_info(account_info_iter)?;
    let credit_line_account = next_account_info(account_info_iter)?;
    let gateway_signer = next_account_info(account_info_iter)?;

    // Load Config
    let config_data = config_account.try_borrow_data()?;
    let config: CoreConfig = wincode::deserialize(&config_data).map_err(|_| ProgramError::InvalidAccountData)?;

    if !gateway_signer.is_signer {
        return Err(CoreError::NotAuthorized.into());
    }

    // Load Credit Line
    let mut data = credit_line_account.try_borrow_mut_data()?;
    let mut credit_line: CreditLine = wincode::deserialize(&data).map_err(|_| ProgramError::InvalidAccountData)?;

    if credit_line.owner != payload.agent_id {
        return Err(CoreError::AgentNotFound.into());
    }

    // Update Logic
    let new_balance = credit_line.balance.saturating_add(payload.credit_amount);
    if new_balance > credit_line.credit_limit {
        credit_line.balance = credit_line.credit_limit;
    } else {
        credit_line.balance = new_balance;
    }
    
    credit_line.last_update = Clock::get()?.unix_timestamp;

    // Write back
    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    data[..bytes.len()].copy_from_slice(&bytes);

    msg!("Credit Updated for Agent: +{}", payload.credit_amount);
    Ok(())
}

fn process_request_payment(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: RequestPaymentPayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let _config_account = next_account_info(account_info_iter)?;
    let credit_line_account = next_account_info(account_info_iter)?;
    let agent_signer = next_account_info(account_info_iter)?;

    // Verify Agent Signature
    if !agent_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // Load Credit Line
    let mut data = credit_line_account.try_borrow_mut_data()?;
    let mut credit_line: CreditLine = wincode::deserialize(&data).map_err(|_| ProgramError::InvalidAccountData)?;

    // Verify Owner
    if credit_line.owner != agent_signer.key.to_bytes() {
        return Err(CoreError::NotAuthorized.into());
    }

    // Check Balance
    if credit_line.balance < payload.amount {
        return Err(CoreError::InsufficientFunds.into());
    }

    // Deduct Balance
    credit_line.balance = credit_line.balance.saturating_sub(payload.amount);
    credit_line.last_update = Clock::get()?.unix_timestamp;

    // Write back state
    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    data[..bytes.len()].copy_from_slice(&bytes);

    msg!("Payment Request Emitted: ID={}, Amount={}, Vendor={:?}", 
        payload.request_id, payload.amount, payload.vendor);

    Ok(())
}

