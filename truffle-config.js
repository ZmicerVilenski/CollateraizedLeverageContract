
module.exports = {

  networks: {
    development: {
     host: "127.0.0.1",     // Localhost (default: none)
     port: 8545,            // Standard Ethereum port (default: none)
     network_id: "*",       // Any network (default: none)
    },
    bsctestnet: {
      provider: () => new HDWalletProvider(mnemonic, 'https://data-seed-prebsc-1-s1.binance.org:8545/'),
      network_id: "97", 
      networkCheckTimeout: 1000000,
      timeoutBlocks: 200,
    }  
  },

  mocha: {
    // timeout: 100000
  },

  compilers: {
    solc: {
      version: "0.8.0",      // Fetch exact version from solc-bin (default: truffle's version)
    }
  },

};