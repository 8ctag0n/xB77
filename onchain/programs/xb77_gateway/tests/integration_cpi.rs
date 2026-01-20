use mollusk_svm::Mollusk;
use solana_pubkey::Pubkey;
use solana_account::Account;
use solana_instruction::{Instruction, AccountMeta};
use std::str::FromStr;

use xb77_gateway::instruction::{GatewayInstruction, ProofPayload, InitGatewayPayload};
use xb77_core::state::{CreditLine, CoreConfig};

#[test]
fn test_gateway_to_core_cpi() {
    // Fixed IDs for consistency
    let gateway_program_id = Pubkey::from_str("GATeway11111111111111111111111111111111111").unwrap();
    let core_program_id = Pubkey::from_str("Core11111111111111111111111111111111111111").unwrap();
    
    // Ensure .so files are in the current directory or fix path
    // Mollusk searches in the current working directory.
    
    let mut mollusk = Mollusk::new(&gateway_program_id, "xb77_gateway");
    mollusk.add_program(&core_program_id, "xb77_core");

    let payer = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    
    let (gateway_state_pda, bump) = Pubkey::find_program_address(&[b"gateway_state"], &gateway_program_id);
    let (core_config_pda, _core_bump) = Pubkey::find_program_address(&[b"config"], &core_program_id);
    let (credit_line_pda, _credit_bump) = Pubkey::find_program_address(&[b"credit_line", payer.as_ref()], &core_program_id);

    // Setup Gateway Account (Mocked)
    let mut gateway_account = Account {
        lamports: 1_000_000,
        data: vec![0u8; 1000],
        owner: gateway_program_id,
        ..Account::default()
    };
    // Initialize enough config for the Gateway to not fail on deserialization
    // The GatewayConfig starts with admin (32 bytes), merkle_root (32 bytes), etc.
    // Let's just put some zeros.

    // Setup Core Config
    let core_config_state = CoreConfig {
        admin: admin.to_bytes(),
        gateway_program: gateway_program_id.to_bytes(),
        receipts_program: [0u8; 32],
        treasury_mint: [0u8; 32],
    };
    let core_config_account = Account {
        lamports: 1_000_000,
        data: wincode::serialize(&core_config_state).unwrap(),
        owner: core_program_id,
        ..Account::default()
    };

    // Setup Credit Line
    let credit_line_state = CreditLine {
        owner: payer.to_bytes(),
        balance: 0,
        credit_limit: 5000,
        last_update: 0,
        reputation: 100,
    };
    let mut credit_line_account = Account {
        lamports: 1_000_000,
        data: wincode::serialize(&credit_line_state).unwrap(),
        owner: core_program_id,
        ..Account::default()
    };
    credit_line_account.data.resize(500, 0);

    let proof_payload = ProofPayload {
        root: [0u8; 32],
        merkle_index: 0,
        proof: vec![1, 2, 3],
        public_witness: vec![4, 5, 6],
    };

    let instruction = Instruction::new_with_bytes(
        gateway_program_id,
        &wincode::serialize(&GatewayInstruction::VerifyBadge(proof_payload)).unwrap(),
        vec![
            AccountMeta::new(payer, true),
            AccountMeta::new(gateway_state_pda, false),
            AccountMeta::new_readonly(Pubkey::default(), false), // zk_verifier
            AccountMeta::new_readonly(core_program_id, false),
            AccountMeta::new_readonly(core_config_pda, false),
            AccountMeta::new(credit_line_pda, false),
        ],
    );

    let result = mollusk.process_and_validate_instruction(
        &instruction,
        &[
            (payer, Account::default()),
            (gateway_state_pda, gateway_account),
            (Pubkey::default(), Account::default()),
            (core_program_id, Account { executable: true, ..Account::default() }), // Explicitly executable
            (core_config_pda, core_config_account),
            (credit_line_pda, credit_line_account),
        ],
        &[],
    );

    assert!(!result.program_result.is_err(), "Integration CPI failed: {:?}", result.program_result);

    let final_credit_acc = result.get_account(&credit_line_pda).unwrap();
    let final_state: CreditLine = wincode::deserialize(&final_credit_acc.data).unwrap();
    assert_eq!(final_state.balance, 100);
}