use alloc::vec::Vec;
use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct ProofPayload {
    pub root: [u8; 32],
    pub merkle_index: u32,
    pub proof: Vec<u8>,
    pub public_inputs: Vec<[u8; 32]>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct InitGatewayPayload {
    pub admin: [u8; 32],
    pub merkle_root: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct UpdateGatewayPayload {
    pub merkle_root: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum GatewayInstruction {
    InitGateway(InitGatewayPayload),
    UpdateGateway(UpdateGatewayPayload),
    VerifyBadge(ProofPayload),
    ExecuteConfidentialTransfer { amount: u64 },
    RecordReceipt { receipt_hash: [u8; 32] },
}
