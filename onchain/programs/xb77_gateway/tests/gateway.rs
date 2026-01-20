use std::{
    collections::HashMap,
    env,
    path::PathBuf,
    sync::Once,
};

use mollusk_svm::{program::keyed_account_for_system_program, result::ProgramResult, Mollusk};
use solana_account::{Account, ReadableAccount};
use solana_instruction::{AccountMeta, Instruction};
use solana_program::pubkey::Pubkey as ProgramPubkey;
use solana_program::system_program;
use solana_program_error::ProgramError;
use solana_pubkey::Pubkey;

use xb77_gateway::error::GatewayError;
use xb77_gateway::instruction::{
    GatewayInstruction,
    InitGatewayPayload,
    ProofPayload,
    SubmitPrivateOrderPayload,
    UpdateGatewayPayload,
};
use xb77_gateway::state::{GatewayConfig, GATEWAY_STATE_SEED, NULLIFIER_SEED};

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

fn init_instruction(
    program_id: Pubkey,
    admin: Pubkey,
    merkle_root: [u8; 32],
    zk_verifier: Pubkey,
) -> Instruction {
    let payload = InitGatewayPayload {
        admin: admin.to_bytes(),
        merkle_root,
        zk_verifier: zk_verifier.to_bytes(),
        auditor: [0u8; 32],
        credit_root: [0u8; 32],
        orderbook_root: [0u8; 32],
        mxe_program_id: [0u8; 32],
        light_system_program: [0u8; 32],
        light_account_compression_program: [0u8; 32],
        light_noop_program: [0u8; 32],
    };
    let data = wincode::serialize(&GatewayInstruction::InitGateway(payload)).unwrap();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(admin, true),
            AccountMeta::new(gateway_state, false),
            AccountMeta::new_readonly(SYSTEM_PROGRAM_ID, false),
        ],
    )
}

fn update_instruction(program_id: Pubkey, admin: Pubkey, merkle_root: [u8; 32]) -> Instruction {
    let payload = UpdateGatewayPayload {
        merkle_root,
        auditor: [0u8; 32],
        credit_root: [0u8; 32],
        orderbook_root: [0u8; 32],
        mxe_program_id: [0u8; 32],
        light_system_program: [0u8; 32],
        light_account_compression_program: [0u8; 32],
        light_noop_program: [0u8; 32],
    };
    let data = wincode::serialize(&GatewayInstruction::UpdateGateway(payload)).unwrap();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

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
    zk_verifier: Pubkey,
) -> Instruction {
    let payload = ProofPayload {
        root: merkle_root,
        merkle_index,
        proof: vec![1, 2, 3],
        public_witness: vec![4, 5, 6],
    };
    verify_instruction_with_payload(program_id, payer, true, zk_verifier, payload)
}

fn verify_instruction_with_payload(
    program_id: Pubkey,
    payer: Pubkey,
    payer_is_signer: bool,
    zk_verifier: Pubkey,
    payload: ProofPayload,
) -> Instruction {
    let data = wincode::serialize(&GatewayInstruction::VerifyBadge(payload)).unwrap();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, payer_is_signer),
            AccountMeta::new(gateway_state, false),
            AccountMeta::new_readonly(zk_verifier, false),
        ],
    )
}

fn submit_instruction(
    program_id: Pubkey,
    payer: Pubkey,
    payload: SubmitPrivateOrderPayload,
    nullifier_pda: Pubkey,
) -> Instruction {
    let data = wincode::serialize(&GatewayInstruction::SubmitPrivateOrder(payload)).unwrap();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(payer, true),
            AccountMeta::new(gateway_state, false),
            AccountMeta::new(nullifier_pda, false),
            AccountMeta::new_readonly(SYSTEM_PROGRAM_ID, false),
        ],
    )
}

