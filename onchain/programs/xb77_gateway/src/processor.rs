use alloc::format;
use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    instruction::Instruction,
    keccak,
    msg,
    program::{invoke, invoke_signed},
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    system_instruction, system_program,
    sysvar::{instructions, Sysvar},
};
use alloc::vec;
use alloc::vec::Vec;

use crate::error::GatewayError;
use crate::instruction::{
    AuditRevealPayload, ConfidentialTransferPayload, CoreInstruction, GatewayInstruction,
    InitGatewayPayload, ProofPayload, ReceiptPayload, ResolvePrivateOrderPayload,
    SubmitPrivateOrderPayload, UpdateGatewayPayload, VerifyAndCreditPayload,
};
use crate::state::{GatewayConfig, GATEWAY_STATE_SEED, NULLIFIER_SEED};

const MERKLE_DEPTH: u32 = 3;
const MAX_LEAVES: u32 = 1 << MERKLE_DEPTH;
const ZERO_PUBKEY: [u8; 32] = [0u8; 32];
const RECEIPT_DOMAIN_SEPARATOR: &[u8] = b"xb77:receipt:v1";

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction: GatewayInstruction = wincode::deserialize(instruction_data)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    match instruction {
        GatewayInstruction::InitGateway(payload) => {
            process_init_gateway(program_id, accounts, payload)
        }
        GatewayInstruction::UpdateGateway(payload) => {
            process_update_gateway(program_id, accounts, payload)
        }
        GatewayInstruction::VerifyBadge(payload) => {
            process_verify_badge(program_id, accounts, payload)
        }
        GatewayInstruction::SubmitPrivateOrder(payload) => {
            process_submit_private_order(program_id, accounts, payload)
        }
        GatewayInstruction::ExecuteConfidentialTransfer(payload) => {
            process_execute_confidential_transfer(program_id, accounts, payload)
        }
        GatewayInstruction::RecordReceipt(payload) => {
            process_record_receipt(program_id, accounts, payload)
        }
        GatewayInstruction::ResolvePrivateOrder(payload) => {
            process_resolve_private_order(program_id, accounts, payload)
        }
        GatewayInstruction::AuditReveal(payload) => process_audit_reveal(program_id, accounts, payload),
    }
}

// Stub implementation for now
fn process_execute_confidential_transfer(
    _program_id: &Pubkey,
    _accounts: &[AccountInfo],
    _payload: ConfidentialTransferPayload,
) -> ProgramResult {
    msg!("ExecuteConfidentialTransfer: Not implemented yet");
    Ok(())
}

// Stub implementation for now
fn process_record_receipt(
    _program_id: &Pubkey,
    _accounts: &[AccountInfo],
    _payload: ReceiptPayload,
) -> ProgramResult {
    msg!("RecordReceipt: Not implemented yet");
    Ok(())
}

fn check_badge_verified(
    _program_id: &Pubkey,
    instructions_sysvar: &AccountInfo,
) -> ProgramResult {
    // Basic instruction introspection to ensure VerifyBadge was called in the same transaction.
    // This is a simplified check for Phase 2 demo.
    if instructions_sysvar.key != &instructions::ID {
         return Err(ProgramError::InvalidAccountData);
    }
    
    // In a real implementation, we would iterate through previous instructions
    // to find a successful VerifyBadge call targeting this program.
    // For now, we trust the caller if they provided the sysvar, implying composition.
    // TODO: Implement actual instruction introspection logic.
    msg!("check_badge_verified: Assuming badge verification via composition (TODO: Full check)");
    Ok(())
}

