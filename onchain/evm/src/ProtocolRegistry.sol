// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IXB77Protocol, IXB77AgentValidator} from "./IXB77Protocol.sol";

/// @title ProtocolRegistry
/// @notice Registry of Arbitrum protocols integrated with the xB77 agent economy.
/// @dev Protocols register here to receive agent actions. The SovereignPolicy
///      checks this registry before forwarding agent UserOps to external protocols.
contract ProtocolRegistry {
    address public immutable owner;
    IXB77AgentValidator public immutable validator;

    struct ProtocolEntry {
        string name;
        address addr;
        bool active;
        uint256 registeredAt;
        uint256 agentActionCount;
    }

    mapping(address => ProtocolEntry) public protocols;
    address[] public protocolList;

    // Per-agent, per-protocol capability grants
    // agent => protocol => capability bitmap
    mapping(address => mapping(address => uint256)) public agentCapabilities;

    // Capability flags
    uint256 public constant CAP_SWAP   = 1 << 0; // Agent can swap tokens
    uint256 public constant CAP_LEND   = 1 << 1; // Agent can supply/borrow
    uint256 public constant CAP_BRIDGE = 1 << 2; // Agent can bridge assets
    uint256 public constant CAP_STAKE  = 1 << 3; // Agent can stake/unstake
    uint256 public constant CAP_MINT   = 1 << 4; // Agent can mint (NFT, token)
    uint256 public constant CAP_ALL    = type(uint256).max;

    event ProtocolRegistered(address indexed protocol, string name);
    event ProtocolDeactivated(address indexed protocol);
    event AgentCapabilityGranted(address indexed agent, address indexed protocol, uint256 capabilities);
    event AgentActionForwarded(address indexed agent, address indexed protocol, bytes32 intentHash);

    error NotOwner();
    error ProtocolNotRegistered();
    error ProtocolAlreadyRegistered();
    error AgentNotApproved();
    error CapabilityNotGranted();

    constructor(address _validator) {
        owner = msg.sender;
        validator = IXB77AgentValidator(_validator);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Register a new Arbitrum protocol in the xB77 ecosystem.
    function registerProtocol(address protocol, string calldata name) external onlyOwner {
        if (protocols[protocol].addr != address(0)) revert ProtocolAlreadyRegistered();
        protocols[protocol] = ProtocolEntry({
            name: name,
            addr: protocol,
            active: true,
            registeredAt: block.timestamp,
            agentActionCount: 0
        });
        protocolList.push(protocol);
        emit ProtocolRegistered(protocol, name);
    }

    /// @notice Deactivate a protocol (emergency pause).
    function deactivateProtocol(address protocol) external onlyOwner {
        protocols[protocol].active = false;
        emit ProtocolDeactivated(protocol);
    }

    /// @notice Grant an agent specific capabilities on a protocol.
    /// @dev Only the protocol itself can grant capabilities to agents (pull model).
    function grantAgentCapability(address agent, uint256 capabilities) external {
        if (!protocols[msg.sender].active) revert ProtocolNotRegistered();
        agentCapabilities[agent][msg.sender] |= capabilities;
        emit AgentCapabilityGranted(agent, msg.sender, capabilities);
    }

    /// @notice Forward an agent action to a registered protocol.
    /// @dev Validates the agent's intent on-chain before forwarding.
    ///      This is the main integration point: any Arbitrum protocol can be called
    ///      through xB77 with full semantic validation.
    function forwardAgentAction(
        address protocol,
        bytes calldata intentVector,
        uint256 requiredCapability,
        bytes calldata actionData
    ) external returns (bool) {
        if (!protocols[protocol].active) revert ProtocolNotRegistered();

        // 1. Check agent is constitutionally approved
        (bool approved,) = validator.isAgentApproved(msg.sender, intentVector);
        if (!approved) revert AgentNotApproved();

        // 2. Check agent has the required capability on this protocol
        if (agentCapabilities[msg.sender][protocol] & requiredCapability == 0) {
            revert CapabilityNotGranted();
        }

        bytes32 intentHash = keccak256(intentVector);
        emit AgentActionForwarded(msg.sender, protocol, intentHash);

        // 3. Forward to protocol
        bool result = IXB77Protocol(protocol).onAgentAction(msg.sender, intentHash, actionData);
        if (result) {
            protocols[protocol].agentActionCount++;
        }
        return result;
    }

    /// @notice Check if a cross-chain agent from Solana/Sui/Arc is trusted on Arbitrum.
    function isCrossChainAgentTrusted(
        uint8 sourceChain,
        bytes32 agentId,
        bytes32 proof
    ) external view returns (bool) {
        return validator.isBridgeAgentTrusted(sourceChain, agentId, proof);
    }

    /// @notice Returns the full list of registered protocol addresses.
    function getProtocols() external view returns (address[] memory) {
        return protocolList;
    }

    /// @notice Returns the number of registered protocols.
    function protocolCount() external view returns (uint256) {
        return protocolList.length;
    }
}
