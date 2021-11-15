import { Contract, ContractFactory } from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, upgrades } from "hardhat";
import { addresses, contractConfig } from "../settings";

let owner: SignerWithAddress,
  admin: SignerWithAddress,
  operator: SignerWithAddress,
  user: SignerWithAddress;
let ownerAddress: string,
  adminAddress: string,
  operatorAddress: string,
  userAddress: string;
let dehubToken: Contract, DehubToken: ContractFactory;
let mockOracle: Contract, MockOracle: ContractFactory;
let prediction: Contract, Prediction: ContractFactory;

const BET_AMOUNT = ethers.utils.parseUnits("5000", 5);
const BET_AMOUNT_2 = ethers.utils.parseUnits("10000", 5);
const PRE_CLAIM_TOTAL_AMOUNT = ethers.utils.parseUnits("29999999985", "ether");
const TOTAL_AMOUNT = ethers.utils.parseUnits("29999999998.5", "ether");

const upgradeInstance = async (owner: any, addressV1: string) => {
  const DeHubPricePredictionV2 = await ethers.getContractFactory(
    "DeHubPricePredictionV2",
    owner
  );

  const predictionV2 = await upgrades.upgradeProxy(
    addressV1,
    DeHubPricePredictionV2
  );
  await predictionV2.upgradeToV2();
  return predictionV2;
};

describe("DeHubPricePrediction contract V1", function () {
  beforeEach(async () => {
    const signers = await ethers.getSigners();
    admin = signers[0];
    operator = signers[1];
    user = signers[2];

    adminAddress = await admin.getAddress();
    operatorAddress = await operator.getAddress();
    userAddress = await user.getAddress();

    // DehubToken = await ethers.getContractFactory("MockDeHub");
    DehubToken = await ethers.getContractFactory("MockERC20", admin);
    MockOracle = await ethers.getContractFactory("MockOracle");
    Prediction = await ethers.getContractFactory("DeHubPricePrediction");

    // dehubToken = await DehubToken.deploy();
    dehubToken = await DehubToken.deploy(
      "Dehub",
      "$Dehub",
      BigNumber.from("1000000000000")
    );
    await dehubToken.deployed();

    mockOracle = await MockOracle.deploy();
    await mockOracle.deployed();

    prediction = await upgrades.deployProxy(
      Prediction,
      [
        // addresses.mainnet.oracleBNBUSD,
        mockOracle.address,
        adminAddress,
        operatorAddress,
        contractConfig.mainnet.intervalBlocks,
        contractConfig.mainnet.bufferBlocks,
        contractConfig.mainnet.minBetAmount,
        contractConfig.mainnet.oracleUpdateAllowance,
        dehubToken.address,
      ],
      {
        kind: "uups",
        initializer: "__PricePrediction_init",
      }
    );
    await prediction.deployed();
    await dehubToken.transfer(userAddress, BET_AMOUNT_2);
  });

  describe("Upgradeability check.", function () {
    // Simulate the upgrade from V1 to V2.
    it("Should upgrade to V2.", async function () {
      // Check V1
      expect(await prediction.version()).to.equal(1);

      // Check V2
      prediction = await upgradeInstance(ownerAddress, prediction.address);
      expect(await prediction.version()).to.equal(2);
    });
  });

  describe.skip("Core functionality check.", async function () {
    it("Should Start Genesis Prediction", async function () {
      await prediction.connect(operator).genesisStartRound();
      await expect(prediction.connect(operator).genesisLockRound()).to.be
        .reverted;
      for (let i = 0; i < 100; i++) {
        ethers.provider.send("evm_mine", []);
      }
      await prediction.connect(operator).genesisLockRound();
    });
    it("Should Bet Successfully", async function () {
      await prediction.connect(operator).genesisStartRound();
      console.log(
        ethers.utils.formatUnits(await dehubToken.balanceOf(adminAddress), 5)
      );
      console.log(
        ethers.utils.formatUnits(await dehubToken.balanceOf(userAddress), 5)
      );
      await dehubToken.approve(
        prediction.address,
        await dehubToken.balanceOf(adminAddress)
      );
      await dehubToken
        .connect(user)
        .approve(prediction.address, await dehubToken.balanceOf(userAddress));

      await prediction.betBull(BET_AMOUNT);
      await prediction.connect(user).betBull(BET_AMOUNT_2);
      for (let i = 0; i < 100; i++) {
        ethers.provider.send("evm_mine", []);
      }
      await prediction.connect(operator).genesisLockRound();
      for (let i = 0; i < 100; i++) {
        ethers.provider.send("evm_mine", []);
      }
      await prediction.connect(operator).executeRound();
    });
    it("Should Claim Successfully", async function () {
      await prediction.connect(operator).genesisStartRound();
      await dehubToken.approve(
        prediction.address,
        await dehubToken.balanceOf(adminAddress)
      );
      await dehubToken
        .connect(user)
        .approve(prediction.address, await dehubToken.balanceOf(userAddress));

      await prediction.betBull(BET_AMOUNT);
      await prediction.connect(user).betBear(BET_AMOUNT_2);
      for (let i = 0; i < 100; i++) {
        ethers.provider.send("evm_mine", []);
      }
      await prediction.connect(operator).genesisLockRound();
      for (let i = 0; i < 100; i++) {
        ethers.provider.send("evm_mine", []);
      }
      await prediction.connect(operator).executeRound();
      expect(await prediction.claimable(1, userAddress)).to.equal(false);
      expect(await prediction.claimable(1, adminAddress)).to.equal(true);
      expect(await dehubToken.balanceOf(adminAddress)).to.equal(
        PRE_CLAIM_TOTAL_AMOUNT
      );
      await prediction.claim(1);
      expect(await dehubToken.balanceOf(adminAddress)).to.equal(TOTAL_AMOUNT);
    });
  });
});
