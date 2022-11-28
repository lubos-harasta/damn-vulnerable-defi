const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Compromised Echidna', function () {
  let deployer, attacker;
  const EXCHANGE_INITIAL_ETH_BALANCE = ethers.utils.parseEther('9990');
  const INITIAL_NFT_PRICE = ethers.utils.parseEther('999');

  before(async function () {
    [deployer, attacker] = await ethers.getSigners();
    const ExchangeFactory = await ethers.getContractFactory(
      'Exchange',
      deployer
    );
    const TrustfulOracleFactory = await ethers.getContractFactory(
      'TrustfulOracle',
      deployer
    );
    const EchidnaCompromisedFactory = await ethers.getContractFactory(
      'EchidnaCompromised',
      deployer
    );
    // deploy echidna
    this.echidna = await EchidnaCompromisedFactory.deploy({
      value: EXCHANGE_INITIAL_ETH_BALANCE,
    });
    // attach exchange deployed
    this.exchange = await ExchangeFactory.attach(this.echidna.exchange());
    // attach oracle deployed
    this.oracle = await TrustfulOracleFactory.attach(this.echidna.oracle());
  });

  describe('Test Echidna Deployment', function () {
    it('DamnValuableNFT Successful Deployment', async function () {
      const nftSymbol = await this.echidna.NFT_SYMBOL();
      expect(nftSymbol).to.be.equal('DVNFT');
    });
    it('Exchange Balance Check', async function () {
      expect(
        await ethers.provider.getBalance(this.exchange.address)
      ).to.be.equal(EXCHANGE_INITIAL_ETH_BALANCE);
    });
    it('Oracle Median Price Check', async function () {
      const medianPrice = await this.oracle.getMedianPrice('DVNFT');
      expect(medianPrice).to.be.equal(INITIAL_NFT_PRICE);
    });
  });
});
