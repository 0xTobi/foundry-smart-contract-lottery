// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 100 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); 
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializedAsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    function testEnterRaffleReverrsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);     // Revert if not enough funds

        // Action
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Action
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayers()[0];
        console.log(playerRecorded);

        // Assert
        assert(raffle.getPlayers().length == 1);
        assert(playerRecorded == PLAYER);
    }

    function testEnterRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        
        // vm.expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData, address emitter);
        // checkTopic1 (true): The first indexed parameter (address indexed player) of the RaffleEntered event will be checked against the actual emitted event.
        vm.expectEmit(true, false, false, false, address(raffle));  // Hey, we're expecting an event to be emitted.
        emit RaffleEntered(PLAYER);                                 // This is the event that should be emitted when a player enters the raffle

        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }
}
