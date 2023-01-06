// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../FlashLoanerPool.sol";
import "../RewardToken.sol";
import "../AccountingToken.sol";
import "../TheRewarderPool.sol";
import "../../DamnValuableToken.sol";

/**
 * @notice to run echidna use following command:
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaRewarderGeneric --config ./contracts/the-rewarder/echidna-generic/config.yaml
 */

contract RewarderTaskDeployer {
    uint256 private TOKENS_IN_LENDER_POOL = 1_000_000 ether;
    uint256 private TOKENS_PER_USER = 100 ether;

    function deployPoolsAndToken()
        public
        payable
        returns (DamnValuableToken, FlashLoanerPool, TheRewarderPool)
    {
        // deploy DamnValuableToken
        DamnValuableToken token;
        token = new DamnValuableToken();
        // deploy FlashLoanerPool
        FlashLoanerPool pool;
        pool = new FlashLoanerPool(address(token));
        // add liquidity to FlashLoanerPool deployed
        token.transfer(address(pool), TOKENS_IN_LENDER_POOL);
        // deploy TheRewarderPool
        TheRewarderPool rewarder;
        rewarder = new TheRewarderPool(address(token));
        // deposit tokens to the rewarder pool (simulate a deposit of 4 users)
        token.approve(address(rewarder), TOKENS_PER_USER * 4);
        rewarder.deposit(TOKENS_PER_USER * 4);
        // return
        return (token, pool, rewarder);
    }
}

