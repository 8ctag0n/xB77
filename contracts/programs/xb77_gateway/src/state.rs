use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct GatewayConfig {
    pub admin: [u8; 32],
    pub merkle_root: [u8; 32],
    pub zk_verifier: [u8; 32],
    pub bump: u8,
}

pub const GATEWAY_STATE_SEED: &[u8] = b"gateway_state";
