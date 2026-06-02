// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SovereignPolicy} from "../src/SovereignPolicy.sol";
import {MockStylusConstitution} from "./mocks/MockStylusConstitution.sol";

contract SovereignPolicyTest is Test {
    SovereignPolicy      public policy;
    MockStylusConstitution public constitution;

    address constant AGENT    = address(0xA6E8);
    address constant NOT_OWNER = address(0xBEEF);

    // 512 bytes of int32[128] — all zeros (neutral-ish vector)
    bytes internal VECTOR_512 = new bytes(512);

    // 512 bytes with all bytes = 0x01 (represents a positive-biased vector)
    bytes internal VECTOR_POS;

    function setUp() public {
        constitution = new MockStylusConstitution();
        policy = new SovereignPolicy(address(constitution));

        VECTOR_POS = new bytes(512);
        for (uint256 i = 0; i < 512; i++) VECTOR_POS[i] = 0x01;
    }

    // ── constructor ───────────────────────────────────────────────────────────

    function test_Constructor_SetsConstitutionAndOwner() public view {
        assertEq(policy.constitutionStylus(), address(constitution));
        assertEq(policy.owner(), address(this));
    }

    // ── validateUserOp — ERC-4337 / ZeroDev Kernel entry point ───────────────

    function test_ValidateUserOp_Approved_ReturnsZero() public view {
        // constitution returns 1 (approved) → validateUserOp must return 0 (SIG_VALIDATION_SUCCESS)
        uint256 result = policy.validateUserOp(bytes32(0), "", VECTOR_512);
        assertEq(result, 0);
    }

    function test_ValidateUserOp_Rejected_ReturnsOne() public {
        constitution.setResult(0);
        uint256 result = policy.validateUserOp(bytes32(0), "", VECTOR_512);
        assertEq(result, 1);
    }

    function test_ValidateUserOp_ShortPolicyData_Reverts() public {
        bytes memory shortData = new bytes(511);
        vm.expectRevert(SovereignPolicy.InvalidIntentVectorLength.selector);
        policy.validateUserOp(bytes32(0), "", shortData);
    }

    function test_ValidateUserOp_EmptyPolicyData_Reverts() public {
        vm.expectRevert(SovereignPolicy.InvalidIntentVectorLength.selector);
        policy.validateUserOp(bytes32(0), "", "");
    }

    function test_ValidateUserOp_Exactly512Bytes_OK() public view {
        uint256 result = policy.validateUserOp(bytes32(0), "", VECTOR_512);
        assertEq(result, 0); // approved
    }

    function test_ValidateUserOp_LargerThan512Bytes_OK() public view {
        bytes memory bigger = new bytes(600);
        uint256 result = policy.validateUserOp(bytes32(0), "", bigger);
        assertEq(result, 0);
    }

    function test_ValidateUserOp_UserOpHashIgnored() public view {
        // The userOpHash param is documented as "verified by the ECDSA signer validator"
        // — SovereignPolicy ignores it. Both hashes should produce same result.
        uint256 r1 = policy.validateUserOp(keccak256("hash-a"), "", VECTOR_512);
        uint256 r2 = policy.validateUserOp(keccak256("hash-b"), "", VECTOR_512);
        assertEq(r1, r2);
    }

    function test_ValidateUserOp_ConstitutionRevert_ReturnsFail() public {
        // Deploy a constitution that always reverts
        RevertingConstitution bad = new RevertingConstitution();
        SovereignPolicy badPolicy = new SovereignPolicy(address(bad));
        uint256 result = badPolicy.validateUserOp(bytes32(0), "", VECTOR_512);
        assertEq(result, 1); // _callStylusValidate returns (false,0) on revert
    }

    // ── isAgentApproved — external protocol queries ───────────────────────────

    function test_IsAgentApproved_Approved() public view {
        (bool approved, int32 similarity) = policy.isAgentApproved(AGENT, VECTOR_512);
        assertTrue(approved);
        assertEq(similarity, 0); // similarity always 0 in view call (logged by Stylus)
    }

    function test_IsAgentApproved_Rejected() public {
        constitution.setResult(0);
        (bool approved,) = policy.isAgentApproved(AGENT, VECTOR_512);
        assertFalse(approved);
    }

    function test_IsAgentApproved_ShortVector_ReturnsFalse() public view {
        bytes memory shortVec = new bytes(64);
        (bool approved,) = policy.isAgentApproved(AGENT, shortVec);
        assertFalse(approved);
    }

    // ── isBridgeAgentTrusted — cross-chain verification ───────────────────────

    function test_IsBridgeAgentTrusted_Trusted() public view {
        bool trusted = policy.isBridgeAgentTrusted(
            0x01, // Solana
            keccak256("solana-agent-pubkey"),
            keccak256("ghost-receipt")
        );
        assertTrue(trusted);
    }

    function test_IsBridgeAgentTrusted_NotTrusted() public {
        constitution.setResult(0);
        bool trusted = policy.isBridgeAgentTrusted(
            0x01,
            keccak256("unknown-agent"),
            keccak256("bad-proof")
        );
        assertFalse(trusted);
    }

    function test_IsBridgeAgentTrusted_ConstitutionRevert_ReturnsFalse() public {
        RevertingConstitution bad = new RevertingConstitution();
        SovereignPolicy badPolicy = new SovereignPolicy(address(bad));
        bool trusted = badPolicy.isBridgeAgentTrusted(0x01, bytes32(0), bytes32(0));
        assertFalse(trusted);
    }

    // ── fuzz ──────────────────────────────────────────────────────────────────

    function testFuzz_ValidateUserOp_ShortData_AlwaysReverts(uint16 len) public {
        vm.assume(len < 512);
        bytes memory shortData = new bytes(len);
        vm.expectRevert(SovereignPolicy.InvalidIntentVectorLength.selector);
        policy.validateUserOp(bytes32(0), "", shortData);
    }

    function testFuzz_ValidateUserOp_ValidData_NoRevert(uint16 extra) public view {
        vm.assume(extra <= 512);
        bytes memory data = new bytes(512 + extra);
        policy.validateUserOp(bytes32(0), "", data); // should not revert
    }

    function testFuzz_BridgeVerify_AnyChainId(uint8 chainId) public view {
        // Any chainId is accepted — the constitution decides trust
        bool trusted = policy.isBridgeAgentTrusted(chainId, bytes32(0), bytes32(0));
        assertTrue(trusted); // constitution returns 1
    }
}

/// @dev Always reverts — used to test the _callStylusValidate failure path.
contract RevertingConstitution {
    fallback(bytes calldata) external returns (bytes memory) {
        revert("down");
    }
}
