// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ERC-4337 v0.7 packed user operation (EntryPoint 0x0000000071727De22E5E9d8BAf0edAc6f37da032)
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

/// @title ISessionValidator
/// @notice Biconomy SmartSessions validator interface (ERC-7579 module).
/// @dev Ref: github.com/erc7579/smartsessions
interface ISessionValidator {
    /// @notice Called by SmartSessions for every UserOp within a session.
    /// @param permissionId keccak256 of the session config, computed by SmartSessions.
    /// @param userOp       The packed user operation being validated.
    /// @param userOpHash   EIP-712 hash of the user operation.
    /// @return validationData 0 = SIG_VALIDATION_SUCCESS, 1 = SIG_VALIDATION_FAILED
    function validateSessionParams(
        bytes32 permissionId,
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external view returns (uint256 validationData);

    /// @notice Returns true if the session has been enabled for the given account.
    function isSessionEnabled(address account, bytes32 permissionId) external view returns (bool);
}

/// @title SovereignSessionValidator
/// @notice Biconomy SmartSessions (ERC-7579) validator that gates every session UserOp
///         behind the xB77 Stylus semantic constitution.
///
/// This completes the xB77 enforcement triad:
///   ZeroDev Kernel      → SovereignPolicy (IPolicy.validateUserOp)
///   MetaMask / ERC-7710 → SovereignCaveatEnforcer (ICaveatEnforcer.beforeHook)
///   Biconomy SmartSessions → SovereignSessionValidator (ISessionValidator.validateSessionParams)
///
/// Session lifecycle:
///   1. Account installs SmartSessions module + grants a session with an intent vector.
///   2. SmartSessions calls `enableSession(account, permissionId, abi.encode(intentVector))`.
///   3. On each UserOp, SmartSessions calls `validateSessionParams(permissionId, userOp, hash)`.
///      The validator retrieves the stored vector and staticcalls the Stylus constitution.
///   4. Account (or SmartSessions module) calls `disableSession(permissionId)` to revoke.
///
/// Encoding for enableData:
///   abi.encode(intentVector)  — where intentVector is bytes of length >= 512 (int32[128] packed)
contract SovereignSessionValidator is ISessionValidator {
    address public immutable constitutionStylus;

    // account → permissionId → intentVector (exactly 512 bytes, int32[128])
    mapping(address => mapping(bytes32 => bytes)) private _sessions;

    // Must match onchain/stylus/main.zig and SovereignPolicy.sol
    uint32 private constant SEL_VALIDATE_SEMANTIC = 0xabcdef01;

    error InvalidIntentVectorLength();
    error SessionNotEnabled();

    event SessionEnabled(address indexed account, bytes32 indexed permissionId);
    event SessionDisabled(address indexed account, bytes32 indexed permissionId);

    constructor(address _constitutionStylus) {
        constitutionStylus = _constitutionStylus;
    }

    // ── Session management ────────────────────────────────────────────────────

    /// @notice Enable a session for an account.
    /// @dev In SmartSessions, this is called by the SmartSessions module during session
    ///      installation — the account's signature already authorized the grant.
    ///      `enableData` must be `abi.encode(intentVector)` where intentVector is >= 512 bytes.
    function enableSession(
        address account,
        bytes32 permissionId,
        bytes calldata enableData
    ) external {
        bytes memory vector = abi.decode(enableData, (bytes));
        if (vector.length < 512) revert InvalidIntentVectorLength();
        // Copy exactly 512 bytes (int32[128]) into storage.
        bytes memory trimmed = new bytes(512);
        assembly {
            let src := add(vector,  0x20)
            let dst := add(trimmed, 0x20)
            for { let i := 0 } lt(i, 512) { i := add(i, 0x20) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }
        _sessions[account][permissionId] = trimmed;
        emit SessionEnabled(account, permissionId);
    }

    /// @notice Disable a session. Only the account itself can revoke its own sessions.
    function disableSession(bytes32 permissionId) external {
        delete _sessions[msg.sender][permissionId];
        emit SessionDisabled(msg.sender, permissionId);
    }

    // ── ISessionValidator ─────────────────────────────────────────────────────

    /// @inheritdoc ISessionValidator
    /// @dev userOp.sender is used as the account address to look up the stored vector.
    ///      userOpHash is not verified here — SmartSessions handles ECDSA session key checks.
    function validateSessionParams(
        bytes32 permissionId,
        PackedUserOperation calldata userOp,
        bytes32 /* userOpHash */
    ) external view override returns (uint256) {
        bytes memory vector = _sessions[userOp.sender][permissionId];
        if (vector.length < 512) revert SessionNotEnabled();

        bytes memory payload = abi.encodePacked(SEL_VALIDATE_SEMANTIC, vector);
        (bool success, bytes memory result) = constitutionStylus.staticcall(payload);

        if (!success || result.length < 32 || abi.decode(result, (uint256)) != 1) {
            return 1; // SIG_VALIDATION_FAILED
        }
        return 0; // SIG_VALIDATION_SUCCESS
    }

    /// @inheritdoc ISessionValidator
    function isSessionEnabled(
        address account,
        bytes32 permissionId
    ) external view override returns (bool) {
        return _sessions[account][permissionId].length >= 512;
    }
}
