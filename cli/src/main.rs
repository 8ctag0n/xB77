use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use clap::{Parser, Subcommand};
use solana_client::rpc_client::RpcClient;
use solana_sdk::{
    compute_budget::ComputeBudgetInstruction,
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::{read_keypair_file, Keypair, Signer},
    system_program,
    transaction::Transaction,
};

use xb77_gateway::instruction::{
    GatewayInstruction, InitGatewayPayload, ProofPayload, ResolvePrivateOrderPayload,
    SubmitPrivateOrderPayload,
};
use xb77_gateway::state::{GATEWAY_STATE_SEED, NULLIFIER_SEED};

#[derive(Parser)]
#[command(name = "xb77-gateway-cli", version)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    Init(InitArgs),
    Verify(VerifyArgs),
    SubmitOrder(SubmitOrderArgs),
    Resolve(ResolveArgs),
}

#[derive(Parser)]
struct InitArgs {
    #[arg(long, default_value = "http://127.0.0.1:8899")]
    url: String,
    #[arg(long)]
    gateway_program_id: Option<String>,
    #[arg(long)]
    verifier_program_id: Option<String>,
    #[arg(long)]
    keypair: Option<PathBuf>,
    #[arg(long, default_value = ".localnet")]
    config_dir: PathBuf,
    #[arg(long)]
    merkle_root_hex: Option<String>,
    #[arg(long, default_value = "sdk/target/agent_badge.meta.json")]
    meta: PathBuf,
}

#[derive(Parser)]
struct VerifyArgs {
    #[arg(long, default_value = "http://127.0.0.1:8899")]
    url: String,
    #[arg(long)]
    gateway_program_id: Option<String>,
    #[arg(long)]
    verifier_program_id: Option<String>,
    #[arg(long)]
    keypair: Option<PathBuf>,
    #[arg(long, default_value = ".localnet")]
    config_dir: PathBuf,
    #[arg(long)]
    merkle_root_hex: Option<String>,
    #[arg(long)]
    merkle_index: Option<u32>,
    #[arg(long, default_value = "sdk/target/agent_badge.meta.json")]
    meta: PathBuf,
    #[arg(long, default_value = "circuits/agent_badge/target/agent_badge.proof")]
    proof: PathBuf,
    #[arg(long, default_value = "circuits/agent_badge/target/agent_badge.pw")]
    public_witness: PathBuf,
    #[arg(long)]
    sw_proof_pda: Option<String>,
    #[arg(long, default_value_t = 1_000_000)]
    compute_units: u32,
    #[arg(long, default_value_t = 0)]
    compute_unit_price: u64,
}

#[derive(Parser)]
struct SubmitOrderArgs {
    #[arg(long, default_value = "http://127.0.0.1:8899")]
    url: String,
    #[arg(long)]
    gateway_program_id: Option<String>,
    #[arg(long)]
    keypair: Option<PathBuf>,
    #[arg(long, default_value = ".localnet")]
    config_dir: PathBuf,
    #[arg(long)]
    order_id: Option<u64>,
    #[arg(long)]
    amount: u64,
    #[arg(long)]
    token: Option<String>,
    #[arg(long)]
    recipient: Option<String>,
    #[arg(long)]
    nullifier_hex: Option<String>,
    #[arg(long, default_value = "sdk/target/agent_badge.meta.json")]
    meta: PathBuf,
    #[arg(long, default_value_t = 200_000)]
    compute_units: u32,
    #[arg(long, default_value_t = 0)]
    compute_unit_price: u64,
}

#[derive(Parser)]
struct ResolveArgs {
    #[arg(long, default_value = "http://127.0.0.1:8899")]
    url: String,
    #[arg(long)]
    gateway_program_id: Option<String>,
    #[arg(long)]
    keypair: Option<PathBuf>,
    #[arg(long, default_value = ".localnet")]
    config_dir: PathBuf,
    #[arg(long)]
    order_commitment_hex: String,
    #[arg(long)]
    receipt_leaf_hash_hex: String,
    #[arg(long)]
    new_orderbook_root_hex: String,
    #[arg(long)]
    receipt_instruction_data: Option<PathBuf>,
    #[arg(long)]
    receipt_program_id: Option<String>,
    #[arg(long)]
    receipt_accounts: Option<PathBuf>,
    #[arg(long, default_value_t = 400_000)]
    compute_units: u32,
    #[arg(long, default_value_t = 0)]
    compute_unit_price: u64,
}

#[derive(serde::Deserialize)]
struct MetaFile {
    merkle_root_hex: String,
    merkle_index: String,
    order_id: Option<String>,
    nullifier: Option<String>,
    nullifier_hex: Option<String>,
}

