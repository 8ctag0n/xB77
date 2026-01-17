#![allow(unexpected_cfgs)]

use borsh::{BorshDeserialize, BorshSerialize};
use light_macros::pubkey;
use light_sdk::{
    account::sha::LightAccount,
    address::v1::derive_address,
    cpi::{
        v1::{CpiAccounts, LightSystemProgramCpi},
        CpiSigner,
        InvokeLightSystemProgram,
    },
    derive_light_cpi_signer,
    instruction::{account_meta::CompressedAccountMeta, PackedAddressTreeInfo, ValidityProof},
    LightDiscriminator,
};
use solana_program::{
    account_info::AccountInfo,
    entrypoint,
    program_error::ProgramError,
    pubkey::Pubkey,
};

pub const ID: Pubkey = pubkey!("Recpt11111111111111111111111111111111");
// Update this constant to the deployed program ID.
pub const LIGHT_CPI_SIGNER: CpiSigner = derive_light_cpi_signer!(
    "Recpt11111111111111111111111111111111"
);

entrypoint!(process_instruction);

#[repr(u8)]
#[derive(Debug)]
pub enum ReceiptInstruction {
    Create = 0,
    Update = 1,
}

impl TryFrom<u8> for ReceiptInstruction {
    type Error = ProgramError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(ReceiptInstruction::Create),
            1 => Ok(ReceiptInstruction::Update),
            _ => Err(ProgramError::InvalidInstructionData),
        }
    }
}

#[derive(Debug, Clone, Default, BorshSerialize, BorshDeserialize, LightDiscriminator)]
pub struct CompressedReceipt {
    pub owner: Pubkey,
    pub order_commitment: [u8; 32],
    pub receipt_hash: [u8; 32],
    pub orderbook_root: [u8; 32],
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct CreateReceiptInstructionData {
    pub proof: Vec<u8>,
    pub address_tree_info: Vec<u8>,
    pub output_state_tree_index: u8,
    pub order_commitment: [u8; 32],
    pub receipt_hash: [u8; 32],
    pub orderbook_root: [u8; 32],
}

#[derive(BorshSerialize, BorshDeserialize)]
pub struct UpdateReceiptInstructionData {
    pub proof: Vec<u8>,
    pub account_meta: Vec<u8>,
    pub order_commitment: [u8; 32],
    pub receipt_hash: [u8; 32],
    pub orderbook_root: [u8; 32],
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

    let instruction = ReceiptInstruction::try_from(instruction_data[0])?;
    match instruction {
        ReceiptInstruction::Create => {
            let data = CreateReceiptInstructionData::try_from_slice(&instruction_data[1..])
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            create_receipt(accounts, data)
        }
        ReceiptInstruction::Update => {
            let data = UpdateReceiptInstructionData::try_from_slice(&instruction_data[1..])
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            update_receipt(accounts, data)
        }
    }
}

fn create_receipt(
    accounts: &[AccountInfo],
    instruction_data: CreateReceiptInstructionData,
) -> Result<(), ProgramError> {
    let signer = accounts
        .first()
        .ok_or(ProgramError::NotEnoughAccountKeys)?;

    let light_cpi_accounts = CpiAccounts::new(signer, &accounts[1..], LIGHT_CPI_SIGNER);

    let proof = ValidityProof::try_from_slice(&instruction_data.proof)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    let address_tree_info = PackedAddressTreeInfo::try_from_slice(&instruction_data.address_tree_info)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    let tree_pubkey = address_tree_info
        .get_tree_pubkey(&light_cpi_accounts)
        .map_err(|_| ProgramError::NotEnoughAccountKeys)?;

    let (address, address_seed) = derive_address(
        &[b"receipt", &instruction_data.order_commitment],
        &tree_pubkey,
        &ID,
    );

    let new_address_params = address_tree_info.into_new_address_params_packed(address_seed);

    let mut receipt = LightAccount::<CompressedReceipt>::new_init(
        &ID,
        Some(address),
        instruction_data.output_state_tree_index,
    );
    receipt.owner = *signer.key;
    receipt.order_commitment = instruction_data.order_commitment;
    receipt.receipt_hash = instruction_data.receipt_hash;
    receipt.orderbook_root = instruction_data.orderbook_root;

    LightSystemProgramCpi::new_cpi(LIGHT_CPI_SIGNER, proof)
        .with_light_account(receipt)
        .map_err(|_| ProgramError::InvalidInstructionData)?
        .with_new_addresses(&[new_address_params])
        .invoke(light_cpi_accounts)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    Ok(())
}

fn update_receipt(
    accounts: &[AccountInfo],
    instruction_data: UpdateReceiptInstructionData,
) -> Result<(), ProgramError> {
    let signer = accounts
        .first()
        .ok_or(ProgramError::NotEnoughAccountKeys)?;

    let light_cpi_accounts = CpiAccounts::new(signer, &accounts[1..], LIGHT_CPI_SIGNER);

    let proof = ValidityProof::try_from_slice(&instruction_data.proof)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    let account_meta = CompressedAccountMeta::try_from_slice(&instruction_data.account_meta)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    let mut receipt = LightAccount::<CompressedReceipt>::new_mut(
        &ID,
        &account_meta,
        CompressedReceipt {
            owner: *signer.key,
            order_commitment: instruction_data.order_commitment,
            receipt_hash: instruction_data.receipt_hash,
            orderbook_root: instruction_data.orderbook_root,
        },
    )
    .map_err(|_| ProgramError::InvalidInstructionData)?;

    receipt.receipt_hash = instruction_data.receipt_hash;
    receipt.orderbook_root = instruction_data.orderbook_root;

    LightSystemProgramCpi::new_cpi(LIGHT_CPI_SIGNER, proof)
        .with_light_account(receipt)
        .map_err(|_| ProgramError::InvalidInstructionData)?
        .invoke(light_cpi_accounts)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    Ok(())
}
