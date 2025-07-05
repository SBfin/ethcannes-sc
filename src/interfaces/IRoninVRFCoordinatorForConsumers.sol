// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoninVRFCoordinatorForConsumers {
  /**
   * @dev Request random seed to the coordinator contract. Returns the request hash.
   *  Consider using the method `estimateRequestRandomFee` to estimate the random fee.
   *
   * @param _callbackGasLimit The callback gas amount.
   * @param _gasPrice The gas price that oracle must send transaction to fulfill.
   * @param _consumer The consumer address to callback.
   * @param _refundAddress Refund address if there is RON left after paying gas fee to oracle.
   */
  function requestRandomSeed(
    uint256 _callbackGasLimit,
    uint256 _gasPrice,
    address _consumer,
    address _refundAddress
  ) external payable returns (bytes32 _reqHash);

  /**
   * @dev Estimates the request random fee in RON.
   *
   * @notice It should be larger than the real cost and the contract will refund if any.
   */
  function estimateRequestRandomFee(uint256 _callbackGasLimit, uint256 _gasPrice) external view returns (uint256);
} 