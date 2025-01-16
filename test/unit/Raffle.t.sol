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

    uint256 entranceFee; // Fee required to enter the raffle
    uint256 interval; // Time interval between raffle draws
    address vrfCoordinator; // Address of the VRF Coordinator
    bytes32 gasLane; // Gas lane for Chainlink VRF
    uint256 subscriptionId; // Subscription ID for Chainlink VRF
    uint32 callbackGasLimit; // Callback gas limit for Chainlink VRF
    address account; // Account used for deployment and interaction

    address public PLAYER = makeAddr("player"); // Simulated player address
    uint256 public STARTING_PLAYER_BALANCE = 100 ether; // Initial balance for the player

    // Events
    event RaffleEntered(address indexed player); // Emitted when a player enters the raffle
    event WinnerPicked(address indexed winner); // Emitted when a winner is selected

    /// @dev Sets up the initial state for the tests, including deploying contracts and configuring parameters.
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle(); // Deploy the raffle contract
        (raffle, helperConfig) = deployer.deployContract(); // Retrieve deployed contracts

        // Load configuration parameters
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        account = config.account;

        // Assign initial balance to the player
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    /// @dev Test to ensure the raffle starts in an "OPEN" state.
    function testRaffleInitializedAsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/

    /// @dev Test to ensure entering the raffle without paying enough reverts.
    function testEnterRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER); // Simulate the player
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector); // Expect revert due to insufficient funds
        raffle.enterRaffle{value: 0.001 ether}(); // Try to enter with insufficient funds
    }

    /// @dev Test to ensure the player is recorded when they enter the raffle.
    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER); // Simulate the player
        raffle.enterRaffle{value: entranceFee}(); // Enter the raffle

        // Check that the player is recorded correctly
        address playerRecorded = raffle.getPlayers()[0];
        console.log(playerRecorded);

        assert(raffle.getPlayers().length == 1); // Ensure only one player is recorded
        assert(playerRecorded == PLAYER); // Ensure the recorded player matches the expected address
    }

    /// @dev Test to ensure an event is emitted when a player enters the raffle.
    function testEnterRaffleEmitsEvent() public {
        vm.prank(PLAYER); // Simulate the player

        // Expect the RaffleEntered event to be emitted
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}(); // Enter the raffle
    }

    /// @dev Test to ensure players cannot enter the raffle while it is in the "CALCULATING" state.
    function testDontAllowPlayersEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER); 
        raffle.enterRaffle{value: entranceFee}(); // Player enters the raffle

        vm.warp(block.timestamp + interval + 1); // Fast-forward time
        vm.roll(block.number + 1); // Mine a new block
        raffle.performUpkeep(""); // Trigger the upkeep process to transition state to CALCULATING

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector); // Expect revert if entering during CALCULATING state
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); 
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/

    /// @dev Test to ensure upkeep is not needed if there is no balance.
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1); // Fast-forward time
        vm.roll(block.number + 1); // Mine a new block

        (bool upkeepNeeded,) = raffle.checkUpkeep(""); // Check upkeep status
        assert(!upkeepNeeded); // Ensure upkeep is not needed
    }

    /// @dev Test to ensure upkeep is not needed if the raffle is not open.
    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // Player enters the raffle

        vm.warp(block.timestamp + interval + 1); // Fast-forward time
        vm.roll(block.number + 1); // Mine a new block
        raffle.performUpkeep(""); // Trigger the upkeep process to transition state to CALCULATING

        (bool upkeepNeeded,) = raffle.checkUpkeep(""); 
        assert(!upkeepNeeded); // Ensure upkeep is not needed
    }

    /// @dev Test to ensure upkeep is not needed if the interval has not passed.
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); 

        (bool upkeepNeeded,) = raffle.checkUpkeep(""); 
        assert(!upkeepNeeded); 
    }

    /// @dev Test to ensure upkeep is needed when all conditions are met.
    function testCheckUpkeepReturnsTrueIfParametersAreMet() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); 

        vm.warp(block.timestamp + interval + 1); // Fast-forward time
        vm.roll(block.number + 1); 
        (bool upkeepNeeded,) = raffle.checkUpkeep(""); 

        assert(upkeepNeeded); 
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/

    /// @dev Test to ensure performUpkeep can only run if checkUpkeep is true.
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); 
        vm.warp(block.timestamp + interval + 1); 
        vm.roll(block.number + 1);

        raffle.performUpkeep(""); 
    }

    /// @dev Test to ensure performUpkeep reverts if checkUpkeep is false.
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 raffleBalance = 0;
        uint256 playersCount = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); 
        raffleBalance += entranceFee;
        playersCount += 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, raffleBalance, playersCount, raffleState)
        );
        raffle.performUpkeep(""); 
    }

    /// @dev Modifier to set up a scenario where the raffle is entered and ready for upkeep.
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    /// @dev Test to ensure performUpkeep updates the raffle state and emits a request ID.
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        vm.recordLogs(); 
        raffle.performUpkeep(""); 
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; 
        Raffle.RaffleState raffleState = raffle.getRaffleState();

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
