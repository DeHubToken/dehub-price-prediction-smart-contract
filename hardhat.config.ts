import dotenv from 'dotenv';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { removeConsoleLog } from 'hardhat-preprocessor';
import '@nomiclabs/hardhat-etherscan';
require('hardhat-tracer');
require('hardhat-abi-exporter');
import 'hardhat-gas-reporter';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-interface-generator';

dotenv.config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	defaultNetwork: 'localhost',
	networks: {
		localhost: {
			url: 'http://127.0.0.1:8545',
			forking: {
				url: process.env.MORALIS_BSC_MAINNET_ARCHIVE_URL || '',
				blockNumber: 10553446,
			},
		},
		testnet: {
			url: process.env.MORALIS_BSC_TESTNET_ARCHIVE_URL || '',
			chainId: 97,
			gasPrice: 20000000000,
			accounts:
				process.env.DEPLOYER001_PRIVATE_KEY !== undefined
					? [process.env.DEPLOYER001_PRIVATE_KEY]
					: [],
		},
		mainnet: {
			url: process.env.MORALIS_BSC_MAINNET_URL || '',
			chainId: 56,
			gasPrice: 20000000000,
			accounts:
				process.env.DEPLOYER001_PRIVATE_KEY !== undefined
					? [process.env.DEPLOYER001_PRIVATE_KEY]
					: [],
		},
		hardhat: {
			allowUnlimitedContractSize: true,
			initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
		},
	},
	solidity: {
		compilers: [
			{
				version: '0.8.4',
			},
		],
	},
	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts',
	},
	mocha: {
		timeout: 100000,
	},
	abiExporter: {
		path: './data/abi',
		clear: true,
		flat: true,
		only: [],
		spacing: 2,
	},
	preprocess: {
		eachLine: removeConsoleLog(
			(hre) =>
				hre.network.name !== 'hardhat' && hre.network.name !== 'localhost'
		),
	},
	etherscan: {
		apiKey: process.env.BSCSCAN_API_KEY || '',
	},
	gasReporter: {
		enabled: process.env.REPORT_GAS !== undefined,
		currency: 'USD',
		gasPrice: 10,
		ethPrice: 297,
		coinmarketcap: process.env.COINMARKETCAP_KEY || '',
	},
};
