// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPuppetV2Pool {
    function borrow(uint256 borrowAmount) external;

    function calculateDepositOfWETHRequired(
        uint256 tokenAmount
    ) external view returns (uint256);
}