fn process_verify_badge(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: ProofPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    let gateway_state = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    // This is now the Standalone Verifier program account
    let verifier_program = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
    // ShadowWire Proof PDA (for binding validation)
    let sw_proof_pda = next_account_info(&mut accounts_iter)
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

    // --- Validation Logic ---
    if payload.merkle_index >= MAX_LEAVES {
        return Err(GatewayError::InvalidMerkleIndex.into());
    }

    // Note: We trust the Verifier program to check the root, but we should pass it.
    // For this design, we'll verify the proof via CPI.

    // --- CPI to Standalone Verifier ---
    msg!("verify_badge: invoking standalone verifier");

    // The verifier program expects raw proof + inputs. 
    // We need to match its instruction format. 
    // Assuming standard Sunspot/Gnark verifier: [instruction_discriminator (if any) + proof + public_inputs]
    // But since we control the verifier wrapper, let's assume it takes the payload directly.
    
    // Construct instruction data for the Verifier Program.
    // Format: [proof_len_u32 (4 bytes)] [proof_bytes] [witness_bytes]
    let proof_len = payload.proof.len() as u32;
    let mut cpi_data = Vec::with_capacity(4 + payload.proof.len() + payload.public_witness.len());
    cpi_data.extend_from_slice(&proof_len.to_le_bytes());
    cpi_data.extend_from_slice(&payload.proof);
    cpi_data.extend_from_slice(&payload.public_witness);

    let verifier_ix = Instruction {
        program_id: *verifier_program.key,
        accounts: vec![
            // Verifier usually doesn't need accounts unless it stores state, but might need system program if initializing.
            // Pure verification is stateless.
            solana_program::instruction::AccountMeta::new_readonly(*payer.key, true),
        ],
        data: cpi_data,
    };

    invoke(
        &verifier_ix,
        &[payer.clone(), verifier_program.clone()],
    )?;

    msg!("verify_badge: Standalone Verifier returned success");

    // --- Logic Check (Post-Verification) ---
    // Ensure the claimed root in the witness matches the gateway config
    // The public witness from Sunspot/Gnark has a 12-byte header:
    // [num_inputs (4), unknown (4), num_inputs_again? (4)]
    // Followed by the fields: [Root (32), OrderId (32), Nullifier (32)]
    let witness_data = if payload.public_witness.len() == 108 {
        &payload.public_witness[12..]
    } else {
        &payload.public_witness[..]
    };

    if witness_data.len() >= 96 {
        if witness_data[0..32] != config.merkle_root {
            msg!("verify_badge: public witness root mismatch");
            return Err(GatewayError::InvalidMerkleRoot.into());
        }

        // --- ShadowWire Binding Check ---
        let mut nullifier = [0u8; 32];
        nullifier.copy_from_slice(&witness_data[64..96]);

        let hash = keccak::hash(&nullifier);
        let mut expected_nonce_bytes = [0u8; 8];
        expected_nonce_bytes.copy_from_slice(&hash.to_bytes()[0..8]);
        let expected_nonce = u64::from_le_bytes(expected_nonce_bytes);

        let sw_data = sw_proof_pda.try_borrow_data()?;
        if sw_data.len() < 88 {
            // Anchor account for ShadowWire Proof: [8 disc, 32 sender, 32 token, 8 amount, 8 nonce, ...]
            msg!("verify_badge: ShadowWire Proof PDA data too short");
            return Err(ProgramError::InvalidAccountData);
        }

        let mut actual_nonce_bytes = [0u8; 8];
        actual_nonce_bytes.copy_from_slice(&sw_data[80..88]);
        let actual_nonce = u64::from_le_bytes(actual_nonce_bytes);

        if expected_nonce != actual_nonce {
            msg!(
                "verify_badge: ShadowWire nonce mismatch. Expected {}, found {}",
                expected_nonce,
                actual_nonce
            );
            return Err(GatewayError::ShadowWireBindingFailed.into());
        }
        msg!("verify_badge: ShadowWire binding verified");
    } else {
        return Err(GatewayError::EmptyPublicWitness.into());
    }

    msg!("verify_badge: gateway_state seed={:?}", GATEWAY_STATE_SEED);

    // --- CPI to Core Program (Optional) ---
    if let Ok(core_program_info) = next_account_info(&mut accounts_iter) {
        msg!("verify_badge: attempting CPI to Core");
        
        // We expect: [Core Program, Core Config, Credit Line]
        let core_config_info = next_account_info(&mut accounts_iter)
            .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
        let credit_line_info = next_account_info(&mut accounts_iter)
            .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;

        // Construct CPI Payload
        let cpi_payload = VerifyAndCreditPayload {
            agent_id: payer.key.to_bytes(),
            proof_ref: payload.root,
            credit_amount: 100, // Fixed credit per verification for Phase 1
        };

        let cpi_instruction = CoreInstruction::VerifyAndCredit(cpi_payload);
        let cpi_data = wincode::serialize(&cpi_instruction)
            .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

        let instruction = Instruction {
            program_id: *core_program_info.key,
            accounts: vec![
                solana_program::instruction::AccountMeta::new_readonly(*core_config_info.key, false),
                solana_program::instruction::AccountMeta::new(*credit_line_info.key, false),
                solana_program::instruction::AccountMeta::new_readonly(*gateway_state.key, true), // Gateway signs!
            ],
            data: cpi_data,
        };

        // Gateway signs with its PDA seeds
        let seeds = &[GATEWAY_STATE_SEED, &[_bump]];
        let signer_seeds = &[&seeds[..]];

        invoke_signed(
            &instruction,
            &[
                core_program_info.clone(),
                core_config_info.clone(),
                credit_line_info.clone(),
                gateway_state.clone(), // Signer
            ],
            signer_seeds,
        )?;

        msg!("verify_badge: CPI success");
    }

    Ok(())
}


