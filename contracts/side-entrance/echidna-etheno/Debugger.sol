// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/**
 * library from https://github.com/rappie/echidna-flashloan-poc
 */

library Debugger {
    event Debug(string description, string data);
    event Debug(string description, bytes32 data);
    event Debug(string description, uint256 data);

    function log(string memory description, string memory data) internal {
        emit Debug(description, data);
    }

    function log(string memory description, bytes32 data) internal {
        emit Debug(description, data);
    }

    function log(string memory description, uint256 data) internal {
        emit Debug(description, data);
    }
}
