// Deploy script which allows us to deploy our smartcontract
const hre = require("hardhat");

async function main() {
  const Lock = await hre.ethers.getContractFactory("Lock");
  const lock = await Lock.deploy();

  await lock.deployed();

  console.log(`CONTRACT DEPLOYED TO ${lock.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
