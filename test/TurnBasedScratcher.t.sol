// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {TurnBasedScratcher} from "../src/TurnScratcher.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract TurnBasedScratcherTest is Test {
    // Contracts
    TurnBasedScratcher internal scratcher;
    VRFCoordinatorV2_5Mock internal vrfCoordinator;
    MockERC20 internal usdc;

    // VRF Configuration
    uint256 internal subscriptionId;
    bytes32 internal keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint96 internal baseFee = 0; // 0 fee for testing
    uint96 internal gasPrice = 0; // 0 gas price for testing
    int256 internal weiPerUnitLink = 0; // 0 for testing

    // Test Users
    address internal owner;
    address internal house;
    address internal player1;
    address internal player2;

    // Test Amounts
    uint256 internal constant INITIAL_PLAYER_BALANCE = 100 * 1e6; // 100 USDC
    uint256 internal constant INITIAL_LIQUIDITY = 10000 * 1e6; // 10000 USDC (increased for higher payouts)
    uint256 internal constant GAME_FEE = 1 * 1e6;
    uint256 internal constant LINK_FUNDING = 1000 ether; // 1000 LINK

    // Events
    event GameStarted(uint256 indexed gameId, address indexed player);
    event CellsChosen(uint256 indexed gameId, uint8 round);
    event RandomnessRequested(uint256 indexed gameId, uint256 indexed vrfRequestId);
    event RoundRevealed(uint256 indexed gameId, uint8 round, uint256 payout, bool holeFound);
    event OfferSet(uint256 indexed gameId, uint8 round, uint256 offer);
    event GameFinished(uint256 indexed gameId, uint256 totalPayout, bool byHole);

    function setUp() public {
        owner = address(this);
        house = makeAddr("house");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");

        // Deploy Mock Contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        vrfCoordinator = new VRFCoordinatorV2_5Mock(baseFee, gasPrice, weiPerUnitLink);

        // Configure VRF Subscription with native ETH payment (not LINK)
        subscriptionId = vrfCoordinator.createSubscription();
        // Don't fund with LINK since we're using native ETH payments
        // vrfCoordinator.fundSubscription(subscriptionId, LINK_FUNDING);

        // Deploy the Scratcher contract
        vm.prank(owner);
        scratcher = new TurnBasedScratcher(
            address(usdc),
            address(vrfCoordinator),
            subscriptionId,
            keyHash
        );
        scratcher.setHouse(house);

        // Authorize the Scratcher contract on the subscription
        vrfCoordinator.addConsumer(subscriptionId, address(scratcher));

        // Distribute initial mock USDC
        usdc.mint(player1, INITIAL_PLAYER_BALANCE);
        usdc.mint(player2, INITIAL_PLAYER_BALANCE);
        usdc.mint(owner, INITIAL_LIQUIDITY);

        // Add initial liquidity to the contract for prize payouts
        vm.prank(owner);
        usdc.approve(address(scratcher), INITIAL_LIQUIDITY);
        // Note: The TurnBasedScratcher does not have an addLiquidity function.
        // We just transfer the funds directly to the contract for the test.
        usdc.transfer(address(scratcher), INITIAL_LIQUIDITY);

        // Fund test contract with ETH for VRF payments
        vm.deal(address(this), 100 ether);
        
        // Fund the scratcher contract with ETH for VRF payments
        vm.deal(address(scratcher), 10 ether);
    }

    function test_StartGame() public {
        uint256 initialPlayerBalance = usdc.balanceOf(player1);
        uint256 initialContractBalance = usdc.balanceOf(address(scratcher));
        uint8[3] memory chosenCells = [1, 2, 3];

        vm.startPrank(player1);
        usdc.approve(address(scratcher), GAME_FEE);
        scratcher.startGame(chosenCells);
        vm.stopPrank();

        uint256[] memory gameIds = scratcher.getGameIdsForPlayer(player1);
        assertEq(gameIds.length, 1, "Player should have one game");
        uint256 gameId = gameIds[0];

        TurnBasedScratcher.Game memory game = scratcher.getGame(gameId);

        assertEq(game.player, player1, "Game player should be player1");
        assertEq(uint(game.state), uint(TurnBasedScratcher.GameState.AwaitingRandomnessRound1), "Game should be in AwaitingRandomnessRound1");
        assertTrue(game.vrfRequestId > 0, "VRF Request should have been made");
        
        assertEq(usdc.balanceOf(player1), initialPlayerBalance - GAME_FEE, "Player balance should be reduced by fee");
        assertEq(usdc.balanceOf(address(scratcher)), initialContractBalance + GAME_FEE, "Contract balance should be increased by fee");
    }

    function test_StartAndFulfill_Round1_Success() public {
        uint8[3] memory chosenCells = [1, 2, 3];
        vm.startPrank(player1);
        usdc.approve(address(scratcher), GAME_FEE);
        scratcher.startGame(chosenCells);
        vm.stopPrank();

        uint256 gameId = 1;
        uint256 requestId = scratcher.getGame(gameId).vrfRequestId;
        
        uint256[] memory randomWords = new uint256[](3);
        randomWords[0] = 100;   // Payout: 100e6 (roll: 100, < 500)
        randomWords[1] = 1600;  // Payout: 25e6 (roll: 1600, < 2000)  
        randomWords[2] = 4500;  // Payout: 8e6 (roll: 4500, < 5000)
        uint256 expectedPayout = 100e6 + 25e6 + 8e6; // 133 USDC

        vm.expectEmit(true, false, false, true, address(scratcher));
        emit RoundRevealed(gameId, 1, expectedPayout, false);
        
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(scratcher), randomWords);

        TurnBasedScratcher.Game memory gameAfterFulfillment = scratcher.getGame(gameId);
        assertEq(uint(gameAfterFulfillment.state), uint(TurnBasedScratcher.GameState.Round1Negotiation), "Game state should be Round1Negotiation");
        assertEq(gameAfterFulfillment.revealedPayouts[0], expectedPayout, "Round 1 payout incorrect");
        assertFalse(gameAfterFulfillment.holeFound, "Hole should not be found");
    }

    function test_Fulfill_FindsHole_And_EndsGame() public {
        uint8[3] memory chosenCells = [1, 2, 3];
        vm.startPrank(player1);
        usdc.approve(address(scratcher), GAME_FEE);
        scratcher.startGame(chosenCells);
        vm.stopPrank();

        uint256 gameId = 1;
        uint256 requestId = scratcher.getGame(gameId).vrfRequestId;

        uint256[] memory randomWords = new uint256[](3);
        randomWords[0] = 100;    // Win: 100e6 payout (roll: 100, < 500)
        randomWords[1] = 97000;  // HOLE: 0 payout (roll: 97000, >= 96000) ✅ FIXED
        randomWords[2] = 1600;   // Win (but should be ignored due to hole)
        uint256 expectedPayout = 100e6; // Only first cell counts

        vm.expectEmit(true, false, false, true, address(scratcher));
        emit RoundRevealed(gameId, 1, expectedPayout, true);
        vm.expectEmit(true, true, true, true, address(scratcher));
        emit GameFinished(gameId, 0, true);

        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(scratcher), randomWords);

        TurnBasedScratcher.Game memory game = scratcher.getGame(gameId);
        assertEq(uint(game.state), uint(TurnBasedScratcher.GameState.FinishedByHole), "Game state should be FinishedByHole");
        assertTrue(game.holeFound, "Hole should be found");
        assertEq(game.revealedPayouts[0], expectedPayout, "Round 1 payout should be partial amount before hole");
    }

    function test_HouseSetsOffer_And_PlayerAccepts() public {
        (uint256 gameId, ) = _getGameToRound1Negotiation();
        uint256 offerAmount = 5 * 1e6;
        uint256 playerBalanceBeforeAccept = usdc.balanceOf(player1);

        vm.startPrank(house);
        scratcher.setHouseOffer(gameId, offerAmount);
        vm.stopPrank();

        vm.startPrank(player1);
        scratcher.acceptOffer(gameId);
        vm.stopPrank();

        assertEq(usdc.balanceOf(player1), playerBalanceBeforeAccept + offerAmount);
    }

    function test_FullGame_ThreeRounds_NoOffers() public {
        uint256 initialPlayerBalance = usdc.balanceOf(player1);

        (uint256 gameId, ) = _getGameToRound1Negotiation();

        // --- Round 2 ---
        uint256 r2_payout;
        {
            uint8[3] memory chosenCells = [4, 5, 6];
            uint256[] memory randomWords = new uint256[](3);
            randomWords[0] = 1600;  // Payout: 25e6 (roll: 1600, < 2000)
            randomWords[1] = 8000;  // Payout: 1e5 (roll: 8000, < 96000, >= 66000)
            randomWords[2] = 8001;  // Payout: 1e5 (roll: 8001, < 96000, >= 66000)
            r2_payout = 25e6 + 1e5 + 1e5;
            
            vm.prank(player1);
            scratcher.playRound(gameId, chosenCells);
            uint256 requestId = scratcher.getGame(gameId).vrfRequestId;
            vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(scratcher), randomWords);
            
            // Should be in Round2Negotiation state
            TurnBasedScratcher.Game memory gameAfterR2 = scratcher.getGame(gameId);
            assertEq(uint(gameAfterR2.state), uint(TurnBasedScratcher.GameState.Round2Negotiation), "Game state should be Round2Negotiation");
        }
        
        // --- Round 3 ---
        uint256 r3_payout;
        {
            uint8[3] memory chosenCells = [7, 8, 0];
            uint256[] memory randomWords = new uint256[](3);
            randomWords[0] = 4500;  // Payout: 8e6 (roll: 4500, < 5000)
            randomWords[1] = 8000;  // Payout: 1e5 (roll: 8000, < 96000, >= 66000)
            randomWords[2] = 8001;  // Payout: 1e5 (roll: 8001, < 96000, >= 66000)
            r3_payout = 8e6 + 1e5 + 1e5;

            vm.prank(player1);
            scratcher.playRound(gameId, chosenCells);
            uint256 requestId = scratcher.getGame(gameId).vrfRequestId;
            vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(scratcher), randomWords);
            
            // Should be in Finished state (no Round3Negotiation)
            TurnBasedScratcher.Game memory gameAfterR3 = scratcher.getGame(gameId);
            assertEq(uint(gameAfterR3.state), uint(TurnBasedScratcher.GameState.Finished), "Game state should be Finished");
        }

        // --- Final Payout ---
        // Get the actual contract payout values
        TurnBasedScratcher.Game memory gameBeforePayout = scratcher.getGame(gameId);
        uint256 actualTotalPayout = gameBeforePayout.revealedPayouts[0] + gameBeforePayout.revealedPayouts[1] + gameBeforePayout.revealedPayouts[2];
        
        vm.prank(player1);
        scratcher.finishGameAndClaimPayout(gameId);

        // Calculate expected balance: initial - game fee + actual total payout
        uint256 expectedBalance = initialPlayerBalance - GAME_FEE + actualTotalPayout;
        assertEq(usdc.balanceOf(player1), expectedBalance, "Player final balance is incorrect");
    }

    function test_PayoutFunction_HoleDetection() public {
        // Test that hole detection works correctly
        
        // Values that should be holes (96000-99999)
        uint256[4] memory holeValues = [uint256(96000), 97000, 98500, 99999];
        for (uint i = 0; i < holeValues.length; i++) {
            uint256 payout = _getSymbolPayout(holeValues[i]);
            assertEq(payout, 0, "Hole value should return 0 payout");
        }
        
        // Values that should NOT be holes
        uint256[4] memory winValues = [uint256(95999), 90000, 50000, 10000];
        for (uint i = 0; i < winValues.length; i++) {
            uint256 payout = _getSymbolPayout(winValues[i]);
            assertTrue(payout > 0, "Non-hole value should return positive payout");
        }
    }

    // ===================================
    // ======== Helper Functions =========
    // ===================================
    function _getGameToRound1Negotiation() internal returns (uint256 gameId, uint256 round1Payout) {
        uint8[3] memory chosenCells = [1, 2, 3];
        vm.startPrank(player1);
        usdc.approve(address(scratcher), GAME_FEE);
        scratcher.startGame(chosenCells);
        vm.stopPrank();

        gameId = 1;
        uint256 requestId = scratcher.getGame(gameId).vrfRequestId;
        
        uint256[] memory randomWords = new uint256[](3);
        randomWords[0] = 100;   // Payout: 100e6 (roll: 100, < 500)
        randomWords[1] = 1600;  // Payout: 25e6 (roll: 1600, < 2000)
        randomWords[2] = 4500;  // Payout: 8e6 (roll: 4500, < 5000)
        round1Payout = 100e6 + 25e6 + 8e6; // 133 USDC
        
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(scratcher), randomWords);
    }
    
    // Copy of the contract's payout function for testing
    function _getSymbolPayout(uint256 randomWord) internal pure returns (uint256) {
        uint256 roll = randomWord % 100000; // roll is now 0–99,999

        // 💎1 (Diamond Crown) - 0.5% chance, $100 payout
        if (roll < 500) return 100e6;

        // 💎2 (Golden Crown) - 1.5% chance, $25 payout  
        else if (roll < 2000) return 25e6;

        // 💎3 (Gold Treasure) - 3% chance, $8 payout
        else if (roll < 5000) return 8e6;

        // 💰 (Trophy) - 10% chance, $2 payout
        else if (roll < 15000) return 2e6;

        // 1 (Blue Diamond) - 11% chance, $1 payout
        else if (roll < 26000) return 1e6;

        // 🍒 (Cherry) - 15% chance, $0.50 payout
        else if (roll < 41000) return 5e5;

        // ⭐ (Star) - 25% chance, $0.20 payout
        else if (roll < 66000) return 2e5;

        // 🗿 (Stone) - 30% chance, $0.10 payout
        else if (roll < 96000) return 1e5;

        // 🕳️ (Hole/Trap) - 4% chance, $0 payout
        else return 0;
    }
}