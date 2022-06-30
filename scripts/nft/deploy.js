const hre = require("hardhat");

// npx hardhat run scripts/deploy.js --network mumbai

async function main() {
  const PropexDealNFT = await hre.ethers.getContractFactory("PropexDealNFT");
  const dealNFT = await PropexDealNFT.deploy("Propex Test Deal", "PPX-0", 0, 1420);

  // 0x41C0A3059De6bE4f1913630db94d93aB5a2904B4
  await dealNFT.deployed();

  console.log("Deal NFT deployed to:", dealNFT.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
