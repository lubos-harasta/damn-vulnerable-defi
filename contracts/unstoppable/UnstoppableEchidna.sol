// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/* @dev import paths changed because
 */
import "../DamnValuableToken.sol";
import "./ReceiverUnstoppable.sol";
import "./UnstoppableLender.sol"; // a lending pool

/**
 * @dev to run this contract, use:
 * npx hardhat clean && npx hardhat compile --force && echidna-test . --contract UnstoppableEchidna --multi-abi --config contracts/unstoppable/config.yaml
 */
contract UnstoppableEchidna {
    // We will send ETHER_IN_POOL to the flash loan pool.
    uint256 constant ETHER_IN_POOL = 1000000e18;
    // We will send INITIAL_ATTACKER_BALANCE to the attacker (which is the deployer) of this contract.
    uint256 constant INITIAL_ATTACKER_BALANCE = 100e18;

    DamnValuableToken token;
    UnstoppableLender pool;

    constructor() payable {
        token = new DamnValuableToken();
        // deploy the flash loan pool
        pool = new UnstoppableLender(address(token));
        // approve tokens for their transfer to the pool
        token.approve(address(pool), ETHER_IN_POOL);
        // deposit approved tokens into the pool
        pool.depositTokens(ETHER_IN_POOL);
        // send the attacker some tokens
        token.transfer(msg.sender, INITIAL_ATTACKER_BALANCE);
    }

    // this is callback function which is inside the pool.flashloan(uint256 borrowAmount)
    function receiveTokens(address tokenAddress, uint256 amount) external {
        require(msg.sender == address(pool), "Sender must be the pool!");
        // return all tokens to the pool
        require(
            // this function will break the UnstoppableLender contract as the
            // poolBalance does not update if transfer() is called
            IERC20(tokenAddress).transfer(msg.sender, amount),
            "Token Transfer failed"
        );
    }

    // This is the Echidna property entrypoint.
    // We want to test whether flash loans can always be made.
    function echidna_testFlashLoan() public returns (bool) {
        pool.flashLoan(10);
        return true;
    }
}
