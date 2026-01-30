#![allow(unexpected_cfgs)]
use borsh::{BorshDeserialize, BorshSerialize};
use shank::{ShankInstruction, ShankType};
use light_sdk::{
    account::sha::LightAccount,
    address::v2::derive_address, // V2 Derivation
    cpi::{
        v2::{CpiAccounts, LightSystemProgramCpi}, // V2 CPI
        CpiSigner,
        InvokeLightSystemProgram,
        LightCpiInstruction,
    },
    derive_light_cpi_signer,
    instruction::{PackedAddressTreeInfo, ValidityProof},
    constants::ADDRESS_TREE_V2, // V2 Constant
    LightDiscriminator,
};
use solana_program::{
    account_info::AccountInfo,
    entrypoint,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::{clock::Clock, Sysvar},
    msg,
};
use solana_program::declare_id;
declare_id!("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");
pub const LIGHT_CPI_SIGNER: CpiSigner = derive_light_cpi_signer!(
    "8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W"
);
entrypoint!(process_instruction);
#[repr(u8)]
#[derive(Debug, Clone, ShankInstruction)]
pub enum ReceiptInstruction {
    #[account(0, signer, name="signer", desc="The payer and authority for the transaction")]
    #[account(1, name="agent_account", desc="The agent account that will own the receipt")]
    #[account(2, name="light_cpi_signer", desc="The PDA signing for Light Protocol CPI")]
    #[account(3, name="system_program", desc="The System Program")]
    #[account(4, name="light_system_program", desc="The Light System Program")]
    // Remaining accounts are variable Light Protocol accounts (trees, etc)
    RecordReceipt(RecordReceiptInstructionData),
}
#[derive(Debug, Clone, Default, BorshSerialize, BorshDeserialize, LightDiscriminator)]
pub struct CompressedReceipt {
    pub owner: Pubkey,
    pub vendor: [u8; 32],
    pub amount: u64,
    pub timestamp: i64,
    pub memo_hash: [u8; 32],
}
#[derive(Debug, Clone, BorshSerialize, BorshDeserialize, ShankType)]
pub struct RecordReceiptInstructionData {
    pub proof: Vec<u8>,
    pub address_tree_info: Vec<u8>,
    pub output_state_tree_index: u8,
    pub vendor: [u8; 32],
    pub amount: u64,
    pub memo_hash: [u8; 32],
}
pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> Result<(), ProgramError> {
    if program_id != &ID {
        return Err(ProgramError::IncorrectProgramId);
    }
    if instruction_data.is_empty() {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => {
            let data = RecordReceiptInstructionData::try_from_slice(&instruction_data[1..])
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            record_receipt(program_id,accounts, data)
        }
        _ => Err(ProgramError::InvalidInstructionData),
    }
}
fn record_receipt(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: RecordReceiptInstructionData,
) -> Result<(), ProgramError> {
    // Deserialize Light Protocol types from Vec<u8>
    let proof = ValidityProof::try_from_slice(&instruction_data.proof)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    let address_tree_info = PackedAddressTreeInfo::try_from_slice(&instruction_data.address_tree_info)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    // ACCOUNTS:
    // 0. Signer (Payer/Authority)
    // 1. Agent (Owner of the receipt)
    // 2... Light accounts (Passed to CpiAccounts)
    let signer = accounts
        .first()
        .ok_or(ProgramError::NotEnoughAccountKeys)?;
    let agent_account = &accounts[1];
    if !signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    // V2: CpiAccounts constructor takes (signer, remaining_accounts, cpi_signer)
    // We skip signer(0) and agent(1), so remaining starts at 2
    let light_cpi_accounts = CpiAccounts::new(signer, &accounts[2..], LIGHT_CPI_SIGNER);
    let address_tree_pubkey = address_tree_info
        .get_tree_pubkey(&light_cpi_accounts)
        .map_err(|_| ProgramError::NotEnoughAccountKeys)?;
    // Derive address using the V2 helper, passing seed components directly
    let (address_bytes, address_seed) = derive_address(
        &[
            b"receipt",
            &instruction_data.vendor,
            &instruction_data.memo_hash,
        ],
        &address_tree_pubkey,
        program_id,
    );
    //let address = Pubkey::new_from_array(address_bytes);
    // Then proceed with new_address_params, etc.
    let new_address_params = address_tree_info
        .into_new_address_params_assigned_packed(address_seed, Some(0));
    msg!("DEBUG: Derived Address Seed: {:?}", address_seed.0);
    msg!("DEBUG: Derived Address (V2): {:?}", Pubkey::new_from_array(address_bytes));
    let mut receipt = LightAccount::<CompressedReceipt>::new_init(
        &ID,
        Some(address_bytes),
        instruction_data.output_state_tree_index,
    );
    // Set properties
    receipt.owner = *agent_account.key;
    receipt.vendor = instruction_data.vendor;
    receipt.amount = instruction_data.amount;
    receipt.timestamp = Clock::get()?.unix_timestamp;
    receipt.memo_hash = instruction_data.memo_hash;
    // V2: Invoke CPI
    LightSystemProgramCpi::new_cpi(LIGHT_CPI_SIGNER, proof)
        .with_light_account(receipt)
        .map_err(|_| ProgramError::InvalidInstructionData)?
        .with_new_addresses(&[new_address_params])
        .invoke(light_cpi_accounts)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    use solana_program::pubkey::Pubkey;
    use std::str::FromStr;
    #[test]
    fn test_derive_address_lab() {
        let program_id = Pubkey::from_str("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W").unwrap();
        let address_tree_pubkey = Pubkey::from_str("CCa2h58a36K2d6zJ6Sj45UjS2u9K5K3h2u5K5K3h2u5K").unwrap(); // Use actual V2 tree in real tests
        let vendor = [1u8; 32];
        let memo_hash = [2u8; 32];
        // Use standard Rust SDK V2 derivation
        let (v2_address_bytes, address_seed) = derive_address(
            &[
                b"receipt",
                &vendor,
                &memo_hash,
            ],
            &address_tree_pubkey,
            &program_id,
        );
        let v2_address = Pubkey::new_from_array(v2_address_bytes);
        println!("Rust V2 Address Seed: {:?}", address_seed.0);
        println!("Rust V2 Address: {}", v2_address);
        // For verification: Add expected value if known, or cross-check with TS V2
        // Assuming client is updated to V2, this should match
    }
}
