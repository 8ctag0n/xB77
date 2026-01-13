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
use solana_pubkey::Pubkey;

use xb77_gateway::instruction::{GatewayInstruction, InitGatewayPayload, UpdateGatewayPayload};
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
