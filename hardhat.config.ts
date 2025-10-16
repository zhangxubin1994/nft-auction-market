import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
// require("@nomiclabs/hardhat-waffle");
// require("@nomiclabs/hardhat-ethers");
// require("@openzeppelin/hardhat-upgrades");
// require("hardhat-deploy");
require("dotenv").config();

const { PRIVATE_KEY, INFURA_API_KEY, ETHERSCAN_API_KEY } = process.env;

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 11155111,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      chainId: 5,
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};