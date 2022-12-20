// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./uni-v2/UniswapV2Pair.sol";
import "./uni-v2/UniswapV2ERC20.sol";
import "./uni-v2/UniswapV2Factory.sol";
import "./uni-v2/UniswapV2Router01.sol"; // used instead of Router02
import "./libraries/UniswapV2Library.sol";

import "./EchidnaDamnValuableToken.sol"; // needed to decrease pragma version due to compiler error (Error HH606)
import "./EchidnaWETH9.sol"; // the same reason as above

// import "hardhat/console.sol";

/**
 * @title PuppetV2Pool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract EchidnaPuppetV2Pool {
    using SafeMath for uint256;

    address private _uniswapPair;
    address private _uniswapFactory;
    IERC20 private _token;
    IERC20 private _weth;

    mapping(address => uint256) public deposits;

    event Borrowed(
        address indexed borrower,
        uint256 depositRequired,
        uint256 borrowAmount,
        uint256 timestamp
    );

    constructor(
        address wethAddress,
        address tokenAddress,
        address uniswapPairAddress,
        address uniswapFactoryAddress
    ) public {
        _weth = IERC20(wethAddress);
        _token = IERC20(tokenAddress);
        _uniswapPair = uniswapPairAddress;
        _uniswapFactory = uniswapFactoryAddress;
    }

    /**
     * @notice Allows borrowing `borrowAmount` of tokens by first depositing three times their value in WETH
     *         Sender must have approved enough WETH in advance.
     *         Calculations assume that WETH and borrowed token have same amount of decimals.
     */
    function borrow(uint256 borrowAmount) external {
        require(
            _token.balanceOf(address(this)) >= borrowAmount,
            "Not enough token balance"
        );

        // Calculate how much WETH the user must deposit
        uint256 depositOfWETHRequired = calculateDepositOfWETHRequired(
            borrowAmount
        );

        // Take the WETH
        _weth.transferFrom(msg.sender, address(this), depositOfWETHRequired);

        // internal accounting
        deposits[msg.sender] += depositOfWETHRequired;

        require(_token.transfer(msg.sender, borrowAmount));

        emit Borrowed(
            msg.sender,
            depositOfWETHRequired,
            borrowAmount,
            block.timestamp
        );
    }

    function calculateDepositOfWETHRequired(
        uint256 tokenAmount
    ) public view returns (uint256) {
        return _getOracleQuote(tokenAmount).mul(3) / (10 ** 18);
    }

    // Fetch the price from Uniswap v2 using the official libraries
    function _getOracleQuote(uint256 amount) private view returns (uint256) {
        (uint256 reservesWETH, uint256 reservesToken) = UniswapV2Library
            .getReserves(_uniswapFactory, address(_weth), address(_token));
        return
            UniswapV2Library.quote(
                amount.mul(10 ** 18),
                reservesToken,
                reservesWETH
            );
    }
}

contract Users {
    address owner;

    constructor() public {
        owner = msg.sender;
    }

    function proxy(
        address target,
        bytes memory _calldata
    ) public payable returns (bool success, bytes memory returnData) {
        (success, returnData) = payable(address(target)).call{value: msg.value}(
            _calldata
        );
    }

    function withdrawEth(
        uint256 _amount
    ) external returns (bool success, bytes memory returnData) {
        require(msg.sender == owner, "Only owner can withdraw");
        require(
            address(this).balance >= _amount,
            "Not enough ETHs in contract"
        );
        (success, returnData) = payable(address(msg.sender)).call{
            value: _amount
        }("");
        require(success, "withdrawal unsuccessful");
    }

    // to be able to receive ETH;
    receive() external payable {}
}

