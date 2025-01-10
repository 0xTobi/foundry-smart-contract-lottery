// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";

contract DeployRaffle is Script {
    function run() external {
        vm.startBroadcast();
        Raffle raffle = new Raffle();
        vm.stopBroadcast();
    }
}

