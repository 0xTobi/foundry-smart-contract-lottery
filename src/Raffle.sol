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
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

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

/**
 * @title A sample Raffle Contract
 * @author 0x_Hexed
 * @notice This contract is for creating a sample raffle contract
 * @dev This implements the Chainlink VRF Version 2
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /* Type Declarations */
    enum RaffleState {
        OPEN,   // 0
        CALCULATING // 1
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORD = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; //  @dev The duration of the lottery in seconds.
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    // The inherited contract "VRFConsumerBaseV2Plus" requires a "vrfCoordinator" parameter in its constructor.
    // We pass the "vrfCoordinator" parameter from our contract's constructor to the parent contract's constructor.
    // This approach promotes modularity and reusability.
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH Sent");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        // Rule of thumb to always follow whenever you update something in storage -- Emit an event
        // 1. Makes migration easier
        // 2. Makes frontend indexing easier
        emit RaffleEntered(msg.sender);
    }

    // 1. Get a random numver
    // 2. Use random number to pick a player
    // 3. Be automatically called
    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,                             // Gas you're willing to pay.
            subId: i_subscriptionId,                        // How we fund the gas for working with chainlink vrf.
            requestConfirmations: REQUEST_CONFIRMATIONS,    // How many blocks we should wait before chainlink gives us the random number.
            callbackGasLimit: i_callbackGasLimit,           // Max amount of gas you're willing to spend - So we don't have to spend too much gas.
            numWords: NUM_WORD,                             // How many random numbers we want to get.
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))    // We don't want to pay for the gas with LINK, we want to pay for the gas with ETH.
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;                // Get the index of the winner.
        address payable recentWinner = s_players[indexOfWinner];                    // Get the address of the winner.
        s_recentWinner = recentWinner;   
        
        s_raffleState = RaffleState.OPEN;
        
        (bool success, ) = recentWinner.call{value: address(this).balance}("");     // Send all the balance of the contract to the winner.
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);                                            // Emit an event to indicate that the winner has been picked.
    }

    // Getters
    function getEntrancefee() external view returns (uint256) {
        return i_entranceFee;
    }
}
