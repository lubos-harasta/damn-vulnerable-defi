// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SideEntranceLenderPool.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @dev to run Echidna:
 * npx hardhat clean && npx hardhat compile --force && echidna-test /src --contract EchidnaEthenoSideEntranceLenderPool --config /src/contracts/side-entrance/echidna-etheno/config.yaml
 */

contract EchidnaEthenoSideEntranceLenderPool is IFlashLoanEtherReceiver {
    // address of deployed contract via Etheno (from init.json)
    address private poolAddress = 0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48;
    uint256 private poolBalance;
    uint256 private amountToBeLoaned;

    SideEntranceLenderPool pool;

    event AssertionFailed(string reason);
    event EchidnaLogSender(string reason, address sender);

    // set up Echidna
    constructor() payable {
        // deploy the SideEntranceLenderPool
        pool = SideEntranceLenderPool(poolAddress);
        // get the balance of the pool
        poolBalance = address(pool).balance;
    }

    // @dev would be possible to perform an attack even though we have not know the vulnerability before?
    function execute() external payable override {
        emit EchidnaLogSender("execute", msg.sender);
        this.withdrawFromPool();
        this.depositToPool(amountToBeLoaned);
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
        amountToBeLoaned = _amount;
        pool.flashLoan(_amount);
    }

    function test_balances() public view {
        assert(address(pool).balance >= poolBalance);
    }

    receive() external payable {}
}
