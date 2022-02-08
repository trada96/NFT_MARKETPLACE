const Migrations = artifacts.require("Migrations");
const TradaMarket = artifacts.require("TradaMarket");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(TradaMarket);
};
