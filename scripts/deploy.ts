import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import hre, { ethers, network, upgrades } from "hardhat";
import { NomicLabsHardhatPluginError } from "hardhat/plugins";
import { addresses, contractConfig } from "../settings";

async function main() {
  const signers = await ethers.getSigners();
  let deployer: SignerWithAddress | undefined;
  let admin: SignerWithAddress | undefined;
  let operator: SignerWithAddress | undefined;
  let implAddr: string | undefined;

  // Check if necessary addresses provided in env
  signers.forEach((a) => {
    if (a.address === process.env.DEPLOYER001) {
      deployer = a;
    }
    if (a.address === process.env.ADMIN_ADDRESS) {
      admin = a;
    }
    if (a.address === process.env.OPERATOR_ADDRESS) {
      operator = a;
    }
  });
  if (!deployer) {
    throw new Error(`${process.env.DEPLOYER001} not found in signers!`);
  }
  if (!admin) {
    throw new Error(`${process.env.ADMIN_ADDRESS} not found in signers!`);
  }
  if (!operator) {
    throw new Error(`${process.env.OPERATOR_ADDRESS} not found in signers!`);
  }

  console.log("Deploying contract with the account:", deployer.address);
  console.log("Network:", network.name);

  // Quit if networks are not supported
  if (network.name !== "testnet" && network.name !== "mainnet") {
    console.log("Network name is not supported");
    return;
  }

  // Deploy contract
  const Prediction = await ethers.getContractFactory("DeHubPricePrediction");
  const prediction = await upgrades.deployProxy(
    Prediction,
    [
      addresses[network.name].oracleBNBUSD,
      process.env.ADMIN_ADDRESS,
      process.env.OPERATOR_ADDRESS,
      contractConfig[network.name].intervalBlocks,
      contractConfig[network.name].bufferBlocks,
      contractConfig[network.name].minBetAmount,
      contractConfig[network.name].oracleUpdateAllowance,
      network.name !== "testnet"
        ? addresses[network.name].dehub
        : addresses[network.name].dehub,
    ],
    {
      kind: "uups",
      initializer: "__PricePrediction_init",
    }
  );

  await prediction.deployed();

  try {
    // Verify
    implAddr = await upgrades.erc1967.getImplementationAddress(
      prediction.address
    );
    console.log("Verifying prediction: ", implAddr);
    await hre.run("verify:verify", {
      address: implAddr,
    });
  } catch (error) {
    if (error instanceof NomicLabsHardhatPluginError) {
      console.log("Contract source code already verified");
    } else {
      console.error(error);
    }
  }

  const deployerLog = { Label: "Deploying Address", Info: deployer.address };
  const proxyLog = {
    Label: "Deployed DeHubPricePrediction Proxy Address",
    Info: prediction.address,
  };
  const implementationLog = {
    Label: "Deployed and Verified Implementation Address",
    Info: implAddr,
  };

  console.table([deployerLog, proxyLog, implementationLog]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
