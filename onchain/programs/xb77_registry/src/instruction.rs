use alloc::vec::Vec;
use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct InitMerchantPayload {
    pub merchant_id: Vec<u8>,
    pub supported_methods: u64,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct UpdateMerchantPayload {
    pub merchant_id: Vec<u8>,
    pub supported_methods: Option<u64>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct AddCatalogPayload {
    pub merchant_id: Vec<u8>,
    pub catalog_id: u64,
    pub category: u8,
    pub catalog_url: Vec<u8>,
    pub metadata_hash: Option<[u8; 32]>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct UpdateCatalogPayload {
    pub merchant_id: Vec<u8>,
    pub catalog_id: u64,
    pub category: Option<u8>,
    pub catalog_url: Option<Vec<u8>>,
    pub metadata_hash: Option<[u8; 32]>,
    pub active: Option<bool>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct DeactivateCatalogPayload {
    pub merchant_id: Vec<u8>,
    pub catalog_id: u64,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum RegistryInstruction {
    InitMerchant(InitMerchantPayload),
    UpdateMerchant(UpdateMerchantPayload),
    AddCatalog(AddCatalogPayload),
    UpdateCatalog(UpdateCatalogPayload),
    DeactivateCatalog(DeactivateCatalogPayload),
}