contract EchidnaPuppetV2Setup {
    uint256 UNISWAP_INITIAL_TOKEN_RESERVE = 100 ether;
    uint256 UNISWAP_INITIAL_WETH_RESERVE = 10 ether;

    uint256 ATTACKER_INITIAL_TOKEN_BALANCE = 10_000 ether;
    uint256 ATTACKER_INITIAL_WETH_BALANCE = 20 ether;
    uint256 POOL_INITIAL_TOKEN_BALANCE = 1_000_000 ether;

    EchidnaDamnValuableToken token;
    EchidnaWETH9 weth;
    UniswapV2Pair pair;
    UniswapV2Factory factory;
    UniswapV2Router01 router;
    EchidnaPuppetV2Pool pool;

    Users attacker;

    bool initialized;
    address owner;

    constructor() public {
        // attacker
        attacker = new Users();
        // deploy tokens to be traded
        token = new EchidnaDamnValuableToken(
            UNISWAP_INITIAL_TOKEN_RESERVE +
                ATTACKER_INITIAL_TOKEN_BALANCE +
                POOL_INITIAL_TOKEN_BALANCE
        );
        weth = new EchidnaWETH9();
        // deploy uniswap factory and router
        factory = new UniswapV2Factory(address(0));
        router = new UniswapV2Router01(address(factory), address(weth));
        address pairAddress = factory.createPair(address(token), address(weth));
        pair = UniswapV2Pair(pairAddress);
        pool = new EchidnaPuppetV2Pool(
            address(weth),
            address(token),
            pairAddress,
            address(factory)
        );
        // set owner
        owner = msg.sender;
    }

    function init() public payable {
        require(!initialized, "Already initialised");
        require(
            msg.value >=
                (UNISWAP_INITIAL_WETH_RESERVE + ATTACKER_INITIAL_WETH_BALANCE),
            "Not enough ETH"
        );
        initialized = true;
        // SET UNISWAP
        // transfer tokens to this contract
        token.transfer(address(this), UNISWAP_INITIAL_TOKEN_RESERVE);
        // aprove tokens to uniswap router
        token.approve(address(router), uint(-1));
        // create and add liquidity
        router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token), // token
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            address(this), // to
            uint(-1) // deadline
        );
        (uint256 wethReserves, uint256 tokenReserves) = UniswapV2Library
            .getReserves(address(factory), address(weth), address(token));
        require(
            wethReserves == UNISWAP_INITIAL_WETH_RESERVE,
            "Uniswap:Wrong WETH reserve"
        );
        require(
            tokenReserves == UNISWAP_INITIAL_TOKEN_RESERVE,
            "Uniswap:Wrong DVT reserve"
        );
        // SET ATTACKER
        // token
        token.transfer(address(attacker), ATTACKER_INITIAL_TOKEN_BALANCE);
        uint256 attackerTokenBalanceAfter = token.balanceOf(address(attacker));
        // token checks
        require(
            attackerTokenBalanceAfter == ATTACKER_INITIAL_TOKEN_BALANCE,
            "Attacker:wrong token balance"
        );
        // eth
        (bool success2, ) = payable(attacker).call{
            value: ATTACKER_INITIAL_WETH_BALANCE
        }("");
        require(success2, "Transaction 2 failed");
        // eth check
        uint256 attackerEthBalance = address(attacker).balance;
        require(
            attackerEthBalance == ATTACKER_INITIAL_WETH_BALANCE,
            "Attacker:wrong eth balance"
        );
        // SET POOL
        token.transfer(address(pool), POOL_INITIAL_TOKEN_BALANCE);
        uint256 poolTokenBalance = token.balanceOf(address(pool));
        require(
            poolTokenBalance == POOL_INITIAL_TOKEN_BALANCE,
            "Pool:wrong token balance"
        );
    }

    function withdrawEth(
        uint256 _amount
    ) external returns (bool success, bytes memory returnData) {
        require(msg.sender == owner, "Only owner can withdraw");
        require(
            address(this).balance >= _amount,
            "Not enough ETHs in contract"
        );
        (success, returnData) = payable(address(msg.sender)).call{
            value: _amount
        }("");
        require(success, "ETH withdrawal unsuccessful");
    }

    // to be able to receive ETH;
    receive() external payable {}
}
