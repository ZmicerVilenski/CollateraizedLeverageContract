const TokenX = artifacts.require("TokenX");
const TokenA = artifacts.require("TokenA");
const CLC = artifacts.require("CollateralizedLeverage");
const CLC_pool = artifacts.require("CollateralizedLeverage_pool");

module.exports = async function (deployer, network, addresses) {

  console.log("Deploying contracts with the account:", deployer.address);

  await deployer.deploy(TokenX, "Token X", "TX");
  const tokenX = await TokenX.deployed();
  console.log("token X address:", tokenX.address);

  await deployer.deploy(TokenA, "Token A", "TA");
  const tokenA = await TokenA.deployed();
  console.log("Token A address:", tokenA.address);

  await deployer.deploy(CLC, tokenX.address, tokenA.address);
  const clc = await CLC.deployed();
  console.log("Collateralized Leverage Contract (CLC) address:", clc.address);

};
