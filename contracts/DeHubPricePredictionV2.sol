// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./DeHubPricePrediction.sol";
import "hardhat/console.sol";

/**
 * @dev V2 upgrade template. Use this if update is needed in the future.
 */
contract DeHubPricePredictionV2 is DeHubPricePrediction {
  /**
   * @dev Must call this jsut after the upgrade deployement, to update state
   * variables and execute other upgrade logic.
   * Ref: https://github.com/OpenZeppelin/openzeppelin-upgrades/issues/62
   */
  function upgradeToV2() public {
    require(version < 2, "StandardLottery: Already upgraded to version 2");
    version = 2;
    console.log("v", version);
  }
}
