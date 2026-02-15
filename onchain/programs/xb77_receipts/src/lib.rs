#![allow(unexpected_cfgs)]
use borsh::{BorshDeserialize, BorshSerialize};
use shank::{ShankInstruction, ShankType};
use light_sdk::{
    account::sha::LightAccount,
    address::v2::derive_address, // V2 Derivation
    cpi::{
        v2::{CpiAccounts, LightSystemProgramCpi}, // V2 CPI
        CpiSigner,
        InvokeLightSystemProgram,
        LightCpiInstruction,
    },
    derive_light_cpi_signer,
    instruction::{PackedAddressTreeInfo, ValidityProof},
    LightDiscriminator,
};
use solana_program::{
    account_info::AccountInfo,
    entrypoint,
    program_error::ProgramError,
    pubkey::Pubkey,
    sysvar::{clock::Clock, Sysvar},
    msg,
};
use solana_program::declare_id;
declare_id!("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W");
pub const LIGHT_CPI_SIGNER: CpiSigner = derive_light_cpi_signer!(
    "8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W"
);
entrypoint!(process_instruction);
#[repr(u8)]
#[derive(Debug, Clone, ShankInstruction)]
pub enum ReceiptInstruction {
    #[account(0, signer, name="signer", desc="The payer and authority for the transaction")]
    // CpiAccounts will take accounts from index 1..N-1
    // Agent account is expected to be the last account (index N)
    RecordReceipt(RecordReceiptInstructionData),
}

#[derive(Debug, Clone, Default, BorshSerialize, BorshDeserialize, LightDiscriminator)]
pub struct CompressedReceipt {
    pub owner: Pubkey,
    pub vendor: [u8; 32],
    pub amount: u64,
    pub timestamp: i64,
    pub memo_hash: [u8; 32],
}

#[derive(Debug, Clone, BorshSerialize, BorshDeserialize, ShankType)]
pub struct RecordReceiptInstructionData {
    pub proof: Vec<u8>,
    pub address_tree_info: Vec<u8>,
    pub output_state_tree_index: u8,
    pub vendor: [u8; 32],
    pub amount: u64,
    pub memo_hash: [u8; 32],
}

pub fn process_instruction(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: &[u8],
) -> Result<(), ProgramError> {
    if program_id != &ID {
        return Err(ProgramError::IncorrectProgramId);
    }
    if instruction_data.is_empty() {
        return Err(ProgramError::InvalidInstructionData);
    }
    match instruction_data[0] {
        0 => {
            let data = RecordReceiptInstructionData::try_from_slice(&instruction_data[1..])
                .map_err(|_| ProgramError::InvalidInstructionData)?;
            record_receipt(program_id, accounts, data)
        }
        _ => Err(ProgramError::InvalidInstructionData),
    }
}

