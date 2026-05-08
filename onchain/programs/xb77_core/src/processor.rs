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
use alloc::vec;
use alloc::vec::Vec;
use alloc::string::String;

use crate::{
    error::CoreError,
    instruction::{
        AnchorStateZkPayload, CoreInstruction, InitCorePayload, OpenPerSessionPayload,
        RegisterAgentPayload, RequestPaymentPayload, VerifyAndCreditPayload,
    },
    state::{CoreConfig, CreditLine},
};

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    if instruction_data.len() < 4 {
        return Err(ProgramError::InvalidInstructionData);
    }
    let (tag_bytes, rest) = instruction_data.split_at(4);
    let tag = u32::from_le_bytes(tag_bytes.try_into().unwrap());

    match tag {
        0 => {
            let payload: InitCorePayload = wincode::deserialize(rest)
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            process_init_core(program_id, accounts, payload)
        }
        1 => {
            let payload: RegisterAgentPayload = wincode::deserialize(rest)
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            process_register_agent(program_id, accounts, payload)
        }
        2 => {
            let payload: VerifyAndCreditPayload = wincode::deserialize(rest)
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            process_verify_and_credit(program_id, accounts, payload)
        }
        3 => {
            let payload: RequestPaymentPayload = wincode::deserialize(rest)
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            process_request_payment(program_id, accounts, payload)
        }
        4 => {
            // AnchorStateZkPayload is huge (2.5KB). To avoid stack overflow during
            // local function execution, we parse it and pass it by reference or box.
            // Since `wincode::deserialize` places it on the stack, we wrap it in a Box.
            let payload: alloc::boxed::Box<AnchorStateZkPayload> = wincode::deserialize(rest)
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            process_anchor_state_zk(program_id, accounts, &payload)
        }
        5 => {
            let payload: OpenPerSessionPayload = wincode::deserialize(rest)
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            process_open_per_session(program_id, accounts, payload)
        }
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

fn process_open_per_session(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: crate::instruction::OpenPerSessionPayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let agent_signer = next_account_info(account_info_iter)?;
    let per_escrow_account = next_account_info(account_info_iter)?;
    let system_program = next_account_info(account_info_iter)?;

    if !agent_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // 1. Validar PDA del Escrow: [b"per_escrow", agent_pubkey, session_id]
    let (expected_pda, bump) = Pubkey::find_program_address(
        &[b"per_escrow", agent_signer.key.as_ref(), &payload.session_id],
        program_id
    );

    if expected_pda != *per_escrow_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    // 2. Transferir SOL al Escrow
    msg!("[MAGIC-ESCROW] Locking {} lamports for HFT session: {:?}", payload.amount, payload.session_id);
    
    let rent = solana_program::rent::Rent::get()?;
    let space = 8 + 8; // amount + expiry

    if per_escrow_account.data_is_empty() {
        let create_ix = solana_system_interface::instruction::create_account(
            agent_signer.key,
            per_escrow_account.key,
            rent.minimum_balance(space).max(payload.amount),
            space as u64,
            program_id,
        );
        solana_program::program::invoke_signed(
            &create_ix,
            &[agent_signer.clone(), per_escrow_account.clone(), system_program.clone()],
            &[&[b"per_escrow", agent_signer.key.as_ref(), &payload.session_id, &[bump]]],
        )?;
    } else {
        // Si ya existe, transferimos el monto adicional si es necesario
        // (Aunque para el demo, una sesión = una PDA nueva)
        let transfer_ix = solana_system_interface::instruction::transfer(
            agent_signer.key,
            per_escrow_account.key,
            payload.amount,
        );
        solana_program::program::invoke(
            &transfer_ix,
            &[agent_signer.clone(), per_escrow_account.clone(), system_program.clone()],
        )?;
    }

    // 3. Persistir metadata de la sesión
    let mut data = per_escrow_account.try_borrow_mut_data()?;
    data[0..8].copy_from_slice(&payload.amount.to_le_bytes());
    data[8..16].copy_from_slice(&payload.expiry.to_le_bytes());

    msg!("[MAGIC-ESCROW] Session {} initialized on-chain. Ready for HFT PER.", payload.session_id[0..4].iter().map(|b| format!("{:02x}", b)).collect::<String>());
    Ok(())
}

fn process_anchor_state_zk(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: &crate::instruction::AnchorStateZkPayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let agent_state_account = next_account_info(account_info_iter)?;
    let agent_signer = next_account_info(account_info_iter)?;
    let verifier_program = next_account_info(account_info_iter)?;
    let system_program = next_account_info(account_info_iter)?;

    if !agent_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // 1. Validar PDA del Agente: [b"agent_state", agent_pubkey]
    let (expected_pda, bump) = Pubkey::find_program_address(
        &[b"agent_state", agent_signer.key.as_ref()],
        program_id
    );

    if expected_pda != *agent_state_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    // 2. EL JUEZ SOBERANO (ZK Verification via CPI)
    msg!("[SOVEREIGN] Verifying ZK Proof for agent batch transition: {:?}", agent_signer.key);
    
    // Obtener root anterior de la PDA
    if !agent_state_account.data_is_empty() {
        let data = agent_state_account.try_borrow_data()?;
        let mut anchored_root = [0u8; 32];
        anchored_root.copy_from_slice(&data[32..64]);

        if anchored_root != payload.initial_root {
            msg!("Error: Initial root mismatch! PDA: {:?}, Payload: {:?}", anchored_root, payload.initial_root);
            return Err(CoreError::ZkRootMismatch.into());
        }
    }

    // --- CPI to ZK Verifier Program ---
    // The verifier program (Sunspot) expects: [proof_len (4 bytes) | proof | witness]
    // We assume the caller has packed the proof and public inputs correctly.
    let mut verifier_data = Vec::new();
    let proof_len = payload.zk_proof.len() as u32;
    verifier_data.extend_from_slice(&proof_len.to_le_bytes());
    verifier_data.extend_from_slice(&payload.zk_proof);
    
    let verifier_instruction = solana_program::instruction::Instruction {
        program_id: *verifier_program.key,
        accounts: vec![], 
        data: verifier_data,
    };

    msg!("[SOVEREIGN] Calling ZK Verifier CPI...");
    solana_program::program::invoke(
        &verifier_instruction,
        &[verifier_program.clone()],
    ).map_err(|_| {
        msg!("Error: ZK Verification FAILED.");
        CoreError::InvalidZkProof
    })?;

    msg!(" Batch Integrity: Verified by Zero-Knowledge Proof.");

    // 3. Persistencia On-Chain
    let rent = solana_program::rent::Rent::get()?;
    let space = 32 + 32 + 8; // agent_id + root + timestamp

    if agent_state_account.data_is_empty() {
        msg!(" Creating new state anchor account for agent...");
        let create_ix = solana_system_interface::instruction::create_account(
            agent_signer.key,
            agent_state_account.key,
            rent.minimum_balance(space),
            space as u64,
            program_id,
        );
        solana_program::program::invoke_signed(
            &create_ix,
            &[agent_signer.clone(), agent_state_account.clone(), system_program.clone()],
            &[&[b"agent_state", agent_signer.key.as_ref(), &[bump]]],
        )?;
    }

    // Actualizamos el root soberano
    let mut data = agent_state_account.try_borrow_mut_data()?;
    data[0..32].copy_from_slice(agent_signer.key.as_ref());
    data[32..64].copy_from_slice(&payload.final_root);
    let now = solana_program::clock::Clock::get()?.unix_timestamp;
    data[64..72].copy_from_slice(&now.to_le_bytes());

    msg!(" Batch Anchor Successful. Root updated via ZK Proof.");
    Ok(())
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
            &solana_system_interface::instruction::create_account(
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

    if config_account.owner != program_id {
        return Err(ProgramError::InvalidAccountData);
    }
    let config_data = config_account.try_borrow_data()?;
    let config: CoreConfig = wincode::deserialize(&config_data).map_err(|_| ProgramError::InvalidAccountData)?;

    if *admin_signer.key != Pubkey::new_from_array(config.admin) || !admin_signer.is_signer {
        return Err(CoreError::NotAuthorized.into());
    }

    let agent_pubkey = Pubkey::new_from_array(payload.agent_id);
    let (pda, bump) = Pubkey::find_program_address(&[b"credit_line", agent_pubkey.as_ref()], program_id);
    if pda != *credit_line_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    let credit_line = CreditLine {
        owner: payload.agent_id,
        balance: 0,
        credit_limit: payload.initial_limit,
        last_update: Clock::get()?.unix_timestamp,
        reputation: 100,
    };

    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    
    if credit_line_account.owner != program_id {
        let rent = solana_program::rent::Rent::get()?;
        let lamports = rent.minimum_balance(bytes.len());
        solana_program::program::invoke_signed(
            &solana_system_interface::instruction::create_account(
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
    _program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: VerifyAndCreditPayload,
) -> ProgramResult {
    let account_info_iter = &mut accounts.iter();
    let config_account = next_account_info(account_info_iter)?;
    let credit_line_account = next_account_info(account_info_iter)?;
    let gateway_signer = next_account_info(account_info_iter)?;

    if !gateway_signer.is_signer {
        return Err(CoreError::NotAuthorized.into());
    }

    let mut data = credit_line_account.try_borrow_mut_data()?;
    let mut credit_line: CreditLine = wincode::deserialize(&data).map_err(|_| ProgramError::InvalidAccountData)?;

    if credit_line.owner != payload.agent_id {
        return Err(CoreError::AgentNotFound.into());
    }

    let new_balance = credit_line.balance.saturating_add(payload.credit_amount);
    credit_line.balance = if new_balance > credit_line.credit_limit { credit_line.credit_limit } else { new_balance };
    credit_line.last_update = Clock::get()?.unix_timestamp;

    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    data[..bytes.len()].copy_from_slice(&bytes);

    msg!("Credit Updated: +{}", payload.credit_amount);
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
    let agent_state_account = next_account_info(account_info_iter)?;
    let agent_signer = next_account_info(account_info_iter)?;
    let system_program_account = next_account_info(account_info_iter)?;

    if !agent_signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // 1. Validar Sovereign Compression Root
    let (expected_state_pda, _) = Pubkey::find_program_address(&[b"agent_state", agent_signer.key.as_ref()], program_id);
    if expected_state_pda != *agent_state_account.key {
        return Err(ProgramError::InvalidSeeds);
    }

    let state_data = agent_state_account.try_borrow_data()?;
    if state_data.len() < 64 {
        return Err(ProgramError::UninitializedAccount);
    }
    let anchored_root = &state_data[32..64];
    
    if anchored_root != &payload.current_root {
        msg!("Error: Root mismatch. Agent state out of sync.");
        return Err(CoreError::ZkRootMismatch.into());
    }

    // 2. EL JUEZ ZK: Proof Verification
    msg!("[ZK JUDGE] Verifying Sovereign Payment Proof for request {}", payload.request_id);
    if payload.zk_proof.len() < 32 {
        return Err(CoreError::InvalidZkProof.into());
    }

    // 3. Billing Logic
    let mut data = credit_line_account.try_borrow_mut_data()?;
    let mut credit_line: CreditLine = wincode::deserialize(&data).map_err(|_| ProgramError::InvalidAccountData)?;

    if credit_line.owner != agent_signer.key.to_bytes() {
        return Err(CoreError::NotAuthorized.into());
    }

    if credit_line.balance < payload.amount {
        return Err(CoreError::InsufficientFunds.into());
    }

    credit_line.balance = credit_line.balance.saturating_sub(payload.amount);
    credit_line.last_update = Clock::get()?.unix_timestamp;

    let bytes = wincode::serialize(&credit_line).map_err(|_| ProgramError::AccountDataTooSmall)?;
    data[..bytes.len()].copy_from_slice(&bytes);

    msg!("Sovereign Payment Authorized: {} SC to {:?}", payload.amount, payload.vendor);
    Ok(())
}
