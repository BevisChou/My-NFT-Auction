// https://ethereum.stackexchange.com/questions/48235/truffle-migrate-store-deployed-contract-address-in-variable

const Item = artifacts.require("Item");
const MarketPlace = artifacts.require("MarketPlace");

module.exports = (deployer) => {
  deployer.deploy(Item, "Item", "ITM").then(function() {
    return deployer.deploy(MarketPlace, Item.address)
  });
};