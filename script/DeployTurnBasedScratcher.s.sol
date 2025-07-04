// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TurnBasedScratcher} from "../src/TurnScratcher.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DeployTurnBasedScratcher is Script {
    
    function run() external {
        // Get chain parameter from environment or auto-detect
        string memory targetChain = "RONIN";
        
        console.log("=== TurnBasedScratcher Deployment ===");
        console.log("Target Chain:", targetChain);
        
        // Read chain-specific environment variables
        string memory usdTokenKey = string.concat(targetChain, "_ADDRESS_USD");
        string memory vrfCoordinatorKey = string.concat(targetChain, "_VRF_COORDINATOR");
        string memory subscriptionIdKey = string.concat(targetChain, "_SUBSCRIPTION_ID");
        string memory keyHashKey = string.concat(targetChain, "_KEY_HASH");
        
        address usdToken = vm.envAddress(usdTokenKey);
        address vrfCoordinator = vm.envAddress(vrfCoordinatorKey);
        uint256 subscriptionId = vm.envUint(subscriptionIdKey);
        bytes32 keyHash = vm.envBytes32(keyHashKey);
        
        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Validate required environment variables
        require(usdToken != address(0), string.concat(usdTokenKey, " not set in environment"));
        require(vrfCoordinator != address(0), string.concat(vrfCoordinatorKey, " not set in environment"));
        require(subscriptionId != 0, string.concat(subscriptionIdKey, " not set in environment"));
        require(keyHash != bytes32(0), string.concat(keyHashKey, " not set in environment"));
        
        console.log("Deployer:", deployer);
        console.log("USDC Token:", usdToken);
        console.log("VRF Coordinator:", vrfCoordinator);
        console.log("Subscription ID:", subscriptionId);
        console.log("Key Hash:", vm.toString(keyHash));
        
        // Check deployer ETH balance
        uint256 ethBalance = deployer.balance;
        console.log("Deployer ETH Balance:", ethBalance / 1e18, "ETH");
        
        if (ethBalance < 0.01 ether) {
            console.log("WARNING: Low ETH balance for deployment and gas fees!");
        }
        
        // Determine token decimals based on chain
        uint256 tokenDecimals;
        string memory tokenName;
        if (keccak256(abi.encodePacked(targetChain)) == keccak256(abi.encodePacked("BSC"))) {
            tokenDecimals = 18; // USDT on BSC has 18 decimals
            tokenName = "USDT";
        } else {
            tokenDecimals = 6; // USDC on BASE has 6 decimals
            tokenName = "USDC";
        }
        
        console.log("Token:", tokenName);
        console.log("Token decimals:", tokenDecimals);
        
        // Check deployer token balance
        IERC20 usd = IERC20(usdToken);
        //uint256 usdBalance = usd.balanceOf(deployer);
        //console.log("Deployer", tokenName, "Balance:", usdBalance / (10**tokenDecimals), tokenName);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the TurnBasedScratcher contract
        TurnBasedScratcher scratcher = new TurnBasedScratcher(
            usdToken,
            vrfCoordinator,
            subscriptionId,
            keyHash
        );
        
        console.log("\n=== Deployment Successful! ===");
        console.log("TurnBasedScratcher deployed to:", address(scratcher));
        console.log("Contract Owner:", scratcher.owner());
        console.log("House:", scratcher.house());
        console.log("Token address:", address(scratcher.usdc()));
        console.log("Game fee:", scratcher.gameFee() / (10**tokenDecimals), tokenName);
        
        // Add initial liquidity if specified and deployer has tokens
        uint256 initialLiquidity = 10 * (10**tokenDecimals); // 10 tokens with correct decimals
        
        // SKIP LIQUIDITY ADDITION FOR NOW - BSC USDT CONTRACT HAS ISSUES
        console.log("\n=== Skipping Liquidity Addition ===");
        console.log("BSC USDT contract has approve() issues - deploying without initial liquidity");
        console.log("You can add liquidity manually after deployment");
        
        /*
        if (initialLiquidity > 0) {
            console.log("\n=== Adding Initial Liquidity ===");
            console.log("Adding liquidity:", initialLiquidity / (10**tokenDecimals), tokenName);
            
            // First approve token spending
            usd.approve(address(scratcher), 0);
            usd.approve(address(scratcher), initialLiquidity);
            console.log(tokenName, "approved for liquidity addition");
            
            // Transfer tokens to contract
            usd.transfer(address(scratcher), initialLiquidity);
            console.log("Initial liquidity transferred to contract");
            
            // Check final balance
            uint256 contractBalance = usd.balanceOf(address(scratcher));
            console.log("Contract", tokenName, "balance:", contractBalance / (10**tokenDecimals), tokenName);
        } else if (initialLiquidity > 0) {
            console.log("\n=== No Initial Liquidity Added ===");
            console.log("Required:", initialLiquidity / (10**tokenDecimals), tokenName);
        }
        */
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Final deployment info
        console.log("\n=== Deployment Summary ===");
        console.log("Contract: TurnBasedScratcher");
        console.log("Address:", address(scratcher));
        console.log(tokenName, "Token:", usdToken);
        console.log("VRF Coordinator:", vrfCoordinator);
        console.log("Subscription ID:", subscriptionId);
        console.log("Key Hash:", vm.toString(keyHash));
        console.log("Game Fee: 1", tokenName);
        
        console.log("\n=== Game Mechanics ===");
        console.log("- Players pay 1", tokenName, "to start a game");
        console.log("- Each game has 3 rounds of 3 cells each");
        console.log("- Chainlink VRF provides randomness for payouts");
        console.log("- House can make offers during negotiation phases");
        console.log("- Players can accept offers or continue to final payout");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Update frontend contract address to:", address(scratcher));
        console.log("2. Verify contract on Basescan");
        console.log("3. Add contract as VRF consumer in Chainlink subscription");
        console.log("4. Test with small amounts first");
        console.log("5. Monitor game activity and contract balance");
        
        console.log("\n=== VRF Configuration ===");
        console.log("- Subscription ID:", subscriptionId);
        console.log("- Request confirmations: 3 blocks");
        console.log("- Callback gas limit: 200,000");
        console.log("- Words per round: 3");
        console.log("- Native payment: true");
        
        console.log("\n=== Frontend Update Required ===");
        console.log("Update your frontend config with new contract address:");
        console.log("NEW:", address(scratcher));
    }

} 

