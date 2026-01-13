#![cfg_attr(not(test), no_std)]

extern crate alloc;

mod error;
mod instruction;
mod processor;
mod state;

use solana_program::entrypoint;

entrypoint!(processor::process_instruction);
