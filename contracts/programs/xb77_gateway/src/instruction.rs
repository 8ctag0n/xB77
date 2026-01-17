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
pub struct SubmitPrivateOrderPayload {
    pub order_id: u64,
    pub amount: u64,
    pub token: [u8; 32],
    pub recipient: [u8; 32],
    pub nullifier: [u8; 32],
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
pub enum GatewayInstruction {
    InitGateway(InitGatewayPayload),
    UpdateGateway(UpdateGatewayPayload),
    VerifyBadge(ProofPayload),
    SubmitPrivateOrder(SubmitPrivateOrderPayload),
    ExecuteConfidentialTransfer { amount: u64 },
    RecordReceipt { receipt_hash: [u8; 32] },
}
