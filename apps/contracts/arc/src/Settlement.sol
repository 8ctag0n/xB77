// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title xB77 Sovereign Settlement (Arc Deluxe Edition)
 * @notice Optimized for Arc Network where USDC is the native gas token.
 * @dev Uses inline assembly (Yul) for surgical transfers and gas efficiency.
 */
contract Settlement {
    // Arc Network USDC ERC-20 Proxy (6 decimals)
    address public constant USDC_ERC20 = 0x3600000000000000000000000000000000000000;
    
    address public immutable facilitator;

    event Settled(address indexed agent, uint256 amount, bytes32 indexed commitment, bytes32 reasoning_hash);
    event ReceiptStored(bytes32 indexed commitment, string metadata_url);

    constructor(address _facilitator) {
        facilitator = _facilitator;
    }

    /**
     * @notice Settles a transaction with a ZK commitment and an AI reasoning trace hash.
     * @dev Uses Yul to bypass Solidity's high-level overhead for the transferFrom call.
     */
    function settle(uint256 amount, bytes32 commitment, bytes32 reasoning_hash) external {
        address _usdc = USDC_ERC20;
        address _facilitator = facilitator;

        assembly {
            let ptr := mload(0x40) // Get free memory pointer
            
            // Selector for transferFrom(address,address,uint256) -> 0x23b872dd
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), caller())      // from
            mstore(add(ptr, 0x24), _facilitator)  // to
            mstore(add(ptr, 0x44), amount)        // value

            // Call USDC contract: gas, addr, value (0 because USDC is native but we use ERC20 interface), in, inSize, out, outSize
            let success := call(gas(), _usdc, 0, ptr, 0x64, 0, 0x20)
            
            // If call failed or returned false (USDC returns bool)
            if iszero(and(success, mload(0))) {
                // Revert with no data to save gas
                revert(0, 0)
            }
        }
        
        emit Settled(msg.sender, amount, commitment, reasoning_hash);
    }

    function verify_receipt(bytes32 commitment, string calldata metadata_url) external {
        emit ReceiptStored(commitment, metadata_url);
    }

    /**
     * @notice Ultra-low-level balance check using staticcall in assembly.
     */
    function fastBalanceOf(address account) external view returns (uint256 balance) {
        address _usdc = USDC_ERC20;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 0x04), account)
            let success := staticcall(gas(), _usdc, ptr, 0x24, ptr, 0x20)
            if iszero(success) { revert(0, 0) }
            balance := mload(ptr)
        }
    }
}
