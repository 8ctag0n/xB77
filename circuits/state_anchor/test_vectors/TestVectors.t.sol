// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Copy the verifier here inline (simplified)
interface IVerifier {
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool);
}

contract TestVectors is Test {
    address verifier;
    
    function setUp() public {
        // Deploy the verifier
        bytes memory code = vm.getDeployedCode("Verifier.sol:UltraVerifier");
        vm.etch(address(0x1234), code);
        verifier = address(0x1234);
    }
    
    function test_verify() public view {
        // Load proof (96 bytes public inputs + 2144 bytes proof)
        bytes memory fullProof = vm.readFileBinary("../target/proof");
        
        // Public inputs are first 96 bytes
        bytes32[] memory pubInputs = new bytes32[](3);
        assembly {
            let src := add(fullProof, 0x20) // skip length
            mstore(add(pubInputs, 0x20), mload(src))
            mstore(add(pubInputs, 0x40), mload(add(src, 0x20)))
            mstore(add(pubInputs, 0x60), mload(add(src, 0x40)))
        }
        
        // Proof bytes are the remaining 2144 bytes
        bytes memory proofBytes = new bytes(2144);
        assembly {
            let src := add(add(fullProof, 0x20), 96) // skip length + 96 byte header
            let dst := add(proofBytes, 0x20)
            for { let i := 0 } lt(i, 2144) { i := add(i, 32) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }
        
        console.log("Calling verify...");
        console.log("Pub input 0:"); console.logBytes32(pubInputs[0]);
        console.log("Pub input 1:"); console.logBytes32(pubInputs[1]);
        console.log("Pub input 2:"); console.logBytes32(pubInputs[2]);
        
        bool result = IVerifier(verifier).verify(proofBytes, pubInputs);
        console.log("Result:", result);
        assertTrue(result, "Proof should be valid");
    }
}