#[derive(serde::Deserialize)]
struct ReceiptAccountSpec {
    pubkey: String,
    #[serde(default)]
    is_signer: bool,
    #[serde(default)]
    is_writable: bool,
}

fn load_localnet_value(path: &Path) -> Result<String, String> {
    fs::read_to_string(path)
        .map(|value| value.trim().to_string())
        .map_err(|err| format!("Failed to read {}: {}", path.display(), err))
}

fn load_receipt_accounts(path: &Path) -> Result<Vec<AccountMeta>, String> {
    let raw = fs::read_to_string(path)
        .map_err(|err| format!("Failed to read {}: {}", path.display(), err))?;
    let specs: Vec<ReceiptAccountSpec> = serde_json::from_str(&raw)
        .map_err(|err| format!("Invalid receipt accounts JSON: {}", err))?;
    specs
        .into_iter()
        .map(|spec| {
            let pubkey = Pubkey::from_str(&spec.pubkey)
                .map_err(|err| format!("Invalid pubkey {}: {}", spec.pubkey, err))?;
            Ok(AccountMeta {
                pubkey,
                is_signer: spec.is_signer,
                is_writable: spec.is_writable,
            })
        })
        .collect()
}

fn load_pubkey(path: &Path) -> Result<Pubkey, String> {
    let value = load_localnet_value(path)?;
    Pubkey::from_str(&value).map_err(|err| format!("Invalid pubkey {}: {}", value, err))
}

fn parse_pubkey_bytes(input: &str) -> Result<[u8; 32], String> {
    let pubkey =
        Pubkey::from_str(input).map_err(|err| format!("Invalid pubkey {}: {}", input, err))?;
    Ok(pubkey.to_bytes())
}

fn load_keypair(path: &Path) -> Result<Keypair, String> {
    read_keypair_file(path).map_err(|err| format!("Failed to read keypair: {}", err))
}

fn decode_hex_32(input: &str) -> Result<[u8; 32], String> {
    let trimmed = input.trim_start_matches("0x");
    let padded = format!("{:0>64}", trimmed);
    let decoded = hex::decode(padded).map_err(|err| format!("Invalid hex: {}", err))?;
    let bytes: [u8; 32] = decoded
        .try_into()
        .map_err(|_| "Expected 32 bytes for merkle root".to_string())?;
    Ok(bytes)
}

fn load_meta(meta_path: &Path) -> Result<MetaFile, String> {
    let data = fs::read_to_string(meta_path)
        .map_err(|err| format!("Failed to read {}: {}", meta_path.display(), err))?;
    serde_json::from_str(&data).map_err(|err| format!("Invalid meta JSON: {}", err))
}

fn resolve_gateway_config(
    config_dir: &Path,
    gateway_program_id: Option<String>,
    verifier_program_id: Option<String>,
    keypair: Option<PathBuf>,
) -> Result<(Pubkey, Pubkey, Keypair), String> {
    let gateway_program_id = match gateway_program_id {
        Some(value) => Pubkey::from_str(&value)
            .map_err(|err| format!("Invalid gateway program id {}: {}", value, err))?,
        None => load_pubkey(&config_dir.join("gateway_program_id.txt"))?,
    };

    let verifier_program_id = match verifier_program_id {
        Some(value) => Pubkey::from_str(&value)
            .map_err(|err| format!("Invalid verifier program id {}: {}", value, err))?,
        None => load_pubkey(&config_dir.join("verifier_program_id.txt"))?,
    };

    let keypair_path = keypair.unwrap_or_else(|| config_dir.join("payer.json"));
    let payer = load_keypair(&keypair_path)?;

    Ok((gateway_program_id, verifier_program_id, payer))
}

fn send_transaction(
    rpc: &RpcClient,
    payer: &Keypair,
    instructions: Vec<Instruction>,
) -> Result<String, String> {
    let recent_blockhash = rpc
        .get_latest_blockhash()
        .map_err(|err| format!("Failed to fetch blockhash: {}", err))?;
    let tx = Transaction::new_signed_with_payer(
        &instructions,
        Some(&payer.pubkey()),
        &[payer],
        recent_blockhash,
    );
    let signature = rpc
        .send_and_confirm_transaction(&tx)
        .map_err(|err| format!("Transaction failed: {}", err))?;
    Ok(signature.to_string())
}

