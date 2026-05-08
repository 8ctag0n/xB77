use solana_program::{
    account_info::{next_account_info, AccountInfo},
    entrypoint::ProgramResult,
    msg,
    program::invoke_signed,
    program_error::ProgramError,
    pubkey::Pubkey,
    rent::Rent,
    sysvar::{clock::Clock, Sysvar},
};

use crate::error::RegistryError;
use crate::instruction::{
    AddCatalogPayload, DeactivateCatalogPayload, InitMerchantPayload, RegistryInstruction,
    UpdateCatalogPayload, UpdateMerchantPayload,
};
use crate::state::{
    CatalogAccount, MerchantAccount, CATALOG_SEED, MAX_CATALOG_URL_LEN, MAX_MERCHANT_ID_LEN,
    MERCHANT_SEED,
};

fn now_ts() -> Result<u64, ProgramError> {
    let clock = Clock::get()?;
    Ok(clock.unix_timestamp.max(0) as u64)
}

fn validate_merchant_id(merchant_id: &[u8]) -> Result<(), ProgramError> {
    if merchant_id.is_empty() {
        return Err(RegistryError::InvalidMerchantId.into());
    }
    if merchant_id.len() > MAX_MERCHANT_ID_LEN {
        return Err(RegistryError::MerchantIdTooLong.into());
    }
    Ok(())
}

fn validate_catalog_url(url: &[u8]) -> Result<(), ProgramError> {
    if url.is_empty() || url.len() > MAX_CATALOG_URL_LEN {
        return Err(RegistryError::CatalogUrlTooLong.into());
    }
    Ok(())
}

fn derive_merchant_pda(program_id: &Pubkey, merchant_id: &[u8]) -> (Pubkey, u8) {
    Pubkey::find_program_address(&[MERCHANT_SEED, merchant_id], program_id)
}

fn derive_catalog_pda(program_id: &Pubkey, merchant_id: &[u8], catalog_id: u64) -> (Pubkey, u8) {
    Pubkey::find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    )
}

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    let instruction: RegistryInstruction = wincode::deserialize(instruction_data)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;

    match instruction {
        RegistryInstruction::InitMerchant(payload) => {
            process_init_merchant(program_id, accounts, payload)
        }
        RegistryInstruction::UpdateMerchant(payload) => {
            process_update_merchant(program_id, accounts, payload)
        }
        RegistryInstruction::AddCatalog(payload) => {
            process_add_catalog(program_id, accounts, payload)
        }
        RegistryInstruction::UpdateCatalog(payload) => {
            process_update_catalog(program_id, accounts, payload)
        }
        RegistryInstruction::DeactivateCatalog(payload) => {
            process_deactivate_catalog(program_id, accounts, payload)
        }
    }
}

fn process_init_merchant(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: InitMerchantPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let merchant_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let system_program_info = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(RegistryError::MissingSigner.into());
    }
    if system_program_info.key != &Pubkey::default() {
        return Err(RegistryError::InvalidSystemProgram.into());
    }

    validate_merchant_id(&payload.merchant_id)?;

    let (expected_pda, bump) = derive_merchant_pda(program_id, &payload.merchant_id);
    if merchant_account.key != &expected_pda {
        return Err(RegistryError::InvalidMerchantPda.into());
    }
    if merchant_account.data_len() > 0 && !merchant_account.data_is_empty() {
        return Err(RegistryError::MerchantAlreadyInitialized.into());
    }

    let now = now_ts()?;
    let merchant = MerchantAccount {
        merchant_id: payload.merchant_id,
        owner: payer.key.to_bytes(),
        supported_methods: payload.supported_methods,
        catalog_count: 0,
        created_at: now,
        updated_at: now,
        bump,
    };

    let serialized = wincode::serialize(&merchant)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    let rent = Rent::get()?;
    let lamports = rent.minimum_balance(serialized.len());

    invoke_signed(
        &solana_system_interface::instruction::create_account(
            payer.key,
            merchant_account.key,
            lamports,
            serialized.len() as u64,
            program_id,
        ),
        &[payer.clone(), merchant_account.clone(), system_program_info.clone()],
        &[&[MERCHANT_SEED, merchant.merchant_id.as_slice(), &[bump]]],
    )?;

    merchant_account
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);
    msg!("merchant initialized");
    Ok(())
}

