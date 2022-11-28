// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../Exchange.sol";
import "../TrustfulOracle.sol";
import "../TrustfulOracleInitializer.sol";
import "../../DamnValuableToken.sol";

contract CompromisedDeployer {
    string constant NFT_SYMBOL = "DVNFT";
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 9990 ether;

    address[] trustedOracles = [
        0xA73209FB1a42495120166736362A1DfA9F95A105,
        0xe92401A4d3af5E446d93D11EEc806b1462b39D15,
        0x81A5D6E50C214044bE44cA0CB057fe119097850c
    ];
    uint256[] nftPrices;
    string[] nftSymbols;

    function deployContracts()
        external
        payable
        returns (TrustfulOracle, Exchange)
    {
        require(msg.value == EXCHANGE_INITIAL_ETH_BALANCE, "Not enough ETH");
        // first, deploy oracle initializer
        nftPrices = [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE];
        nftSymbols = [NFT_SYMBOL, NFT_SYMBOL, NFT_SYMBOL];
        TrustfulOracleInitializer oracleInitializer;
        oracleInitializer = new TrustfulOracleInitializer(
            trustedOracles,
            nftSymbols,
            nftPrices
        );
        // second, get an oracle
        TrustfulOracle oracle = oracleInitializer.oracle();
        // third, deploy exchange
        Exchange exchange;
        exchange = new Exchange{value: msg.value}(address(oracle));
        return (oracle, exchange);
    }
}

contract EchidnaCompromised {
    string public NFT_SYMBOL;
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 9990 ether;

    TrustfulOracle public oracle;
    Exchange public exchange;
    DamnValuableNFT public token;

    constructor() payable {
        CompromisedDeployer compromisedDeployer = new CompromisedDeployer();
        (oracle, exchange) = compromisedDeployer.deployContracts{
            value: EXCHANGE_INITIAL_ETH_BALANCE
        }();
        token = exchange.token();
        NFT_SYMBOL = token.symbol();
    }

    function postPrice(uint256 _newPrice) external {
        oracle.postPrice(NFT_SYMBOL, _newPrice);
    }

    function echidna_median_price_never_drops() external view returns (bool) {
        uint256 nftPrice = oracle.getMedianPrice(NFT_SYMBOL);
        return (nftPrice >= INITIAL_NFT_PRICE);
    }
}