fn main() -> Result<(), String> {
    let cli = Cli::parse();

    match cli.command {
        Command::Init(args) => {
            let (gateway_program_id, verifier_program_id, payer) = resolve_gateway_config(
                &args.config_dir,
                args.gateway_program_id,
                args.verifier_program_id,
                args.keypair,
            )?;

            let merkle_root_hex = match args.merkle_root_hex {
                Some(value) => value,
                None => load_meta(&args.meta)?.merkle_root_hex,
            };
            let merkle_root = decode_hex_32(&merkle_root_hex)?;

            let payload = InitGatewayPayload {
                admin: payer.pubkey().to_bytes(),
                merkle_root,
                zk_verifier: verifier_program_id.to_bytes(),
                auditor: [0u8; 32],
                credit_root: [0u8; 32],
                orderbook_root: [0u8; 32],
                mxe_program_id: [0u8; 32],
                light_system_program: [0u8; 32],
                light_account_compression_program: [0u8; 32],
                light_noop_program: [0u8; 32],
            };
            let data = wincode::serialize(&GatewayInstruction::InitGateway(payload))
                .map_err(|err| format!("Failed to serialize init payload: {}", err))?;

            let (gateway_state, _bump) =
                Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &gateway_program_id);

            let instruction = Instruction::new_with_bytes(
                gateway_program_id,
                &data,
                vec![
                    AccountMeta::new(payer.pubkey(), true),
                    AccountMeta::new(gateway_state, false),
                    AccountMeta::new_readonly(system_program::ID, false),
                ],
            );

            let rpc = RpcClient::new(args.url);
            let sig = send_transaction(&rpc, &payer, vec![instruction])?;
            println!("Initialized gateway: {}", sig);
        }
        Command::Verify(args) => {
            let (gateway_program_id, verifier_program_id, payer) = resolve_gateway_config(
                &args.config_dir,
                args.gateway_program_id,
                args.verifier_program_id,
                args.keypair,
            )?;

            let meta = load_meta(&args.meta)?;
            let merkle_root_hex = args.merkle_root_hex.unwrap_or(meta.merkle_root_hex);
            let merkle_root = decode_hex_32(&merkle_root_hex)?;
            let merkle_index = args
                .merkle_index
                .unwrap_or_else(|| meta.merkle_index.parse::<u32>().unwrap_or(0));

            let proof = fs::read(&args.proof)
                .map_err(|err| format!("Failed to read proof: {}", err))?;
            let public_witness = fs::read(&args.public_witness)
                .map_err(|err| format!("Failed to read public witness: {}", err))?;

            let payload = ProofPayload {
                root: merkle_root,
                merkle_index,
                proof,
                public_witness,
            };
            let data = wincode::serialize(&GatewayInstruction::VerifyBadge(payload))
                .map_err(|err| format!("Failed to serialize verify payload: {}", err))?;

            let (gateway_state, _bump) =
                Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &gateway_program_id);

            let sw_proof_pda = match args.sw_proof_pda {
                Some(value) => Pubkey::from_str(&value)
                    .map_err(|err| format!("Invalid shadowwire proof pda {}: {}", value, err))?,
                None => return Err("Missing --sw-proof-pda".to_string()),
            };

            let instruction = Instruction::new_with_bytes(
                gateway_program_id,
                &data,
                vec![
                    AccountMeta::new(payer.pubkey(), true),
                    AccountMeta::new(gateway_state, false),
                    AccountMeta::new_readonly(verifier_program_id, false),
                    AccountMeta::new_readonly(sw_proof_pda, false),
                ],
            );

            let mut instructions = Vec::new();
            instructions.push(ComputeBudgetInstruction::set_compute_unit_limit(
                args.compute_units,
            ));
            if args.compute_unit_price > 0 {
                instructions.push(ComputeBudgetInstruction::set_compute_unit_price(
                    args.compute_unit_price,
                ));
            }
            instructions.push(instruction);

            let rpc = RpcClient::new(args.url);
            let sig = send_transaction(&rpc, &payer, instructions)?;
            println!("Verified badge: {}", sig);
        }
        Command::SubmitOrder(args) => {
            let (gateway_program_id, _verifier_program_id, payer) = resolve_gateway_config(
                &args.config_dir,
                args.gateway_program_id,
                None,
                args.keypair,
            )?;

            let meta = load_meta(&args.meta)?;
            let order_id = match args.order_id {
                Some(value) => value,
                None => meta
                    .order_id
                    .as_deref()
                    .ok_or_else(|| "Missing order_id in meta or args".to_string())?
                    .parse::<u64>()
                    .map_err(|err| format!("Invalid order_id in meta: {}", err))?,
            };
            let nullifier_hex = match args.nullifier_hex {
                Some(value) => value,
                None => match meta.nullifier_hex {
                    Some(value) => value,
                    None => match meta.nullifier {
                        Some(value) if value.starts_with("0x") => value,
                        Some(_) => {
                            return Err(
                                "Meta nullifier is not hex; regenerate proof or pass --nullifier-hex"
                                    .to_string(),
                            )
                        }
                        None => return Err("Missing nullifier in meta or args".to_string()),
                    },
                },
            };
            let nullifier = decode_hex_32(&nullifier_hex)?;

            let token = args
                .token
                .as_deref()
                .ok_or_else(|| "Missing --token".to_string())
                .and_then(parse_pubkey_bytes)?;
            let recipient = args
                .recipient
                .as_deref()
                .ok_or_else(|| "Missing --recipient".to_string())
                .and_then(parse_pubkey_bytes)?;

            let payload = SubmitPrivateOrderPayload {
                order_id,
                amount: args.amount,
                token,
                recipient,
                nullifier,
            };
            let data = wincode::serialize(&GatewayInstruction::SubmitPrivateOrder(payload))
                .map_err(|err| format!("Failed to serialize submit payload: {}", err))?;

            let (gateway_state, _bump) =
                Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &gateway_program_id);
            let (nullifier_pda, _nullifier_bump) =
                Pubkey::find_program_address(&[NULLIFIER_SEED, &nullifier], &gateway_program_id);

            let instruction = Instruction::new_with_bytes(
                gateway_program_id,
                &data,
                vec![
                    AccountMeta::new(payer.pubkey(), true),
                    AccountMeta::new(gateway_state, false),
                    AccountMeta::new(nullifier_pda, false),
                    AccountMeta::new_readonly(system_program::ID, false),
                ],
            );

            let mut instructions = Vec::new();
            instructions.push(ComputeBudgetInstruction::set_compute_unit_limit(
                args.compute_units,
            ));
            if args.compute_unit_price > 0 {
                instructions.push(ComputeBudgetInstruction::set_compute_unit_price(
                    args.compute_unit_price,
                ));
            }
            instructions.push(instruction);

            let rpc = RpcClient::new(args.url);
            let sig = send_transaction(&rpc, &payer, instructions)?;
            println!("Submitted private order: {}", sig);
        }
        Command::Resolve(args) => {
            let (gateway_program_id, _verifier_program_id, payer) = resolve_gateway_config(
                &args.config_dir,
                args.gateway_program_id,
                None,
                args.keypair,
            )?;

            let order_commitment = decode_hex_32(&args.order_commitment_hex)?;
            let receipt_leaf_hash = decode_hex_32(&args.receipt_leaf_hash_hex)?;
            let new_orderbook_root = decode_hex_32(&args.new_orderbook_root_hex)?;

            let receipt_instruction_data = match args.receipt_instruction_data {
                Some(ref path) => fs::read(path)
                    .map_err(|err| format!("Failed to read receipt instruction data: {}", err))?,
                None => Vec::new(),
            };

            let payload = ResolvePrivateOrderPayload {
                order_commitment,
                receipt_leaf_hash,
                new_orderbook_root,
                receipt_instruction_data,
            };
            let data = wincode::serialize(&GatewayInstruction::ResolvePrivateOrder(payload))
                .map_err(|err| format!("Failed to serialize resolve payload: {}", err))?;

            let (gateway_state, _bump) =
                Pubkey::find_program_address(&[GATEWAY_STATE_SEED], &gateway_program_id);

            let mut metas = vec![
                AccountMeta::new(payer.pubkey(), true),
                AccountMeta::new(gateway_state, false),
                AccountMeta::new_readonly(solana_sdk::sysvar::instructions::ID, false),
            ];

            if args.receipt_instruction_data.is_some() {
                let receipt_program_id = args
                    .receipt_program_id
                    .ok_or_else(|| "Missing --receipt-program-id".to_string())
                    .and_then(|value| {
                        Pubkey::from_str(&value)
                            .map_err(|err| format!("Invalid receipt program id {}: {}", value, err))
                    })?;
                let receipt_accounts_path = args
                    .receipt_accounts
                    .as_ref()
                    .ok_or_else(|| "Missing --receipt-accounts".to_string())?;
                let receipt_accounts = load_receipt_accounts(receipt_accounts_path)?;

                metas.push(AccountMeta::new_readonly(receipt_program_id, false));
                metas.extend(receipt_accounts);
            }

            let instruction = Instruction::new_with_bytes(gateway_program_id, &data, metas);

            let mut instructions = Vec::new();
            instructions.push(ComputeBudgetInstruction::set_compute_unit_limit(
                args.compute_units,
            ));
            if args.compute_unit_price > 0 {
                instructions.push(ComputeBudgetInstruction::set_compute_unit_price(
                    args.compute_unit_price,
                ));
            }
            instructions.push(instruction);

            let rpc = RpcClient::new(args.url);
            let sig = send_transaction(&rpc, &payer, instructions)?;
            println!("Resolved private order: {}", sig);
        }
    }

    Ok(())
}
