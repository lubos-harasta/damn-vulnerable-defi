// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../FlashLoanerPool.sol";
import "../RewardToken.sol";
import "../TheRewarderPool.sol";
import "../../DamnValuableToken.sol";
import "hardhat/console.sol";

/**
 * Used for debugging
 */

contract TestHelpers {
    uint256 REWARDS_ROUND_MIN_DURATION = 5 days;
    uint256 flashLoanAmount;
    uint256 reward;

    uint256[] functionsOrder;
    uint256[3] numArray;

    constructor() {}

    function receiveFlashLoan() external view {
        console.log("Entering the receiveFlashLoan()");
        for (uint256 i = 0; i < functionsOrder.length; i++) {
            uint256 funcToBeCalled = functionsOrder[i];
            console.log("funcToBeCalled: ", funcToBeCalled);
            selectFunctionToCall(funcToBeCalled);
        }
    }

    function selectFunctionToCall(uint256 funcOrder) internal view {
        if (funcOrder == 0) {
            // deposit to pool with prior approval
            console.log("funcOrder == 0");
        }
        if (funcOrder == 1) {
            // withdraw from the pool
            console.log("funcOrder == 1");
        }
        if (funcOrder == 2) {
            // distribute rewards
            console.log("funcOrder == 3");
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

    function generateFuncsToCall(uint256 _randomNumber) external {
        console.log("Entering generateFuncsToCall");
        // delete current functionOrder
        delete functionsOrder;
        // select functions
        uint256 id = 0;
        for (uint256 i = 0; i < numArray.length; i++) {
            console.log("Iteration: #", i);
            console.log("numArray[i]: ", numArray[i]);
            // select function according to selectFunctionToCall
            uint256 selectedFunc = numArray[i] % numArray.length;
            console.log("selectedFunc: ", selectedFunc);
            // decide whether the function to be included or not
            uint256 bitIndex = _randomNumber & (1 << i);
            console.log("bitIndex: ", bitIndex);
            // if bitIndex is not zero, than include the function selected
            if (bitIndex > 0) {
                console.log("Setting: ");
                functionsOrder.push(selectedFunc);
                id++;
            }
            console.log("All done");
        }
    }
}
