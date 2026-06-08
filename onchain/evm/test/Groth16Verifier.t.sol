// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Groth16Verifier.sol";

/// @dev Gas benchmark for Groth16Verifier vs the Stylus WASM baseline.
///
///      Proof format (matches e2e_full.sh mk_proof_groth16):
///        byte 0:     0x01 (Groth16 type tag)
///        bytes 1-64: A  (G1, filled with 0xa1 — not on curve, ecPairing returns 0)
///        bytes 65-192: B (G2, filled with 0xb2)
///        bytes 193-256: C (G1, filled with 0xc3)
///
///      Gas target: execution overhead only (same precompile path as Zig).
///      Stylus reference: ~537k gas net (total − 2,909,485 no-op baseline).
contract Groth16VerifierTest is Test {
    Groth16Verifier verifier;

    bytes   proof;
    bytes32[] pubInputs;

    // BN254 G1 generator
    uint256 constant G1_X = 1;
    uint256 constant G1_Y = 2;

    // BN254 G2 generator (EIP-197 encoding: x.c1, x.c0, y.c1, y.c0)
    bytes32 constant G2_X1 = bytes32(uint256(0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2));
    bytes32 constant G2_X0 = bytes32(uint256(0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed));
    bytes32 constant G2_Y1 = bytes32(uint256(0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b));
    bytes32 constant G2_Y0 = bytes32(uint256(0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa));

    function setUp() public {
        verifier = new Groth16Verifier();

        // Build proof with valid BN254 curve points (G1/G2 generators).
        // Cryptographically invalid → verifyProof returns false, but all
        // precompile calls (ecMul, ecAdd, ecPairing×4) execute fully.
        // Layout: 0x01 | A/G1(64) | B/G2(128) | C/G1(64) = 257 bytes
        proof = abi.encodePacked(
            bytes1(0x01),                      // type tag
            bytes32(uint256(G1_X)),            // A.x
            bytes32(uint256(G1_Y)),            // A.y
            G2_X1, G2_X0, G2_Y1, G2_Y0,       // B (G2 generator)
            bytes32(uint256(G1_X)),            // C.x
            bytes32(uint256(G1_Y))             // C.y
        );

        // Small BN254 scalars (well within R)
        pubInputs = new bytes32[](3);
        pubInputs[0] = bytes32(uint256(1));
        pubInputs[1] = bytes32(uint256(2));
        pubInputs[2] = bytes32(uint256(3));
    }

    /// @dev Main benchmark: measures gas for the full verifyProof() path.
    ///      The mock proof has non-curve points so ecPairing returns false —
    ///      but gas cost is identical to a valid proof (same precompile call).
    function test_gasVerifyProof() public {
        uint256 gasBefore = gasleft();
        bool valid = verifier.verifyProof(proof, pubInputs);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Groth16Verifier.verifyProof() gasUsed", gasUsed);
        emit log_named_string("result", valid ? "VALID" : "invalid (expected: mock proof)");

        // Stylus WASM reference (from local Nitro measurement, session 3):
        //   total gasUsed: 3,446,075   baseline (no-op): 2,909,485   net: ~537k
        // This test measures Solidity net execution. Ratio tells the real story.
        emit log_named_uint("Stylus WASM net gas (ref)", 537_000);
        if (gasUsed > 0) {
            // rough ratio x100 to avoid floats
            uint256 ratio100 = (537_000 * 100) / gasUsed;
            emit log_named_uint("Stylus/Solidity ratio x100 (>100 = Stylus cheaper)", ratio100);
        }
    }

    /// @dev Decomposed benchmark: isolate ecPairing cost from ecMul/ecAdd overhead.
    function test_gasBreakdown() public {
        // Cost of the 3 ecMul + 3 ecAdd for pub input accumulation
        bytes32[] memory oneInput = new bytes32[](1);
        oneInput[0] = keccak256("xb77.pub.input.1");

        uint256 g1 = gasleft();
        try verifier.verifyProof(proof, oneInput) {} catch {}
        uint256 cost1 = g1 - gasleft();

        uint256 g3 = gasleft();
        try verifier.verifyProof(proof, pubInputs) {} catch {}
        uint256 cost3 = g3 - gasleft();

        emit log_named_uint("gasUsed (1 pub input)", cost1);
        emit log_named_uint("gasUsed (3 pub inputs)", cost3);
        if (cost3 > cost1) {
            emit log_named_uint("ecMul+ecAdd overhead per extra input", (cost3 - cost1) / 2);
        }
    }

    /// @dev Baseline: empty call overhead (no BN254 ops).
    function test_gasBaseline() public {
        // Direct ecPairing with 0 pairs — precompile returns 1 with minimal cost
        uint256 gBefore = gasleft();
        (bool ok, bytes memory ret) = address(0x08).staticcall("");
        uint256 cost = gBefore - gasleft();
        emit log_named_uint("ecPairing(0 pairs) baseline gas", cost);
        emit log_named_uint("ok", ok ? 1 : 0);
        assertEq(abi.decode(ret, (uint256)), 1);
    }
}
