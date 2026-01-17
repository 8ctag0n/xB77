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
    AuditRevealPayload, ConfidentialTransferPayload, GatewayInstruction, InitGatewayPayload,
    ProofPayload, ReceiptPayload, ResolvePrivateOrderPayload, SubmitPrivateOrderPayload,
    UpdateGatewayPayload,
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

/// Helper to ensure VerifyBadge was called in the same transaction for this program.
fn check_badge_verified(
    program_id: &Pubkey,
    instructions_sysvar: &AccountInfo,
) -> Result<(), ProgramError> {
    let current_index = instructions::load_current_index_checked(instructions_sysvar)?;
    if current_index == 0 {
        return Err(GatewayError::MissingSigner.into());
    }

    let prev_index = current_index - 1;
    let instruction = instructions::load_instruction_at_checked(prev_index as usize, instructions_sysvar)?;

    if instruction.program_id != *program_id {
        return Err(GatewayError::InvalidInstruction.into());
    }

    if instruction.data.is_empty() || instruction.data[0] != 2 {
        return Err(GatewayError::InvalidInstruction.into());
    }

    Ok(())
}

fn process_execute_confidential_transfer(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: ConfidentialTransferPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)?;
    let gateway_state = next_account_info(&mut accounts_iter)?;
    let _mint = next_account_info(&mut accounts_iter)?;
    let source_ata = next_account_info(&mut accounts_iter)?;
    let dest_ata = next_account_info(&mut accounts_iter)?;
    let token_program = next_account_info(&mut accounts_iter)?;
    let instructions_sysvar = next_account_info(&mut accounts_iter)?;

    if !payer.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    check_badge_verified(program_id, instructions_sysvar)?;

    let (expected_pda, bump) = Pubkey::find_program_address(&[GATEWAY_STATE_SEED], program_id);
    if gateway_state.key != &expected_pda {
        return Err(GatewayError::InvalidGatewayStatePda.into());
    }

    let mut amount_bytes = [0u8; 8];
    amount_bytes.copy_from_slice(&payload.encrypted_amount[0..8]);
    let amount = u64::from_le_bytes(amount_bytes);

    msg!("execute_confidential_transfer: transfer executed");

    let transfer_ix = spl_token::instruction::transfer(
        token_program.key,
        source_ata.key,
        dest_ata.key,
        &expected_pda,
        &[],
        amount,
    )?;

    invoke_signed(
        &transfer_ix,
        &[source_ata.clone(), dest_ata.clone(), gateway_state.clone(), token_program.clone()],
        &[&[GATEWAY_STATE_SEED, &[bump]]],
    )?;

    Ok(())
}

fn process_record_receipt(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: ReceiptPayload,
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

    let mut config: GatewayConfig = wincode::deserialize(&gateway_state.data.borrow())
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    let mut data_to_hash = Vec::with_capacity(32 + 32 + 8 + 8);
    data_to_hash.extend_from_slice(&payload.vendor_id);
    data_to_hash.extend_from_slice(&payload.item_hash);
    data_to_hash.extend_from_slice(&payload.amount.to_le_bytes());
    data_to_hash.extend_from_slice(&payload.timestamp.to_le_bytes());

    let receipt_leaf = keccak::hash(&data_to_hash);

    let mut root_data = Vec::with_capacity(64);
    root_data.extend_from_slice(&config.receipt_root);
    root_data.extend_from_slice(&receipt_leaf.0);
    let new_root = keccak::hash(&root_data);

    config.receipt_root = new_root.0;

    let serialized = wincode::serialize(&config)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;
    gateway_state
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("record_receipt: receipt_root updated");

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
