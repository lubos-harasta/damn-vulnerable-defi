// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 * @notice possible fix: to check if the balance after the hack is bigger than
 * before the flash loan (see the ADDITION #N)
 */
contract FlashLoanReceiver {
    using Address for address payable;

    address payable private pool;

    constructor(address payable poolAddress) {
        pool = poolAddress;
    }

    // Function called by the pool during flash loan
    function receiveEther(uint256 fee) public payable {
        require(msg.sender == pool, "Sender must be pool");

        uint256 amountToBeRepaid = msg.value + fee;
        // ADDITION #1
        uint256 balanceBeforeFlashLoan = address(this).balance;

        require(
            balanceBeforeFlashLoan >= amountToBeRepaid,
            "Cannot borrow that much"
        );

        _executeActionDuringFlashLoan();

        // Return funds to pool
        pool.sendValue(amountToBeRepaid);

        // ADDITION #2
        // check that the flashloan has been profitable -> prevent before draining the
        require(
            address(this).balance >= balanceBeforeFlashLoan,
            "FlashLoan must be profitable"
        );
    }

    // Internal function where the funds received are used
    function _executeActionDuringFlashLoan() internal {}

    // Allow deposits of ETH
    receive() external payable {}
}
