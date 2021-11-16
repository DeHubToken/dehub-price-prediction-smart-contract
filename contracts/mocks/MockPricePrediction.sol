// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "hardhat/console.sol";

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData(bool isLock)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

abstract contract DeHubPricePredictionUpgradeable is
  Initializable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  UUPSUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using AddressUpgradeable for address;

  uint256 public version;

  /// @custom:oz-upgrades-unsafe-allow constructor
  function initialize() public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
    __UUPSUpgradeable_init();
    version = 1;
    console.log("v", version);
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyOwner
  {}
}

contract MockPricePrediction is DeHubPricePredictionUpgradeable {
  using SafeMathUpgradeable for uint256;
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using AddressUpgradeable for address;

  struct Round {
    uint256 epoch;
    uint256 startBlock;
    uint256 lockBlock;
    uint256 endBlock;
    int256 lockPrice;
    int256 closePrice;
    uint256 totalAmount;
    uint256 bullAmount;
    uint256 bearAmount;
    uint256 rewardBaseCalAmount;
    uint256 rewardAmount;
    bool oracleCalled;
  }

  enum Position {
    Bull,
    Bear
  }

  struct BetInfo {
    Position position;
    uint256 amount;
    uint256 timestamp;
    bool claimed; // default false
  }

  mapping(uint256 => Round) public rounds;
  mapping(uint256 => mapping(address => BetInfo)) public ledger;
  mapping(address => uint256[]) public userRounds;
  uint256 public currentEpoch;
  uint256 public intervalBlocks;
  uint256 public bufferBlocks;
  address public adminAddress;
  address public operatorAddress;
  uint256 public treasuryAmount;
  AggregatorV3Interface internal oracle;
  uint256 public oracleLatestRoundId;

  uint256 public constant TOTAL_RATE = 100; // 100%
  uint256 public rewardRate;
  uint256 public treasuryRate;
  uint256 public minBetAmount;
  uint256 public oracleUpdateAllowance; // seconds

  bool public genesisStartOnce;
  bool public genesisLockOnce;

  IERC20Upgradeable public reserveToken;

  event StartRound(uint256 indexed epoch, uint256 blockNumber);
  event LockRound(uint256 indexed epoch, uint256 blockNumber, int256 price);
  event EndRound(uint256 indexed epoch, uint256 blockNumber, int256 price);
  event BetBull(
    address indexed sender,
    uint256 indexed currentEpoch,
    uint256 amount
  );
  event BetBear(
    address indexed sender,
    uint256 indexed currentEpoch,
    uint256 amount
  );
  event Claim(
    address indexed sender,
    uint256 indexed currentEpoch,
    uint256 amount
  );
  event ClaimTreasury(uint256 amount);
  event RatesUpdated(
    uint256 indexed epoch,
    uint256 rewardRate,
    uint256 treasuryRate
  );
  event MinBetAmountUpdated(uint256 indexed epoch, uint256 minBetAmount);
  event RewardsCalculated(
    uint256 indexed epoch,
    uint256 rewardBaseCalAmount,
    uint256 rewardAmount,
    uint256 treasuryAmount
  );
  event Pause(uint256 epoch);
  event Unpause(uint256 epoch);

  function __PricePrediction_init(
    AggregatorV3Interface _oracle,
    address _adminAddress,
    address _operatorAddress,
    uint256 _intervalBlocks,
    uint256 _bufferBlocks,
    uint256 _minBetAmount,
    uint256 _oracleUpdateAllowance,
    IERC20Upgradeable _reserveToken
  ) public initializer {
    DeHubPricePredictionUpgradeable.initialize();

    rewardRate = 90; // 90%
    treasuryRate = 10; // 10%
    genesisStartOnce = false;
    genesisLockOnce = false;

    oracle = _oracle;
    adminAddress = _adminAddress;
    operatorAddress = _operatorAddress;
    intervalBlocks = _intervalBlocks;
    bufferBlocks = _bufferBlocks;
    minBetAmount = _minBetAmount;
    oracleUpdateAllowance = _oracleUpdateAllowance;
    reserveToken = _reserveToken;
  }

  modifier onlyAdmin() {
    require(msg.sender == adminAddress, "PP: admin only function");
    _;
  }

  modifier onlyOperator() {
    require(msg.sender == operatorAddress, "PP: operator only function");
    _;
  }

  modifier onlyAdminOrOperator() {
    require(
      msg.sender == adminAddress || msg.sender == operatorAddress,
      "PP: admin | operator only"
    );
    _;
  }

  modifier notContract() {
    require(!msg.sender.isContract(), "Contract not allowed");
    _;
  }

  /**
   * @dev set admin address
   * callable by owner
   */
  function setAdmin(address _adminAddress) external onlyOwner {
    require(_adminAddress != address(0), "Cannot be zero address");
    adminAddress = _adminAddress;
  }

  /**
   * @dev set operator address
   * callable by admin
   */
  function setOperator(address _operatorAddress) external onlyAdmin {
    require(_operatorAddress != address(0), "Cannot be zero address");
    operatorAddress = _operatorAddress;
  }

  /**
   * @dev set interval blocks
   * callable by admin
   */
  function setIntervalBlocks(uint256 _intervalBlocks) external onlyAdmin {
    intervalBlocks = _intervalBlocks;
  }

  /**
   * @dev set buffer blocks
   * callable by admin
   */
  function setBufferBlocks(uint256 _bufferBlocks) external onlyAdmin {
    require(_bufferBlocks <= intervalBlocks, "Can't be > intervalBlocks");
    bufferBlocks = _bufferBlocks;
  }

  /**
   * @dev set Oracle address
   * callable by admin
   */
  function setOracle(address _oracle) external onlyAdmin {
    require(_oracle != address(0), "Can't be 0 addr");
    oracle = AggregatorV3Interface(_oracle);
  }

  /**
   * @dev set oracle update allowance
   * callable by admin
   */
  function setOracleUpdateAllowance(uint256 _oracleUpdateAllowance)
    external
    onlyAdmin
  {
    oracleUpdateAllowance = _oracleUpdateAllowance;
  }

  /**
   * @dev set reward rate
   * callable by admin
   */
  function setRewardRate(uint256 _rewardRate) external onlyAdmin {
    require(_rewardRate <= TOTAL_RATE, "rewardRate can't be > 100%");
    rewardRate = _rewardRate;
    treasuryRate = TOTAL_RATE.sub(_rewardRate);

    emit RatesUpdated(currentEpoch, rewardRate, treasuryRate);
  }

  /**
   * @dev set treasury rate
   * callable by admin
   */
  function setTreasuryRate(uint256 _treasuryRate) external onlyAdmin {
    require(_treasuryRate <= TOTAL_RATE, "treasuryRate can't be > 100%");
    rewardRate = TOTAL_RATE.sub(_treasuryRate);
    treasuryRate = _treasuryRate;

    emit RatesUpdated(currentEpoch, rewardRate, treasuryRate);
  }

  /**
   * @dev set minBetAmount
   * callable by admin
   */
  function setMinBetAmount(uint256 _minBetAmount) external onlyAdmin {
    minBetAmount = _minBetAmount;

    emit MinBetAmountUpdated(currentEpoch, minBetAmount);
  }

  /**
   * @dev Start genesis round
   */
  function genesisStartRound() external onlyOperator whenNotPaused {
    require(!genesisStartOnce, "Can only run once");

    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisStartOnce = true;
  }

  /**
   * @dev Lock genesis round
   */
  function genesisLockRound() external onlyOperator whenNotPaused {
    require(genesisStartOnce, "genesisStartRound not triggered");
    require(!genesisLockOnce, "Can only run once");
    require(
      block.number <= rounds[currentEpoch].lockBlock.add(bufferBlocks),
      "Not within bufferBlocks"
    );

    int256 currentPrice = _getPriceFromOracle(false);
    _safeLockRound(currentEpoch, currentPrice);

    currentEpoch = currentEpoch + 1;
    _startRound(currentEpoch);
    genesisLockOnce = true;
  }

  /**
   * @dev Start the next round n, lock price for round n-1, end round n-2
   */
  function executeRound() external onlyOperator whenNotPaused {
    require(
      genesisStartOnce && genesisLockOnce,
      "Genesis start/lock not triggered"
    );

    int256 currentPrice = _getPriceFromOracle(true);
    // CurrentEpoch refers to previous round (n-1)
    _safeLockRound(currentEpoch, currentPrice);
    _safeEndRound(currentEpoch - 1, currentPrice);
    _calculateRewards(currentEpoch - 1);

    // Increment currentEpoch to current round (n)
    currentEpoch = currentEpoch + 1;
    _safeStartRound(currentEpoch);
  }

  /**
   * @dev Bet bear position
   */
  function betBear(uint256 _amount)
    external
    payable
    whenNotPaused
    nonReentrant
    notContract
  {
    require(_bettable(currentEpoch), "Round not bettable");
    require(
      reserveToken.balanceOf(msg.sender) >= _amount,
      "Insuff. balance of reserveToken"
    );
    require(_amount >= minBetAmount, "Bet must be > minBetAmount");
    require(
      ledger[currentEpoch][msg.sender].amount == 0,
      "Can only bet once per round"
    );

    reserveToken.safeTransferFrom(msg.sender, address(this), _amount);

    // Update round data
    Round storage round = rounds[currentEpoch];
    round.totalAmount = round.totalAmount.add(_amount);
    round.bearAmount = round.bearAmount.add(_amount);

    // Update user data
    BetInfo storage betInfo = ledger[currentEpoch][msg.sender];
    betInfo.position = Position.Bear;
    betInfo.amount = _amount;
    betInfo.timestamp = block.timestamp;
    userRounds[msg.sender].push(currentEpoch);

    emit BetBear(msg.sender, currentEpoch, _amount);
  }

  /**
   * @dev Bet bull position
   */
  function betBull(uint256 _amount)
    external
    payable
    whenNotPaused
    nonReentrant
    notContract
  {
    require(_bettable(currentEpoch), "Round not bettable");
    require(
      reserveToken.balanceOf(msg.sender) >= _amount,
      "Insuff. balance of reserveToken"
    );
    require(_amount >= minBetAmount, "Bet must be > minBetAmount");
    require(
      ledger[currentEpoch][msg.sender].amount == 0,
      "Can only bet once per round"
    );

    reserveToken.safeTransferFrom(msg.sender, address(this), _amount);

    // Update round data
    Round storage round = rounds[currentEpoch];
    round.totalAmount = round.totalAmount.add(_amount);
    round.bullAmount = round.bullAmount.add(_amount);

    // Update user data
    BetInfo storage betInfo = ledger[currentEpoch][msg.sender];
    betInfo.position = Position.Bull;
    betInfo.amount = _amount;
    betInfo.timestamp = block.timestamp;
    userRounds[msg.sender].push(currentEpoch);

    emit BetBull(msg.sender, currentEpoch, _amount);
  }

  /**
   * @dev Claim reward
   */
  function claim(uint256 epoch) external notContract {
    require(rounds[epoch].startBlock != 0, "Round has not started");
    require(block.number > rounds[epoch].endBlock, "Round has not ended");
    require(!ledger[epoch][msg.sender].claimed, "Rewards claimed");

    uint256 reward;
    // Round valid, claim rewards
    if (rounds[epoch].oracleCalled) {
      require(claimable(epoch, msg.sender), "Not eligible for claim");
      Round memory round = rounds[epoch];
      reward = ledger[epoch][msg.sender].amount.mul(round.rewardAmount).div(
        round.rewardBaseCalAmount
      );
    }
    // Round invalid, refund bet amount
    else {
      require(refundable(epoch, msg.sender), "Not eligible for refund");
      reward = ledger[epoch][msg.sender].amount;
    }

    BetInfo storage betInfo = ledger[epoch][msg.sender];
    betInfo.claimed = true;
    _safeTransferreserveToken(address(msg.sender), reward);

    emit Claim(msg.sender, epoch, reward);
  }

  /**
   * @dev Claim all rewards in treasury
   * callable by admin
   */
  function claimTreasury() external onlyAdmin {
    uint256 currentTreasuryAmount = treasuryAmount;
    treasuryAmount = 0;
    _safeTransferreserveToken(adminAddress, currentTreasuryAmount);

    emit ClaimTreasury(currentTreasuryAmount);
  }

  /**
   * @dev Return the total number of rounds a user has entered
   */
  function getTotalUserRounds(address user) external view returns (uint256) {
    return userRounds[user].length;
  }

  /**
   * @dev Return round epochs that a user has participated
   */
  function getUserRounds(
    address user,
    uint256 cursor,
    uint256 size
  ) external view returns (uint256[] memory, uint256) {
    uint256 length = size;
    if (length > userRounds[user].length - cursor) {
      length = userRounds[user].length - cursor;
    }

    uint256[] memory values = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
      values[i] = userRounds[user][cursor + i];
    }

    return (values, cursor + length);
  }

  /**
   * @dev called by the admin to pause, triggers stopped state
   */
  function pause() public onlyAdminOrOperator whenNotPaused {
    _pause();

    emit Pause(currentEpoch);
  }

  /**
   * @dev called by the admin to unpause, returns to normal state
   * Reset genesis state. Once paused, the rounds would need to be kickstarted by genesis
   */
  function unpause() public onlyAdmin whenPaused {
    genesisStartOnce = false;
    genesisLockOnce = false;
    _unpause();

    emit Unpause(currentEpoch);
  }

  /**
   * @dev Get the claimable stats of specific epoch and user account
   */
  function claimable(uint256 epoch, address user) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch][user];
    Round memory round = rounds[epoch];
    if (round.lockPrice == round.closePrice) {
      return false;
    }
    return
      round.oracleCalled &&
      ((round.closePrice > round.lockPrice &&
        betInfo.position == Position.Bull) ||
        (round.closePrice < round.lockPrice &&
          betInfo.position == Position.Bear));
  }

  /**
   * @dev Get the refundable stats of specific epoch and user account
   */
  function refundable(uint256 epoch, address user) public view returns (bool) {
    BetInfo memory betInfo = ledger[epoch][user];
    Round memory round = rounds[epoch];
    return
      !round.oracleCalled &&
      block.number > round.endBlock.add(bufferBlocks) &&
      betInfo.amount != 0;
  }

  /**
   * @dev Start round
   * Previous round n-2 must end
   */
  function _safeStartRound(uint256 epoch) internal {
    require(genesisStartOnce, "genesisStartRound not triggered");
    require(rounds[epoch - 2].endBlock != 0, "Round n-2 not ended");
    require(
      block.number >= rounds[epoch - 2].endBlock,
      "Round n-2 not endBlock"
    );
    _startRound(epoch);
  }

  function _startRound(uint256 epoch) internal {
    Round storage round = rounds[epoch];
    round.startBlock = block.number;
    round.lockBlock = block.number.add(intervalBlocks);
    round.endBlock = block.number.add(intervalBlocks * 2);
    round.epoch = epoch;
    round.totalAmount = 0;

    emit StartRound(epoch, block.number);
  }

  /**
   * @dev Lock round
   */
  function _safeLockRound(uint256 epoch, int256 price) internal {
    require(rounds[epoch].startBlock != 0, "Round not started");
    require(block.number >= rounds[epoch].lockBlock, "Round not lockBlock");
    require(
      block.number <= rounds[epoch].lockBlock.add(bufferBlocks),
      "Round not within bufferBlocks"
    );
    _lockRound(epoch, price);
  }

  function _lockRound(uint256 epoch, int256 price) internal {
    Round storage round = rounds[epoch];
    round.lockPrice = price;

    emit LockRound(epoch, block.number, round.lockPrice);
  }

  /**
   * @dev End round
   */
  function _safeEndRound(uint256 epoch, int256 price) internal {
    require(rounds[epoch].lockBlock != 0, "Round not locked");
    require(block.number >= rounds[epoch].endBlock, "Round not endBlock");
    require(
      block.number <= rounds[epoch].endBlock.add(bufferBlocks),
      "Round not within bufferBlocks"
    );
    _endRound(epoch, price);
  }

  function _endRound(uint256 epoch, int256 price) internal {
    Round storage round = rounds[epoch];
    round.closePrice = price;
    round.oracleCalled = true;

    emit EndRound(epoch, block.number, round.closePrice);
  }

  /**
   * @dev Calculate rewards for round
   */
  function _calculateRewards(uint256 epoch) internal {
    require(
      rewardRate.add(treasuryRate) == TOTAL_RATE,
      "Reward + treasury != TOTAL_RATE"
    );
    require(
      rounds[epoch].rewardBaseCalAmount == 0 && rounds[epoch].rewardAmount == 0,
      "Rewards calculated"
    );
    Round storage round = rounds[epoch];
    uint256 rewardBaseCalAmount;
    uint256 rewardAmount;
    uint256 treasuryAmt;
    // Bull wins
    if (round.closePrice > round.lockPrice) {
      rewardBaseCalAmount = round.bullAmount;
      rewardAmount = round.totalAmount.mul(rewardRate).div(TOTAL_RATE);
      treasuryAmt = round.totalAmount.mul(treasuryRate).div(TOTAL_RATE);
    }
    // Bear wins
    else if (round.closePrice < round.lockPrice) {
      rewardBaseCalAmount = round.bearAmount;
      rewardAmount = round.totalAmount.mul(rewardRate).div(TOTAL_RATE);
      treasuryAmt = round.totalAmount.mul(treasuryRate).div(TOTAL_RATE);
    }
    // House wins
    else {
      rewardBaseCalAmount = 0;
      rewardAmount = 0;
      treasuryAmt = round.totalAmount;
    }
    round.rewardBaseCalAmount = rewardBaseCalAmount;
    round.rewardAmount = rewardAmount;

    // Add to treasury
    treasuryAmount = treasuryAmount.add(treasuryAmt);

    emit RewardsCalculated(
      epoch,
      rewardBaseCalAmount,
      rewardAmount,
      treasuryAmt
    );
  }

  /**
   * @dev Get latest recorded price from oracle
   * If it falls below allowed buffer or has not updated, it would be invalid
   */
  function _getPriceFromOracle(bool isLock) internal returns (int256) {
    uint256 leastAllowedTimestamp = block.timestamp.add(oracleUpdateAllowance);
    (uint80 roundId, int256 price, , uint256 timestamp, ) = oracle
      .latestRoundData(isLock);
    require(
      timestamp <= leastAllowedTimestamp,
      "Oracle update exceeded max time"
    );
    require(roundId > oracleLatestRoundId, "roundId must be > latest id");
    oracleLatestRoundId = uint256(roundId);
    return price;
  }

  function _safeTransferreserveToken(address to, uint256 value) internal {
    reserveToken.safeTransfer(to, value);
  }

  /**
   * @dev Determine if a round is valid for receiving bets
   * Round must have started and locked
   * Current block must be within startBlock and endBlock
   */
  function _bettable(uint256 epoch) internal view returns (bool) {
    return
      rounds[epoch].startBlock != 0 &&
      rounds[epoch].lockBlock != 0 &&
      block.number > rounds[epoch].startBlock &&
      block.number < rounds[epoch].lockBlock;
  }
}
