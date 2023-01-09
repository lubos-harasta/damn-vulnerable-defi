// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IUniswapV2Pair {
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IWeth {
    function withdraw(uint wad) external;

    function deposit() external payable;

    function transfer(address dst, uint wad) external returns (bool);
}

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

interface IFreeRiderNFTMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;

    function offerMany(
        uint256[] calldata tokenIds,
        uint256[] calldata prices
    ) external;
}

interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

// interface IERC721Receiver {
//     function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
// }
