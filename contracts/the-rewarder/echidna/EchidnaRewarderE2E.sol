// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../FlashLoanerPool.sol";
import "../RewardToken.sol";
import "../AccountingToken.sol";
import "../TheRewarderPool.sol";
import "../../DamnValuableToken.sol";

/**
 * @notice to run echidna use following command:
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaRewarderE2E --config ./contracts/the-rewarder/echidna/config-tutorial.yaml
 */

contract RewarderTaskDeployer {
    uint256 private TOKENS_IN_LENDER_POOL = 1_000_000 ether;
    uint256 private TOKENS_PER_USER = 100 ether;

    event LogEvent(string message);

    function deployPoolsAndToken()
        public
        payable
        returns (
            DamnValuableToken,
            FlashLoanerPool,
            TheRewarderPool
        )
    {
        // deploy DamnValuableToken
        emit LogEvent("Deploying DamnValuableToken");
        DamnValuableToken token;
        token = new DamnValuableToken();
        // deploy FlashLoanerPool
        emit LogEvent("Deploying FlashLoanerPool");
        FlashLoanerPool pool;
        pool = new FlashLoanerPool(address(token));
        // add liquidity to FlashLoanerPool deployed
        token.transfer(address(pool), TOKENS_IN_LENDER_POOL);
        // deploy TheRewarderPool
        emit LogEvent("Deploying TheRewarderPool");
        TheRewarderPool rewarder;
        rewarder = new TheRewarderPool(address(token));
        // deposit tokens to the rewarder pool (simulate a deposit of 4 users)
        token.approve(address(rewarder), TOKENS_PER_USER * 4);
        rewarder.deposit(TOKENS_PER_USER * 4);
        // return
        return (token, pool, rewarder);
    }
}

contract EchidnaRewarderE2E {
    uint256 REWARDS_ROUND_MIN_DURATION = 5 days;
    uint256 flashLoanAmount;
    uint256 reward;

    FlashLoanerPool pool;
    TheRewarderPool rewarder;
    RewardToken rewardToken;
    DamnValuableToken damnValuableToken;
    // order of functions to be called in receiveFlashLoan()
    uint256[] functionsOrder;
    // hardcoded three as we have three function possible to be called
    // in receiveFlashLoan()
    uint256[3] numArray;

    event AssertionFailed(string reason, uint256 balance);
    event LogEvent(string message);

    constructor() payable {
        // deploy
        emit LogEvent("Creating a contract..");
        RewarderTaskDeployer deployer = new RewarderTaskDeployer();
        emit LogEvent("Deploying pool..");
        (damnValuableToken, pool, rewarder) = deployer.deployPoolsAndToken();
        emit LogEvent("Getting a token reward..");
        rewardToken = rewarder.rewardToken();
    }

    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function."
        );
        // logic
        require(
            functionsOrder.length > 0,
            "At least one function must be called."
        );
        // call functions based on the functionOrder array
        for (uint256 i = 0; i < functionsOrder.length; i++) {
            uint256 funcToBeCalled = functionsOrder[i];
            selectFunctionToCall(funcToBeCalled);
        }
        // get reward amount for checking the INVARIANT
        reward = rewardToken.balanceOf(address(this));
        //
        require(
            damnValuableToken.transfer(address(pool), amount),
            "Flashloan pay back failed"
        );
    }

    /**
     * @notice call one of defined function based on the input number
     * @param funcOrder a number to call the given function
     */
    function selectFunctionToCall(uint256 funcOrder) internal {
        if (funcOrder == 0) {
            // deposit to the pool with prior approval
            damnValuableToken.approve(address(rewarder), flashLoanAmount);
            rewarder.deposit(flashLoanAmount);
        }
        if (funcOrder == 1) {
            // withdraw from the pool
            rewarder.withdraw(flashLoanAmount);
        }
        if (funcOrder == 2) {
            // distribute rewards
            rewarder.distributeRewards();
        }
    }

    /**
     * @notice let echidna to populate array with different numbers to achieve
     * kind of randomness
     */
    function setNumArray(
        uint256 num1,
        uint256 num2,
        uint256 num3
    ) public {
        numArray[0] = num1;
        numArray[1] = num2;
        numArray[2] = num3;
    }

    /**
     * @notice helper function to generate different functions in different order to be called in receiveFlashLoan()
     * and thus test all possible scenarios
     * @param _randomNumber input by Echidna which is used to include/exclude function (see BitMap operation)
     */
    function generateFuncsToCall(uint256 _randomNumber) external {
        // delete current functionOrder
        delete functionsOrder;
        // select functions
        uint256 id = 0;
        for (uint256 i = 0; i < numArray.length; i++) {
            // select function according to selectFunctionToCall
            uint256 selectedFunc = numArray[i] % numArray.length;
            // decide whether the function to be included or not
            uint256 bitIndex = _randomNumber & (1 << i);
            // if bitIndex is not zero, than include the function selected
            if (bitIndex > 0) {
                functionsOrder.push(selectedFunc);
                id++;
            }
        }
    }

    function flashLoan() public {
        uint256 lastRewardsTimestamp = rewarder.lastRecordedSnapshotTimestamp();
        require(
            block.timestamp >=
                lastRewardsTimestamp + REWARDS_ROUND_MIN_DURATION,
            "It is useless to call flashloan if no rewards can be taken."
        );
        // borrow max number of tokens
        flashLoanAmount = damnValuableToken.balanceOf(address(pool));
        // call flashloan
        pool.flashLoan(flashLoanAmount);
    }

    /**
     * @notice INVARIANT: one user cannot get almost all of reward
     * (max reward is 100)
     */
    function testRewards() public view {
        assert(reward < 99 ether);
    }
}
