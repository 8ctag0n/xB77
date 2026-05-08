use mollusk_svm::{Mollusk, result::InstructionResult};
use solana_pubkey::Pubkey;
use solana_account::Account;
use solana_instruction::{Instruction, AccountMeta};

use xb77_core::{
    instruction::{CoreInstruction, InitCorePayload, RegisterAgentPayload, VerifyAndCreditPayload, RequestPaymentPayload},
    state::{CoreConfig, CreditLine},
};

#[test]
fn test_core_full_flow() {
    let program_id = Pubkey::new_unique();
    let mollusk = Mollusk::new(&program_id, "xb77_core");

    // --- Actors ---
    let admin = Pubkey::new_unique();
    let agent = Pubkey::new_unique();
    let gateway_program = Pubkey::new_unique(); // Mock Gateway
    let receipts_program = Pubkey::new_unique();
    let treasury_mint = Pubkey::new_unique();

    // --- 1. Init Core ---
    let (config_pda, _bump) = Pubkey::find_program_address(&[b"config_v3"], &program_id);

    let init_payload = InitCorePayload {
        admin: admin.to_bytes(),
        gateway_program: gateway_program.to_bytes(),
        receipts_program: receipts_program.to_bytes(),
        treasury_mint: treasury_mint.to_bytes(),
    };

    let system_program = solana_pubkey::Pubkey::default(); // system program ID is 11111111111111111111111111111111

    let instruction = Instruction::new_with_bytes(
        program_id,
        &wincode::serialize(&CoreInstruction::InitCore(init_payload)).unwrap(),
        vec![
            AccountMeta::new(config_pda, false),
            AccountMeta::new(admin, true),
            AccountMeta::new_readonly(system_program, false),
        ],
    );

    let config_space = 200; // Enough for config
    let mut config_account = Account {
        lamports: 1_000_000,
        data: vec![0u8; config_space],
        owner: program_id,
        executable: false,
        rent_epoch: 0,
    };

    let result = mollusk.process_and_validate_instruction(
        &instruction,
        &[
            (config_pda, config_account.clone()), 
            (admin, Account::default()),
            (system_program, Account::default()),
        ],
        &[],
    );
    assert!(!result.program_result.is_err(), "InitCore failed: {:?}", result.program_result);

    // Verify Config State
    let modified_config_acc = result.get_account(&config_pda).unwrap();
    let config_state: CoreConfig = wincode::deserialize(&modified_config_acc.data).unwrap();
    assert_eq!(config_state.admin, admin.to_bytes());

    // Update local state
    config_account = modified_config_acc.clone();


    // --- 2. Register Agent ---
    let (credit_pda, _bump) = Pubkey::find_program_address(
        &[b"credit_line", agent.as_ref()], 
        &program_id
    );

    let register_payload = RegisterAgentPayload {
        agent_id: agent.to_bytes(),
        initial_limit: 10_000,
    };

    let instruction = Instruction::new_with_bytes(
        program_id,
        &wincode::serialize(&CoreInstruction::RegisterAgent(register_payload)).unwrap(),
        vec![
            AccountMeta::new_readonly(config_pda, false),
            AccountMeta::new(credit_pda, false),
            AccountMeta::new(admin, true),
            AccountMeta::new_readonly(system_program, false),
        ],
    );

    let credit_space = 200;
    let mut credit_account = Account {
        lamports: 1_000_000,
        data: vec![0u8; credit_space],
        owner: program_id,
        executable: false,
        rent_epoch: 0,
    };

    let result = mollusk.process_and_validate_instruction(
        &instruction,
        &[
            (config_pda, config_account.clone()),
            (credit_pda, credit_account.clone()),
            (admin, Account::default()),
            (system_program, Account::default()),
        ],
        &[],
    );
    assert!(!result.program_result.is_err(), "RegisterAgent failed: {:?}", result.program_result);
    
    credit_account = result.get_account(&credit_pda).unwrap().clone();
    let credit_state: CreditLine = wincode::deserialize(&credit_account.data).unwrap();
    assert_eq!(credit_state.balance, 0);
    assert_eq!(credit_state.credit_limit, 10_000);


    // --- 3. VerifyAndCredit ---
    let credit_amount = 500;
    let verify_payload = VerifyAndCreditPayload {
        agent_id: agent.to_bytes(),
        proof_ref: [1u8; 32],
        credit_amount,
    };

    let instruction = Instruction::new_with_bytes(
        program_id,
        &wincode::serialize(&CoreInstruction::VerifyAndCredit(verify_payload)).unwrap(),
        vec![
            AccountMeta::new_readonly(config_pda, false),
            AccountMeta::new(credit_pda, false),
            AccountMeta::new(gateway_program, true), // Signer!
        ],
    );

    let result = mollusk.process_and_validate_instruction(
        &instruction,
        &[
            (config_pda, config_account.clone()),
            (credit_pda, credit_account.clone()),
            (gateway_program, Account::default()), // Gateway is signer
        ],
        &[],
    );
    assert!(!result.program_result.is_err(), "VerifyAndCredit failed: {:?}", result.program_result);

    credit_account = result.get_account(&credit_pda).unwrap().clone();
    let credit_state: CreditLine = wincode::deserialize(&credit_account.data).unwrap();
    assert_eq!(credit_state.balance, 500);


    // --- 4. Request Payment ---
    let (agent_state_pda, _) = Pubkey::find_program_address(&[b"agent_state", agent.as_ref()], &program_id);
    let agent_state_account = Account {
        lamports: 1_000_000,
        data: vec![0u8; 100], // Needs to be >64 for the anchored root
        owner: program_id,
        executable: false,
        rent_epoch: 0,
    };
    
    let payment_amount = 200;
    let payment_payload = RequestPaymentPayload {
        request_id: 1,
        amount: payment_amount,
        vendor: [2u8; 32],
        memo_hash: [0u8; 32],
        zk_proof: vec![0; 64],
        current_root: [0; 32],
    };

    let instruction = Instruction::new_with_bytes(
        program_id,
        &wincode::serialize(&CoreInstruction::RequestPayment(payment_payload)).unwrap(),
        vec![
            AccountMeta::new_readonly(config_pda, false),
            AccountMeta::new(credit_pda, false),
            AccountMeta::new_readonly(agent_state_pda, false),
            AccountMeta::new(agent, true), // Agent signs
            AccountMeta::new_readonly(system_program, false),
        ],
    );

    let result = mollusk.process_and_validate_instruction(
        &instruction,
        &[
            (config_pda, config_account.clone()),
            (credit_pda, credit_account.clone()),
            (agent_state_pda, agent_state_account.clone()),
            (agent, Account::default()),
            (system_program, Account::default()),
        ],
        &[],
    );
    assert!(!result.program_result.is_err(), "RequestPayment failed: {:?}", result.program_result);

    credit_account = result.get_account(&credit_pda).unwrap().clone();
    let credit_state: CreditLine = wincode::deserialize(&credit_account.data).unwrap();
    assert_eq!(credit_state.balance, 300); // 500 - 200 = 300
}