const { ethers } = require('hardhat');

async function main() {
  [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
  const TestHelpersFactory = await ethers.getContractFactory(
    'TestHelpers',
    deployer
  );
  const testHelpers = await TestHelpersFactory.deploy();
  await testHelpers.deployed();

  await testHelpers.setNumArray(44949362980314018620414221567796018725980385013528536665,0,678814581660681564245100978459667189436262621600532226662);
  await testHelpers.generateFuncsToCall(4969398797224184056839180724067253576389194702624624983427830);
  await testHelpers.receiveFlashLoan();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
