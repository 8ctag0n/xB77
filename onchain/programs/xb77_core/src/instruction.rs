use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct InitCorePayload {
    pub admin: [u8; 32],
    pub gateway_program: [u8; 32],
    pub receipts_program: [u8; 32],
    pub treasury_mint: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct RegisterAgentPayload {
    pub agent_id: [u8; 32],
    pub initial_limit: u64,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct VerifyAndCreditPayload {
    pub agent_id: [u8; 32],
    pub proof_ref: [u8; 32], // Reference to the Gateway proof
    pub credit_amount: u64, // How much to credit based on the proof
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct RequestPaymentPayload {
    pub request_id: u64,
    pub amount: u64,
    pub vendor: [u8; 32],
    pub memo_hash: [u8; 32],
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum CoreInstruction {
    /// Initialize the global config
    InitCore(InitCorePayload),
    
    /// Create a new credit line for an agent
    RegisterAgent(RegisterAgentPayload),
    
    /// Called by Gateway (CPI) to update credit after verification
    VerifyAndCredit(VerifyAndCreditPayload),
    
    /// Agent requests a payment (checking credit balance)
    RequestPayment(RequestPaymentPayload),
}