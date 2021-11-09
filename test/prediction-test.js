const { expect } = require("chai");
const env = require("hardhat");

let mock, Mock;
let mockOracle, MockOracle;
let prediction, Prediction;

const BET_AMOUNT = ethers.utils.parseUnits("5", "ether");
const BET_AMOUNT_2 = ethers.utils.parseUnits("10", "ether");
const PRE_CLAIM_TOTAL_AMOUNT = ethers.utils.parseUnits("29999999985", "ether");
const TOTAL_AMOUNT = ethers.utils.parseUnits("29999999998.5", "ether");

describe("PricePrediction", function() {
  beforeEach(async function () {
    accounts = await ethers.getSigners();
    admin = accounts[0];
    operator = accounts[1];
    user = accounts[2];

    adminAddress = await admin.getAddress();
    operatorAddress = await operator.getAddress();
    userAddress = await user.getAddress();

    Mock = await ethers.getContractFactory('MockBEP20');
    mock = await Mock.deploy();
    await mock.deployed();

    MockOracle = await ethers.getContractFactory('MockOracle');
    mockOracle = await MockOracle.deploy();
    await mockOracle.deployed();

    Prediction = await ethers.getContractFactory('MockBNBPricePrediction');
    prediction = await Prediction.deploy(
      mockOracle.address, //_oracle 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
      adminAddress,                                 //_adminAddress
      operatorAddress,                              //_operatorAddress
      "100",                                        //_intervalBlocks
      "20",                                         //_bufferBlocks
      "1000000000000000",                           //_minBetAmount
      "300",                                        //_oracleUpdateAllowance
      mock.address,                                 //_BUSD
    );
    await prediction.deployed();
    await mock.transfer(userAddress, BET_AMOUNT_2);
  });
  it("Should Start Genesis Prediction", async function() {
    await prediction.connect(operator).genesisStartRound();
    await expect(prediction.connect(operator).genesisLockRound()).to.be.reverted;
    for (i = 0; i < 100; i++) {
      ethers.provider.send("evm_mine");
    }
    await prediction.connect(operator).genesisLockRound();
  });
  it("Should Bet Successfully", async function() {
    await prediction.connect(operator).genesisStartRound();
    await mock.approve(prediction.address, await mock.balanceOf(adminAddress));
    await mock.connect(user).approve(prediction.address, await mock.balanceOf(userAddress));

    await prediction.betBull(BET_AMOUNT);
    await prediction.connect(user).betBull(BET_AMOUNT_2);
    for (i = 0; i < 100; i++) {
      ethers.provider.send("evm_mine");
    }
    await prediction.connect(operator).genesisLockRound();
    for (i = 0; i < 100; i++) {
      ethers.provider.send("evm_mine");
    }
    await prediction.connect(operator).executeRound();
  });
  it("Should Claim Successfully", async function() {
    await prediction.connect(operator).genesisStartRound();
    await mock.approve(prediction.address, await mock.balanceOf(adminAddress));
    await mock.connect(user).approve(prediction.address, await mock.balanceOf(userAddress));

    await prediction.betBull(BET_AMOUNT);
    await prediction.connect(user).betBear(BET_AMOUNT_2);
    for (i = 0; i < 100; i++) {
      ethers.provider.send("evm_mine");
    }
    await prediction.connect(operator).genesisLockRound();
    for (i = 0; i < 100; i++) {
      ethers.provider.send("evm_mine");
    }
    await prediction.connect(operator).executeRound();
    expect(await prediction.claimable(1, userAddress)).to.equal(false);
    expect(await prediction.claimable(1, adminAddress)).to.equal(true);
    expect(await mock.balanceOf(adminAddress)).to.equal(PRE_CLAIM_TOTAL_AMOUNT);
    await prediction.claim(1);
    expect(await mock.balanceOf(adminAddress)).to.equal(TOTAL_AMOUNT);
  });
});
