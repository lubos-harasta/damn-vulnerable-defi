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

    uint256 private actionId; // to tract id of queued actions
    uint256[] private actionsToBeCalled; // actions to be called in callback function

    // all possible actions for callback
    enum Actions {
        noActionToBeCalled,
        drainAllFunds,
        transferFrom,
        queueAction,
        executeAction
    }
    uint256 private actionsLength = 5; // must correspond with the length of Actions

    // function's parameters to be defined by Echidna
    struct FunctionParameters {
        bool amountTransferForTransferFunction;
        bool amountTransferForPayload;
        bool weiInQueueAction;
        bool payloadInQueueAction;
    }
    FunctionParameters functionParametersSet; // to check if parameter has been already set

    // queueAction payloads to be created by Echidna
    enum Payloads {
        emptyPayload,
        drainAllFunds,
        transferFrom
    }
    uint256 private payloadsLength = 3; // must correspond with the length of Payloads
    uint256 private _payloadSet; // to know which payload has been set (logging purposes)
    bytes private _payload; // current payload

    // other parameters to be set by echidna
    uint256 private _amountToTransferForPayloadForQueueAction;
    uint256 private _weiAmountForQueueAction;
    uint256 private _amountToTransferForTransferFunction;

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

    /**
     * @notice an action to be called
     * @param _num a number representing the action to be called
     */
    function callAction(uint256 _num) internal {
        // no action
        if (_num == uint256(Actions.noActionToBeCalled)) {
            // just do nothing
        }
        // drain all funds
        if (_num == uint256(Actions.drainAllFunds)) {
            drainAllFunds();
        }
        // transfer funds
        if (_num == uint256(Actions.transferFrom)) {
            transferFrom();
            // reset setter after the call
            functionParametersSet.amountTransferForTransferFunction = false;
        }
        // queue an action
        if (_num == uint256(Actions.queueAction)) {
            // reset setters after the call
            functionParametersSet.payloadInQueueAction = false;
            functionParametersSet.weiInQueueAction = false;
            if (_payloadSet == uint256(Payloads.transferFrom)) {
                functionParametersSet.amountTransferForPayload = false;
            }
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

    //////////////////////////////////////////////
    // PUSHERS AND SETTTERS OF CALLBACK ACTIONS //
    //////////////////////////////////////////////

    ////////////////////////
    // 1: drainAllFunds() //
    function drainAllFunds() public {
        pool.drainAllFunds(address(this));
    }

    function pushDrainAllFundsToCallback() external {
        actionsToBeCalled.push(uint256(Actions.drainAllFunds));
    }

    ///////////////////////
    // 2: transferFrom() //
    // -> pushers: pushTransferFromToCallback()
    // -> setters: setAmountToTransferForTransfer()
    function transferFrom() public {
        token.transferFrom(
            address(pool),
            address(this),
            _amountToTransferForTransferFunction
        );
    }

    function pushTransferFromToCallback() external {
        require(
            functionParametersSet.amountTransferForTransferFunction,
            "Amount to Transfer has not been defined"
        );
        actionsToBeCalled.push(uint256(Actions.transferFrom));
    }

    function setAmountToTransferForTransfer(uint256 _amount) external {
        _amountToTransferForTransferFunction = _amount;
        functionParametersSet.amountTransferForTransferFunction = true;
    }

    //////////////////////
    // 3: queueAction() //
    // -> pushers: pushQueueActionToCallback()
    // -> setters: setWeiAmountForQueueAction(), setPayload(), setAmountToTransferForPayload()
    function queueAction() public {
        require(
            address(this).balance >= _weiAmountForQueueAction,
            "Not sufficient account balance to queue an action"
        );
        // take a snaphost first as it is needed in queueAction()
        token.snapshot();
        // queue the action;
        actionId = governance.queueAction(
            address(pool),
            _payload,
            _weiAmountForQueueAction
        );
    }

    function pushQueueActionToCallback() external {
        require(
            functionParametersSet.payloadInQueueAction == true,
            "Payload must be specified."
        );
        require(
            functionParametersSet.weiInQueueAction == true,
            "Amount of WEI must be specified."
        );
        actionsToBeCalled.push(uint256(Actions.queueAction));
    }

    function setWeiAmountForQueueAction(uint256 _amount) external {
        require(
            address(this).balance >= _amount,
            "Not sufficient account balance"
        );
        // _amount = _amount % address(this).balance;
        _weiAmountForQueueAction = _amount;
        // _weiAmountForQueueAction = 0;
        functionParametersSet.weiInQueueAction = true;
    }

    function setPayload(uint256 _num) external {
        _num = _num % actionsLength;
        // update state variables
        _payloadSet = _num; // to know which payload use in queueAction()
        functionParametersSet.payloadInQueueAction = true;
        // create payloads:
        //  - empty payload
        if (_num == uint256(Payloads.emptyPayload)) {
            _payload = "";
        }
        //  - drainAllFunds
        if (_num == uint256(Payloads.drainAllFunds)) {
            _payload = abi.encodeWithSignature(
                "drainAllFunds(address)",
                address(this)
            );
        }
        //  - transfer
        if (_num == uint256(Payloads.transferFrom)) {
            require(
                functionParametersSet.amountTransferForPayload == true,
                "amountTransferForPayload has not been set"
            );
            _payload = abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                address(pool),
                address(this),
                _amountToTransferForPayloadForQueueAction // needs to be set
            );
        }
    }

    function setAmountToTransferForPayload(uint256 _amount) external {
        _amountToTransferForPayloadForQueueAction = _amount;
        functionParametersSet.amountTransferForPayload = true;
    }

    ////////////////////////
    // 4: executeAction() //
    function executeAction() public {
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
        governance.executeAction{value: weiAmount}(actionId); // TODO: Add if statement for weiAmount == 0?
    }

    function pushExecuteActionToCallback() external {
        actionsToBeCalled.push(uint256(Actions.executeAction));
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
                _amountToTransferForPayloadForQueueAction
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
