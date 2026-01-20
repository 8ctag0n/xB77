use std::{
    collections::HashMap,
    env,
    path::PathBuf,
    sync::Once,
};

use mollusk_svm::{program::keyed_account_for_system_program, Mollusk};
use solana_account::{Account, ReadableAccount};
use solana_instruction::{AccountMeta, Instruction};
use solana_program::pubkey::Pubkey as ProgramPubkey;
use solana_program::system_program;
use solana_program_error::ProgramError;
use solana_pubkey::Pubkey;

use xb77_registry::error::RegistryError;
use xb77_registry::instruction::{
    AddCatalogPayload, DeactivateCatalogPayload, InitMerchantPayload, RegistryInstruction,
    UpdateCatalogPayload,
};
use xb77_registry::state::{CatalogAccount, MerchantAccount, CATALOG_SEED, MERCHANT_SEED};

static INIT: Once = Once::new();
const SYSTEM_PROGRAM_ID: Pubkey = Pubkey::new_from_array(system_program::ID.to_bytes());

fn system_program_account() -> Account {
    keyed_account_for_system_program().1
}

fn find_program_address(seeds: &[&[u8]], program_id: Pubkey) -> (Pubkey, u8) {
    let program_id_sp = ProgramPubkey::new_from_array(program_id.to_bytes());
    let (pda, bump) = ProgramPubkey::find_program_address(seeds, &program_id_sp);
    (Pubkey::new_from_array(pda.to_bytes()), bump)
}

fn setup_mollusk(program_id: &Pubkey) -> Mollusk {
    INIT.call_once(|| {
        let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let sbf_out_dir = manifest_dir
            .join("../../target/deploy")
            .canonicalize()
            .unwrap_or_else(|_| manifest_dir.join("../../target/deploy"));
        let program_path = sbf_out_dir.join("xb77_registry.so");
        if !program_path.exists() {
            panic!(
                "Missing program ELF at {}. Run `cargo build-sbf` in `onchain/`.",
                program_path.display()
            );
        }
        env::set_var("SBF_OUT_DIR", sbf_out_dir);
    });

    Mollusk::new(program_id, "xb77_registry")
}

fn init_merchant_ix(program_id: Pubkey, payer: Pubkey, merchant_id: &[u8]) -> Instruction {
    let payload = InitMerchantPayload {
        merchant_id: merchant_id.to_vec(),
    };
    let data = wincode::serialize(&RegistryInstruction::InitMerchant(payload)).unwrap();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, true),
            AccountMeta::new(merchant_pda, false),
            AccountMeta::new_readonly(SYSTEM_PROGRAM_ID, false),
        ],
    )
}

fn add_catalog_ix(
    program_id: Pubkey,
    payer: Pubkey,
    merchant_id: &[u8],
    catalog_id: u64,
    category: u8,
    catalog_url: &[u8],
) -> Instruction {
    let payload = AddCatalogPayload {
        merchant_id: merchant_id.to_vec(),
        catalog_id,
        category,
        catalog_url: catalog_url.to_vec(),
        metadata_hash: None,
    };
    let data = wincode::serialize(&RegistryInstruction::AddCatalog(payload)).unwrap();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, true),
            AccountMeta::new(merchant_pda, false),
            AccountMeta::new(catalog_pda, false),
            AccountMeta::new_readonly(SYSTEM_PROGRAM_ID, false),
        ],
    )
}

fn update_catalog_ix(
    program_id: Pubkey,
    payer: Pubkey,
    merchant_id: &[u8],
    catalog_id: u64,
    category: Option<u8>,
    catalog_url: Option<Vec<u8>>,
    active: Option<bool>,
) -> Instruction {
    let payload = UpdateCatalogPayload {
        merchant_id: merchant_id.to_vec(),
        catalog_id,
        category,
        catalog_url,
        metadata_hash: None,
        active,
    };
    let data = wincode::serialize(&RegistryInstruction::UpdateCatalog(payload)).unwrap();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, true),
            AccountMeta::new(merchant_pda, false),
            AccountMeta::new(catalog_pda, false),
        ],
    )
}

