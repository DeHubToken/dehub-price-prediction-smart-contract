import { ethers } from "ethers";

export const addresses = {
  mainnet: {
    dehub: "0xFC206f429d55c71cb7294EfF40c6ADb20dC21508",
    oracleBNBUSD: "0x0567f2323251f0aab15c8dfb1967e4e8a7d42aee",
  },
  testnet: {
    dehub: "0x5A5e32fE118E7c7b6536d143F446269123c0ba74",
    oracleBNBUSD: "0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526",
  },
};

export const contractConfig = {
  mainnet: {
    intervalBlocks: 100,
    bufferBlocks: 20,
    minBetAmount: ethers.utils.parseUnits("1000", 5),
    oracleUpdateAllowance: 300,
  },
  testnet: {
    intervalBlocks: 100,
    bufferBlocks: 20,
    minBetAmount: ethers.utils.parseUnits("1000", 5),
    oracleUpdateAllowance: 300,
  },
};

export const amounts = {
  oneBNB: ethers.utils.parseEther("1.00"),
  fortyFiveBNB: ethers.utils.parseEther("45.00"),
  tenMillionDeHub: ethers.utils.parseUnits("10000000", 5),
};