fn process_update_merchant(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: UpdateMerchantPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let merchant_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(RegistryError::MissingSigner.into());
    }

    validate_merchant_id(&payload.merchant_id)?;
    let (merchant_pda, _) = derive_merchant_pda(program_id, &payload.merchant_id);
    if merchant_account.key != &merchant_pda {
        return Err(RegistryError::InvalidMerchantPda.into());
    }
    if merchant_account.data_is_empty() {
        return Err(RegistryError::MerchantNotInitialized.into());
    }

    let mut merchant: MerchantAccount = wincode::deserialize(&merchant_account.data.borrow())
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if merchant.owner != payer.key.to_bytes() {
        return Err(RegistryError::InvalidOwner.into());
    }

    if let Some(methods) = payload.supported_methods {
        merchant.supported_methods = methods;
    }
    merchant.updated_at = now_ts()?;

    let serialized = wincode::serialize(&merchant)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if serialized.len() > merchant_account.data_len() {
        return Err(RegistryError::DataTooLarge.into());
    }
    merchant_account
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("merchant updated");
    Ok(())
}

fn process_add_catalog(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: AddCatalogPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let merchant_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let catalog_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let system_program_info = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(RegistryError::MissingSigner.into());
    }
    if system_program_info.key != &Pubkey::default() {
        return Err(RegistryError::InvalidSystemProgram.into());
    }

    validate_merchant_id(&payload.merchant_id)?;
    validate_catalog_url(&payload.catalog_url)?;

    let (merchant_pda, merchant_bump) = derive_merchant_pda(program_id, &payload.merchant_id);
    if merchant_account.key != &merchant_pda {
        return Err(RegistryError::InvalidMerchantPda.into());
    }
    if merchant_account.data_is_empty() {
        return Err(RegistryError::MerchantNotInitialized.into());
    }

    let mut merchant: MerchantAccount = wincode::deserialize(&merchant_account.data.borrow())
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if merchant.owner != payer.key.to_bytes() {
        return Err(RegistryError::InvalidOwner.into());
    }

    let (catalog_pda, catalog_bump) =
        derive_catalog_pda(program_id, &payload.merchant_id, payload.catalog_id);
    if catalog_account.key != &catalog_pda {
        return Err(RegistryError::InvalidCatalogPda.into());
    }
    if catalog_account.data_len() > 0 && !catalog_account.data_is_empty() {
        return Err(RegistryError::CatalogAlreadyInitialized.into());
    }

    let now = now_ts()?;
    let catalog = CatalogAccount {
        merchant_id: payload.merchant_id,
        catalog_id: payload.catalog_id,
        category: payload.category,
        catalog_url: payload.catalog_url,
        metadata_hash: payload.metadata_hash,
        active: true,
        updated_at: now,
        bump: catalog_bump,
    };

    let serialized = wincode::serialize(&catalog)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    let rent = Rent::get()?;
    let lamports = rent.minimum_balance(serialized.len());

    invoke_signed(
        &solana_system_interface::instruction::create_account(
            payer.key,
            catalog_account.key,
            lamports,
            serialized.len() as u64,
            program_id,
        ),
        &[payer.clone(), catalog_account.clone(), system_program_info.clone()],
        &[&[
            CATALOG_SEED,
            catalog.merchant_id.as_slice(),
            &payload.catalog_id.to_le_bytes(),
            &[catalog_bump],
        ]],
    )?;

    catalog_account
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    merchant.catalog_count = merchant.catalog_count.saturating_add(1);
    merchant.updated_at = now;
    merchant.bump = merchant_bump;
    let merchant_serialized = wincode::serialize(&merchant)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if merchant_serialized.len() > merchant_account.data_len() {
        return Err(RegistryError::DataTooLarge.into());
    }
    merchant_account
        .data
        .borrow_mut()
        .copy_from_slice(&merchant_serialized);

    msg!("catalog added");
    Ok(())
}

