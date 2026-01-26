#![allow(unexpected_cfgs)]

use borsh::{BorshDeserialize, BorshSerialize};
use solana_program::pubkey;
use shank::{ShankInstruction, ShankType};
use light_sdk::{
    account::sha::LightAccount,
    address::v1::derive_address,
    cpi::{
        v1::{CpiAccounts, LightSystemProgramCpi},
        CpiSigner,
        InvokeLightSystemProgram,
        LightCpiInstruction,
    },
    derive_light_cpi_signer,
    instruction::{PackedAddressTreeInfo, ValidityProof},
    LightDiscriminator,
};
use solana_program::{
    account_info::AccountInfo,
    entrypoint,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::{clock::Clock, Sysvar},
};

use solana_program::declare_id;

declare_id!("6LM5tQioTsog9AmiHbXBN69YrFBzzhspVWyxBvxKZss3");
pub const LIGHT_CPI_SIGNER: CpiSigner = derive_light_cpi_signer!(
    "6LM5tQioTsog9AmiHbXBN69YrFBzzhspVWyxBvxKZss3"
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
            record_receipt(accounts, data)
        }
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

fn record_receipt(
    accounts: &[AccountInfo],
    instruction_data: RecordReceiptInstructionData,
) -> Result<(), ProgramError> {
    let signer = accounts
        .first()
        .ok_or(ProgramError::NotEnoughAccountKeys)?;

    // Signer should be the Core program if it's a CPI, or the User if creating directly.
    // In our architecture, the Core program invokes this.
    // The 'owner' of the receipt will be the first account passed (signer), 
    // BUT we might want to allow specifying the owner if the Core program is the signer.
    // For simplicity: The signer becomes the owner. 
    // If Core signs, Core is owner? No, we want the Agent to own it.
    // So if Core calls this, Core must sign, but we want the receipt.owner to be the Agent.
    // NOTE: LightAccount::new_init defaults owner to the signer? No, we set it manually.
    
    // Adjust logic: The 'signer' account here is the one paying for the transaction / signing the CPI.
    // If this is called via CPI from Core, 'signer' is the Core Program (as a PDA or Keypair).
    // But we want the receipt to belong to the Agent.
    // So we should probably pass the Agent's Pubkey as an argument or another account.
    // Let's assume for now the 'signer' IS the Agent (if Core just passes signature) 
    // OR 'signer' is Core and we rely on 'RecordReceiptInstructionData' to carry the owner?
    // OR we pass the Agent as account[1] (non-signer, just for address).
    
    // Let's modify: `signer` is the payer/authority.
    // `owner_account` is the intended owner (Agent).
    // accounts[0] = signer (Core Program or User)
    // accounts[1] = owner_account (Agent)
    // ... rest of light accounts ...
    
    // Actually, looking at CpiAccounts::new, it takes `signer` and `remaining_accounts`.
    // Let's stick to: accounts[0] is signer. We set receipt.owner = *signer.key.
    // If Core calls this, Core is owner. The Agent can "view" it if they derive the address?
    // No, Core program cannot "own" compressed accounts in the same way (it's not a user wallet).
    // If Core is the signer, the receipt is owned by Core.
    // This is fine if the Core program manages the receipts.
    // BUT, if we want the Agent to "see" it in their wallet, Agent should be owner.
    // Can Core sign *for* the Agent? No.
    // Can Core create an account owned by Agent?
    // Yes! `receipt.owner` is just a field. We can set it to anything.
    // So let's add `owner` to the InstructionData or pass it as an account.
    // Passing as account is safer/cleaner.
    
    // REVISED ACCOUNTS:
    // 0. Signer (Payer/Authority)
    // 1. Agent (Owner of the receipt)
    // 2... Light accounts
    
    let signer = &accounts[0];
    let agent_account = &accounts[1];
    
    if !signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    let light_cpi_accounts = CpiAccounts::new(signer, &accounts[2..], LIGHT_CPI_SIGNER);

    let proof = ValidityProof::try_from_slice(&instruction_data.proof)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    let address_tree_info = PackedAddressTreeInfo::try_from_slice(&instruction_data.address_tree_info)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    let tree_pubkey = address_tree_info
        .get_tree_pubkey(&light_cpi_accounts)
        .map_err(|_| ProgramError::NotEnoughAccountKeys)?;

    // Derive deterministic address based on seed.
    // Seed: "receipt" + vendor + memo_hash
    // This ensures uniqueness per payment.
    let mut seed = Vec::with_capacity(64);
    seed.extend_from_slice(b"receipt");
    seed.extend_from_slice(&instruction_data.vendor);
    seed.extend_from_slice(&instruction_data.memo_hash);

    let (address, address_seed) = derive_address(
        &[&seed],
        &tree_pubkey,
        &ID,
    );

    let new_address_params = address_tree_info.into_new_address_params_packed(address_seed);

    let mut receipt = LightAccount::<CompressedReceipt>::new_init(
        &ID,
        Some(address),
        instruction_data.output_state_tree_index,
    );
    
    // Set the owner to the Agent!
    receipt.owner = *agent_account.key;
    
    receipt.vendor = instruction_data.vendor;
    receipt.amount = instruction_data.amount;
    receipt.timestamp = Clock::get()?.unix_timestamp;
    receipt.memo_hash = instruction_data.memo_hash;

    LightSystemProgramCpi::new_cpi(LIGHT_CPI_SIGNER, proof)
        .with_light_account(receipt)
        .map_err(|_| ProgramError::InvalidInstructionData)?
        .with_new_addresses(&[new_address_params])
        .invoke(light_cpi_accounts)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    Ok(())
}
