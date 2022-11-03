// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../SideEntranceLenderPool.sol";

/**
 * @dev to run Echidna:
 * echidna-test . --contract EchidnaSideEntranceLenderPool --config ./contracts/side-entrance/echidna/config.yaml
 */

contract SideEntrancePoolDeployer {
    function deployNewPool() public payable returns (SideEntranceLenderPool) {
        SideEntranceLenderPool p;
        p = new SideEntranceLenderPool();
        p.deposit{value: msg.value}();
        return p;
    }
}

contract EchidnaSideEntranceLenderPool is IFlashLoanEtherReceiver {
    uint256 private ETHER_IN_POOL = 100 ether;

    SideEntranceLenderPool pool;

    uint256 initialPoolBalance;
    bool enableWithdraw;
    bool enableDeposit;
    uint256 depositAmount;

    event EchidnaLogSender(string reason, address sender);

    // set up Echidna
    constructor() payable {
        require(msg.value == ETHER_IN_POOL);
        // deployer the pool deployer
        SideEntrancePoolDeployer p = new SideEntrancePoolDeployer();
        // deploy the pool by the pool deployer to have different owner
        pool = p.deployNewPool{value: ETHER_IN_POOL}();
        // set initial balance
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

    function flashLoan(uint256 _amount) public {
        pool.flashLoan(_amount);
    }

    function testPoolBalance() public view {
        assert(address(pool).balance >= initialPoolBalance);
    }
}
