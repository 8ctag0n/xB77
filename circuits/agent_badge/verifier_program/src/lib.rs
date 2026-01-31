use solana_program::{
    account_info::AccountInfo,
    entrypoint,
    entrypoint::ProgramResult,
    msg,
    program_error::ProgramError,
    pubkey::Pubkey,
};
use verifier_lib::{proof::Groth16Proof, verifier::Groth16Verifier, witness::Groth16Witness};

pub mod vk;
use vk::VK;

entrypoint!(process_instruction);

pub fn process_instruction(
    _program_id: &Pubkey,
    _accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> ProgramResult {
    msg!("Verifier: Processing verification request");

    // Attempt to parse proof and witness from instruction_data.
    // Since we don't have a strict schema (like Bincode headers for lengths),
    // and both proof and witness might be variable length (though typically fixed for specific curves),
    // we need to know where to split.
    
    // However, Groth16Proof and Groth16Witness impl SchemaRead (wincode/borsh).
    // If they are serialized sequentially, we can try to deserialize them sequentially.
    // Or we can rely on fixed sizes if known.
    
    // For bn254 Groth16:
    // Proof is 3 G1 points + 1 G2 point (compressed/uncompressed).
    // Let's assume standard Sunspot serialization which likely uses wincode or manual bytes.
    
    // Let's try to infer from the payload structure used in Gateway:
    // payload.proof (Vec<u8>) + payload.public_witness (Vec<u8>)
    // Wait, in Gateway we concatenated them raw. This loses length information if they are variable.
    // But Groth16 proofs are generally fixed size (128 bytes or 256 bytes depending on compression).
    // Public witness size depends on number of inputs.
    
    // Let's modify Gateway to send [proof_len (4 bytes) | proof | witness].
    // BUT, the simplest way is to try to parse `Groth16Proof` first, which should consume exactly what it needs,
    // and then parse `Groth16Witness` from the remainder.
    
    // verifier-lib's `Groth16Proof::from_bytes` takes a slice. If it consumes exact bytes and returns, great.
    // But typical `from_bytes` might expect *only* the object or consume everything.
    
    // WORKAROUND: For this specific setup, we know the proof size is constant.
    // A standard Groth16 proof (compressed) on BN254 is:
    // A (32*2 = 64), B (32*4 = 128), C (32*2 = 64) -> Total 256 bytes? 
    // Or 32 bytes per field element? 
    // Usually 128 bytes if compressed.
    
    // Let's inspect verifier-lib or trial-and-error. 
    // The safest bet is for the Gateway to prepend the length of the proof.
    // But I can't easily change `xb77_gateway`'s serialization logic without wincode unless I write bytes manually.
    
    // Let's try to assume proof is first 128 bytes (if compressed) or similar.
    // Actually, `verifier-lib`'s `Groth16Proof` likely has a constant size constant.
    
    // Let's look at `from_bytes` signature in `verifier-lib` if I could... but I can't easily.
    // I'll assume that `Groth16Proof::from_bytes` expects the slice to *be* the proof.
    // So I need to split `instruction_data`.
    
    // Hack: Pass proof length as the first 4 bytes (u32 little endian).
    
    if instruction_data.len() < 4 {
        return Err(ProgramError::InvalidInstructionData);
    }
    
    // But wait, in `processor.rs` I just did:
    // cpi_data.extend_from_slice(&payload.proof);
    // cpi_data.extend_from_slice(&payload.public_witness);
    // This is ambiguous.
    
    // I WILL UPDATE `processor.rs` to prepend the proof length.
    
    // Let's just implement assuming the first 4 bytes are length.
    let proof_len_bytes: [u8; 4] = instruction_data[0..4].try_into().unwrap();
    let proof_len = u32::from_le_bytes(proof_len_bytes) as usize;
    
    if instruction_data.len() < 4 + proof_len {
        msg!("Verifier: Data too short for proof");
        return Err(ProgramError::InvalidInstructionData);
    }
    
    let proof_bytes = &instruction_data[4..4+proof_len];
    let witness_bytes = &instruction_data[4+proof_len..];
    
    let proof = Groth16Proof::from_bytes(proof_bytes).map_err(|_| {
        msg!("Verifier: Failed to parse proof");
        ProgramError::InvalidInstructionData
    })?;
    
    let witness = Groth16Witness::from_bytes(witness_bytes).map_err(|_| {
        msg!("Verifier: Failed to parse witness");
        ProgramError::InvalidInstructionData
    })?;
    
    // Verify
    // 3 public inputs (root, order_id, nullifier)
    let mut verifier: Groth16Verifier<3> = Groth16Verifier::new(&VK);
    
    verifier.verify(proof, witness).map_err(|_| {
        msg!("Verifier: Verification FAILED");
        ProgramError::InvalidInstructionData
    })?;
    
    msg!("Verifier: Verification SUCCEEDED");
    Ok(())
}
