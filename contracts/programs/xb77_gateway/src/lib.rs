#![cfg_attr(not(test), no_std)]

#[cfg(not(feature = "no-entrypoint"))]
use solana_program::entrypoint;

extern crate alloc;
use alloc::format;

pub mod error;
pub mod instruction;
pub mod processor;
pub mod state;

// Fix for getrandom on Solana
#[cfg(target_os = "solana")]
use getrandom::register_custom_getrandom;

#[cfg(target_os = "solana")]
fn custom_getrandom(buf: &mut [u8]) -> Result<(), getrandom::Error> {
    for (i, byte) in buf.iter_mut().enumerate() {
        *byte = i as u8; // Dummy deterministic content
    }
    Ok(())
}

#[cfg(target_os = "solana")]
register_custom_getrandom!(custom_getrandom);

#[cfg(not(feature = "no-entrypoint"))]
use processor::process_instruction;
#[cfg(not(feature = "no-entrypoint"))]
entrypoint!(process_instruction);