fn deactivate_catalog_ix(
    program_id: Pubkey,
    payer: Pubkey,
    merchant_id: &[u8],
    catalog_id: u64,
) -> Instruction {
    let payload = DeactivateCatalogPayload {
        merchant_id: merchant_id.to_vec(),
        catalog_id,
    };
    let data = wincode::serialize(&RegistryInstruction::DeactivateCatalog(payload)).unwrap();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, true),
            AccountMeta::new(merchant_pda, false),
            AccountMeta::new(catalog_pda, false),
        ],
    )
}

#[test]
fn init_merchant_creates_account() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let merchant_id = b"merchant-alpha";

    let mollusk = setup_mollusk(&program_id);
    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);

    let instruction = init_merchant_ix(program_id, payer, merchant_id);
    let accounts = vec![
        (payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID)),
        (merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID)),
        (SYSTEM_PROGRAM_ID, system_program_account()),
    ];

    let result = mollusk.process_instruction(&instruction, &accounts);
    assert!(result.program_result.is_ok());

    let (_, merchant_account) = result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &merchant_pda)
        .expect("merchant account missing");

    assert_eq!(merchant_account.owner(), &program_id);
    let merchant: MerchantAccount = wincode::deserialize(merchant_account.data()).unwrap();
    assert_eq!(merchant.owner, payer.to_bytes());
    assert_eq!(merchant.merchant_id, merchant_id.to_vec());
}

#[test]
fn add_catalog_creates_catalog_account() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let merchant_id = b"merchant-beta";
    let catalog_id = 7;
    let category = 3;
    let catalog_url = b"https://merchant.test/catalog.json";

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    store.insert(payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID));
    store.insert(merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(catalog_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(SYSTEM_PROGRAM_ID, system_program_account());

    let context = mollusk.with_context(store);
    let init_ix = init_merchant_ix(program_id, payer, merchant_id);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let add_ix = add_catalog_ix(
        program_id,
        payer,
        merchant_id,
        catalog_id,
        category,
        catalog_url,
    );
    let add_result = context.process_instruction(&add_ix);
    assert!(add_result.program_result.is_ok());

    let (_, catalog_account) = add_result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &catalog_pda)
        .expect("catalog account missing");

    let catalog: CatalogAccount = wincode::deserialize(catalog_account.data()).unwrap();
    assert_eq!(catalog.catalog_id, catalog_id);
    assert_eq!(catalog.category, category);
    assert_eq!(catalog.catalog_url, catalog_url.to_vec());
    assert!(catalog.active);
}

#[test]
fn update_catalog_changes_fields() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let merchant_id = b"merchant-gamma";
    let catalog_id = 42;

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    store.insert(payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID));
    store.insert(merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(catalog_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(SYSTEM_PROGRAM_ID, system_program_account());

    let context = mollusk.with_context(store);
    let init_ix = init_merchant_ix(program_id, payer, merchant_id);
    assert!(context.process_instruction(&init_ix).program_result.is_ok());

    let add_ix = add_catalog_ix(
        program_id,
        payer,
        merchant_id,
        catalog_id,
        1,
        b"https://merchant.test/old.json",
    );
    assert!(context.process_instruction(&add_ix).program_result.is_ok());

    let update_ix = update_catalog_ix(
        program_id,
        payer,
        merchant_id,
        catalog_id,
        Some(9),
        Some(b"https://merchant.test/new.json".to_vec()),
        Some(false),
    );
    let update_result = context.process_instruction(&update_ix);
    assert!(update_result.program_result.is_ok());

    let (_, catalog_account) = update_result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &catalog_pda)
        .expect("catalog account missing");

    let catalog: CatalogAccount = wincode::deserialize(catalog_account.data()).unwrap();
    assert_eq!(catalog.category, 9);
    assert_eq!(catalog.catalog_url, b"https://merchant.test/new.json".to_vec());
    assert!(!catalog.active);
}

