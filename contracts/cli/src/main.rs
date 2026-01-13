use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;

use clap::{Parser, Subcommand};
use solana_client::rpc_client::RpcClient;
use solana_sdk::{
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    signature::{read_keypair_file, Keypair, Signer},
    system_program,
    transaction::Transaction,
};

use xb77_gateway::instruction::{GatewayInstruction, InitGatewayPayload, ProofPayload};
use xb77_gateway::state::GATEWAY_STATE_SEED;

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
}

#[derive(serde::Deserialize)]
struct MetaFile {
    merkle_root_hex: String,
    merkle_index: String,
}

fn load_localnet_value(path: &Path) -> Result<String, String> {
    fs::read_to_string(path)
        .map(|value| value.trim().to_string())
        .map_err(|err| format!("Failed to read {}: {}", path.display(), err))
}

fn load_pubkey(path: &Path) -> Result<Pubkey, String> {
    let value = load_localnet_value(path)?;
    Pubkey::from_str(&value).map_err(|err| format!("Invalid pubkey {}: {}", value, err))
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
    instruction: Instruction,
) -> Result<String, String> {
    let recent_blockhash = rpc
        .get_latest_blockhash()
        .map_err(|err| format!("Failed to fetch blockhash: {}", err))?;
    let tx = Transaction::new_signed_with_payer(
        &[instruction],
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
            let sig = send_transaction(&rpc, &payer, instruction)?;
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

            let instruction = Instruction::new_with_bytes(
                gateway_program_id,
                &data,
                vec![
                    AccountMeta::new(payer.pubkey(), true),
                    AccountMeta::new(gateway_state, false),
                    AccountMeta::new_readonly(verifier_program_id, false),
                ],
            );

            let rpc = RpcClient::new(args.url);
            let sig = send_transaction(&rpc, &payer, instruction)?;
            println!("Verified badge: {}", sig);
        }
    }

    Ok(())
}
