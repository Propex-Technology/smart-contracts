const hre = require("hardhat");

const CONTRACT = "0x41C0A3059De6bE4f1913630db94d93aB5a2904B4";
const ADDRESS = "0x076F52Ca03Ac87180cFfca2fE4a126c6A4B23cDb";
const AMOUNT = 7;

// npx hardhat run scripts/mint.js --network mumbai

async function main() {
  const PropexDealNFT = await hre.ethers.getContractFactory("PropexDealNFT");
  const contract = PropexDealNFT.attach(CONTRACT);

  await contract.mintForUser(ADDRESS, AMOUNT);

  console.log(`${AMOUNT} was minted to ${ADDRESS}.`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
