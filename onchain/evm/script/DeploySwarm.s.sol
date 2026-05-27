// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Settlement} from "../src/Settlement.sol";
import {SovereignPolicy} from "../src/SovereignPolicy.sol";

/**
 * @title DeploySwarmEconomy
 * @notice Deploys the xB77 Sovereign Swarm Economy stack on Arbitrum.
 */
contract DeploySwarmEconomy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stylusConstitution = vm.envAddress("STYLUS_CONSTITUTION_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Settlement
        Settlement settlement = new Settlement();
        console.log("Settlement deployed at:", address(settlement));

        // 2. Deploy SovereignPolicy (Bridges ZeroDev with Stylus)
        SovereignPolicy policy = new SovereignPolicy(stylusConstitution);
        console.log("SovereignPolicy deployed at:", address(policy));

        vm.stopBroadcast();
        
        console.log("--- xB77 Arbitrum Stack Ready ---");
    }
}
