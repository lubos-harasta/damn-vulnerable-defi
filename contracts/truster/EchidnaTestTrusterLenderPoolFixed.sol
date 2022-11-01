// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./EchidnaDVToken.sol";
import "./TrusterLenderPoolFixed.sol";
import "./ITrusterLenderPool.sol";

/**
 * @dev run in docker:
 * npx hardhat clean && npx hardhat compile --force && echidna-test /src --contract EchidnaTestTrusterLenderPoolFixed --config /src/contracts/truster/config.yaml
 * @dev WHAT IS THE POINT TO RUN ECHIDNA HERE IF WE KNOW HOW TO ATTACK ALREADY?
 */

contract EchidnaTestTrusterLenderPoolFixed {
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    ERC20 public token;
    TrusterLenderPoolFixed public pool;

    event AssertionFailed(string reason, uint256 balance);

    address echidna_caller = msg.sender;

    // Echidna setup
    constructor() {
        // deploy token
        token = new EchidnaDVToken();
        // deploy vulnerable pool
        pool = new TrusterLenderPoolFixed(address(token));
        // deposit tokens into the pool
        token.transfer(address(pool), TOKENS_IN_POOL);
    }

    // @note if function's name uses `echidna` word (for instance: test_echidna_contract_balance), it fails because of
    // "test_echidna_contract_balance has arguments, aborting"

    function test_contract_balance_fixed(uint256 borrowAmount) public {
        // pre: check the initial balance
        uint256 poolBalanceBefore = token.balanceOf(address(pool));
        require(poolBalanceBefore == 1_000_000 ether);
        // pre: borrowAmount cannot be zero
        require(borrowAmount > 0);
        // TEST
        // create payload
        bytes memory approvePayload = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            poolBalanceBefore
        );
        // execute flashloan
        pool.flashLoan(
            borrowAmount,
            msg.sender,
            address(token),
            approvePayload
        );
        // try to withdraw tokens from the pool
        try token.transferFrom(address(pool), msg.sender, poolBalanceBefore) {
            /* not reverted */
        } catch {
            assert(false);
        }
        // using assertion event
        uint256 poolBalanceAfter = token.balanceOf(address(pool));
        if (poolBalanceBefore != poolBalanceAfter) {
            emit AssertionFailed("Pool Balance Decreased", poolBalanceAfter);
        }
        // using assert
        assert(token.balanceOf(address(pool)) >= TOKENS_IN_POOL);
    }
}
