// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Drop-in mock for the Stylus constitution contract.
///      Handles any selector — SEL_VALIDATE_SEMANTIC (0xabcdef01) and
///      SEL_BRIDGE_VERIFY (0x3a4b5c6d) both return abi.encode(result).
///      Call setResult(0) to simulate rejection/distrust.
contract MockStylusConstitution {
    uint256 private _result = 1; // 1 = approved/trusted, 0 = rejected

    function setResult(uint256 r) external { _result = r; }
    function getResult() external view returns (uint256) { return _result; }

    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(_result);
    }
}
