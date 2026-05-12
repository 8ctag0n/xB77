//! Onchain module: IDL-driven instruction encoding + Solana tx building.
//!
//! Import this as a named module in build.zig to expose it to the CLI
//! and test binaries.

pub const wincode = @import("wincode.zig");
pub const idl_client = @import("idl_client.zig");
pub const solana_tx = @import("solana_tx.zig");
pub const solana_rpc = @import("solana_rpc.zig");

pub const Writer = wincode.Writer;
pub const Reader = wincode.Reader;
pub const IdlClient = idl_client.IdlClient;
pub const FieldValue = idl_client.FieldValue;
pub const NamedField = idl_client.NamedField;
pub const Instruction = solana_tx.Instruction;
pub const AccountMeta = solana_tx.AccountMeta;
pub const buildLegacyTx = solana_tx.buildLegacyTx;
pub const signTx = solana_tx.signTx;
pub const SolanaRpc = solana_rpc.SolanaRpc;
