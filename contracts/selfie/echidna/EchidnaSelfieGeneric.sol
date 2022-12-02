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
        returns (SelfiePool, SimpleGovernance, DamnValuableTokenSnapshot)
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

contract EchidnaSelfieGeneric {
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;
    uint256 private TOKENS_IN_POOL = 1_500_000 ether;

    uint256[] private actionIds; // to track id of queued actions
    uint256 private actionIdCounter;

    uint256[] private actionsToBeCalled; // actions to be called in callback function

    // all possible actions for callback
    enum CallbackActions {
        drainAllFunds,
        transferFrom,
        queueAction,
        executeAction
    }
    uint256 private callbackActionsLength = 4; // must correspond with the length of Actions

    // queueAction payloads to be created by Echidna
    enum PayloadsForQueueAction {
        noPayloadSet, // only for logging purposes
        drainAllFunds,
        transferFrom
    }
    uint256 private payloadsLength = 3; // must correspond with the length of Payloads

    bytes[] private _payloads; // payloads for queueAction()
    uint256 private _payloadsCounter;

    uint256[] private _payloadsTracker; // payloads tracker for logging purposes
    uint256 _payloadTrackerCounter;

    uint256[] private _weiForQueueAction; // the second queueAction parameters
    uint256 private _weiForQueueActionCounter;
    uint256 private _weiForQueueActionTrackerCounter; // used only for logging purposes

    uint256[] private _transferAmountInCallback; // amount for transferFrom called in callback function
    uint256 private __transferAmountInCallbackCounter;
    uint256 private _transferAmountInCallbackTrackerCounter; // used only for logging purposes

    uint256[] private _transferAmountInPayload; // amount for transferFrom for payload in queueAction
    uint256 private _transferAmountInPayloadCounter;
    uint256 private _transferAmountInPayloadTrackerCounter; // used only for logging purposes

    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    event ActionCalledInCallback(string action); // to track which actions has been called in callback
    event AssertionFailed(string reason);
    event QueueActionPayloadSetTo(string payload);
    event QueueActionVariable(string name, uint256 variable);
    event CallbackVariable(string name, uint256 variable);

    constructor() payable {
        SelfieDeployment deployer;
        deployer = new SelfieDeployment();
        (pool, governance, token) = deployer.deployContracts();
    }

    /**
     * @notice to call a flash loan
     */
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
     * @notice actions to be called once receiveTokens() of this contract is called
     */
    function callbackActions() internal {
        uint256 genArrLength = actionsToBeCalled.length;
        if (genArrLength != 0) {
            for (uint256 i; i < genArrLength; i++) {
                callAction(actionsToBeCalled[i]);
            }
        } else {
            revert("actionsToBeCalled is empty, no action called");
        }
    }

    /**
     * @notice an action to be called
     * @param _num a number representing the action to be called
     */
    function callAction(uint256 _num) internal {
        // drain all funds
        if (_num == uint256(CallbackActions.drainAllFunds)) {
            drainAllFunds();
        }
        // transfer funds
        if (_num == uint256(CallbackActions.transferFrom)) {
            callbackTransferFrom();
        }
        // queue an action
        if (_num == uint256(CallbackActions.queueAction)) {
            try this.queueAction() {} catch {
                revert("queueAction unsuccessful");
            }
        }
        // execute an action
        if (_num == uint256(CallbackActions.executeAction)) {
            try this.executeAction() {} catch {
                revert("queueAction unsuccessful");
            }
        }
    }

    //////////////////////
    // CALLBACK ACTIONS //
    //////////////////////

    // 1: drainAllFunds()
    function drainAllFunds() public {
        pool.drainAllFunds(address(this));
    }

    function pushDrainAllFundsToCallback() external {
        actionsToBeCalled.push(uint256(CallbackActions.drainAllFunds));
    }

    ///////////////////////
    // 2: transferFrom() //
    function transferFrom(uint256 _amount) external {
        require(_amount > 0, "Cannot transfer zero tokens");
        token.transferFrom(address(pool), address(this), _amount);
    }

    // callable only in a callback function
    function callbackTransferFrom() internal {
        // get the amount of tokens to be transfered
        uint256 _amount = _transferAmountInCallback[
            __transferAmountInCallbackCounter
        ];
        // increase the counter
        __transferAmountInCallbackCounter =
            __transferAmountInCallbackCounter +
            1;
        // call the transfer function
        token.transferFrom(address(pool), address(this), _amount);
    }

    function pushTransferFromToCallback(uint256 _amount) external {
        require(_amount > 0, "Cannot transfer zero tokens");
        _transferAmountInCallback.push(_amount);
        actionsToBeCalled.push(uint256(CallbackActions.transferFrom));
    }

    //////////////////////
    // 3: queueAction() //
    function queueAction() public {
        // get the next value of wei amount set
        uint256 _weiAmount = _weiForQueueAction[_weiForQueueActionCounter];
        // increase counter
        _weiForQueueActionCounter = _weiForQueueActionCounter + 1;
        require(
            address(this).balance >= _weiAmount,
            "Not sufficient account balance to queue an action"
        );
        // get the next _payload set
        bytes memory _payload = _payloads[_payloadsCounter];
        // increase the payload counter
        _payloadsCounter = _payloadsCounter + 1;
        // take a snaphost first as it is needed in queueAction()
        token.snapshot();
        // queue the action
        uint256 actionId = governance.queueAction(
            address(pool), // TODO cannot be hardcoded, as we can call token.transferFrom(), thus address(token) is the second parameter
            _payload,
            _weiAmount
        );
        // store actionIds // TODO: not necessary? (to be deleted?)
        actionIds.push(actionId);
    }

    function pushQueueActionToCallback(
        uint256 _weiAmount,
        uint256 _payloadNum,
        uint256 _amountToTransfer
    ) external {
        require(
            address(this).balance >= _weiAmount,
            "Not sufficient account balance to queue an action"
        );
        if (_payloadNum == uint256(PayloadsForQueueAction.transferFrom)) {
            require(_amountToTransfer > 0, "Cannot transfer 0 tokens");
        }
        // Add the action into callback array
        actionsToBeCalled.push(uint256(CallbackActions.queueAction));
        // Define parameters
        // 1: set WEI for queue action
        _weiForQueueAction.push(_weiAmount);
        // 2: create payload
        setPayload(_payloadNum, _amountToTransfer);
    }

    /**
     * @notice create payload for queue action
     * @param _payloadNum a number to decide which payload to be created
     */
    function setPayload(
        uint256 _payloadNum,
        uint256 _amountToTransfer
    ) internal {
        // optimization: to create only valid payloads, narrow down the _payloadNum
        _payloadNum = _payloadNum % payloadsLength;
        // update the state to know which payload was used in queueAction() (logging purposes, see emitPayloadCreated())
        _payloadsTracker.push(_payloadNum);
        // create payload of drainAllFunds
        if (_payloadNum == uint256(PayloadsForQueueAction.drainAllFunds)) {
            bytes memory _payload = abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(this)
            );
            _payloads.push(_payload);
        }
        // create payload of transfer
        if (_payloadNum == uint256(PayloadsForQueueAction.transferFrom)) {
            _transferAmountInPayload.push(_amountToTransfer);
            bytes memory _payload = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                address(pool),
                address(this),
                _amountToTransfer // TODO: figure out how to track it
            );
            _payloads.push(_payload);
        }
    }

    ////////////////////////
    // 4: executeAction() //
    function executeAction() public {
        // get the first unexecuted actionId
        uint256 actionId = actionIds[actionIdCounter];
        // increase action Id counter
        actionIdCounter = actionIdCounter + 1;
        // get data related to the action to be executed
        (, , uint256 weiAmount, uint256 proposedAt, ) = governance.actions(
            actionId
        );
        require(
            address(this).balance >= weiAmount,
            "Not sufficient account balance to execute the action"
        );
        require(
            block.timestamp >= proposedAt + ACTION_DELAY_IN_SECONDS,
            "Time for action execution has not passed yet"
        );
        // Action
        governance.executeAction{value: weiAmount}(actionId);
    }

    function pushExecuteActionToCallback() external {
        actionsToBeCalled.push(uint256(CallbackActions.executeAction));
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
        if (_actionNumber == uint256(CallbackActions.queueAction)) {
            emit ActionCalledInCallback("queueAction()");
            // type of payload in queueAction
            uint256 _payloadNum = _payloadsTracker[_payloadTrackerCounter];
            _payloadTrackerCounter = _payloadTrackerCounter + 1;
            emitPayloadCreated(_payloadNum);
            // wei amount in queueAction
            uint256 _weiAmount = _weiForQueueAction[
                _weiForQueueActionTrackerCounter
            ];
            _weiForQueueActionTrackerCounter =
                _weiForQueueActionTrackerCounter +
                1;
            emit QueueActionVariable("_weiForQueueAction: ", _weiAmount);
        }
        if (_actionNumber == uint256(CallbackActions.executeAction)) {
            emit ActionCalledInCallback("executeAction()");
        }
        if (_actionNumber == uint256(CallbackActions.drainAllFunds)) {
            emit ActionCalledInCallback("drainAllFunds()");
        }
        if (_actionNumber == uint256(CallbackActions.transferFrom)) {
            emit ActionCalledInCallback("transferFrom()");
            uint256 _transferedAmout = _transferAmountInCallback[
                _transferAmountInCallbackTrackerCounter
            ];
            _transferAmountInCallbackTrackerCounter =
                _transferAmountInCallbackTrackerCounter +
                1;
            emit CallbackVariable("_transferedAmout: ", _transferedAmout);
        }
    }

    /**
     * @notice emit event of a payload created in queueAction()
     */
    function emitPayloadCreated(uint256 _payloadNum) internal {
        if (_payloadNum == uint256(PayloadsForQueueAction.drainAllFunds)) {
            emit QueueActionPayloadSetTo("drainAllFunds(address)");
        }
        if (_payloadNum == uint256(PayloadsForQueueAction.transferFrom)) {
            emit QueueActionPayloadSetTo(
                "transferFrom(address,address,uint256)"
            );
            // get the next amount of token transfered and increase counter
            uint256 _transferedAmount = _transferAmountInPayload[
                _transferAmountInPayloadTrackerCounter
            ];
            _transferAmountInPayloadTrackerCounter =
                _transferAmountInPayloadTrackerCounter +
                1;
            emit QueueActionVariable("_transferedAmount: ", _transferedAmount);
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
            uint256 actionsArrLength = actionsToBeCalled.length;
            for (uint256 i; i < actionsArrLength; i++) {
                emitActionExecuted(actionsToBeCalled[i]);
            }
            // emit assertion violation
            emit AssertionFailed("Invariant broken");
        }
    }
}
