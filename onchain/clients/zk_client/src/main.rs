use std::env;
use std::fs;
use std::str::FromStr;

use solana_client::rpc_client::RpcClient;
use solana_commitment_config::CommitmentConfig;
use solana_sdk::{
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::{read_keypair_file, Signer},
    transaction::Transaction,
};

const SYSTEM_PROGRAM_ID: Pubkey = solana_sdk::pubkey::Pubkey::new_from_array([0u8; 32]);

const TAG_INIT: u8 = 0;
const TAG_WRITE: u8 = 1;
const TAG_VERIFY: u8 = 2;
const CHUNK: usize = 900;

fn main() {
    let rpc_url = env::var("RPC_URL").unwrap_or_else(|_| "http://127.0.0.1:8899".to_string());
    let proof_path = env::var("PROOF_PATH").unwrap_or_else(|_| "/proof/zk_receipt.proof".to_string());
    let keypair_path = env::var("PAYER_KEYPAIR")
        .unwrap_or_else(|_| "/root/.config/solana/id.json".to_string());
    let verifier_id_str = env::var("VERIFIER_PROGRAM_ID")
        .expect("VERIFIER_PROGRAM_ID env var required");

    let verifier_id = Pubkey::from_str(&verifier_id_str).expect("invalid verifier program id");
    let payer = read_keypair_file(&keypair_path).expect("cannot read payer keypair");
    let proof = fs::read(&proof_path).expect("cannot read proof file");
    let proof_len = proof.len() as u32;

    println!("[CLIENT] RPC: {}", rpc_url);
    println!("[CLIENT] verifier program: {}", verifier_id);
    println!("[CLIENT] proof: {} bytes from {}", proof.len(), proof_path);
    println!("[CLIENT] payer: {}", payer.pubkey());

    let client = RpcClient::new_with_commitment(rpc_url, CommitmentConfig::confirmed());

    // Random salt = first 8 bytes of latest blockhash for a unique buffer per run
    let bh0 = client.get_latest_blockhash().expect("blockhash");
    let salt: [u8; 8] = bh0.to_bytes()[..8].try_into().unwrap();
    let (buffer_pda, _bump) = Pubkey::find_program_address(
        &[b"proof_buf", payer.pubkey().as_ref(), &salt],
        &verifier_id,
    );
    println!("[CLIENT] buffer PDA: {}", buffer_pda);

    // 1) INIT
    let mut init_data = Vec::with_capacity(1 + 8 + 4);
    init_data.push(TAG_INIT);
    init_data.extend_from_slice(&salt);
    init_data.extend_from_slice(&proof_len.to_le_bytes());
    let init_ix = Instruction {
        program_id: verifier_id,
        accounts: vec![
            AccountMeta::new(payer.pubkey(), true),
            AccountMeta::new(buffer_pda, false),
            AccountMeta::new_readonly(SYSTEM_PROGRAM_ID, false),
        ],
        data: init_data,
    };
    let blockhash = client.get_latest_blockhash().expect("blockhash");
    let tx = Transaction::new_signed_with_payer(&[init_ix], Some(&payer.pubkey()), &[&payer], blockhash);
    let sig = client.send_and_confirm_transaction(&tx).expect("init tx");
    println!("[CLIENT] init sig: {}", sig);

    // 2) WRITE chunks
    let mut offset: usize = 0;
    while offset < proof.len() {
        let end = (offset + CHUNK).min(proof.len());
        let chunk = &proof[offset..end];
        let mut data = Vec::with_capacity(1 + 4 + chunk.len());
        data.push(TAG_WRITE);
        data.extend_from_slice(&(offset as u32).to_le_bytes());
        data.extend_from_slice(chunk);
        let ix = Instruction {
            program_id: verifier_id,
            accounts: vec![
                AccountMeta::new(payer.pubkey(), true),
                AccountMeta::new(buffer_pda, false),
            ],
            data,
        };
        let blockhash = client.get_latest_blockhash().expect("blockhash");
        let tx = Transaction::new_signed_with_payer(&[ix], Some(&payer.pubkey()), &[&payer], blockhash);
        let sig = client.send_and_confirm_transaction(&tx).expect("write tx");
        println!("[CLIENT] write {}..{} sig: {}", offset, end, sig);
        offset = end;
    }

    // 3) VERIFY
    let verify_ix = Instruction {
        program_id: verifier_id,
        accounts: vec![
            AccountMeta::new(payer.pubkey(), true),
            AccountMeta::new_readonly(buffer_pda, false),
        ],
        data: vec![TAG_VERIFY],
    };
    let blockhash = client.get_latest_blockhash().expect("blockhash");
    let tx = Transaction::new_signed_with_payer(&[verify_ix], Some(&payer.pubkey()), &[&payer], blockhash);
    match client.send_and_confirm_transaction(&tx) {
        Ok(sig) => {
            println!("[CLIENT]  verify sig: {}", sig);
            println!("[CLIENT] (see validator logs for [ZK-JUDGE] verdict)");
        }
        Err(e) => {
            eprintln!("[CLIENT]  verify failed: {:?}", e);
            std::process::exit(1);
        }
    }
}
