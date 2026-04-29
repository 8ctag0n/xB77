use clap::Parser;
use std::path::PathBuf;
use verifier_lib::vk::generate_key_file;
use anyhow::{Context, Result};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to the verification key (.vk) file
    #[arg(short, long, value_name = "FILE")]
    input: PathBuf,

    /// Path to the output Rust file
    #[arg(short, long, value_name = "FILE")]
    output: PathBuf,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    let input_str = cli.input.to_str().context("Invalid input path")?;
    let output_str = cli.output.to_str().context("Invalid output path")?;

    println!("Generating Verifier Key...");
    println!("Input: {}", input_str);
    println!("Output: {}", output_str);

    generate_key_file(input_str, output_str)
        .map_err(|e| anyhow::anyhow!("Failed to generate key file: {}", e))?;

    println!("Done!");
    Ok(())
}