#[test]
fn init_gateway_creates_state() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let zk_verifier = Pubkey::new_unique();
    let merkle_root = [7u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    let instruction = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let accounts = vec![
        (
            admin,
            Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
        ),
        (
            gateway_state,
            Account::new(0, 0, &SYSTEM_PROGRAM_ID),
        ),
        (
            SYSTEM_PROGRAM_ID,
            system_program_account(),
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
    assert_eq!(config.zk_verifier, zk_verifier.to_bytes());
}

#[test]
fn update_gateway_changes_root() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [1u8; 32];
    let new_root = [2u8; 32];
    let zk_verifier = Pubkey::default();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
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
    assert_eq!(config.zk_verifier, zk_verifier.to_bytes());
}

#[test]
fn verify_badge_checks_root_and_index() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [9u8; 32];
    let zk_verifier = Pubkey::default();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let verify_ix = verify_instruction(program_id, admin, merkle_root, 2, zk_verifier);
    let verify_result = context.process_instruction(&verify_ix);
    assert!(verify_result.program_result.is_ok());

    let bad_root = [3u8; 32];
    let bad_verify_ix = verify_instruction(program_id, admin, bad_root, 2, zk_verifier);
    let bad_verify_result = context.process_instruction(&bad_verify_ix);
    assert_eq!(
        bad_verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::InvalidMerkleRoot as u32
        ))
    );
}

#[test]
fn verify_badge_rejects_index_out_of_range() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [4u8; 32];
    let zk_verifier = Pubkey::default();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let verify_ix = verify_instruction(program_id, admin, merkle_root, 8, zk_verifier);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::InvalidMerkleIndex as u32
        ))
    );
}

#[test]
fn verify_badge_rejects_empty_proof() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [6u8; 32];
    let zk_verifier = Pubkey::default();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 1,
        proof: Vec::new(),
        public_witness: vec![1],
    };
    let verify_ix = verify_instruction_with_payload(program_id, admin, true, zk_verifier, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(GatewayError::EmptyProof as u32))
    );
}

#[test]
fn verify_badge_rejects_empty_public_witness() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [8u8; 32];
    let zk_verifier = Pubkey::default();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 3,
        proof: vec![9],
        public_witness: Vec::new(),
    };
    let verify_ix = verify_instruction_with_payload(program_id, admin, true, zk_verifier, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::EmptyPublicWitness as u32
        ))
    );
}

#[test]
fn verify_badge_rejects_invalid_verifier_program() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [12u8; 32];
    let zk_verifier = Pubkey::new_unique();
    let wrong_verifier = Pubkey::new_unique();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 2,
        proof: vec![3],
        public_witness: vec![4],
    };
    let verify_ix =
        verify_instruction_with_payload(program_id, admin, true, wrong_verifier, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::InvalidZkVerifier as u32
        ))
    );
}

#[test]
fn verify_badge_rejects_missing_signer() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [11u8; 32];
    let zk_verifier = Pubkey::new_unique();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = ProofPayload {
        root: merkle_root,
        merkle_index: 1,
        proof: vec![1],
        public_witness: vec![2],
    };
    let verify_ix = verify_instruction_with_payload(program_id, admin, false, zk_verifier, payload);
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(GatewayError::MissingSigner as u32))
    );
}

#[test]
fn verify_badge_rejects_invalid_pda() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let zk_verifier = Pubkey::new_unique();

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let invalid_state = Pubkey::new_unique();

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        invalid_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let payload = ProofPayload {
        root: [1u8; 32],
        merkle_index: 0,
        proof: vec![1],
        public_witness: vec![1],
    };
    let data = wincode::serialize(&GatewayInstruction::VerifyBadge(payload)).unwrap();

    let verify_ix = Instruction::new_with_bytes(
        program_id,
        &data,
        vec![
            AccountMeta::new(admin, true),
            AccountMeta::new(invalid_state, false),
            AccountMeta::new_readonly(zk_verifier, false),
        ],
    );
    let verify_result = context.process_instruction(&verify_ix);
    assert_eq!(
        verify_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::InvalidGatewayStatePda as u32
        ))
    );
}

