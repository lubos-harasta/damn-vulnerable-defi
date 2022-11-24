// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../SelfiePool.sol";
import "../SimpleGovernance.sol";
import "../../DamnValuableTokenSnapshot.sol";

/**
 * @notice to run echidna use following command:
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaSelfie --config ./selfie.yaml
 */

// the SelfieDeployment contract is used to set fuzzing environment (to deploy all necessary contracts)
contract SelfieDeployment {
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
        // return all necessary contracts
        return (pool, governance, token);
    }
}

contract EchidnaSelfie {
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;
    uint256 private TOKENS_IN_POOL = 1_500_000 ether;

    uint256 private actionId; // to tract id of queued actions
    uint256 private timestampOfActionQueued; // to track timestamp of queued actions

    uint256[] private actionsToBeCalled; // actions to be called in callback function

    // TODO: no action as a parameter as well?
    enum Actions {
        drainAllFunds,
        transferFrom,
        queueAction,
        executeAction
    }
    uint256 private actionsLength = 4; // must correspond with the length of Actions

    enum Payloads {
        emptyPayload,
        drainAllFunds,
        transferFrom
    }
    uint256 private payloadsLength = 3; // must correspond with the length of Payloads
    uint256 private _payloadSet;
    bytes private _payload;

    uint256 private _amountToTransferForPayload;
    uint256 private _amountToTransferForTransferFunction;
    uint256 private _weiAmountForQueueAction;

    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    event ActionCalledInCallback(string action); // to track which actions has been called in callback
    event AssertionFailed(string reason);
    event PayloadSet(string payload);
    event PayloadVariable(string name, uint256 variable);

    constructor() payable {
        SelfieDeployment deployer;
        deployer = new SelfieDeployment();
        (pool, governance, token) = deployer.deployContracts();
    }

    function flashLoan() public {
        // borrow max amount of tokens
        uint256 borrowAmount = token.balanceOf(address(pool)); // TODO: parametrize?
        pool.flashLoan(borrowAmount);
    }

    /**
     * @notice a callback to be called by pool once flashloan is taken
     * @param _amount amount of tokens to borrow
     */
    function receiveTokens(address, uint256 _amount) external {
        require(
            msg.sender == address(pool),
            "Only SelfiePool can call this function."
        );
        // logic
        callbackActions();
        // repay the loan
        require(token.transfer(address(pool), _amount), "Flash loan failed");
    }

    /**
     * @notice Echidna populates actionsToBeCalled by a numbers representing functions
     * to be called during callback in receiveTokens()
     * @param num a number represing a function to be called
     */
    function pushActionToCallback(uint256 num) external {
        num = num % actionsLength;
        actionsToBeCalled.push(num);
    }

    /**
     * @notice an action to be called
     * @param _num a number representing the action to be called
     */
    function callAction(uint256 _num) internal {
        require(0 <= _num && _num < actionsLength, "Out of range");
        // drain all funds
        if (_num == uint256(Actions.drainAllFunds)) {
            drainAllFunds();
        }
        // transfer
        if (_num == uint256(Actions.transferFrom)) {
            transferFrom();
        }
        // queue an action
        if (_num == uint256(Actions.queueAction)) {
            try this.queueAction() {} catch {
                revert("queueAction unsuccessful");
            }
        }
        // execute an action
        if (_num == uint256(Actions.executeAction)) {
            try this.executeAction() {} catch {
                revert("queueAction unsuccessful");
            }
        }
    }

    function setPayload(uint256 _num) external {
        require(0 <= _num && _num < actionsLength, "Out of range");
        _payloadSet = _num;
        // empty payload
        if (_num == uint256(Payloads.emptyPayload)) {
            _payload = "";
        }
        // drainAllFunds;
        if (_num == uint256(Payloads.drainAllFunds)) {
            _payload = abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(this)
            );
        }
        // transfer
        if (_num == uint256(Payloads.transferFrom)) {
            _payload = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                address(pool),
                address(this),
                _amountToTransferForPayload
            );
        }
    }

    /**
     * @notice set amount to transfer into payload
     */
    function setAmountToTransferForPayload(uint256 _amount) external {
        _amountToTransferForPayload = _amount;
    }

    /**
     * @notice set amount to transfer into payload
     */
    function setAmountToTransferForTransfer(uint256 _amount) external {
        _amountToTransferForTransferFunction = _amount;
    }

    /**
     * @notice set amount of wei for transferFrom
     */
    function setWeiAmountForQueueAction(uint256 _amount) external {
        _weiAmountForQueueAction = _amount;
    }

    /////////////
    // ACTIONS //
    /////////////

    /**
     * @notice actions to be called once receiveTokens() is called
     */
    function callbackActions() internal {
        uint256 genArrLength = actionsToBeCalled.length;
        if (genArrLength != 0) {
            for (uint256 i; i < genArrLength - 1; i++) {
                callAction(actionsToBeCalled[i]);
            }
        } else {
            revert("actionsToBeCalled is empty, no action called");
        }
    }

    function queueAction() public {
        // take a snaphost first as it is needed in queueAction()
        token.snapshot();
        // queue the action
        actionId = governance.queueAction(
            address(pool),
            _payload,
            _weiAmountForQueueAction
        );
        // set timestamp when action was queued (needed to pass the requirement in the executeAction)
        timestampOfActionQueued = block.timestamp;
    }

    function executeAction() public {
        // it does not make sense to call executeAction if the requirment is not met
        require(
            block.timestamp >=
                timestampOfActionQueued + ACTION_DELAY_IN_SECONDS,
            "Time for action execution has not passed yet"
        );
        governance.executeAction(actionId);
    }

    /**
     * @notice this function should always revert as we should not be able
     * to drain all funds from pool
     */
    function drainAllFunds() public {
        uint256 _poolBalance = token.balanceOf(address(pool));
        pool.drainAllFunds(address(this));
        uint256 _poolBalanceAfter = token.balanceOf(address(pool));
        require(
            _poolBalanceAfter > _poolBalance,
            "Draining all funds has been unsuccessful"
        );
    }

    /**
     * @notice this function should always revert as we should not be able
     * to transfer token from pool
     */
    function transferFrom() public {
        uint256 _poolBalance = token.balanceOf(address(pool));
        token.transferFrom(
            address(pool),
            address(this),
            _amountToTransferForTransferFunction
        );
        uint256 _poolBalanceAfter = token.balanceOf(address(pool));
        require(_poolBalanceAfter > _poolBalance, "Transfer unsuccessful");
    }

    /////////////
    // HELPERS //
    /////////////

    /**
     * @notice check if a balance of DVT in pool has changed;
     */
    function _checkPoolBalance() external view returns (bool) {
        if (token.balanceOf(address(pool)) == TOKENS_IN_POOL) {
            return true;
        } else {
            revert("Invariant broken");
        }
    }

    /**
     * @notice emit event of an action executed in callback, i.e. once receiveTokens() is called
     * @param _actionNumber a number of action executed
     */
    function emitActionExecuted(uint256 _actionNumber) internal {
        if (_actionNumber == uint256(Actions.queueAction)) {
            emit ActionCalledInCallback("queueAction()");
        }
        if (_actionNumber == uint256(Actions.executeAction)) {
            emit ActionCalledInCallback("executeAction()");
        }
        if (_actionNumber == uint256(Actions.drainAllFunds)) {
            emit ActionCalledInCallback("drainAllFunds()");
        }
        if (_actionNumber == uint256(Actions.transferFrom)) {
            emit ActionCalledInCallback("transferFrom()");
        }
    }

    function emitPayloadCreated() internal {
        if (_payloadSet == uint256(Payloads.emptyPayload)) {
            emit PayloadSet("Empty payload");
        }
        if (_payloadSet == uint256(Payloads.drainAllFunds)) {
            emit PayloadSet("drainAllFunds(address)");
        }
        if (_payloadSet == uint256(Payloads.transferFrom)) {
            emit PayloadSet("transferFrom(address,address,uint256)");
            emit PayloadVariable(
                "_amountToTransfer",
                _amountToTransferForPayload
            );
        }
    }

    ////////////////
    // INVARIANTS //
    ////////////////

    // GENERAL: Can we drain SelfiePool?

    function checkPoolBalance() external {
        try this._checkPoolBalance() {
            // pool balance has not changed
        } catch {
            // log which payload has been set
            emitPayloadCreated();
            // log actions called
            for (uint256 i; i < actionsToBeCalled.length; i++) {
                emitActionExecuted(actionsToBeCalled[i]);
            }
            emit AssertionFailed("Invariant broken");
        }
    }
}
