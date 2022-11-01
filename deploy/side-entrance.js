/// MY SCRIPT (TUTORIAL ONE BELOW THIS ONE)

// const { ethers } = require('hardhat');
// // const hre = require('hardhat');
// // const ethers = hre.ethers;

// /**
//  * @notice deploy side-entrance contract and deposit 1000 ether
//  * @dev to deploy contract run the following command:
//  * `yarn hardhat  run ./deploy/side-entrance.js`
//  */
// async function deploySideEntrance() {
//   const ETHER_IN_POOL = ethers.utils.parseEther('1000');
//   const provider = ethers.provider;

//   [deployer, attacker] = await ethers.getSigners();

//   // donate deployer
//   await attacker.sendTransaction({
//     to: deployer.address,
//     value: ethers.utils.parseEther('10'),
//   });

//   // check the deployer balance
//   const deployerBalance = await deployer.getBalance();
//   console.log('Deployer balance: ', ethers.utils.formatEther(deployerBalance));

//   // deploy the contract
//   const sideEntranceFactory = await ethers.getContractFactory(
//     'SideEntranceLenderPool',
//     deployer
//   );
//   pool = await sideEntranceFactory.deploy();
//   await pool.deployed();
//   console.log(
//     'sideEntranceContract deployed at: ',
//     pool.address,
//     '\nby account: ',
//     deployer.address
//   );

//   // check contract balance
//   const contractBalanceBefore = await provider.getBalance(pool.address);
//   console.log(
//     'Contract balance before deposit: ',
//     ethers.utils.formatEther(contractBalanceBefore)
//   );
//   // deposit ether to the contract
//   const depositTx = await pool.deposit({
//     value: ETHER_IN_POOL,
//   });
//   await depositTx.wait(1);
//   // check balance
//   const contractBalanceAfter = await provider.getBalance(pool.address);
//   console.log(
//     'Contract balance after deposit: ',
//     ethers.utils.formatEther(contractBalanceAfter)
//   );
//   console.log(contractBalanceAfter);
//   await provider.send('evm_mine');
// }

// deploySideEntrance()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });

/// ECHIDNA TUTORIAL
const hre = require('hardhat');
const ethers = hre.ethers;

async function main() {
  const ETHER_IN_POOL = ethers.utils.parseEther('900');

  [deployer, attacker] = await ethers.getSigners();

  const SideEntranceLenderPoolFactory = await ethers.getContractFactory(
    'SideEntranceLenderPool',
    deployer
  );

  pool = await SideEntranceLenderPoolFactory.deploy();
  await pool.deployed();
  console.log(`pool address ${pool.address}`);

  const depositTx = await pool.deposit({ value: ETHER_IN_POOL });
  await depositTx.wait(1);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
