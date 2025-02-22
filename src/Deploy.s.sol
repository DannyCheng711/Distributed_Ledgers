// Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "./HumanResources.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        new HumanResources();
        vm.stopBroadcast();
    }
}