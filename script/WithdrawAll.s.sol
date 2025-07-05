// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TurnBasedScratcher} from "../src/TurnScratcher.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract WithdrawAll is Script {
    // Base network USDC contract address
    address constant BASE_USDC = 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc;
    
    // Your deployed TurnBasedScratcher contract address
    address payable constant SCRATCHER_CONTRACT = payable(0xA5a2250b0170bdb9bd0904C0440717f00A506023);
    
    function run() external {
        // Get private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Contract Balance Check ===");
        console.log("Contract Address:", SCRATCHER_CONTRACT);
        console.log("USDC Token:", BASE_USDC);
        console.log("Deployer Address:", deployer);
        
        // Get contract instance
        TurnBasedScratcher scratcher = TurnBasedScratcher(SCRATCHER_CONTRACT);
        IERC20 usdc = IERC20(BASE_USDC);
        
        // Check contract owner
        address contractOwner = scratcher.owner();
        console.log("Contract Owner:", contractOwner);
        console.log("Is Deployer Owner?", contractOwner == deployer);
        
        if (contractOwner != deployer) {
            console.log("ERROR: Deployer is not the contract owner!");
            console.log("Only the owner can withdraw funds.");
            return;
        }
        
        // Check USDC balance
        uint256 usdcBalance = usdc.balanceOf(SCRATCHER_CONTRACT);
        uint8 decimals = usdc.decimals();
        string memory symbol = usdc.symbol();
        
        console.log("\n=== Current Balances ===");
        console.log("Contract USDC Balance (raw):", usdcBalance);
        console.log("Contract USDC Balance (formatted):", usdcBalance / 10**decimals, symbol);
        
        if (usdcBalance == 0) {
            console.log("No USDC to withdraw!");
            return;
        }
        
        // Check ETH balance for gas
        uint256 ethBalance = deployer.balance;
        console.log("Deployer ETH Balance:", ethBalance / 1e18, "ETH");
        
        if (ethBalance < 0.001 ether) {
            console.log("WARNING: Low ETH balance for gas fees!");
        }
        
        console.log("\n=== Withdrawing All Funds ===");
        console.log("Amount to withdraw:", usdcBalance / 10**decimals, symbol);
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Withdraw all USDC
        scratcher.withdraw(usdcBalance);
        console.log(" Withdrawal transaction sent!");
        
        vm.stopBroadcast();
        
        // Check balances after withdrawal
        uint256 newUsdcBalance = usdc.balanceOf(SCRATCHER_CONTRACT);
        uint256 ownerUsdcBalance = usdc.balanceOf(deployer);
        
        console.log("\n=== Post-Withdrawal Balances ===");
        console.log("Contract USDC Balance:", newUsdcBalance / 10**decimals, symbol);
        console.log("Owner USDC Balance:", ownerUsdcBalance / 10**decimals, symbol);
        
        if (newUsdcBalance == 0) {
            console.log(" All funds successfully withdrawn!");
        } else {
            console.log("Some funds remain in contract");
        }
        
        console.log("\n=== Summary ===");
        console.log("Withdrawn Amount:", (usdcBalance - newUsdcBalance) / 10**decimals, symbol);
        console.log("Transaction completed successfully!");
    }
} 