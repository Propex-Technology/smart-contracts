const hre = require("hardhat");

// npx hardhat run scripts/deployStress.js --network mumbai

// Input
const DEAL_INDEX = 2;
const AMOUNT = 5000;
const DEAL_NAME = "Propex Test Deal";
const ENTRIES_TO_QUERY = 4500;

async function main() {
  const PropexDealERC20 = await hre.ethers.getContractFactory("PropexDealERC20");
  const dealERC = await PropexDealERC20
    .deploy(DEAL_NAME, `PPX-${DEAL_INDEX}`, DEAL_INDEX, AMOUNT);

  console.log("Deal ERC20 deployed to:", dealERC.address);
  console.log("Beginning stress.");

  for (let i = 0; i < 49; i++) {
    const addresses = [];
    const amounts = [];
    for (let j = 0; j < 100; j++) {
      addresses[j] = hre.ethers.Wallet.createRandom().address;
      amounts[j] = 1;
    }
    console.log(`Batch series ${i}`);
    await dealERC.batchMintForUser(addresses, amounts);
  }

  const entries = await dealERC.entriesInLastSnapshot();
  console.log(`ENTRIES: ${entries}`);
  const snapshot = await dealERC.entriesFromLastSnapshot(0, ENTRIES_TO_QUERY);
  console.log(snapshot);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
