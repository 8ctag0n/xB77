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
use alloc::format;
use alloc::vec;
use alloc::vec::Vec;

use crate::error::GatewayError;
use crate::instruction::{
    ConfidentialTransferPayload, GatewayInstruction, InitGatewayPayload, ProofPayload, ReceiptPayload,
    UpdateGatewayPayload,
};
use crate::state::{GatewayConfig, GATEWAY_STATE_SEED};

const MERKLE_DEPTH: u32 = 3;
const MAX_LEAVES: u32 = 1 << MERKLE_DEPTH;
const ZERO_PUBKEY: [u8; 32] = [0u8; 32];

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
        GatewayInstruction::ExecuteConfidentialTransfer(payload) => {
            process_execute_confidential_transfer(program_id, accounts, payload)
        }
        GatewayInstruction::RecordReceipt(payload) => {
            process_record_receipt(program_id, accounts, payload)
        }
    }
}

/// Helper to ensure VerifyBadge was called in the same transaction for this program.
fn check_badge_verified(
    program_id: &Pubkey,
    instructions_sysvar: &AccountInfo,
) -> Result<(), ProgramError> {
    let current_index = instructions::load_current_index_checked(instructions_sysvar)?;
    if current_index == 0 {
        return Err(GatewayError::MissingSigner.into()); // Reusing error or add "OrderViolation"
    }

    // Look at the immediately preceding instruction
    let prev_index = current_index - 1;
    let instruction = instructions::load_instruction_at_checked(prev_index as usize, instructions_sysvar)?;

    // Check if it calls our program
    if instruction.program_id != *program_id {
        return Err(GatewayError::InvalidInstruction.into()); // Should be our program
    }

    // Check if the instruction data corresponds to VerifyBadge
    // Note: We can't easily fully parse it again without cost, but we can check the variant.
    // Assuming wincode serialization, the first byte *might* be the variant index if it's simple enum?
    // Wincode serialization for enums usually prefixes with a variant index.
    // VerifyBadge is the 3rd variant (index 2).
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
    // 1. Payer/Signer (who pays for fees and is the authority for the SPL transfer destination?)
    // Actually for ConfTransfer:
    // 0. Payer (Signer)
    // 1. Gateway State
    // 2. Token Mint (Treasury)
    // 3. Source Token Account (Gateway's ATA)
    // 4. Destination Token Account
    // 5. Token Program
    // 6. Instructions Sysvar (for introspection)
    let payer = next_account_info(&mut accounts_iter)?;
    let gateway_state = next_account_info(&mut accounts_iter)?;
    let _mint = next_account_info(&mut accounts_iter)?; // Optional verification
    let source_ata = next_account_info(&mut accounts_iter)?;
    let dest_ata = next_account_info(&mut accounts_iter)?;
    let token_program = next_account_info(&mut accounts_iter)?;
    let instructions_sysvar = next_account_info(&mut accounts_iter)?;

    if !payer.is_signer {
        return Err(GatewayError::MissingSigner.into());
    }

    // Introspection Check
    check_badge_verified(program_id, instructions_sysvar)?;

    // Gateway State Verification
    let (expected_pda, bump) = Pubkey::find_program_address(&[GATEWAY_STATE_SEED], program_id);
    if gateway_state.key != &expected_pda {
        return Err(GatewayError::InvalidGatewayStatePda.into());
    }
    
    // Decrypt amount (Mock: First 8 bytes of ciphertext as u64 LE)
    let mut amount_bytes = [0u8; 8];
    amount_bytes.copy_from_slice(&payload.encrypted_amount[0..8]);
    let amount = u64::from_le_bytes(amount_bytes);

    msg!("execute_confidential_transfer: decrypted_amount={}", amount);

    // CPI to SPL Token
    let transfer_ix = spl_token::instruction::transfer(
        token_program.key,
        source_ata.key,
        dest_ata.key,
        &expected_pda, // Owner is the Gateway PDA
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
    
    // Introspection Check: Ensure we only record receipts if badge was verified
    // (Or we can allow receipt recording without verification? 
    // Research Plan says "Sequence: verify -> transfer -> receipt", so yes check.)
    check_badge_verified(program_id, instructions_sysvar)?;

    if !gateway_state.is_writable {
         return Err(GatewayError::GatewayStateNotWritable.into());
    }

    // Load Config
    let mut config: GatewayConfig = wincode::deserialize(&gateway_state.data.borrow())
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;

    // Hash Receipt
    // Structure to hash: vendor_id (32) + item_hash (32) + amount (8) + timestamp (8)
    let mut data_to_hash = Vec::with_capacity(32 + 32 + 8 + 8);
    data_to_hash.extend_from_slice(&payload.vendor_id);
    data_to_hash.extend_from_slice(&payload.item_hash);
    data_to_hash.extend_from_slice(&payload.amount.to_le_bytes());
    data_to_hash.extend_from_slice(&payload.timestamp.to_le_bytes());

    let receipt_leaf = keccak::hash(&data_to_hash);
    
    msg!("record_receipt: leaf={:?}", receipt_leaf.0);

    // Update State Root (Rolling Hash Mock)
    // new_root = hash(old_root || new_leaf)
    let mut root_data = Vec::with_capacity(64);
    root_data.extend_from_slice(&config.receipt_root);
    root_data.extend_from_slice(&receipt_leaf.0);
    let new_root = keccak::hash(&root_data);

    config.receipt_root = new_root.0;

    // Save State
    let serialized = wincode::serialize(&config)
        .map_err(|_| ProgramError::from(GatewayError::InvalidInstruction))?;
    gateway_state
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("record_receipt: new_root={:?}", config.receipt_root);

    Ok(())
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
        treasury_mint: [0u8; 32], // Default for now
        receipt_root: [0u8; 32], // Default
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