contract EchidnaRewarderGeneric {
    uint256 private REWARDS_ROUND_MIN_DURATION = 5 days; // see TheRewarderPool::REWARDS_ROUND_MIN_DURATION
    uint256 private _flashLoanAmount; // to know how much we borrowed from the pool

    FlashLoanerPool pool;
    TheRewarderPool rewarder;
    RewardToken rewardToken;
    DamnValuableToken damnValuableToken;

    // all possible actions to be called in a callback
    enum CallbackActions {
        deposit,
        withdraw,
        distributeRewards
    }
    // cb = callback
    uint256[] private _cbActionsToBeCalled;

    // to track rewards and be able to assess if invariant has been broken
    struct Rewards {
        uint256 _amountBorrowed; // if zero, no flashloan
        uint256 _reward;
    }
    mapping(uint256 => Rewards) rewards;
    uint256 private _rewardsIndex;
    uint256 private _rewardsTestedIndex;

    // EVENTS
    event AssertionFailed(string reason);
    event Reward(uint256 reward);
    event FlashloanAmount(uint256 flashLoanAmount);

    // set Echidna fuzzing environment
    constructor() payable {
        RewarderTaskDeployer deployer = new RewarderTaskDeployer();
        (damnValuableToken, pool, rewarder) = deployer.deployPoolsAndToken();
        rewardToken = rewarder.rewardToken();
    }

    function flashLoanAll() public {
        uint256 lastRewardsTimestamp = rewarder.lastRecordedSnapshotTimestamp();
        require(
            block.timestamp >=
                lastRewardsTimestamp + REWARDS_ROUND_MIN_DURATION,
            "It is useless to call flashloan if no rewards can be taken"
        );
        // set _amount into storage to have the value available across
        // other functions in the callback
        _flashLoanAmount = damnValuableToken.balanceOf(address(pool));
        // take a flashloan
        pool.flashLoan(_flashLoanAmount);
    }

    // @note not even after 1_000_000 iterations, echidna has 
    // not been able to break it
    // function flashLoan(uint256 _amount) public {
    //     uint256 lastRewardsTimestamp = rewarder.lastRecordedSnapshotTimestamp();
    //     require(
    //         block.timestamp >=
    //             lastRewardsTimestamp + REWARDS_ROUND_MIN_DURATION,
    //         "It is useless to call flashloan if no rewards can be taken"
    //     );
    //     require(
    //         _amount <= damnValuableToken.balanceOf(address(pool)),
    //         "Cannot borrow more than it is in the pool."
    //     );
    //     // set _amount into storage to have the value available across
    //     // other functions in the callback
    //     _flashLoanAmount = _amount;
    //     // take a flashloan
    //     pool.flashLoan(_flashLoanAmount);
    // }

    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function."
        );
        uint256 rewardBefore = rewardToken.balanceOf(address(this));
        // call selected functions
        cbActions();
        // get max reward amount for checking the INVARIANT
        uint256 rewardAfter = rewardToken.balanceOf(address(this));
        // repay the loan
        require(
            damnValuableToken.transfer(address(pool), amount),
            "Flashloan failed"
        );
        // track of the borrowed amount and the reward
        updateRewards(amount, rewardBefore, rewardAfter);
        // reset _flashLoanAmount @note is the reset necessary?
        _flashLoanAmount = 0;
    }

    function updateRewards(
        uint256 amountBorrowed,
        uint256 rewardBefore,
        uint256 rewardAfter
    ) internal {
        rewards[_rewardsIndex]._amountBorrowed = amountBorrowed;
        rewards[_rewardsIndex]._reward = rewardAfter - rewardBefore;
        _rewardsIndex = _rewardsIndex + 1;
    }

    function cbActions() internal {
        uint256 _cbActionsLength = _cbActionsToBeCalled.length;
        if (_cbActionsLength != 0) {
            for (uint256 i; i < _cbActionsLength; i++) {
                callAction(_cbActionsToBeCalled[i]);
            }
        } else {
            revert("No actions to be called.");
        }
    }

    function callAction(uint256 _num) internal {
        if (_num == uint256(CallbackActions.deposit)) {
            cbDepositToRewarder();
        }
        if (_num == uint256(CallbackActions.withdraw)) {
            cbWithdrawFromRewarder();
        }
        if (_num == uint256(CallbackActions.distributeRewards)) {
            cbDistributeRewardsFromRewarder();
        }
    }

    /////////////
    // ACTIONS //
    /////////////

    // DEPOSIT

    // @note _amount to deposit == amount of tokens borrowed in flashloan, thus not a subject
    // of parametrization
    function pushDepositToCb() external {
        _cbActionsToBeCalled.push(uint256(CallbackActions.deposit));
    }

    function cbDepositToRewarder() internal {
        _depositTokensToRewarderPool(_flashLoanAmount);
    }

    function _depositTokensToRewarderPool(uint256 _amount) internal {
        require(_amount > 0, "TheRewarderPool::Must deposit tokens");
        // approve the rewarder pool
        damnValuableToken.approve(address(rewarder), _amount);
        // deposit amount of tokens to rewarder pool
        rewarder.deposit(_amount);
    }

    function depositTokensToRewarderPool(uint256 _amount) external {
        require(
            damnValuableToken.balanceOf(address(this)) >= _amount,
            "Not enough tokens to deposit"
        );
        uint256 _rewardBefore = rewardToken.balanceOf(address(this));
        _depositTokensToRewarderPool(_amount);
        uint256 _rewardAfter = rewardToken.balanceOf(address(this));
        updateRewards(0, _rewardBefore, _rewardAfter);
    }

    // WITHDRAW

    function pushWithdrawToCb() external {
        _cbActionsToBeCalled.push(uint256(CallbackActions.withdraw));
    }

    function cbWithdrawFromRewarder() internal {
        withdrawFromRewarder(_flashLoanAmount);
    }

    function withdrawFromRewarder(uint256 _amount) public {
        // @todo
        // is possible to check that withdrawal has been successful
        // even though the function does not have return value?
        rewarder.withdraw(_amount);
    }

    // DISTRIBUTE REWARDS

    function pushDistributeRewardToCb() external {
        _cbActionsToBeCalled.push(uint256(CallbackActions.distributeRewards));
    }

    function cbDistributeRewardsFromRewarder() internal {
        rewarder.distributeRewards();
    }

    // @note multi-abi disabled, thus specifying the following function
    function distributeRewardsFromRewarder() external {
        uint256 _rewardBefore = rewardToken.balanceOf(address(this));
        rewarder.distributeRewards();
        uint256 _rewardAfter = rewardToken.balanceOf(address(this));
        updateRewards(0, _rewardBefore, _rewardAfter);
        // @todo remove after testing
        assert(_rewardAfter >= _rewardBefore);
    }

    /**
     * @notice INVARIANT: one user cannot get almost all of rewards
     * (max reward is 100 per turnus, 4 users already deposited)
     */
    function testRewards() external {
        require(_rewardsIndex > _rewardsTestedIndex, "No rewards to be tested");
        for (uint256 i = _rewardsTestedIndex; i < _rewardsIndex; i++) {
            uint256 reward = rewards[i]._reward;
            // test the invariant
            if (reward > 99 ether) {
                emit FlashloanAmount(rewards[i]._amountBorrowed);
                emit Reward(reward);
                emit AssertionFailed("Invariant broken");
            }
            _rewardsTestedIndex++;
        }
    }

    // @todo remove the following function after testing
    // (double check that testRewards works correctly)
    function testAllRewards() external {
        for (uint256 i; i < _rewardsIndex; i++) {
            uint256 reward = rewards[i]._reward;
            if (reward > 99 ether) {
                emit FlashloanAmount(rewards[i]._amountBorrowed);
                emit Reward(reward);
                emit AssertionFailed("Invariant broken");
            }
        }
    }
}
