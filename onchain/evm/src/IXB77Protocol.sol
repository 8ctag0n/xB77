// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IXB77Protocol
/// @notice Interface for Arbitrum protocols to integrate with xB77 agent authorization.
/// @dev Any DeFi protocol on Arbitrum (DEX, lending, bridge) can implement this interface
///      to gate their functions behind xB77 semantic agent validation.
interface IXB77Protocol {
    /// @notice Called by xB77 before an agent executes an action on this protocol.
    /// @param agent The smart account address of the agent.
    /// @param intentHash keccak256 of the agent's 128-dim intent vector.
    /// @param data Arbitrary protocol-specific calldata.
    /// @return True if this protocol approves the agent action.
    function onAgentAction(
        address agent,
        bytes32 intentHash,
        bytes calldata data
    ) external returns (bool);

    /// @notice Returns the protocol's name for registry display.
    function protocolName() external view returns (string memory);

    /// @notice Returns what chain IDs this protocol accepts cross-chain agents from.
    /// @dev xB77 chain IDs: 0x01=Solana, 0x02=Sui, 0x03=Arc, 0x04=Arbitrum
    function acceptedSourceChains() external view returns (uint8[] memory);
}

/// @title IXB77AgentValidator
/// @notice Read-only interface exposed by xB77 SovereignPolicy for external queries.
interface IXB77AgentValidator {
    /// @notice Check if an agent is constitutionally approved for a given intent.
    /// @param agent The agent's smart account address.
    /// @param intentVector ABI-encoded int32[128] semantic intent vector.
    /// @return approved True if the intent passes the on-chain constitution.
    /// @return similarity The cosine similarity score (0–10000 scale).
    function isAgentApproved(
        address agent,
        bytes calldata intentVector
    ) external view returns (bool approved, int32 similarity);

    /// @notice Check if an agent from another chain is trusted.
    /// @param chainId xB77 chain ID of the source chain.
    /// @param agentId Chain-specific agent identifier (pubkey hash, object ID, etc).
    /// @param proof Cross-chain proof (ghost receipt hash, PTB digest, etc).
    function isBridgeAgentTrusted(
        uint8 chainId,
        bytes32 agentId,
        bytes32 proof
    ) external view returns (bool);
}
