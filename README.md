Gas used: 2249500

== Logs ==
  === TurnBasedScratcher Deployment ===
  Target Chain: RONIN
  Deployer: 0x6786B1148E0377BEFe86fF46cc073dE96B987FE4
  USDC Token: 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
  VRF Coordinator: 0x16A62a921e7fEC5Bf867fF5c805b662Db757B778
  Deployer ETH Balance: 0 ETH
  WARNING: Low ETH balance for deployment and gas fees!
  Token: USDC
  Token decimals: 6
  
=== Deployment Successful! ===
  TurnBasedScratcher deployed to: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
  Contract Owner: 0x6786B1148E0377BEFe86fF46cc073dE96B987FE4
  House: 0x6786B1148E0377BEFe86fF46cc073dE96B987FE4
  Token address: 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
  Game fee: 1 USDC
  
=== Skipping Liquidity Addition ===
  BSC USDT contract has approve() issues - deploying without initial liquidity
  You can add liquidity manually after deployment
  
=== Deployment Summary ===
  Contract: TurnBasedScratcher
  Address: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
  USDC Token: 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
  VRF Coordinator: 0x16A62a921e7fEC5Bf867fF5c805b662Db757B778
  Game Fee: 1 USDC
  
=== Game Mechanics ===
  - Players pay 1 USDC to start a game
  - Each game has 3 rounds of 3 cells each
  - Ronin VRF provides randomness for payouts
  - House can make offers during negotiation phases
  - Players can accept offers or continue to final payout
  
=== Next Steps ===
  1. Update frontend contract address to: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
  2. Verify contract on Ronin Explorer
  3. Fund contract with RON for VRF fees
  4. Test with small amounts first
  5. Monitor game activity and contract balance
  
=== VRF Configuration ===
  - Service: Ronin VRF
  - Callback gas limit: 500,000
  - Service charge: 0.01 USD in RON
  - Native payment: RON
  
=== Frontend Update Required ===
  Update your frontend config with new contract address:
  NEW: 0xA5a2250b0170bdb9bd0904C0440717f00A506023

If you wish to simulate on-chain transactions pass a RPC URL.
zsh: no such file or directory: https://api.roninchain.com/rpc
zsh: command not found: --broadcast
(base) silviobusonero@Silvios-MacBook-Air smart-contracts % echo $RONIN_RPC
https://api.roninchain.com/rpc
(base) silviobusonero@Silvios-MacBook-Air smart-contracts % forge script script/DeployTurnBasedScratcher.s.sol:DeployTurnBasedScratcher \
  --rpc-url https://api.roninchain.com/rpc \
  --broadcast
[⠊] Compiling...
No files changed, compilation skipped
Warning: EIP-3855 is not supported in one or more of the RPCs used.
Unsupported Chain IDs: 2020.
Contracts deployed with a Solidity version equal or higher than 0.8.20 might not work properly.
For more information, please see https://eips.ethereum.org/EIPS/eip-3855
Script ran successfully.

== Logs ==
  === TurnBasedScratcher Deployment ===
  Target Chain: RONIN
  Deployer: 0x6786B1148E0377BEFe86fF46cc073dE96B987FE4
  USDC Token: 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
  VRF Coordinator: 0x16A62a921e7fEC5Bf867fF5c805b662Db757B778
  Deployer ETH Balance: 1 ETH
  Token: USDC
  Token decimals: 6
  
=== Deployment Successful! ===
  TurnBasedScratcher deployed to: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
  Contract Owner: 0x6786B1148E0377BEFe86fF46cc073dE96B987FE4
  House: 0x6786B1148E0377BEFe86fF46cc073dE96B987FE4
  Token address: 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
  Game fee: 1 USDC
  
=== Skipping Liquidity Addition ===
  BSC USDT contract has approve() issues - deploying without initial liquidity
  You can add liquidity manually after deployment
  
=== Deployment Summary ===
  Contract: TurnBasedScratcher
  Address: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
  USDC Token: 0x0B7007c13325C48911F73A2daD5FA5dCBf808aDc
  VRF Coordinator: 0x16A62a921e7fEC5Bf867fF5c805b662Db757B778
  Game Fee: 1 USDC
  
=== Game Mechanics ===
  - Players pay 1 USDC to start a game
  - Each game has 3 rounds of 3 cells each
  - Ronin VRF provides randomness for payouts
  - House can make offers during negotiation phases
  - Players can accept offers or continue to final payout
  
=== Next Steps ===
  1. Update frontend contract address to: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
  2. Verify contract on Ronin Explorer
  3. Fund contract with RON for VRF fees
  4. Test with small amounts first
  5. Monitor game activity and contract balance
  
=== VRF Configuration ===
  - Service: Ronin VRF
  - Callback gas limit: 500,000
  - Service charge: 0.01 USD in RON
  - Native payment: RON
  
=== Frontend Update Required ===
  Update your frontend config with new contract address:
  NEW: 0xA5a2250b0170bdb9bd0904C0440717f00A506023

## Setting up 1 EVM.

==========================

Chain 2020

Estimated gas price: 21 gwei

Estimated total gas used for script: 3082822

Estimated amount required: 0.064739262 ETH

==========================

##### ronin
✅  [Success] Hash: 0x809625ba0fbffea4b188db1dabcb576330fa5b4f939c98c0efad9c7f5e38951d
Contract Address: 0xA5a2250b0170bdb9bd0904C0440717f00A506023
Block: 46600387
Paid: 0.049799442 ETH (2371402 gas * 21 gwei)

✅ Sequence #1 on ronin | Total Paid: 0.049799442 ETH (2371402 gas * avg 21 gwei)
                                                                            

==========================