fn record_receipt(
    program_id: &Pubkey,
    accounts: &[AccountInfo],
    instruction_data: RecordReceiptInstructionData,
) -> Result<(), ProgramError> {
    // Deserialize Light Protocol types from Vec<u8>
    let proof = ValidityProof::try_from_slice(&instruction_data.proof)
        .map_err(|_| ProgramError::InvalidInstructionData)?;
    let address_tree_info = PackedAddressTreeInfo::try_from_slice(&instruction_data.address_tree_info)
        .map_err(|_| ProgramError::InvalidInstructionData)?;

    if accounts.len() < 3 {
        return Err(ProgramError::NotEnoughAccountKeys);
    }

    // 0. Signer (Payer/Authority)
    let signer = &accounts[0];
    if !signer.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }

    // Last account: Agent (Owner of the receipt)
    let agent_account = accounts
        .last()
        .ok_or(ProgramError::NotEnoughAccountKeys)?;

    // Light accounts: Everything between signer and agent
    let light_accounts_slice = &accounts[1..accounts.len() - 1];
    if light_accounts_slice.is_empty() {
        msg!("ERROR: No light accounts provided between signer and agent");
        return Err(ProgramError::NotEnoughAccountKeys);
    }

    msg!("DEBUG: Light Accounts Slice Len: {}", light_accounts_slice.len());
    
    let light_cpi_accounts = CpiAccounts::new(signer, light_accounts_slice, LIGHT_CPI_SIGNER);

    let address_tree_index = address_tree_info.address_merkle_tree_pubkey_index as usize;
    let address_queue_index = address_tree_info.address_queue_pubkey_index as usize;
    let output_state_tree_index = instruction_data.output_state_tree_index as usize;
    msg!("DEBUG: Address Tree Packed Index: {}", address_tree_index);
    msg!("DEBUG: Address Queue Packed Index: {}", address_queue_index);
    msg!("DEBUG: Output State Tree Packed Index: {}", output_state_tree_index);

    if address_tree_index >= light_accounts_slice.len() {
        msg!(
            "ERROR: Address tree index {} out of range for light accounts len {}",
            address_tree_index,
            light_accounts_slice.len()
        );
        return Err(ProgramError::InvalidInstructionData);
    }
    if address_queue_index >= light_accounts_slice.len() {
        msg!(
            "ERROR: Address queue index {} out of range for light accounts len {}",
            address_queue_index,
            light_accounts_slice.len()
        );
        return Err(ProgramError::InvalidInstructionData);
    }
    if output_state_tree_index >= light_accounts_slice.len() {
        msg!(
            "ERROR: Output state tree index {} out of range for light accounts len {}",
            output_state_tree_index,
            light_accounts_slice.len()
        );
        return Err(ProgramError::InvalidInstructionData);
    }

    let address_tree_pubkey = light_cpi_accounts
        .get_account_info(address_tree_index)
        .map(|acc| *acc.key)
        .map_err(|_| {
             msg!("ERROR: Failed to get address tree at index {}", address_tree_index);
             ProgramError::NotEnoughAccountKeys
        })?;
    let address_queue_pubkey = light_cpi_accounts
        .get_account_info(address_queue_index)
        .map(|acc| *acc.key)
        .map_err(|_| {
            msg!("ERROR: Failed to get address queue at index {}", address_queue_index);
            ProgramError::NotEnoughAccountKeys
        })?;
    let output_state_tree_pubkey = light_cpi_accounts
        .get_account_info(output_state_tree_index)
        .map(|acc| *acc.key)
        .map_err(|_| {
            msg!(
                "ERROR: Failed to get output state tree at index {}",
                output_state_tree_index
            );
            ProgramError::NotEnoughAccountKeys
        })?;
        
        
        
                msg!("DEBUG: Address Tree Pubkey: {:?}", address_tree_pubkey);
                msg!("DEBUG: Address Queue Pubkey: {:?}", address_queue_pubkey);
                msg!("DEBUG: Output State Tree Pubkey: {:?}", output_state_tree_pubkey);
        
        
        
                msg!("DEBUG: Output State Tree Index: {}", instruction_data.output_state_tree_index);
        
        
        
                msg!("DEBUG: Program ID: {:?}", program_id);
        
        
        
            
    
        // Derive address using the V2 helper, passing seed components directly
    
    let (address_bytes, address_seed) = derive_address(
        &[
            b"receipt",
            &instruction_data.vendor,
            &instruction_data.memo_hash,
        ],
        &address_tree_pubkey,
        program_id,
    );
    //let address = Pubkey::new_from_array(address_bytes);
    // Then proceed with new_address_params, etc.
    let new_address_params = address_tree_info
        .into_new_address_params_assigned_packed(address_seed, None);
    msg!("DEBUG: Derived Address Seed: {:?}", address_seed.0);
    msg!("DEBUG: Derived Address (V2): {:?}", Pubkey::new_from_array(address_bytes));
    let mut receipt = LightAccount::<CompressedReceipt>::new_init(
        &ID,
        Some(address_bytes),
        instruction_data.output_state_tree_index,
    );
    // Set properties
    receipt.owner = *agent_account.key;
    receipt.vendor = instruction_data.vendor;
    receipt.amount = instruction_data.amount;
    receipt.timestamp = Clock::get()?.unix_timestamp;
    receipt.memo_hash = instruction_data.memo_hash;
    // V2: Invoke CPI
    msg!("DEBUG: Invoking Light CPI...");
    let cpi_result = match LightSystemProgramCpi::new_cpi(LIGHT_CPI_SIGNER, proof)
        .with_light_account(receipt)
        .map_err(|e| {
            msg!("Error building CPI with account: {:?}", e);
            ProgramError::InvalidInstructionData
        })?
        .with_new_addresses(&[new_address_params])
        .invoke(light_cpi_accounts) 
    {
        Ok(_) => {
            msg!("Light CPI Success");
            Ok(())
        },
        Err(e) => {
            msg!("Light CPI failed with: {:?}", e);
            if let ProgramError::Custom(code) = e {
                msg!("Light CPI custom code: {}", code);
            }
            Err(e)
        }
    };

    cpi_result
}
#[cfg(test)]
mod tests {
    use super::*;
    use solana_program::pubkey::Pubkey;
    use std::str::FromStr;
    #[test]
    fn test_derive_address_lab() {
        let program_id = Pubkey::from_str("8iGuTTFLhNfbUN8teY6t1SEJ7vFFzvkd3bsXUhi1R12W").unwrap();
        let address_tree_pubkey = Pubkey::from_str("amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx").unwrap(); // Use actual V2 tree in real tests
        let vendor = [1u8; 32];
        let memo_hash = [2u8; 32];
        // Use standard Rust SDK V2 derivation
        let (v2_address_bytes, address_seed) = derive_address(
            &[
                b"receipt",
                &vendor,
                &memo_hash,
            ],
            &address_tree_pubkey,
            &program_id,
        );
        let v2_address = Pubkey::new_from_array(v2_address_bytes);
        println!("Rust V2 Address Seed: {:?}", address_seed.0);
        println!("Rust V2 Address: {}", v2_address);
        // For verification: Add expected value if known, or cross-check with TS V2
        // Assuming client is updated to V2, this should match
    }
    use borsh::{BorshDeserialize, BorshSerialize};
    use light_program_test::{
        program_test::LightProgramTest, AddressWithTree, Indexer, ProgramTestConfig, Rpc, RpcError,
    };
    use light_sdk::{
        address::v2::derive_address,
        instruction::{PackedAccounts, SystemAccountMetaConfig},
    };
    use solana_sdk::{
        instruction::{Instruction,AccountMeta},
        signature::{Keypair, Signer},
    };
    use super::{CompressedReceipt, RecordReceiptInstructionData, ID}; // Assuming these are in the parent module
    
