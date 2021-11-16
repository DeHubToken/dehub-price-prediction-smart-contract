//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDEHUB.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev THIS CONTRACT IS FOR TESTING PURPOSES ONLY.
 */
contract MockDeHub is IDEHUB, Ownable {
  mapping(address => bool) public override specialAddresses;
  address public override deadAddr = 0x000000000000000000000000000000000000dEaD;
  struct LimitExemptions {
    bool all;
    bool transaction;
    bool wallet;
    bool sell;
    bool fees;
  }
  mapping(address => LimitExemptions) internal limitExemptions;
  address internal uniswapV2Pair;

  // FAKE only for testing
  mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) private _allowances;

  constructor() IDEHUB() {
    // Set special addresses
    specialAddresses[owner()] = true;
    specialAddresses[address(this)] = true;
    specialAddresses[deadAddr] = true;
    // Set limit exemptions
    LimitExemptions memory exemptions;
    exemptions.all = true;
    limitExemptions[owner()] = exemptions;
    limitExemptions[address(this)] = exemptions;

    balances[owner()] = 800000000000000;
  }

  receive() external payable {}

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    balances[msg.sender] -= amount;
    balances[recipient] += amount;
    return true;
  }

  /**
   * @dev Just for testing purposes we can set pair address manually
   */
  function setMockPairAddress(address pair) external {
    require(pair != address(0), "Can't be 0 address.");
    uniswapV2Pair = pair;
    transfer(pair, 14321905408238);
  }

  /* ----------------- THESE ARE JUST TO SILENCE THE COMPILER ----------------- */

  function balanceOf(address account) external view override returns (uint256) {
    return balances[account];
  }

  function totalCirculatingSupply() external pure override returns (uint256) {
    // Returns static number, for testing
    return 399280549791206;
  }

  function approve(address spender, uint256 amount)
    external
    override
    returns (bool)
  {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
  }
}
