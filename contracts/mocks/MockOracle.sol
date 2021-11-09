pragma solidity 0.6.12;

contract MockOracle {
    uint80 public roundId;
    constructor() public {}

    function latestRoundData(bool isLock) public returns(uint80, int256, uint256, uint256, uint80) {
      int256 price = isLock ? 2 ether : 1 ether;
      uint80 thisRound = isLock ? roundId + 2 : roundId + 1;
      return (thisRound, price, block.timestamp, block.timestamp, roundId);
    }
}