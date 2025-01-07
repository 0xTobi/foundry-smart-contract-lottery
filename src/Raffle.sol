// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title A sample Raffle Contract
 * @author 0x_Hexed
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;           //  @dev The duration of the lottery in seconds.
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    
    /* Events */
    event RaffleEntered(address indexed player);

    // The inherited contract "VRFConsumerBaseV2Plus" requires a "vrfCoordinator" parameter in its constructor.
    // We pass the "vrfCoordinator" parameter from our contract's constructor to the parent contract's constructor.
    // This approach promotes modularity and reusability.
    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        // s_vrfCoordinator.requestRandomWords();      // This is available in the inherited parent contract, so we can access it here.
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH Sent");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        s_players.push(payable(msg.sender));
        // Rule of thumb to always follow whenever you update something in storage.
        // 1. Makes migration easier
        // 2. Makes frontend indexing easier
        emit RaffleEntered(msg.sender);
    }

    // 1. Get a random numver
    // 2. Use random number to pick a player
    // 3. Be automatically called
    function pickWinner() external {
        if((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        // requestId = s_vrfCoordinator.requestRandomWords(
        //     VRFV2PlusClient.RandomWordsRequest({
        //         keyHash: s_keyHash,
        //         subId: s_subscriptionId,
        //         requestConfirmations: requestConfirmations,
        //         callbackGasLimit: callbackGasLimit,
        //         numWords: numWords,
        //         // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
        //         extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        //     })
        // );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override {

    }

    // Getters
    function getEntrancefee() external view returns (uint256) {
        return i_entranceFee;
    }
}