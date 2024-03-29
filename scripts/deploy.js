const hre = require("hardhat");

// npx hardhat run scripts/deploy.js --network mumbai

// Input
const DEAL_INDEX = 0;
const AMOUNT = 1420;
const DEAL_NAME = "Propex Test Deal";

async function main() {
  const PropexDealERC20 = await hre.ethers.getContractFactory("PropexDealERC20");
  const dealNFT = await PropexDealERC20
    .deploy(DEAL_NAME, `PPX-${DEAL_INDEX}`, DEAL_INDEX, AMOUNT);

  console.log("Deal NFT deployed to:", dealNFT.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
