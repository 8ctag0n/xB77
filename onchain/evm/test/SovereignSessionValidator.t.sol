// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SovereignSessionValidator, PackedUserOperation} from "../src/SovereignSessionValidator.sol";

/// @dev Mock Stylus constitution: returns abi.encode(1) by default.
///      Call `setApproved(false)` to simulate rejection.
contract MockConstitution {
    bool private _approved = true;

    function setApproved(bool v) external { _approved = v; }

    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(_approved ? uint256(1) : uint256(0));
    }
}

/// @dev Always reverts on staticcall.
contract RevertingConstitution {
    fallback(bytes calldata) external returns (bytes memory) {
        revert("constitution down");
    }
}

/// @dev Returns empty bytes on staticcall.
contract EmptyConstitution {
    fallback(bytes calldata) external returns (bytes memory) {
        return "";
    }
}

contract SovereignSessionValidatorTest is Test {
    SovereignSessionValidator public validator;
    MockConstitution          public constitution;

    address constant ACCOUNT     = address(0xA11CE);
    address constant OTHER       = address(0xB0B);
    bytes32 constant PERM_ID     = keccak256("test-session");
    bytes32 constant PERM_ID_2   = keccak256("test-session-2");

    function setUp() public {
        constitution = new MockConstitution();
        validator    = new SovereignSessionValidator(address(constitution));
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    function _vector(uint256 len) internal pure returns (bytes memory) {
        return new bytes(len);
    }

    function _enableData(uint256 vectorLen) internal pure returns (bytes memory) {
        return abi.encode(_vector(vectorLen));
    }

    function _userOp(address sender) internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender:              sender,
            nonce:               0,
            initCode:            "",
            callData:            "",
            accountGasLimits:    bytes32(0),
            preVerificationGas:  0,
            gasFees:             bytes32(0),
            paymasterAndData:    "",
            signature:           ""
        });
    }

    // ── enableSession ─────────────────────────────────────────────────────────

    function test_EnableSession_StoresVector() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function test_EnableSession_LargerVector_Accepted() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(1024));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function test_EnableSession_OverwritesExisting() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(1024));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function test_EnableSession_DifferentPermIds_Independent() public {
        validator.enableSession(ACCOUNT, PERM_ID,   _enableData(512));
        validator.enableSession(ACCOUNT, PERM_ID_2, _enableData(512));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID_2));
    }

    function test_EnableSession_DifferentAccounts_Independent() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        validator.enableSession(OTHER,   PERM_ID, _enableData(512));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
        assertTrue(validator.isSessionEnabled(OTHER,   PERM_ID));
    }

    function test_EnableSession_ShortVector_Reverts() public {
        vm.expectRevert(SovereignSessionValidator.InvalidIntentVectorLength.selector);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(511));
    }

    function test_EnableSession_EmptyVector_Reverts() public {
        vm.expectRevert(SovereignSessionValidator.InvalidIntentVectorLength.selector);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(0));
    }

    function test_EnableSession_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit SovereignSessionValidator.SessionEnabled(ACCOUNT, PERM_ID);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
    }

    // ── disableSession ────────────────────────────────────────────────────────

    function test_DisableSession_ClearsVector() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        vm.prank(ACCOUNT);
        validator.disableSession(PERM_ID);
        assertFalse(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function test_DisableSession_OtherAccountUnaffected() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        validator.enableSession(OTHER,   PERM_ID, _enableData(512));
        vm.prank(ACCOUNT);
        validator.disableSession(PERM_ID);
        assertFalse(validator.isSessionEnabled(ACCOUNT, PERM_ID));
        assertTrue(validator.isSessionEnabled(OTHER,   PERM_ID));
    }

    function test_DisableSession_NonExistent_NoRevert() public {
        vm.prank(ACCOUNT);
        validator.disableSession(PERM_ID); // must not revert
    }

    function test_DisableSession_EmitsEvent() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        vm.expectEmit(true, true, false, false);
        emit SovereignSessionValidator.SessionDisabled(ACCOUNT, PERM_ID);
        vm.prank(ACCOUNT);
        validator.disableSession(PERM_ID);
    }

    // ── validateSessionParams — happy path ────────────────────────────────────

    function test_Validate_ApprovedIntent_ReturnsZero() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        uint256 result = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
        assertEq(result, 0);
    }

    function test_Validate_LargerStoredVector_ApprovedIntent_ReturnsZero() public {
        // enableSession trims to 512 bytes regardless of input length
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(1024));
        uint256 result = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
        assertEq(result, 0);
    }

    function test_Validate_UserOpHashIgnored() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        // different hashes must produce same semantic result
        uint256 r1 = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
        uint256 r2 = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), keccak256("other"));
        assertEq(r1, r2);
    }

    // ── validateSessionParams — rejection ─────────────────────────────────────

    function test_Validate_RejectedByConstitution_ReturnsOne() public {
        constitution.setApproved(false);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        uint256 result = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
        assertEq(result, 1);
    }

    function test_Validate_SessionNotEnabled_Reverts() public {
        vm.expectRevert(SovereignSessionValidator.SessionNotEnabled.selector);
        validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
    }

    function test_Validate_WrongAccount_Reverts() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        // userOp.sender = OTHER — session is under ACCOUNT, so not found
        vm.expectRevert(SovereignSessionValidator.SessionNotEnabled.selector);
        validator.validateSessionParams(PERM_ID, _userOp(OTHER), bytes32(0));
    }

    function test_Validate_AfterDisable_Reverts() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        vm.prank(ACCOUNT);
        validator.disableSession(PERM_ID);
        vm.expectRevert(SovereignSessionValidator.SessionNotEnabled.selector);
        validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
    }

    // ── validateSessionParams — constitution failure paths ────────────────────

    function test_Validate_ConstitutionReverts_ReturnsOne() public {
        RevertingConstitution bad = new RevertingConstitution();
        SovereignSessionValidator v2 = new SovereignSessionValidator(address(bad));
        v2.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        uint256 result = v2.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
        assertEq(result, 1);
    }

    function test_Validate_ConstitutionReturnsEmpty_ReturnsOne() public {
        EmptyConstitution empty = new EmptyConstitution();
        SovereignSessionValidator v2 = new SovereignSessionValidator(address(empty));
        v2.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        uint256 result = v2.validateSessionParams(PERM_ID, _userOp(ACCOUNT), bytes32(0));
        assertEq(result, 1);
    }

    // ── isSessionEnabled ──────────────────────────────────────────────────────

    function test_IsSessionEnabled_BeforeEnable_False() public view {
        assertFalse(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function test_IsSessionEnabled_AfterEnable_True() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function test_IsSessionEnabled_AfterDisable_False() public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        vm.prank(ACCOUNT);
        validator.disableSession(PERM_ID);
        assertFalse(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    // ── fuzz ──────────────────────────────────────────────────────────────────

    function testFuzz_EnableSession_ShortVector_AlwaysReverts(uint16 len) public {
        vm.assume(len < 512);
        vm.expectRevert(SovereignSessionValidator.InvalidIntentVectorLength.selector);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(len));
    }

    function testFuzz_EnableSession_ValidVector_AlwaysSucceeds(uint16 extra) public {
        vm.assume(extra <= 2048);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512 + extra));
        assertTrue(validator.isSessionEnabled(ACCOUNT, PERM_ID));
    }

    function testFuzz_Validate_ApprovedIntent_ReturnsZero(bytes32 randomHash) public {
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        uint256 result = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), randomHash);
        assertEq(result, 0);
    }

    function testFuzz_Validate_RejectedIntent_ReturnsOne(bytes32 randomHash) public {
        constitution.setApproved(false);
        validator.enableSession(ACCOUNT, PERM_ID, _enableData(512));
        uint256 result = validator.validateSessionParams(PERM_ID, _userOp(ACCOUNT), randomHash);
        assertEq(result, 1);
    }
}
