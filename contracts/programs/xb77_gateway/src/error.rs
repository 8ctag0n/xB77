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
}

impl From<GatewayError> for ProgramError {
    fn from(error: GatewayError) -> Self {
        ProgramError::Custom(error as u32)
    }
}
