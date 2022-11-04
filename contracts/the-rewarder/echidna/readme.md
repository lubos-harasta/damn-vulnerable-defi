## General description

To break the Rewarder contract by Echidna, I decided to populate `receiveFlashLoan` function with all possible functions which might be called without taking care about the order of calls. The aim here is to let Echidna find the correct order by itself which might be useful for fuzzing more complex cases. Also I would like to have a possibility to call one function several times and/or to exclude a function completely from the callback function. To do that I created the following functions:

1. `selectFunctionToCall(uint256 funcOrder)`: calls the specific function.
2. `generateFuncsToCall(uint256 _randomNumber)`: generates functions which will be called once receiveFlashLoan() is called.
3. `setNumArray(numArray[0] = num1; numArray[1] = num2; numArray[2] = num3;)`: let Echidna generate different possible combination of numbers to be used in selecting functions to be called in generateFuncsToCall().

## Questions

With the version of `flashLoan()` function applied, Echidna is able to break Rewarder.

```solidity
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
```

However if `flashLoan()` function has input parameter (the amount to be loaned), Echidna was not able to break the rewarder after 500K simulations.

```solidity
function flashLoan(uint256 _amount)) public {
    uint256 lastRewardsTimestamp = rewarder.lastRecordedSnapshotTimestamp();
    require(
        block.timestamp >=
            lastRewardsTimestamp + REWARDS_ROUND_MIN_DURATION,
        "It is useless to call flashloan if no rewards can be taken."
    );
    flashLoanAmount = _amount;
    pool.flashLoan(flashLoanAmount);
}
```

What is the reason of that? What is wrong with this approach? Why Echidna cannot find the solution?
