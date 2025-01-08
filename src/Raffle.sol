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
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author 0x_Hexed
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORD = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;           //  @dev The duration of the lottery in seconds.
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    
    /* Events */
    event RaffleEntered(address indexed player);

    // The inherited contract "VRFConsumerBaseV2Plus" requires a "vrfCoordinator" parameter in its constructor.
    // We pass the "vrfCoordinator" parameter from our contract's constructor to the parent contract's constructor.
    // This approach promotes modularity and reusability.
    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        s_vrfCoordinator.requestRandomWords();      // This is available in the inherited parent contract, so we can access it here.
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
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

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,         // Gas you're willing to pay
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,     // Max amount of gas you're willing to spend
                numWords: NUM_WORD,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
                request
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override {

    }

    // Getters
    function getEntrancefee() external view returns (uint256) {
        return i_entranceFee;
    }
}