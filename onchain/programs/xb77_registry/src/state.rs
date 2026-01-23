use alloc::vec::Vec;
use wincode::{SchemaRead, SchemaWrite};

pub const MERCHANT_SEED: &[u8] = b"merchant";
pub const CATALOG_SEED: &[u8] = b"catalog";

pub const MAX_MERCHANT_ID_LEN: usize = 64;
pub const MAX_CATALOG_URL_LEN: usize = 256;

// Payment Methods Bitmask
pub const METHOD_PRIVACY_CASH: u64 = 1 << 0;
pub const METHOD_STARPAY: u64 = 1 << 1;
pub const METHOD_SHADOWWIRE: u64 = 1 << 2;
pub const METHOD_SILENTSWAP: u64 = 1 << 3;

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct MerchantAccount {
    pub merchant_id: Vec<u8>,
    pub owner: [u8; 32],
    pub supported_methods: u64,
    pub catalog_count: u32,
    pub created_at: u64,
    pub updated_at: u64,
    pub bump: u8,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct CatalogAccount {
    pub merchant_id: Vec<u8>,
    pub catalog_id: u64,
    pub category: u8,
    pub catalog_url: Vec<u8>,
    pub metadata_hash: Option<[u8; 32]>,
    pub active: bool,
    pub updated_at: u64,
    pub bump: u8,
}
