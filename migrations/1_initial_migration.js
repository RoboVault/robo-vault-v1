const Migrations = artifacts.require("Migrations");
const Vault = artifacts.require("Vault");


module.exports = function (deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(Strategy)
};
