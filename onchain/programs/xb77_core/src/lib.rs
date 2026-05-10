#![cfg_attr(not(test), no_std)]

#[cfg(not(feature = "no-entrypoint"))]
use solana_program::entrypoint;

extern crate alloc;
use alloc::format; // Required by msg! and entrypoint! macros

pub mod error;
pub mod instruction;
pub mod processor;
pub mod state;

#[cfg(not(feature = "no-entrypoint"))]
use processor::process_instruction;

use solana_program::declare_id;
declare_id!("73vhQZLxjEyAFXHorS1yNEQqCCtXWGAvrBF8RJrHBkv3");

#[cfg(not(feature = "no-entrypoint"))]
entrypoint!(process_instruction);