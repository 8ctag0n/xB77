use solana_program::program_error::ProgramError;

#[derive(Debug, Copy, Clone)]
pub enum CoreError {
    InvalidInstruction = 0,
    NotAuthorized = 1,
    AgentAlreadyExists = 2,
    AgentNotFound = 3,
    InsufficientFunds = 4,
    CreditLimitExceeded = 5,
    MathOverflow = 6,
    InvalidCPI = 7,
    InvalidZkProof = 8,
    ZkRootMismatch = 9,
}

impl From<CoreError> for ProgramError {
    fn from(e: CoreError) -> Self {
        ProgramError::Custom(e as u32)
    }
}
