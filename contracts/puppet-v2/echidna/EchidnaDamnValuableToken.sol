pragma solidity ^0.6.0;

import "./uni-v2/UniswapV2ERC20.sol";

contract EchidnaDamnValuableToken is UniswapV2ERC20 {
    constructor(uint256 _amountToMint) public {
        require(_amountToMint <= uint(-1));
        _mint(msg.sender, _amountToMint);
    }
}