#[test]
fn deactivate_catalog_marks_inactive() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let merchant_id = b"merchant-delta";
    let catalog_id = 99;

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    store.insert(payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID));
    store.insert(merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(catalog_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(SYSTEM_PROGRAM_ID, system_program_account());

    let context = mollusk.with_context(store);
    assert!(context
        .process_instruction(&init_merchant_ix(program_id, payer, merchant_id))
        .program_result
        .is_ok());
    assert!(context
        .process_instruction(&add_catalog_ix(
            program_id,
            payer,
            merchant_id,
            catalog_id,
            4,
            b"https://merchant.test/catalog.json",
        ))
        .program_result
        .is_ok());

    let deactivate_ix = deactivate_catalog_ix(program_id, payer, merchant_id, catalog_id);
    let deactivate_result = context.process_instruction(&deactivate_ix);
    assert!(deactivate_result.program_result.is_ok());

    let (_, catalog_account) = deactivate_result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &catalog_pda)
        .expect("catalog account missing");

    let catalog: CatalogAccount = wincode::deserialize(catalog_account.data()).unwrap();
    assert!(!catalog.active);
}

#[test]
fn add_catalog_rejects_wrong_owner() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let attacker = Pubkey::new_unique();
    let merchant_id = b"merchant-epsilon";
    let catalog_id = 5;

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    store.insert(payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID));
    store.insert(attacker, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID));
    store.insert(merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(catalog_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(SYSTEM_PROGRAM_ID, system_program_account());

    let context = mollusk.with_context(store);
    assert!(context
        .process_instruction(&init_merchant_ix(program_id, payer, merchant_id))
        .program_result
        .is_ok());

    let add_ix = add_catalog_ix(
        program_id,
        attacker,
        merchant_id,
        catalog_id,
        1,
        b"https://merchant.test/catalog.json",
    );
    let result = context.process_instruction(&add_ix);
    assert_eq!(
        result.program_result,
        Err(ProgramError::Custom(RegistryError::InvalidOwner as u32))
    );
}

#[test]
fn init_merchant_rejects_empty_id() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let merchant_id: &[u8] = b"";

    let mollusk = setup_mollusk(&program_id);
    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);

    let instruction = init_merchant_ix(program_id, payer, merchant_id);
    let accounts = vec![
        (payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID)),
        (merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID)),
        (SYSTEM_PROGRAM_ID, system_program_account()),
    ];

    let result = mollusk.process_instruction(&instruction, &accounts);
    assert_eq!(
        result.program_result,
        Err(ProgramError::Custom(RegistryError::InvalidMerchantId as u32))
    );
}

#[test]
fn add_catalog_rejects_long_url() {
    let program_id = Pubkey::new_unique();
    let payer = Pubkey::new_unique();
    let merchant_id = b"merchant-zeta";
    let catalog_id = 1;

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (merchant_pda, _bump) =
        find_program_address(&[MERCHANT_SEED, merchant_id], program_id);
    let (catalog_pda, _bump) = find_program_address(
        &[CATALOG_SEED, merchant_id, &catalog_id.to_le_bytes()],
        program_id,
    );

    store.insert(payer, Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID));
    store.insert(merchant_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(catalog_pda, Account::new(0, 0, &SYSTEM_PROGRAM_ID));
    store.insert(SYSTEM_PROGRAM_ID, system_program_account());

    let context = mollusk.with_context(store);
    assert!(context
        .process_instruction(&init_merchant_ix(program_id, payer, merchant_id))
        .program_result
        .is_ok());

    let long_url = vec![b'a'; 300];
    let add_ix = add_catalog_ix(
        program_id,
        payer,
        merchant_id,
        catalog_id,
        1,
        &long_url,
    );
    let result = context.process_instruction(&add_ix);
    assert_eq!(
        result.program_result,
        Err(ProgramError::Custom(RegistryError::CatalogUrlTooLong as u32))
    );
}
