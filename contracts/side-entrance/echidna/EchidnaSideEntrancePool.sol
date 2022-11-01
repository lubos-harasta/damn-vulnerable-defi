// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SideEntranceLenderPool.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @dev to run Echidna:
 * npx hardhat clean && npx hardhat compile --force && echidna-test /src --contract EchidnaSideEntranceLenderPool --config /src/contracts/side-entrance/echidna/config.yaml
 */

contract EchidnaSideEntranceLenderPool {
    using Address for address payable;

    uint256 private ETHER_IN_POOL = 1000e18;

    SideEntranceLenderPool pool;

    event EchidnaLogSender(string reason, address sender);

    // set up Echidna
    constructor() payable {
        // deploy the SideEntranceLenderPool
        pool = new SideEntranceLenderPool();
        // approve tokens for their transfer into the pool
        pool.deposit{value: ETHER_IN_POOL}();
    }

    // @dev would be possible to perform an attack even though we have not know the vulnerability before?
    function execute(uint256 amount) external payable {
        require(msg.sender == address(pool), "Sender must be the pool");
        emit EchidnaLogSender("execute", msg.sender);
        pool.deposit{value: amount}();
    }

    function withdrawFromPool() external payable {
        emit EchidnaLogSender("withdrawFromPool", msg.sender);
        pool.withdraw();
    }

    function depositToPool(uint256 _amount) external {
        emit EchidnaLogSender("depositToPool", msg.sender);
        pool.deposit{value: _amount}();
    }

    function flashLoanFromPool(uint256 _amount) external {
        emit EchidnaLogSender("flashLoanFromPool", msg.sender);
        pool.flashLoan(_amount);
    }

    // test invariant
    function test_balances() public view {
        assert(address(pool).balance >= ETHER_IN_POOL);
    }

    receive() external payable {}
}
