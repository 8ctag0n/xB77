use xb77_core::instruction::{CoreInstruction, InitCorePayload};

#[test]
fn test_tag() {
    let payload = InitCorePayload {
        admin: [0; 32],
        gateway_program: [0; 32],
        receipts_program: [0; 32],
        treasury_mint: [0; 32],
    };
    let bytes = wincode::serialize(&CoreInstruction::InitCore(payload)).unwrap();
    panic!("TAG BYTES: {:?}", &bytes[0..8]);
}
