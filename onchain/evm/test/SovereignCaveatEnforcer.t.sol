// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {SovereignCaveatEnforcer} from "../src/SovereignCaveatEnforcer.sol";

/// @dev Mock Stylus constitution: returns abi.encode(1) (approved) by default.
///      Call `setApproved(false)` to simulate a semantic violation.
contract MockConstitution {
    bool private _approved = true;

    function setApproved(bool v) external { _approved = v; }

    // Catch-all: accepts any selector (SEL_VALIDATE_SEMANTIC = 0xabcdef01 + 512 bytes)
    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(_approved ? uint256(1) : uint256(0));
    }
}

contract SovereignCaveatEnforcerTest is Test {
    SovereignCaveatEnforcer public enforcer;
    MockConstitution         public constitution;

    // Dummy values for unused beforeHook params
    bytes32 constant MODE     = bytes32(0);
    bytes32 constant DEL_HASH = bytes32(0);
    address constant DEL_MGR  = address(0);
    address constant SENDER   = address(0);

    function setUp() public {
        enforcer    = new SovereignCaveatEnforcer();
        constitution = new MockConstitution();
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    function _terms() internal view returns (bytes memory) {
        return abi.encode(address(constitution));
    }

    function _args(uint256 len) internal pure returns (bytes memory) {
        return abi.encode(new bytes(len));
    }

    function _call(bytes memory terms, bytes memory args) internal view {
        enforcer.beforeHook(terms, args, MODE, "", DEL_HASH, DEL_MGR, SENDER);
    }

    // ── happy path ────────────────────────────────────────────────────────────

    function test_ApprovedIntent_DoesNotRevert() public view {
        _call(_terms(), _args(512));
    }

    function test_ApprovedIntent_LargerVector() public view {
        // > 512 bytes is fine — enforcer reads first 512
        _call(_terms(), _args(1024));
    }

    // ── semantic violation ────────────────────────────────────────────────────

    function test_RejectedByConstitution_Reverts() public {
        constitution.setApproved(false);
        vm.expectRevert(SovereignCaveatEnforcer.SemanticViolation.selector);
        _call(_terms(), _args(512));
    }

    // ── bad input ─────────────────────────────────────────────────────────────

    function test_ShortVector_RevertsInvalidLength() public {
        vm.expectRevert(SovereignCaveatEnforcer.InvalidIntentVectorLength.selector);
        _call(_terms(), _args(100));
    }

    function test_EmptyVector_RevertsInvalidLength() public {
        vm.expectRevert(SovereignCaveatEnforcer.InvalidIntentVectorLength.selector);
        _call(_terms(), _args(0));
    }

    function test_511ByteVector_RevertsInvalidLength() public {
        vm.expectRevert(SovereignCaveatEnforcer.InvalidIntentVectorLength.selector);
        _call(_terms(), _args(511));
    }

    // ── constitution failure ──────────────────────────────────────────────────

    function test_ConstitutionReverts_RevertsSemanticViolation() public {
        // Deploy a constitution that always reverts
        RevertingConstitution bad = new RevertingConstitution();
        bytes memory badTerms = abi.encode(address(bad));
        vm.expectRevert(SovereignCaveatEnforcer.SemanticViolation.selector);
        _call(badTerms, _args(512));
    }

    function test_ConstitutionReturnsEmpty_RevertsSemanticViolation() public {
        EmptyConstitution empty = new EmptyConstitution();
        bytes memory emptyTerms = abi.encode(address(empty));
        vm.expectRevert(SovereignCaveatEnforcer.SemanticViolation.selector);
        _call(emptyTerms, _args(512));
    }

    // ── fuzz ──────────────────────────────────────────────────────────────────

    function testFuzz_ShortVector_AlwaysReverts(uint16 len) public {
        vm.assume(len < 512);
        vm.expectRevert(SovereignCaveatEnforcer.InvalidIntentVectorLength.selector);
        _call(_terms(), _args(len));
    }

    function testFuzz_ValidVector_NeverRevertsWhenApproved(uint16 extra) public view {
        vm.assume(extra <= 1024);
        _call(_terms(), _args(512 + extra));
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
