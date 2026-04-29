use wincode::{SchemaRead, SchemaWrite};

#[derive(Debug, SchemaRead, SchemaWrite)]
pub struct InitMerchantPayload {
    pub merchant_id: Vec<u8>,
    pub supported_methods: u64,
}

#[derive(Debug, SchemaRead, SchemaWrite)]
pub enum RegistryInstruction {
    InitMerchant(InitMerchantPayload),
}

fn main() {
    let payload = InitMerchantPayload {
        merchant_id: b"merchant_01".to_vec(),
        supported_methods: 1,
    };
    let inst = RegistryInstruction::InitMerchant(payload);
    let data = wincode::serialize(&inst).unwrap();
    println!("Hex: {:02x?}", data);
}
