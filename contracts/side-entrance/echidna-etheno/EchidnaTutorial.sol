// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../SideEntranceLenderPool.sol";
import "./Debugger.sol";

/**
 * @dev to run this file use :
 * npx hardhat clean && npx hardhat compile --force
 * && echidna-test . --contract E2E --config ./contracts/side-entrance/echidna-etheno/config-tutorial.yaml
 */

contract E2E is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    address ADDRESS_POOL = 0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48;

    uint256 initialPoolBalance;

    bool enableWithdraw;
    bool enableDeposit;
    uint256 depositAmount;

    constructor() payable {
        pool = SideEntranceLenderPool(ADDRESS_POOL);
        initialPoolBalance = address(pool).balance;
    }

    receive() external payable {}

    function setEnableWithdraw(bool _enabled) public {
        enableWithdraw = _enabled;
    }

    function setEnableDeposit(bool _enabled, uint256 _amount) public {
        enableDeposit = _enabled;
        depositAmount = _amount;
    }

    function execute() external payable override {
        if (enableWithdraw) {
            pool.withdraw();
        }
        if (enableDeposit) {
            pool.deposit{value: depositAmount}();
        }
    }

    function flashLoan() public {
        Debugger.log("depositAmount", depositAmount);
        pool.flashLoan(depositAmount);
    }

    function testPoolBalance() public view {
        assert(address(pool).balance >= initialPoolBalance);
    }
}
