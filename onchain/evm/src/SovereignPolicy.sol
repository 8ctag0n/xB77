// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IXB77AgentValidator} from "./IXB77Protocol.sol";

/// @title IPolicy — ZeroDev Kernel v3 Policy interface
interface IPolicy {
    function validateUserOp(
        bytes32 userOpHash,
        bytes calldata kernelSignature,
        bytes calldata policyData
    ) external view returns (uint256);
}

/// @title SovereignPolicy
/// @notice Bridges ZeroDev Kernel v3 permissions with the xB77 Zig-Stylus Semantic Engine.
///         Also implements IXB77AgentValidator so external Arbitrum protocols can query
///         agent authorization without going through the full UserOp flow.
///
/// Integration points:
///   • ZeroDev Kernel v3.1 — called during UserOp validation (ERC-4337)
///   • ProtocolRegistry — queries isAgentApproved() before forwarding to DeFi protocols
///   • Cross-chain agents — queries isBridgeAgentTrusted() for Solana/Sui/Arc agents
contract SovereignPolicy is IPolicy, IXB77AgentValidator {
    address public immutable constitutionStylus;
    address public immutable owner;

    // Stylus contract selectors (must match onchain/stylus/main.zig)
    uint32 private constant SEL_VALIDATE_SEMANTIC = 0xabcdef01;
    uint32 private constant SEL_BRIDGE_VERIFY     = 0x3a4b5c6d;

    event SemanticValidation(address indexed agent, bool approved, int32 similarity);
    event CrossChainAgentVerified(uint8 chainId, bytes32 agentId, bool trusted);

    error InvalidIntentVectorLength();

    constructor(address _constitutionStylus) {
        constitutionStylus = _constitutionStylus;
        owner = msg.sender;
    }

    // ── ZeroDev Kernel v3 — UserOp validation ─────────────────────────────

    /// @notice Called by ZeroDev Kernel to validate every agent UserOperation.
    /// @param policyData Must contain the ABI-encoded int32[128] intent vector (512 bytes).
    /// @return 0 = SIG_VALIDATION_SUCCESS, 1 = SIG_VALIDATION_FAILED
    function validateUserOp(
        bytes32, /* userOpHash — verified by the ECDSA signer validator */
        bytes calldata, /* kernelSignature */
        bytes calldata policyData
    ) external view override returns (uint256) {
        if (policyData.length < 512) revert InvalidIntentVectorLength();

        (bool approved,) = _callStylusValidate(policyData[0:512]);
        return approved ? 0 : 1;
    }

    // ── IXB77AgentValidator — external protocol queries ────────────────────

    /// @inheritdoc IXB77AgentValidator
    function isAgentApproved(
        address agent,
        bytes calldata intentVector
    ) external view override returns (bool approved, int32 similarity) {
        if (intentVector.length < 512) return (false, 0);
        (approved, similarity) = _callStylusValidate(intentVector[0:512]);
        emit SemanticValidation(agent, approved, similarity);
    }

    /// @inheritdoc IXB77AgentValidator
    function isBridgeAgentTrusted(
        uint8 chainId,
        bytes32 agentId,
        bytes32 proof
    ) external view override returns (bool) {
        // ABI-encode bridgeVerify(uint8, bytes32, bytes32) for the Stylus contract
        bytes memory stylusPayload = abi.encodePacked(
            SEL_BRIDGE_VERIFY,
            uint256(chainId),   // uint8 ABI-padded to 32 bytes
            agentId,
            proof
        );

        (bool success, bytes memory result) = constitutionStylus.staticcall(stylusPayload);
        if (!success || result.length < 32) return false;

        bool trusted = abi.decode(result, (uint256)) == 1;
        emit CrossChainAgentVerified(chainId, agentId, trusted);
        return trusted;
    }

    // ── Internal ───────────────────────────────────────────────────────────

    function _callStylusValidate(
        bytes calldata intentVector512
    ) internal view returns (bool approved, int32 similarity) {
        bytes memory stylusPayload = abi.encodePacked(
            SEL_VALIDATE_SEMANTIC,
            intentVector512
        );

        (bool success, bytes memory result) = constitutionStylus.staticcall(stylusPayload);
        if (!success) return (false, 0);

        if (result.length >= 32) {
            approved = abi.decode(result, (uint256)) == 1;
            // Similarity is packed into log data by Stylus, not returned in call result.
            // For view calls, we return 0 as a safe default; logs carry the real value.
            similarity = 0;
        }
    }
}
