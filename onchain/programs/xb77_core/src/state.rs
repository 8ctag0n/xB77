use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct CoreConfig {
    pub admin: [u8; 32],
    pub gateway_program: [u8; 32],
    pub receipts_program: [u8; 32],
    pub treasury_mint: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct CreditLine {
    pub owner: [u8; 32],
    pub balance: u64,       // Public for Phase 1 (Psyop)
    pub credit_limit: u64,
    pub last_update: i64,
    pub reputation: u8,
}
