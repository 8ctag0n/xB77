// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICaveatEnforcer — MetaMask Delegation Toolkit interface (ERC-7710)
interface ICaveatEnforcer {
    function beforeHook(
        bytes calldata terms,
        bytes calldata args,
        bytes32 mode,
        bytes calldata executionCallData,
        bytes32 delegationHash,
        address delegationManager,
        address sender
    ) external;
}

/// @title SovereignCaveatEnforcer
/// @notice ERC-7710 caveat enforcer that gates execution on the xB77 Stylus semantic constitution.
///         Enables MetaMask Delegation Toolkit (Path B) for ERC-7715 `wallet_grantPermissions`.
///
/// Encoding:
///   terms = abi.encode(constitutionStylusAddress)  — set once at grant time
///   args  = abi.encode(intentVector)               — 512 bytes, int32[128], per call
///
/// The enforcer does a staticcall to the Stylus constitution with SEL_VALIDATE_SEMANTIC.
/// It reverts if the semantic check fails, blocking the delegated call.
contract SovereignCaveatEnforcer is ICaveatEnforcer {
    // Must match onchain/stylus/main.zig and SovereignPolicy.sol
    uint32 private constant SEL_VALIDATE_SEMANTIC = 0xabcdef01;

    error SemanticViolation();
    error InvalidIntentVectorLength();

    function beforeHook(
        bytes calldata terms,
        bytes calldata args,
        bytes32,        /* mode */
        bytes calldata, /* executionCallData */
        bytes32,        /* delegationHash */
        address,        /* delegationManager */
        address         /* sender */
    ) external view override {
        address constitution = abi.decode(terms, (address));
        bytes memory vector  = abi.decode(args, (bytes));

        if (vector.length < 512) revert InvalidIntentVectorLength();

        bytes memory payload = abi.encodePacked(SEL_VALIDATE_SEMANTIC, vector);
        (bool success, bytes memory result) = constitution.staticcall(payload);

        if (!success || result.length < 32 || abi.decode(result, (uint256)) != 1) {
            revert SemanticViolation();
        }
    }
}
