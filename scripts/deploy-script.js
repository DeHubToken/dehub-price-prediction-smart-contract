const hre = require("hardhat");

async function main() {
    let accounts = await hre.ethers.getSigners();
    let admin = accounts[0];
    let operator = accounts[1];
    let adminAddress = await admin.getAddress();
    let operatorAddress = await operator.getAddress();

    const Prediction = await hre.ethers.getContractFactory('BNBPricePrediction');
    const prediction = await Prediction.deploy(
        "", //_oracle BNB / USD, 8 DEC, mainnet: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        adminAddress,                                 //_adminAddress
        operatorAddress,                              //_operatorAddress
        "",                                        //_intervalBlocks
        "",                                         //_bufferBlocks
        "",                           //_minBetAmount
        "",                                        //_oracleUpdateAllowance
        "", //_BUSD, 0xe9e7cea3dedca5984780bafc599bd69add087d56
    );
    await prediction.deployed();

    console.log("Prediction deployed to:", prediction.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
