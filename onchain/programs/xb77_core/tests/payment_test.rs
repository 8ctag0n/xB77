use mollusk_svm::{Mollusk, result::ProgramResult};
use solana_pubkey::Pubkey;
use solana_account::Account;
use solana_instruction::{Instruction, AccountMeta};

use xb77_core::instruction::{CoreInstruction, RequestPaymentPayload};
use xb77_core::state::{CreditLine, CoreConfig};

#[test]
#[ignore]
fn test_core_payment_logic() {
    let core_program_id = Pubkey::new_unique();
    // We mock the receipts program with a random ID. 
    // In Mollusk, if we don't load code for this ID, the CPI might fail or do nothing depending on config.
    // However, we want to test the CORE logic primarily.
    let receipts_program_id = Pubkey::new_unique(); 

    let mut mollusk = Mollusk::new(&core_program_id, "xb77_core");

    let agent = Pubkey::new_unique();
    let admin = Pubkey::new_unique();
    
    let (config_pda, _) = Pubkey::find_program_address(&[b"config"], &core_program_id);
    let (credit_line_pda, _) = Pubkey::find_program_address(
        &[b"credit_line", agent.as_ref()], 
        &core_program_id
    );

    // 1. Setup Core Config
    let config_state = CoreConfig {
        admin: admin.to_bytes(),
        gateway_program: Pubkey::new_unique().to_bytes(),
        receipts_program: receipts_program_id.to_bytes(), // Point to our mocked receipts
        treasury_mint: [0u8; 32],
    };
    
    let config_account = Account {
        lamports: 1_000_000,
        data: wincode::serialize(&config_state).unwrap(),
        owner: core_program_id,
        executable: false,
        rent_epoch: 0,
    };

    // 2. Setup Credit Line with Balance
    let initial_balance = 0; // Set to 0 to force InsufficientFunds error
    let payment_amount = 500;
    
    let credit_line_state = CreditLine {
        owner: agent.to_bytes(),
        balance: initial_balance,
        credit_limit: 5000,
        last_update: 0,
        reputation: 100,
    };
    
    let mut credit_line_account = Account {
        lamports: 1_000_000,
        data: wincode::serialize(&credit_line_state).unwrap(),
        owner: core_program_id,
        executable: false,
        rent_epoch: 0,
    };
    // Ensure data buffer has space for updates
    credit_line_account.data.resize(500, 0); 

    // 3. Prepare RequestPayment Instruction
    let payload = RequestPaymentPayload {
        request_id: 1,
        amount: payment_amount,
        vendor: [7u8; 32],
        memo_hash: [8u8; 32],
        proof: vec![0; 64], // Dummy proof
        address_tree_info: vec![0; 32], // Dummy tree info
        output_state_tree_index: 0,
    };

    let instruction = Instruction::new_with_bytes(
        core_program_id,
        &wincode::serialize(&CoreInstruction::RequestPayment(payload)).unwrap(),
        vec![
            AccountMeta::new_readonly(config_pda, false),
            AccountMeta::new(credit_line_pda, false),
            AccountMeta::new_readonly(agent, true), // Signer
            AccountMeta::new_readonly(receipts_program_id, false), // Receipts Program
        ],
    );

    // 4. Execute
    let result = mollusk.process_and_validate_instruction(
        &instruction,
        &[
            (config_pda, config_account),
            (credit_line_pda, credit_line_account),
            (agent, Account::default()),
            (receipts_program_id, Account { executable: true, ..Account::default() }), // Pretend it's executable
        ],
        &[],
    );

    // 5. Verify Results
    match result.program_result {
        ProgramResult::Success => panic!("Should have failed due to insufficient funds"),
        ProgramResult::Failure(err) => {
            println!("Got Error: {:?}", err);
            // We expect a Custom error from the program (likely 1 or 6001 depending on mapping)
            // NOT a panic or system error.
        },
        _ => panic!("Unexpected result variant"),
    }
}