fn process_update_catalog(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: UpdateCatalogPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let merchant_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let catalog_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(RegistryError::MissingSigner.into());
    }

    validate_merchant_id(&payload.merchant_id)?;
    let (merchant_pda, _) = derive_merchant_pda(program_id, &payload.merchant_id);
    if merchant_account.key != &merchant_pda {
        return Err(RegistryError::InvalidMerchantPda.into());
    }
    if merchant_account.data_is_empty() {
        return Err(RegistryError::MerchantNotInitialized.into());
    }

    let merchant: MerchantAccount = wincode::deserialize(&merchant_account.data.borrow())
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if merchant.owner != payer.key.to_bytes() {
        return Err(RegistryError::InvalidOwner.into());
    }

    let (catalog_pda, _) =
        derive_catalog_pda(program_id, &payload.merchant_id, payload.catalog_id);
    if catalog_account.key != &catalog_pda {
        return Err(RegistryError::InvalidCatalogPda.into());
    }
    if catalog_account.data_is_empty() {
        return Err(RegistryError::CatalogNotInitialized.into());
    }

    let mut catalog: CatalogAccount = wincode::deserialize(&catalog_account.data.borrow())
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;

    if let Some(category) = payload.category {
        catalog.category = category;
    }
    if let Some(url) = payload.catalog_url {
        validate_catalog_url(&url)?;
        catalog.catalog_url = url;
    }
    if let Some(hash) = payload.metadata_hash {
        catalog.metadata_hash = Some(hash);
    }
    if let Some(active) = payload.active {
        catalog.active = active;
    }
    catalog.updated_at = now_ts()?;

    let serialized = wincode::serialize(&catalog)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if serialized.len() > catalog_account.data_len() {
        return Err(RegistryError::DataTooLarge.into());
    }
    catalog_account
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("catalog updated");
    Ok(())
}

fn process_deactivate_catalog(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    payload: DeactivateCatalogPayload,
) -> ProgramResult {
    let mut accounts_iter = accounts.iter();
    let payer = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let merchant_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;
    let catalog_account = next_account_info(&mut accounts_iter)
        .map_err(|_| ProgramError::from(RegistryError::NotEnoughAccounts))?;

    if !payer.is_signer {
        return Err(RegistryError::MissingSigner.into());
    }

    validate_merchant_id(&payload.merchant_id)?;
    let (merchant_pda, _) = derive_merchant_pda(program_id, &payload.merchant_id);
    if merchant_account.key != &merchant_pda {
        return Err(RegistryError::InvalidMerchantPda.into());
    }
    if merchant_account.data_is_empty() {
        return Err(RegistryError::MerchantNotInitialized.into());
    }

    let merchant: MerchantAccount = wincode::deserialize(&merchant_account.data.borrow())
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if merchant.owner != payer.key.to_bytes() {
        return Err(RegistryError::InvalidOwner.into());
    }

    let (catalog_pda, _) =
        derive_catalog_pda(program_id, &payload.merchant_id, payload.catalog_id);
    if catalog_account.key != &catalog_pda {
        return Err(RegistryError::InvalidCatalogPda.into());
    }
    if catalog_account.data_is_empty() {
        return Err(RegistryError::CatalogNotInitialized.into());
    }

    let mut catalog: CatalogAccount = wincode::deserialize(&catalog_account.data.borrow())
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    catalog.active = false;
    catalog.updated_at = now_ts()?;
    let serialized = wincode::serialize(&catalog)
        .map_err(|_| ProgramError::from(RegistryError::InvalidInstruction))?;
    if serialized.len() > catalog_account.data_len() {
        return Err(RegistryError::DataTooLarge.into());
    }
    catalog_account
        .data
        .borrow_mut()
        .copy_from_slice(&serialized);

    msg!("catalog deactivated");
    Ok(())
}
