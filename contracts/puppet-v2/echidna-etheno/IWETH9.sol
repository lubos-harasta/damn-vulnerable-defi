// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWETH9 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function deposit() external payable;

    function withdraw(uint wad) external;

    function approve(address guy, uint wad) external returns (bool);
}
