// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FlashLoanReceiver.sol";
import "./NaiveReceiverLenderPool.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @dev in docker: npx hardhat clean && npx hardhat compile --force && echidna-test /src --contract EchidnaTestNaiveReceiver --config /src/contracts/naive-receiver/config.yaml
/// @notice see https://github.com/crytic/building-secure-contracts/blob/master/program-analysis/echidna/Exercise-6.md

contract EchidnaTestNaiveReceiver {
    using Address for address payable;

    uint256 constant ETH_IN_POOL = 1000e18;
    uint256 constant ETH_IN_RECEIVER = 10e18;

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    // setup Echidna
    constructor() payable {
        pool = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(payable(address(pool)));
        payable(address(pool)).sendValue(ETH_IN_POOL);
        payable(address(receiver)).sendValue(ETH_IN_RECEIVER);
    }

    // test if we can decrease the balance (drain it partially)
    // IF YOU WANT THE TEST TO FAIL THEN REMOVE ADDITION #N from ./NaiveReceiverLenderPool.sol
    function echidna_test_contract_balance() public view returns (bool) {
        return address(receiver).balance >= 10 ether;
    }
}
