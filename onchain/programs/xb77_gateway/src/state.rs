use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct GatewayConfig {
    pub admin: [u8; 32],
    pub merkle_root: [u8; 32],
    pub receipt_root: [u8; 32],
    pub zk_verifier: [u8; 32],
    pub treasury_mint: [u8; 32],
    pub auditor: [u8; 32],
    pub credit_root: [u8; 32],
    pub orderbook_root: [u8; 32],
    pub mxe_program_id: [u8; 32],
    pub receipts_program_id: [u8; 32],
    pub light_system_program: [u8; 32],
    pub light_account_compression_program: [u8; 32],
    pub light_noop_program: [u8; 32],
    pub bump: u8,
}

pub const GATEWAY_STATE_SEED: &[u8] = b"gateway_state";
pub const NULLIFIER_SEED: &[u8] = b"nullifier";
