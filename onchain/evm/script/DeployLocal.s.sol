// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SovereignPolicy} from "../src/SovereignPolicy.sol";
import {SovereignCaveatEnforcer} from "../src/SovereignCaveatEnforcer.sol";
import {Settlement} from "../src/Settlement.sol";

/// @dev Minimal mock constitution — handles all selectors, returns approved/trusted by default.
///      Exposes setResult(uint256) to flip between approved (1) and rejected (0).
contract MockStylusConstitutionDeploy {
    uint256 private _result = 1;
    function setResult(uint256 r) external { _result = r; }
    fallback(bytes calldata) external returns (bytes memory) {
        return abi.encode(_result);
    }
}

/// @dev Deploys the full xB77 EVM stack against a local anvil node.
///      Run via scripts/evm-local.sh or directly:
///        forge script script/DeployLocal.s.sol \
///          --rpc-url http://127.0.0.1:8545 \
///          --private-key $KEY --broadcast
///
///      Deployed addresses are logged as KEY=value pairs for easy shell parsing.
contract DeployLocal is Script {
    function run() external {
        uint256 deployerKey = vm.envOr(
            "DEPLOYER_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80) // anvil key 0
        );

        vm.startBroadcast(deployerKey);

        MockStylusConstitutionDeploy constitution = new MockStylusConstitutionDeploy();
        SovereignPolicy              policy       = new SovereignPolicy(address(constitution));
        SovereignCaveatEnforcer      enforcer     = new SovereignCaveatEnforcer();
        Settlement                   settlement   = new Settlement();

        vm.stopBroadcast();

        // Log as KEY=value — parsed by scripts/evm-local.sh
        console.log("CONSTITUTION_ADDRESS=%s", address(constitution));
        console.log("SOVEREIGN_POLICY_ADDRESS=%s", address(policy));
        console.log("CAVEAT_ENFORCER_ADDRESS=%s", address(enforcer));
        console.log("SETTLEMENT_ADDRESS=%s", address(settlement));
    }
}