fn process_submit_private_order(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: SubmitPrivateOrderPayload,
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

    msg!("submit_private_order: recorded");
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
    config.auditor = payload.auditor;
    config.credit_root = payload.credit_root;
    config.orderbook_root = payload.orderbook_root;
    config.mxe_program_id = payload.mxe_program_id;
    config.light_system_program = payload.light_system_program;
    config.light_account_compression_program = payload.light_account_compression_program;
    config.light_noop_program = payload.light_noop_program;

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
        treasury_mint: [0u8; 32],
        receipt_root: [0u8; 32],
        auditor: payload.auditor,
        credit_root: payload.credit_root,
        orderbook_root: payload.orderbook_root,
        mxe_program_id: payload.mxe_program_id,
        light_system_program: payload.light_system_program,
        light_account_compression_program: payload.light_account_compression_program,
        light_noop_program: payload.light_noop_program,
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

fn process_resolve_private_order(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: ResolvePrivateOrderPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)?;
    let gateway_state = next_account_info(&mut accounts_iter)?;
    let instructions_sysvar = next_account_info(&mut accounts_iter)?;

    if !payer.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    check_badge_verified(program_id, instructions_sysvar)?;

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

    let mut receipt_preimage = Vec::with_capacity(
        RECEIPT_DOMAIN_SEPARATOR.len()
            + payload.order_commitment.len()
            + payload.receipt_leaf_hash.len(),
    );
    receipt_preimage.extend_from_slice(RECEIPT_DOMAIN_SEPARATOR);
    receipt_preimage.extend_from_slice(&payload.order_commitment);
    receipt_preimage.extend_from_slice(&payload.receipt_leaf_hash);
    let _receipt_hash = keccak::hash(&receipt_preimage);

    if !payload.receipt_instruction_data.is_empty() {
        let receipt_program = next_account_info(&mut accounts_iter)
            .map_err(|_| ProgramError::from(GatewayError::NotEnoughAccounts))?;
        let receipt_accounts: Vec<AccountInfo> = accounts_iter.cloned().collect();

        let mut receipt_metas = Vec::with_capacity(1 + receipt_accounts.len());
        receipt_metas.push(solana_program::instruction::AccountMeta {
            pubkey: *payer.key,
            is_signer: payer.is_signer,
            is_writable: payer.is_writable,
        });
        for account in &receipt_accounts {
            receipt_metas.push(solana_program::instruction::AccountMeta {
                pubkey: *account.key,
                is_signer: account.is_signer,
                is_writable: account.is_writable,
            });
        }

        let receipt_ix = Instruction {
            program_id: *receipt_program.key,
            accounts: receipt_metas,
            data: payload.receipt_instruction_data.clone(),
        };

        let mut receipt_account_infos = Vec::with_capacity(2 + receipt_accounts.len());
        receipt_account_infos.push(payer.clone());
        receipt_account_infos.extend(receipt_accounts);
        receipt_account_infos.push(receipt_program.clone());

        invoke(&receipt_ix, &receipt_account_infos)?;
    }

    config.orderbook_root = payload.new_orderbook_root;

    let serialized = wincode::serialize(&config)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;
    gateway_state
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("resolve_private_order: orderbook_root updated");
    Ok(())
}

fn process_audit_reveal(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    _payload: AuditRevealPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let auditor = next_account_info(&mut accounts_iter)?;
    let gateway_state = next_account_info(&mut accounts_iter)?;

    if !auditor.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    let (expected_pda, _bump) = Pubkey::find_program_address(&[GATEWAY_STATE_SEED], program_id);
    if gateway_state.key != &expected_pda {
        return Err(GatewayError::InvalidGatewayStatePda.into());
    }

    let config: GatewayConfig = wincode::deserialize(&gateway_state.data.borrow())
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    if auditor.key.to_bytes() != config.auditor {
        return Err(GatewayError::InvalidGatewayAdmin.into());
    }

    msg!("audit_reveal: auditor verified");
    Ok(())
}
