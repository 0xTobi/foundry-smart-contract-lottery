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
    uint256 subscriptionId;
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

    function testEnterRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector); // Revert if not enough funds

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
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        // Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Action
        vm.warp(block.timestamp + interval + 1); // Move time forward to simulate passing the interval
        vm.roll(block.number + 1); // Mine a new block to simulate blockchain activity
        raffle.performUpkeep(""); // Call `performUpkeep` to transition the raffle state to `CALCULATING`

        // Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1); // Move time forward to simulate passing the interval
        vm.roll(block.number + 1); // Mine a new block to simulate blockchain activity

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Action
        vm.warp(block.timestamp + interval + 1); // Move time forward to simulate passing the interval
        vm.roll(block.number + 1); // Mine a new block to simulate blockchain activity
        raffle.performUpkeep(""); // Call `performUpkeep` to transition the raffle state to `CALCULATING`
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    // More Tests
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();   // Raffle has players, balance and is open

        // Action
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfParametersAreMet() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();   //Raffle has players, balance and is open

        // Action
        vm.warp(block.timestamp + interval + 1);    // Raffle has passed the interval
        vm.roll(block.number + 1); 
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();   //Raffle has players, balance and is open
        vm.warp(block.timestamp + interval + 1);    // Raffle has passed the interval
        vm.roll(block.number + 1); 

        // Action / Assert
        raffle.performUpkeep(""); // This should pass
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 raffleBalance = 0;
        uint256 playersCount = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // +Balance +Player +Open -Interval = CheckUpkeep false
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        raffleBalance += entranceFee;
        playersCount += 1;

        // Action / Assert
        // Using `abi.encodeWithSelector` to call the error message because it takes in some very specific parameters.
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, raffleBalance, playersCount, raffleState)
        );
        raffle.performUpkeep(""); // This should revert
    }
}


