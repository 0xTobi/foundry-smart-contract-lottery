// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // Deploy the HelperConfig contract
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); // Get the configuration for the current chain

        // If there's no subscriptionId, create a subscription.
        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.account); // Create a subscription using the vrfCoordinator

            // Fund Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account); // Fund the subscription using the vrfCoordinator
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add Consumer
        // We first need to deploy the contract to add the consumer
        // We don't need to broadcast this transaction because we already have a broadcast in the AddConsumer contract
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account); // Add the consumer to the vrfCoordinator

        return (raffle, helperConfig);
    }
}
