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
declare_id!("FpWZN1FB9yMfip3vYQhsZhgT4fCB3US9BqAv5kh5uDxv");

#[cfg(not(feature = "no-entrypoint"))]
entrypoint!(process_instruction);