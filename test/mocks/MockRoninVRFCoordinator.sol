// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../src/interfaces/IRoninVRFCoordinatorForConsumers.sol";
import "../../src/consumer/VRFConsumer.sol";

contract MockRoninVRFCoordinator is IRoninVRFCoordinatorForConsumers {
    uint256 private constant BASE_FEE = 0.01 ether; // 0.01 RON service charge
    uint256 private nonce = 0;
    
    mapping(bytes32 => bool) public pendingRequests;
    
    event RandomSeedRequested(
        bytes32 indexed requestHash,
        uint256 callbackGasLimit,
        uint256 gasPrice,
        address consumer,
        address refundAddress
    );
    
    event RandomSeedFulfilled(bytes32 indexed requestHash, uint256 randomSeed);

    function requestRandomSeed(
        uint256 _callbackGasLimit,
        uint256 _gasPrice,
        address _consumer,
        address _refundAddress
    ) external payable override returns (bytes32 _reqHash) {
        require(msg.value >= this.estimateRequestRandomFee(_callbackGasLimit, _gasPrice), "Insufficient fee");
        
        _reqHash = keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            nonce++
        ));
        
        pendingRequests[_reqHash] = true;
        
        emit RandomSeedRequested(_reqHash, _callbackGasLimit, _gasPrice, _consumer, _refundAddress);
        
        return _reqHash;
    }

    function estimateRequestRandomFee(uint256 _callbackGasLimit, uint256 _gasPrice) 
        external 
        pure 
        override 
        returns (uint256) 
    {
        uint256 fulfillmentGasFee = _gasPrice * (_callbackGasLimit + 500000);
        return BASE_FEE + fulfillmentGasFee;
    }
    
    // Test helper function to fulfill requests
    function fulfillRandomSeed(bytes32 _reqHash, uint256 _randomSeed, address _consumer) external {
        require(pendingRequests[_reqHash], "Request not found");
        
        pendingRequests[_reqHash] = false;
        
        VRFConsumer(_consumer).rawFulfillRandomSeed(_reqHash, _randomSeed);
        
        emit RandomSeedFulfilled(_reqHash, _randomSeed);
    }
    
    // Test helper to fulfill with a deterministic seed
    function fulfillRandomSeedWithSeed(bytes32 _reqHash, address _consumer, uint256 _seed) external {
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(_seed, block.timestamp, _reqHash)));
        this.fulfillRandomSeed(_reqHash, randomSeed, _consumer);
    }
} 