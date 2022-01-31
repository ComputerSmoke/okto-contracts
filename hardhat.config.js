require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("crypto");
const fs = require("fs");

let key = JSON.parse(fs.readFileSync(".env.local", "UTF-8")).key;
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337,
      accounts: {
        accountsBalance: "1000000000000000000000000000"//1 billion ether
      }
    },
    ftm_test: {
      url: "https://rpc.testnet.fantom.network",
      accounts: [key]
    }
  },
  mocha: {
    timeout: 20000000000
  }
};