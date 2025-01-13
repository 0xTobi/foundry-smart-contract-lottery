// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        
        // Create a subscription using the vrfCoordinator...
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console2.log("Creating subscription on chain Id: %s", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console2.log("Your subscription Id is: %s", subId);
        console2.log("Please update the subscription Id in the HelperConfig contract");

        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}


contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 1 ether; // 1 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        
        // Fund the subscription using the vrfCoordinator...
        fundSubscription(vrfCoordinator, subscriptionId);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId) public {
        console2.log("Funding subscription on chain Id: %s", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
        vm.stopBroadcast();

        console2.log("Subscription funded with 1 ether");
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}