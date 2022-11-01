// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title DamnValuableToken
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract EchidnaDVToken is ERC20 {
    // Decimals are set to 18 by default in `ERC20`
    constructor() ERC20("EchidnaDamnValuableToken", "EDVT") {
        _mint(msg.sender, type(uint256).max);
    }
}
