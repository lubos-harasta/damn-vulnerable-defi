const pairJson = require('@uniswap/v2-core/build/UniswapV2Pair.json');
const factoryJson = require('@uniswap/v2-core/build/UniswapV2Factory.json');
const routerJson = require('@uniswap/v2-periphery/build/UniswapV2Router02.json');

const { ethers } = require('hardhat');
const { expect } = require('chai');

const GANACHE_ENABLED = true;

async function main() {
  // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
  const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('100');
  const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('10');

  const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('10000');
  const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000000');

  [deployer, attacker] = await ethers.getSigners();

  console.log('Ganache enabled: ', GANACHE_ENABLED);
  if (GANACHE_ENABLED) {
    expect(await ethers.provider.getBalance(attacker.address)).to.eq(
      ethers.utils.parseEther('20')
    );
  }

  const UniswapFactoryFactory = new ethers.ContractFactory(
    factoryJson.abi,
    factoryJson.bytecode,
    deployer
  );
  const UniswapRouterFactory = new ethers.ContractFactory(
    routerJson.abi,
    routerJson.bytecode,
    deployer
  );
  const UniswapPairFactory = new ethers.ContractFactory(
    pairJson.abi,
    pairJson.bytecode,
    deployer
  );

  // Deploy tokens to be traded
  const token = await (
    await ethers.getContractFactory('DamnValuableToken', deployer)
  ).deploy();
  console.log('DamnValuableToken deployed at:', token.address);
  const weth = await (
    await ethers.getContractFactory('WETH9', deployer)
  ).deploy();
  console.log('WETH9 deployed at:', weth.address);

  // Deploy Uniswap Factory and Router
  const uniswapFactory = await UniswapFactoryFactory.deploy(
    ethers.constants.AddressZero
  );
  console.log('Factory deployed at:', uniswapFactory.address);
  const uniswapRouter = await UniswapRouterFactory.deploy(
    uniswapFactory.address,
    weth.address
  );
  console.log('Router deployed at:', uniswapRouter.address);

  // Create Uniswap pair against WETH and add liquidity
  await token.approve(uniswapRouter.address, UNISWAP_INITIAL_TOKEN_RESERVE);
  await uniswapRouter.addLiquidityETH(
    token.address,
    UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
    0, // amountTokenMin
    0, // amountETHMin
    deployer.address, // to
    (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
    { value: UNISWAP_INITIAL_WETH_RESERVE }
  );
  uniswapExchange = await UniswapPairFactory.attach(
    await uniswapFactory.getPair(token.address, weth.address)
  );
  console.log('Exchange deployed at:', uniswapExchange.address);
  expect(await uniswapExchange.balanceOf(deployer.address)).to.be.gt('0');

  // Deploy the lending pool
  lendingPool = await (
    await ethers.getContractFactory('PuppetV2Pool', deployer)
  ).deploy(
    weth.address,
    token.address,
    uniswapExchange.address,
    uniswapFactory.address
  );
  console.log('PuppetV2Pool deployed at:', lendingPool.address);

  // Setup initial token balances of pool and attacker account
  await token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE);
  console.log('Attacker address: ', attacker.address);
  await token.transfer(lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

  // approve echidna contract
  await token
    .connect(attacker)
    .approve(
      '0x00a329c0648769a73afac7f9381e08fb43dbea72',
      ATTACKER_INITIAL_TOKEN_BALANCE
    );

  // Ensure correct setup of pool.
  expect(
    await lendingPool.calculateDepositOfWETHRequired(
      ethers.utils.parseEther('1')
    )
  ).to.be.eq(ethers.utils.parseEther('0.3'));
  expect(
    await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
  ).to.be.eq(ethers.utils.parseEther('300000'));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