    #[tokio::test]
    async fn test_record_receipt() {
        std::env::set_var("LIGHT_RUN_MODE", "mock");
        std::env::set_var("LIGHT_PROVER_MODE", "mock");
        std::env::set_var("LIGHT_DISABLE_PROVER", "1");
        let config = ProgramTestConfig::new(true, Some(vec![("xb77_receipts", ID)]));
        let mut rpc = LightProgramTest::new(config).await.unwrap();
        let payer = rpc.get_payer().insecure_clone();
        let address_tree_info = rpc.get_address_tree_v2();
        let address_tree_pubkey = address_tree_info.tree;
    
        // Define test data for the receipt
        let vendor = [1u8; 32];
        let amount = 100u64;
        let memo_hash = [2u8; 32];
    
        // Derive the address for the compressed receipt
        let (address_bytes, _) = derive_address(
            &[b"receipt", &vendor, &memo_hash],
            &address_tree_pubkey,
            &ID,
        );
    
        // Use payer as agent (owner) for simplicity
        record_receipt(
            &payer,
            &mut rpc,
            address_tree_pubkey,
            address_bytes,
            vendor,
            amount,
            memo_hash,
            payer.pubkey(), // Agent pubkey (owner)
        )
        .await
        .unwrap();
    
        // Get the created compressed account
        let compressed_account = rpc
            .get_compressed_account(address_bytes, None)
            .await
            .unwrap()
            .value
            .unwrap();
    
        assert_eq!(compressed_account.address.unwrap(), address_bytes);
    
        // Deserialize and verify the account data
        let receipt = CompressedReceipt::deserialize(
            &mut compressed_account.data.as_ref().unwrap().data.as_slice(),
        )
        .unwrap();
    
        assert_eq!(receipt.owner, payer.pubkey());
        assert_eq!(receipt.vendor, vendor);
        assert_eq!(receipt.amount, amount);
        assert_eq!(receipt.memo_hash, memo_hash);
        assert!(receipt.timestamp > 0); // Timestamp should be set to a positive value
    }
    
    pub async fn record_receipt(
        payer: &Keypair,
        rpc: &mut LightProgramTest,
        address_tree_pubkey: Pubkey,
        address: [u8; 32],
        vendor: [u8; 32],
        amount: u64,
        memo_hash: [u8; 32],
        agent_pubkey: Pubkey, // The pubkey for the agent_account (owner)
    ) -> Result<(), RpcError> {
        let system_account_meta_config = SystemAccountMetaConfig::new(ID);
        let mut accounts = PackedAccounts::default();
        accounts.add_pre_accounts_signer(payer.pubkey());

        accounts.add_pre_accounts_meta(AccountMeta::new(
            agent_pubkey,
            false, // agent NO es signer
        ));

        accounts.add_system_accounts_v2(system_account_meta_config)?;
    
        let rpc_result = rpc
            .get_validity_proof(
                vec![],
                vec![AddressWithTree {
                    address,
                    tree: address_tree_pubkey,
                }],
                None,
            )
            .await?
            .value;
    
        let packed_address_tree_info = rpc_result.pack_tree_infos(&mut accounts).address_trees[0].try_to_vec().unwrap();
        let output_state_tree_index = rpc
            .get_random_state_tree_info()?
            .pack_output_tree_index(&mut accounts)?;
    
        let instruction_data = RecordReceiptInstructionData {
            proof: rpc_result.proof.try_to_vec().unwrap(),
            address_tree_info: packed_address_tree_info,
            output_state_tree_index,
            vendor,
            amount,
            memo_hash,
        };
    
        let inputs = instruction_data.try_to_vec().unwrap();
        let (account_metas, _, _) = accounts.to_account_metas();
        let instruction = Instruction {
            program_id: ID,
            accounts: account_metas,
            data: [&[0u8][..], &inputs[..]].concat(),
        };
    
        rpc.create_and_send_transaction(&[instruction], &payer.pubkey(), &[payer])
            .await?;
        Ok(())
    }
}
