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
use alloc::vec::Vec;

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
    let system_program_account = next_account_info(account_info_iter)?;

    if !admin_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // Determine expected PDA
    let (pda, bump) = Pubkey::find_program_address(&[b"config_v3"], program_id);
    if pda != *config_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    let config = CoreConfig {
        admin: payload.admin,
        gateway_program: payload.gateway_program,
        receipts_program: payload.receipts_program,
        treasury_mint: payload.treasury_mint,
    };

    let bytes = wincode::serialize(&config).map_err(|_| ProgramError::AccountDataTooSmall)?;
    
    if config_account.owner != program_id {
        let rent = solana_program::rent::Rent::get()?;
        let lamports = rent.minimum_balance(bytes.len());
        solana_program::program::invoke_signed(
            &solana_program::system_instruction::create_account(
                admin_signer.key,
                config_account.key,
                lamports,
                bytes.len() as u64,
                program_id,
            ),
            &[admin_signer.clone(), config_account.clone(), system_program_account.clone()],
            &[&[b"config_v3", &[bump]]],
        )?;
    }

    let mut data = config_account.try_borrow_mut_data()?;
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
    let system_program_account = next_account_info(account_info_iter)?;

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
    let (pda, bump) = Pubkey::find_program_address(
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

    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    
    if credit_line_account.owner != program_id {
        let rent = solana_program::rent::Rent::get()?;
        let lamports = rent.minimum_balance(bytes.len());
        solana_program::program::invoke_signed(
            &solana_program::system_instruction::create_account(
                admin_signer.key,
                credit_line_account.key,
                lamports,
                bytes.len() as u64,
                program_id,
            ),
            &[admin_signer.clone(), credit_line_account.clone(), system_program_account.clone()],
            &[&[b"credit_line", agent_pubkey.as_ref(), &[bump]]],
        )?;
    }

    let mut data = credit_line_account.try_borrow_mut_data()?;
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
    let config_account = next_account_info(account_info_iter)?;
    let credit_line_account = next_account_info(account_info_iter)?;
    let agent_signer = next_account_info(account_info_iter)?;
    // Explicitly expect the Receipts Program account next
    let receipts_program_account = next_account_info(account_info_iter)?;

    // Verify Agent Signature
    if !agent_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // Load Config (to get receipts program ID)
    let config_data = config_account.try_borrow_data()?;
    let config: CoreConfig = wincode::deserialize(&config_data).map_err(|_| ProgramError::InvalidAccountData)?;

    // Verify Receipts Program ID
    let receipts_program_id = Pubkey::new_from_array(config.receipts_program);
    if *receipts_program_account.key != receipts_program_id {
        return Err(ProgramError::IncorrectProgramId);
    }
    if !receipts_program_account.executable {
        return Err(ProgramError::IncorrectProgramId);
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

    // --- CPI to Receipts Program ---
    
    // Collect remaining accounts (Light Protocol accounts passed by client)
    let remaining_accounts: Vec<AccountInfo> = account_info_iter.cloned().collect();
    
    if !remaining_accounts.is_empty() {
        msg!("DEBUG CORE: Remaining[0]: {:?}", remaining_accounts[0].key);
    }
    if remaining_accounts.len() > 1 {
        msg!("DEBUG CORE: Remaining[1]: {:?}", remaining_accounts[1].key);
    }
    if remaining_accounts.len() > 2 {
        msg!("DEBUG CORE: Remaining[2]: {:?}", remaining_accounts[2].key);
    }

    // Prepare CPI Data
    #[derive(borsh::BorshSerialize)]
    struct RecordReceiptInstructionData {
        pub proof: Vec<u8>,
        pub address_tree_info: Vec<u8>,
        pub output_state_tree_index: u8,
        pub vendor: [u8; 32],
        pub amount: u64,
        pub memo_hash: [u8; 32],
    }

    let receipt_data = RecordReceiptInstructionData {
        proof: payload.proof,
        address_tree_info: payload.address_tree_info,
        output_state_tree_index: payload.output_state_tree_index,
        vendor: payload.vendor,
        amount: payload.amount,
        memo_hash: payload.memo_hash,
    };

    let mut instruction_data = Vec::new();
    instruction_data.push(0u8); // Discriminator: RecordReceipt = 0
    borsh::BorshSerialize::serialize(&receipt_data, &mut instruction_data)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    // Prepare CPI Accounts
    // xb77_receipts expects: [Signer, ...LightAccounts, Owner]
    
    let mut cpi_accounts = Vec::with_capacity(2 + remaining_accounts.len());
    
    // 1. Signer (Agent)
    cpi_accounts.push(solana_program::instruction::AccountMeta::new(*agent_signer.key, true));

    // 2. Remaining Light Accounts (NOW IN THE MIDDLE)
    for acc in &remaining_accounts {
        if acc.is_writable {
            cpi_accounts.push(solana_program::instruction::AccountMeta::new(*acc.key, acc.is_signer));
        } else {
            cpi_accounts.push(solana_program::instruction::AccountMeta::new_readonly(*acc.key, acc.is_signer));
        }
    }
    
    // 3. Owner (Agent) - duplicate, but distinct role in receipts program (NOW AT THE END)
    cpi_accounts.push(solana_program::instruction::AccountMeta::new(*agent_signer.key, false));
    

    let instruction = solana_program::instruction::Instruction {
        program_id: receipts_program_id,
        accounts: cpi_accounts,
        data: instruction_data,
    };

    // AccountInfos for invoke must include the program being invoked
    let mut invoke_account_infos = Vec::with_capacity(4 + remaining_accounts.len());
    invoke_account_infos.push(receipts_program_account.clone()); // Executable
    invoke_account_infos.push(agent_signer.clone()); // Signer
    invoke_account_infos.extend(remaining_accounts); // Light Accounts
    invoke_account_infos.push(agent_signer.clone()); // Owner (at the end)
    
    solana_program::program::invoke(
        &instruction,
        &invoke_account_infos,
    )?;

    msg!("Receipt CPI Success");
    Ok(())
}

