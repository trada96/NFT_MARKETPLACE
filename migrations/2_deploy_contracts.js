const Marketplace = artifacts.require("Marketplace");
require('dotenv').config();

module.exports = function (deployer) {
    deployer.deploy(Marketplace, process.env.FEE, process.env.LPTOKEN, process.env.COMMUNITY_ADDRESS);
};