#[test]
fn submit_private_order_creates_nullifier_pda() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [5u8; 32];
    let zk_verifier = Pubkey::default();
    let nullifier = [7u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);
    let (nullifier_pda, _nullifier_bump) =
        find_program_address(&[NULLIFIER_SEED, &nullifier], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        nullifier_pda,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = SubmitPrivateOrderPayload {
        order_id: 1,
        amount: 5,
        token: Pubkey::new_unique().to_bytes(),
        recipient: Pubkey::new_unique().to_bytes(),
        nullifier,
    };
    let submit_ix = submit_instruction(program_id, admin, payload, nullifier_pda);
    let submit_result = context.process_instruction(&submit_ix);
    assert!(submit_result.program_result.is_ok());

    let (_, nullifier_account) = submit_result
        .resulting_accounts
        .iter()
        .find(|(key, _)| key == &nullifier_pda)
        .expect("nullifier account missing from results");
    assert_eq!(nullifier_account.owner(), &program_id);
    assert_eq!(nullifier_account.data(), &[1u8]);
}

#[test]
fn submit_private_order_rejects_nullifier_reuse() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [6u8; 32];
    let zk_verifier = Pubkey::default();
    let nullifier = [9u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);
    let (nullifier_pda, _nullifier_bump) =
        find_program_address(&[NULLIFIER_SEED, &nullifier], program_id);

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        nullifier_pda,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = SubmitPrivateOrderPayload {
        order_id: 1,
        amount: 5,
        token: Pubkey::new_unique().to_bytes(),
        recipient: Pubkey::new_unique().to_bytes(),
        nullifier,
    };
    let submit_ix = submit_instruction(program_id, admin, payload, nullifier_pda);
    let submit_result = context.process_instruction(&submit_ix);
    assert!(submit_result.program_result.is_ok());

    let reuse_payload = SubmitPrivateOrderPayload {
        order_id: 2,
        amount: 8,
        token: Pubkey::new_unique().to_bytes(),
        recipient: Pubkey::new_unique().to_bytes(),
        nullifier,
    };
    let reuse_ix = submit_instruction(program_id, admin, reuse_payload, nullifier_pda);
    let reuse_result = context.process_instruction(&reuse_ix);
    assert_eq!(
        reuse_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::NullifierAlreadyUsed as u32
        ))
    );
}

#[test]
fn submit_private_order_rejects_invalid_nullifier_pda() {
    let program_id = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    let merkle_root = [10u8; 32];
    let zk_verifier = Pubkey::default();
    let nullifier = [11u8; 32];

    let mollusk = setup_mollusk(&program_id);
    let mut store: HashMap<Pubkey, Account> = HashMap::new();

    let (gateway_state, _bump) =
        find_program_address(&[GATEWAY_STATE_SEED], program_id);
    let wrong_nullifier_pda = Pubkey::new_unique();

    store.insert(
        admin,
        Account::new(1_000_000_000, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        gateway_state,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        wrong_nullifier_pda,
        Account::new(0, 0, &SYSTEM_PROGRAM_ID),
    );
    store.insert(
        SYSTEM_PROGRAM_ID,
            system_program_account(),
    );

    let context = mollusk.with_context(store);
    let init_ix = init_instruction(program_id, admin, merkle_root, zk_verifier);
    let init_result = context.process_instruction(&init_ix);
    assert!(init_result.program_result.is_ok());

    let payload = SubmitPrivateOrderPayload {
        order_id: 1,
        amount: 5,
        token: Pubkey::new_unique().to_bytes(),
        recipient: Pubkey::new_unique().to_bytes(),
        nullifier,
    };
    let submit_ix = submit_instruction(program_id, admin, payload, wrong_nullifier_pda);
    let submit_result = context.process_instruction(&submit_ix);
    assert_eq!(
        submit_result.program_result,
        ProgramResult::Failure(ProgramError::Custom(
            GatewayError::InvalidNullifierPda as u32
        ))
    );
}
