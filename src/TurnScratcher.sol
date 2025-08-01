// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./consumer/VRFConsumer.sol";
import "./interfaces/IRoninVRFCoordinatorForConsumers.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TurnBasedScratcher is VRFConsumer, Ownable {
    IERC20 public usdc;
    address public house;
    uint256 public gameFee = 1e6;
    uint256 public gameIdCounter;

    // Ronin VRF configuration
    uint256 private constant CALLBACK_GAS_LIMIT = 500000;
    uint256 private constant NUM_WORDS_PER_ROUND = 3;

    enum GameState {
        AwaitingRandomnessRound1,
        Round1Negotiation,
        AwaitingRandomnessRound2,
        Round2Negotiation,
        AwaitingRandomnessRound3,
        Finished,
        FinishedByHole 
    }

    struct Game {
        address player;
        GameState state;
        bytes32 vrfRequestHash;
        uint8[9] chosenCells;
        bool[9] isCellChosen;
        uint256[3] revealedPayouts; // Total payout per round
        uint256[3] offeredPayouts;
        bool holeFound;
        // Store individual cell results for each round (3 cells per round)
        uint256[9] cellPayouts; // cellPayouts[0-2] = round 1, [3-5] = round 2, [6-8] = round 3
        uint256[9] cellRandomValues; // Store the random values to recreate symbols
    }

    mapping(uint256 => Game) public games;
    mapping(bytes32 => uint256) public vrfRequestToGameId;
    mapping(address => uint256[]) public gamesByUser;

    event GameStarted(uint256 indexed gameId, address indexed player);
    event CellsChosen(uint256 indexed gameId, uint8 round);
    event RandomnessRequested(uint256 indexed gameId, bytes32 indexed vrfRequestHash);
    event RoundRevealed(uint256 indexed gameId, uint8 round, uint256 payout, bool holeFound);
    event OfferSet(uint256 indexed gameId, uint8 round, uint256 offer);
    event GameFinished(uint256 indexed gameId, uint256 totalPayout, bool byHole);

    constructor(address _usdcAddress, address _vrfCoordinator)
        VRFConsumer(_vrfCoordinator)
        Ownable(msg.sender)
    {
        usdc = IERC20(_usdcAddress);
        house = msg.sender;
    }

    // Receive function to accept RON for VRF payments
    receive() external payable {}

    function setHouse(address _newHouse) external onlyOwner {
        house = _newHouse;
    }

    function callbackGasLimit() public pure returns (uint256) {
        return CALLBACK_GAS_LIMIT;
    }

    function gasPrice() public view returns (uint256) {
        return 20e9 + block.basefee * 2; // basefee * 2 + 20 GWEI as recommended
    }

    function estimateVRFFee() public view returns (uint256) {
        return IRoninVRFCoordinatorForConsumers(vrfCoordinator).estimateRequestRandomFee(
            callbackGasLimit(),
            gasPrice()
        );
    }

    function startGame(uint8[3] calldata cellIndexes) external payable {
        require(usdc.transferFrom(msg.sender, address(this), gameFee), "USDC transfer failed");
        
        // Ensure contract has enough RON for VRF
        uint256 vrfFee = estimateVRFFee();
        require(msg.value >= vrfFee, "Insufficient RON for VRF fee");
        
        gameIdCounter++;
        
        Game storage game = games[gameIdCounter];
        game.player = msg.sender;
        game.state = GameState.AwaitingRandomnessRound1;

        for (uint i=0; i<3; i++) {
            uint8 cell = cellIndexes[i];
            require(cell < 9, "Invalid cell index");
            game.isCellChosen[cell] = true;
            game.chosenCells[i] = cell;
        }

        gamesByUser[msg.sender].push(gameIdCounter);
        emit GameStarted(gameIdCounter, msg.sender);
        emit CellsChosen(gameIdCounter, 1);
        
        bytes32 vrfRequestHash = _requestRandomness(
            msg.value,
            callbackGasLimit(),
            gasPrice(),
            msg.sender
        );
        
        game.vrfRequestHash = vrfRequestHash;
        vrfRequestToGameId[vrfRequestHash] = gameIdCounter;
        emit RandomnessRequested(gameIdCounter, vrfRequestHash);
    }

    function playRound(uint256 gameId, uint8[3] calldata cellIndexes) external payable {
        Game storage game = games[gameId];
        require(msg.sender == game.player || msg.sender == house, "Not player or house");

        uint8 round;
        uint8 cellStartIndex;

        if (game.state == GameState.Round1Negotiation) {
            round = 2;
            cellStartIndex = 3;
            game.state = GameState.AwaitingRandomnessRound2;
        } else if (game.state == GameState.Round2Negotiation) {
            round = 3;
            cellStartIndex = 6;
            game.state = GameState.AwaitingRandomnessRound3;
        } else {
            revert("Not in a valid state to play a round");
        }

        // Ensure sufficient RON for VRF
        uint256 vrfFee = estimateVRFFee();
        require(msg.value >= vrfFee, "Insufficient RON for VRF fee");

        for (uint i=0; i<3; i++) {
            uint8 cell = cellIndexes[i];
            require(cell < 9, "Invalid cell index");
            require(!game.isCellChosen[cell], "Cell already chosen");
            game.isCellChosen[cell] = true;
            game.chosenCells[cellStartIndex+i] = cell;
        }

        emit CellsChosen(gameId, round);
        
        bytes32 vrfRequestHash = _requestRandomness(
            msg.value,
            callbackGasLimit(),
            gasPrice(),
            msg.sender
        );
        
        game.vrfRequestHash = vrfRequestHash;
        vrfRequestToGameId[vrfRequestHash] = gameId;
        emit RandomnessRequested(gameId, vrfRequestHash);
    }

    function _fulfillRandomSeed(bytes32 _reqHash, uint256 _randomSeed) internal override {
        uint256 gameId = vrfRequestToGameId[_reqHash];
        Game storage game = games[gameId];
        require(game.vrfRequestHash == _reqHash, "Invalid request hash");

        // Generate 3 random values from the single seed
        uint256[3] memory randomWords;
        randomWords[0] = uint256(keccak256(abi.encode(_randomSeed, 0)));
        randomWords[1] = uint256(keccak256(abi.encode(_randomSeed, 1)));
        randomWords[2] = uint256(keccak256(abi.encode(_randomSeed, 2)));

        uint256 roundPayout = 0;
        bool holeInThisRound = false;
        uint8 round;
        uint8 cellStartIndex;

        // Determine which round we're in and cell start index
        if (game.state == GameState.AwaitingRandomnessRound1) {
            round = 1;
            cellStartIndex = 0;
        } else if (game.state == GameState.AwaitingRandomnessRound2) {
            round = 2;
            cellStartIndex = 3;
        } else if (game.state == GameState.AwaitingRandomnessRound3) {
            round = 3;
            cellStartIndex = 6;
        } else {
            revert("Fulfilled in invalid state");
        }

        // Process each cell in the round
        for(uint i = 0; i < NUM_WORDS_PER_ROUND; i++){
            uint256 cellPayout = _getSymbolPayout(randomWords[i]);
            
            // Store individual cell results
            game.cellPayouts[cellStartIndex + i] = cellPayout;
            game.cellRandomValues[cellStartIndex + i] = randomWords[i];
            
            if (cellPayout == 0) {
                holeInThisRound = true;
                break; 
            }
            roundPayout += cellPayout;
        }
        
        // Update game state based on round
        if (round == 1) {
            game.revealedPayouts[0] = roundPayout;
            game.state = holeInThisRound ? GameState.FinishedByHole : GameState.Round1Negotiation;
        } else if (round == 2) {
            game.revealedPayouts[1] = roundPayout;
            game.state = holeInThisRound ? GameState.FinishedByHole : GameState.Round2Negotiation;
        } else if (round == 3) {
            game.revealedPayouts[2] = roundPayout;
            game.state = holeInThisRound ? GameState.FinishedByHole : GameState.Finished;
        }

        emit RoundRevealed(gameId, round, roundPayout, holeInThisRound);

        if (holeInThisRound) {
            game.holeFound = true;
            emit GameFinished(gameId, 0, true);
        }
    }

    function setHouseOffer(uint256 gameId, uint256 offerAmount) external {
        require(msg.sender == house, "Not the house");
        Game storage game = games[gameId];
        uint8 roundIndex;
        if (game.state == GameState.Round1Negotiation) roundIndex = 0;
        else if (game.state == GameState.Round2Negotiation) roundIndex = 1;
        else if (game.state == GameState.Finished) roundIndex = 2;
        else revert("Not in a negotiation state");
        
        game.offeredPayouts[roundIndex] = offerAmount;
        emit OfferSet(gameId, roundIndex + 1, offerAmount);
    }

    function acceptOffer(uint256 gameId) external {
        Game storage game = games[gameId];
        require(msg.sender == game.player || msg.sender == house, "Not the player or house");
        uint8 roundIndex;
        if(game.state == GameState.Round1Negotiation) roundIndex = 0;
        else if(game.state == GameState.Round2Negotiation) roundIndex = 1;
        else if(game.state == GameState.Finished) roundIndex = 2;
        else revert("Not in negotiation state");
        
        uint256 offer = game.offeredPayouts[roundIndex];
        require(offer > 0, "No offer to accept");
        
        usdc.transfer(game.player, offer);
        game.state = GameState.Finished;
        emit GameFinished(gameId, offer, false);
    }

    function finishGameAndClaimPayout(uint256 gameId) external {
        Game storage game = games[gameId];
        require(msg.sender == game.player || msg.sender == house, "Not the player or house");
        require(game.state == GameState.Finished, "Not in a valid state to claim final payout");

        uint256 totalPayout = game.revealedPayouts[0] + game.revealedPayouts[1] + game.revealedPayouts[2];
        if (totalPayout > 0) {
            usdc.transfer(game.player, totalPayout);
        }
        game.state = GameState.Finished;
        emit GameFinished(gameId, totalPayout, false);
    }
    
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

    function withdraw(uint256 amount) external onlyOwner {
        require(usdc.transfer(owner(), amount), "Withdraw failed");
    }

    function withdrawRON(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient RON balance");
        payable(owner()).transfer(amount);
    }

    function getGame(uint256 _gameId) external view returns (Game memory) {
        return games[_gameId];
    }

    function getGameIdsForPlayer(address _player) external view returns (uint256[] memory) {
        return gamesByUser[_player];
    }

    // Get individual cell results for a specific round
    function getRoundCellResults(uint256 _gameId, uint8 _round) external view returns (
        uint256[3] memory cellPayouts,
        uint256[3] memory cellRandomValues,
        uint8[3] memory cellIndexes
    ) {
        require(_round >= 1 && _round <= 3, "Invalid round");
        Game storage game = games[_gameId];
        
        uint8 startIndex = (_round - 1) * 3;
        
        for (uint i = 0; i < 3; i++) {
            cellPayouts[i] = game.cellPayouts[startIndex + i];
            cellRandomValues[i] = game.cellRandomValues[startIndex + i];
            cellIndexes[i] = game.chosenCells[startIndex + i];
        }
    }

    // Get all revealed cell results (useful for completed rounds)
    function getRevealedCells(uint256 _gameId) external view returns (
        uint256[] memory cellPayouts,
        uint256[] memory cellRandomValues,
        uint8[] memory cellIndexes,
        uint8 revealedRounds
    ) {
        Game storage game = games[_gameId];
        
        // Determine how many rounds have been revealed
        revealedRounds = 0;
        if (game.revealedPayouts[0] > 0 || (game.state >= GameState.Round1Negotiation && !game.holeFound)) revealedRounds = 1;
        if (game.revealedPayouts[1] > 0 || (game.state >= GameState.Round2Negotiation && !game.holeFound)) revealedRounds = 2;
        if (game.revealedPayouts[2] > 0 || (game.state >= GameState.Finished && !game.holeFound)) revealedRounds = 3;
        
        if (game.holeFound) {
            // If hole found, determine which round it was found in
            if (game.state == GameState.FinishedByHole) {
                if (game.revealedPayouts[0] == 0) revealedRounds = 1;
                else if (game.revealedPayouts[1] == 0) revealedRounds = 2;
                else revealedRounds = 3;
            }
        }
        
        uint256 totalCells = revealedRounds * 3;
        cellPayouts = new uint256[](totalCells);
        cellRandomValues = new uint256[](totalCells);
        cellIndexes = new uint8[](totalCells);
        
        for (uint i = 0; i < totalCells; i++) {
            cellPayouts[i] = game.cellPayouts[i];
            cellRandomValues[i] = game.cellRandomValues[i];
            cellIndexes[i] = game.chosenCells[i];
        }
    }
}
