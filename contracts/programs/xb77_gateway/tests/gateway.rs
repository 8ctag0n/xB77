use std::{
    collections::HashMap,
    env,
    path::PathBuf,
    sync::Once,
};

use mollusk_svm::Mollusk;
use solana_account::Account;
use solana_instruction::{AccountMeta, Instruction};
use solana_program::system_program;
use solana_program::program_error::ProgramError;
use solana_pubkey::Pubkey;

use xb77_gateway::error::GatewayError;
use xb77_gateway::instruction::{
    GatewayInstruction,
    InitGatewayPayload,
    ProofPayload,
    UpdateGatewayPayload,
};
use xb77_gateway::state::{GatewayConfig, GATEWAY_STATE_SEED};

static INIT: Once = Once::new();

fn setup_mollusk(program_id: &Pubkey) -> Mollusk {
    INIT.call_once(|| {
        let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let sbf_out_dir = manifest_dir
            .join("../../target/deploy")
            .canonicalize()
            .unwrap_or_else(|_| manifest_dir.join("../../target/deploy"));
        let program_path = sbf_out_dir.join("xb77_gateway.so");
        if !program_path.exists() {
            panic!(
                "Missing program ELF at {}. Run `cargo build-sbf` in `contracts/`.",
                program_path.display()
            );
        }
        env::set_var("SBF_OUT_DIR", sbf_out_dir);
    });

    Mollusk::new(program_id, "xb77_gateway")
}

fn init_instruction(program_id: Pubkey, admin: Pubkey, merkle_root: [u8; 32]) -> Instruction {
    let payload = InitGatewayPayload {
        admin: admin.to_bytes(),
        merkle_root,
    };
    let data = wincode::serialize(&GatewayInstruction::InitGateway(payload)).unwrap();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(admin, true),
            AccountMeta::new(gateway_state, false),
            AccountMeta::new_readonly(system_program::ID, false),
        ],
    )
}

fn update_instruction(program_id: Pubkey, admin: Pubkey, merkle_root: [u8; 32]) -> Instruction {
    let payload = UpdateGatewayPayload { merkle_root };
    let data = wincode::serialize(&GatewayInstruction::UpdateGateway(payload)).unwrap();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![AccountMeta::new(admin, true), AccountMeta::new(gateway_state, false)],
    )
}

fn verify_instruction(
    program_id: Pubkey,
    payer: Pubkey,
    merkle_root: [u8; 32],
    merkle_index: u32,
) -> Instruction {
    let payload = ProofPayload {
        root: merkle_root,
        merkle_index,
        proof: vec![1, 2, 3],
        public_inputs: vec![merkle_root],
    };
    verify_instruction_with_payload(program_id, payer, true, payload)
}

fn verify_instruction_with_payload(
    program_id: Pubkey,
    payer: Pubkey,
    payer_is_signer: bool,
    payload: ProofPayload,
) -> Instruction {
    let data = wincode::serialize(&GatewayInstruction::VerifyBadge(payload)).unwrap();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, payer_is_signer),
            AccountMeta::new(gateway_state, false),
        ],
    )
}

#[test]
fn init_gateway_creates_state() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [7u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    let instruction = init_instruction(program_id, admin, merkle_root);
    let accounts = vec![
        (
            admin,
            Account::new(1_000_000_000, 0, &system_program::ID),
        ),
        (
            gateway_state,
            Account::new(0, 0, &system_program::ID),
        ),
        (
            system_program::ID,
            Account::new(0, 0, &system_program::ID),
        ),
    ];

    let result = mollusk.process_instruction(&instruction, &accounts);
    assert!(result.program_result.is_ok());

    let (_, state_account) = result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &gateway_state)
        .expect("gateway_state missing from results");

    assert_eq!(state_account.owner(), &program_id);
    let config: GatewayConfig = wincode::deserialize(state_account.data()).unwrap();
    assert_eq!(config.admin, admin.to_bytes());
    assert_eq!(config.merkle_root, merkle_root);
}

#[test]
fn update_gateway_changes_root() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [1u8; 32];
    let new_root = [2u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let update_ix = update_instruction(program_id, admin, new_root);
    let update_result = context.process_instruction(&update_ix);
    assert!(update_result.program_result.is_ok());

    let (_, state_account) = update_result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &gateway_state)
        .expect("gateway_state missing from results");

    let config: GatewayConfig = wincode::deserialize(state_account.data()).unwrap();
    assert_eq!(config.merkle_root, new_root);
}

#[test]
fn verify_badge_checks_root_and_index() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [9u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let verify_ix = verify_instruction(program_id, admin, merkle_root, 2);
    let verify_result = context.process_instruction(&verify_ix);
    assert!(verify_result.program_result.is_ok());

    let bad_root = [3u8; 32];
    let bad_verify_ix = verify_instruction(program_id, admin, bad_root, 2);
    let bad_verify_result = context.process_instruction(&bad_verify_ix);
    assert_eq!(
        bad_verify_result.program_result.unwrap_err(),
        ProgramError::Custom(GatewayError::InvalidMerkleRoot as u32)
    );
}

#[test]
fn verify_badge_rejects_index_out_of_range() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [4u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let verify_ix = verify_instruction(program_id, admin, merkle_root, 8);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result.unwrap_err(),
        ProgramError::Custom(GatewayError::InvalidMerkleIndex as u32)
    );
}

#[test]
fn verify_badge_rejects_empty_proof() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [6u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 1,
        proof: Vec::new(),
        public_inputs: vec![merkle_root],
    };
    let verify_ix = verify_instruction_with_payload(program_id, admin, true, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result.unwrap_err(),
        ProgramError::Custom(GatewayError::EmptyProof as u32)
    );
}

#[test]
fn verify_badge_rejects_public_input_mismatch() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [8u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 3,
        proof: vec![9],
        public_inputs: vec![[2u8; 32]],
    };
    let verify_ix = verify_instruction_with_payload(program_id, admin, true, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result.unwrap_err(),
        ProgramError::Custom(GatewayError::InvalidPublicInputs as u32)
    );
}

#[test]
fn verify_badge_rejects_missing_signer() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [11u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 1,
        proof: vec![1],
        public_inputs: vec![merkle_root],
    };
    let verify_ix = verify_instruction_with_payload(program_id, admin, false, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result.unwrap_err(),
        ProgramError::Custom(GatewayError::MissingSigner as u32)
    );
}

#[test]
fn verify_badge_rejects_invalid_pda() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let invalid_state = Pubkey::new_unique();

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &system_program::ID),
    );
    store.insert(
        invalid_state,
        Account::new(0, 0, &system_program::ID),
    );
    store.insert(
        system_program::ID,
        Account::new(0, 0, &system_program::ID),
    );

    let context = mollusk.with_context(store);
    let payload = ProofPayload {
        root: [1u8; 32],
        merkle_index: 0,
        proof: vec![1],
        public_inputs: vec![[1u8; 32]],
    };
    let data = wincode::serialize(&GatewayInstruction::VerifyBadge(payload)).unwrap();

    let verify_ix = Instruction::new_with_bytes(
        program_id,
        &data,
        vec![AccountMeta::new(admin, true), AccountMeta::new(invalid_state, false)],
    );
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result.unwrap_err(),
        ProgramError::Custom(GatewayError::InvalidGatewayStatePda as u32)
    );
}
