// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPolicy
 * @notice Minimal interface for ZeroDev Kernel v3 Policies
 */
interface IPolicy {
    function validateUserOp(
        bytes32 userOpHash,
        bytes calldata kernelSignature,
        bytes calldata policyData
    ) external view returns (uint256);
}

/**
 * @title SovereignPolicy
 * @notice Bridges ZeroDev Kernel v3 permissions with the xB77 Zig-Stylus Semantic Engine.
 * @dev This contract is called by the ZeroDev Kernel to verify if an agent's 
 *      action complies with its semantic constitution.
 */
contract SovereignPolicy is IPolicy {
    address public immutable constitutionStylus;

    event SemanticValidation(address indexed agent, bool approved, int32 similarity);

    constructor(address _constitutionStylus) {
        constitutionStylus = _constitutionStylus;
    }

    /**
     * @notice Validates a UserOperation using the Zig-Stylus Semantic Engine.
     * @param userOpHash Hash of the UserOperation.
     * @param kernelSignature Signature from the agent's session key.
     * @param policyData Contains the Intent Vector (128 * int32).
     * @return validationData 0 for success, 1 for failure.
     */
    function validateUserOp(
        bytes32 userOpHash,
        bytes calldata kernelSignature,
        bytes calldata policyData
    ) external view override returns (uint256) {
        // userOpHash and kernelSignature are used by the Signer validator.
        // This Policy focuses on the 'policyData' which we've designated 
        // to carry the agent's Intent Vector.
        
        require(policyData.length >= 512, "Invalid Intent Vector length");

        // Prepare the call to the Stylus contract
        // Selector: 0xabcdef01 (validateSemantic(int32[128]))
        bytes memory stylusPayload = abi.encodePacked(uint32(0xabcdef01), policyData[0:512]);

        (bool success, bytes memory result) = constitutionStylus.staticcall(stylusPayload);

        if (!success) return 1; // SIG_VALIDATION_FAILED

        // The Stylus contract returns 32 bytes (uint256 1 for success)
        if (result.length >= 32) {
            uint256 approved = abi.decode(result, (uint256));
            if (approved == 1) {
                return 0; // SIG_VALIDATION_SUCCESS
            }
        }

        return 1;
    }
}
