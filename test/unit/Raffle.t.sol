// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console, console2} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address account;

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
        account = config.account;

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
        raffle.enterRaffle{value: entranceFee}(); // Raffle has players, balance and is open

        // Action
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfParametersAreMet() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); //Raffle has players, balance and is open

        // Action
        vm.warp(block.timestamp + interval + 1); // Raffle has passed the interval
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
        raffle.enterRaffle{value: entranceFee}(); //Raffle has players, balance and is open
        vm.warp(block.timestamp + interval + 1); // Raffle has passed the interval
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

    // Since we have to keep repeating this.
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Action
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOMWORDS
    //////////////////////////////////////////////////////////////*/

    // The tests below require simulating the VRFCoordinator on an actual chain.
    // These tests will fail if run on a live chain, so we skip them using the skipFork modifier.

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return; // Skip execution if not on the local chain.
        }
        _;
    }

    function testFulfillRandomWordsCanOnlybeRunAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // Ensure fulfillRandomWords cannot be called unless performUpkeep has been executed.
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // Arrange: Add additional entrants to the raffle.
        uint256 additionalEntrants = 3; // Total players: 4 (1 initial + 3 new)
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether); // Simulate new player with sufficient balance.
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act: Perform upkeep and fulfill the random words to pick a winner.
        vm.recordLogs();
        raffle.performUpkeep(""); // Trigger the upkeep process.
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // Extract request ID from logs.
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert: Verify the winner, raffle state, and prize distribution.
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnersPrize = entranceFee * (startingIndex + additionalEntrants);

        assert(recentWinner == expectedWinner); // Ensure the winner is correct.
        assert(uint256(raffleState) == 0); // Ensure the raffle state is reset to "Open".
        assert(winnerBalance == winnerStartingBalance + winnersPrize); // Verify prize distribution.
        assert(endingTimeStamp > startingTimestamp); // Confirm timestamp is updated.
    }
}
