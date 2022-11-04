/**
 * deploy script to generate init.json by etheno
 * 1. run: etheno --ganache --ganache-args="--miner.blockGasLimit 10000000" -x init.json
 * 2. run: yarn hardhat run ./deploy/the-rewarder.js 
 */

const { ethers } = require('hardhat');

async function main() {
  [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
  users = [alice, bob, charlie, david];

  const TOKENS_IN_LENDER_POOL = ethers.utils.parseEther('1000000');

  const FlashLoanerPoolFactory = await ethers.getContractFactory(
    'FlashLoanerPool',
    deployer
  );
  const TheRewarderPoolFactory = await ethers.getContractFactory(
    'TheRewarderPool',
    deployer
  );
  const DamnValuableTokenFactory = await ethers.getContractFactory(
    'DamnValuableToken',
    deployer
  );
  const RewardTokenFactory = await ethers.getContractFactory(
    'RewardToken',
    deployer
  );
  const AccountingTokenFactory = await ethers.getContractFactory(
    'AccountingToken',
    deployer
  );
  liquidityToken = await DamnValuableTokenFactory.deploy();
  await liquidityToken.deployed();
  console.log('liquidityToken deployed at: ', liquidityToken.address);

  flashLoanPool = await FlashLoanerPoolFactory.deploy(liquidityToken.address);
  await flashLoanPool.deployed();
  console.log('flashLoanPool deployed at: ', flashLoanPool.address);

  // add damnVulnerable tokens to the pool
  await liquidityToken.transfer(flashLoanPool.address, TOKENS_IN_LENDER_POOL);

  rewarderPool = await TheRewarderPoolFactory.deploy(liquidityToken.address);
  await rewarderPool.deployed();
  console.log('rewarderPool deployed at: ', rewarderPool.address);

  rewardToken = await RewardTokenFactory.attach(
    await this.rewarderPool.rewardToken()
  );
  await rewardToken.deployed();
  console.log('rewardToken deployed at: ', rewardToken.address);

  accountingToken = await AccountingTokenFactory.attach(
    await this.rewarderPool.accToken()
  );
  await accountingToken.deployed();
  console.log('accountingToken deployed at: ', accountingToken.address);

  // deposit tokens to the rewarder pool by users
  for (let i = 0; i < users.length; i++) {
    const amount = ethers.utils.parseEther('100');
    await liquidityToken.transfer(users[i].address, amount);
    await liquidityToken
      .connect(users[i])
      .approve(rewarderPool.address, amount);
    await rewarderPool.connect(users[i]).deposit(amount);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
