use solana_program::program_error::ProgramError;

#[repr(u32)]
pub enum RegistryError {
    InvalidInstruction = 0,
    NotEnoughAccounts = 1,
    MissingSigner = 2,
    InvalidSystemProgram = 3,
    InvalidMerchantPda = 4,
    InvalidCatalogPda = 5,
    InvalidOwner = 6,
    MerchantAlreadyInitialized = 7,
    MerchantNotInitialized = 8,
    CatalogAlreadyInitialized = 9,
    CatalogNotInitialized = 10,
    MerchantIdTooLong = 11,
    CatalogUrlTooLong = 12,
    DataTooLarge = 13,
    InvalidMerchantId = 14,
}

impl From<RegistryError> for ProgramError {
    fn from(error: RegistryError) -> Self {
        ProgramError::Custom(error as u32)
    }
}
