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
    pub auditor: [u8; 32],
    pub credit_root: [u8; 32],
    pub orderbook_root: [u8; 32],
    pub mxe_program_id: [u8; 32],
    pub light_system_program: [u8; 32],
    pub light_account_compression_program: [u8; 32],
    pub light_noop_program: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct UpdateGatewayPayload {
    pub merkle_root: [u8; 32],
    pub auditor: [u8; 32],
    pub credit_root: [u8; 32],
    pub orderbook_root: [u8; 32],
    pub mxe_program_id: [u8; 32],
    pub light_system_program: [u8; 32],
    pub light_account_compression_program: [u8; 32],
    pub light_noop_program: [u8; 32],
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
pub struct ResolvePrivateOrderPayload {
    pub order_commitment: [u8; 32],
    pub receipt_leaf_hash: [u8; 32],
    pub new_orderbook_root: [u8; 32],
    pub receipt_instruction_data: Vec<u8>,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct AuditRevealPayload {
    pub order_commitment: [u8; 32],
    pub audit_hash: [u8; 32],
}

// --- Core Program CPI Types ---
#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct VerifyAndCreditPayload {
    pub agent_id: [u8; 32],
    pub proof_ref: [u8; 32],
    pub credit_amount: u64,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum CoreInstruction {
    InitCore, // Placeholder, 0
    RegisterAgent, // Placeholder, 1
    VerifyAndCredit(VerifyAndCreditPayload), // Target, 2
    RequestPayment, // Placeholder, 3
}
// -----------------------------

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum GatewayInstruction {
    InitGateway(InitGatewayPayload),
    UpdateGateway(UpdateGatewayPayload),
    VerifyBadge(ProofPayload),
    SubmitPrivateOrder(SubmitPrivateOrderPayload),
    ExecuteConfidentialTransfer(ConfidentialTransferPayload),
    RecordReceipt(ReceiptPayload),
    ResolvePrivateOrder(ResolvePrivateOrderPayload),
    AuditReveal(AuditRevealPayload),
}
