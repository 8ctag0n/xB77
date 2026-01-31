use solana_program::program_error::ProgramError;

#[repr(u32)]
pub enum GatewayError {
    InvalidInstruction = 0,
    NotEnoughAccounts = 1,
    MissingSigner = 2,
    InvalidGatewayStateOwner = 3,
    InvalidGatewayStatePda = 4,
    GatewayStateAlreadyInitialized = 5,
    GatewayStateNotWritable = 6,
    InvalidSystemProgram = 7,
    InvalidGatewayAdmin = 8,
    InvalidMerkleIndex = 9,
    InvalidMerkleRoot = 10,
    InvalidPublicInputs = 11,
    EmptyProof = 12,
    EmptyPublicWitness = 13,
    InvalidZkVerifier = 14,
    InvalidOrderId = 15,
    InvalidAmount = 16,
    InvalidToken = 17,
    InvalidRecipient = 18,
    InvalidNullifier = 19,
    InvalidNullifierPda = 20,
    NullifierAlreadyUsed = 21,
    InvalidLightReceiptAccount = 22,
    ShadowWireBindingFailed = 23,
    BadgeNotVerified = 24,
    InvalidReceiptsProgram = 25,
    MissingInstructionData = 26,
    InvalidMxeProgram = 27,
}

impl From<GatewayError> for ProgramError {
    fn from(error: GatewayError) -> Self {
        ProgramError::Custom(error as u32)
    }
}
