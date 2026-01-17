use alloc::vec::Vec;
use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct ProofPayload {
    pub root: [u8; 32],
    pub merkle_index: u32,
    pub proof: Vec<u8>,
    pub public_witness: Vec<u8>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct InitGatewayPayload {
    pub admin: [u8; 32],
    pub merkle_root: [u8; 32],
    pub zk_verifier: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct UpdateGatewayPayload {
    pub merkle_root: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct ConfidentialTransferPayload {
    pub encrypted_amount: [u8; 32],
    pub nonce: [u8; 12],
    pub public_key: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct ReceiptPayload {
    pub vendor_id: [u8; 32],
    pub item_hash: [u8; 32],
    pub amount: u64,
    pub timestamp: i64,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum GatewayInstruction {
    InitGateway(InitGatewayPayload),
    UpdateGateway(UpdateGatewayPayload),
    VerifyBadge(ProofPayload),
    ExecuteConfidentialTransfer(ConfidentialTransferPayload),
    RecordReceipt(ReceiptPayload),
}
