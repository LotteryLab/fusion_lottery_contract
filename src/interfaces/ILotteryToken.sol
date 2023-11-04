// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILotteryToken {

    function ownerOf(uint256 _tokenId) external view returns (address);

    function safeMint(address to, uint256 tokenId) external;

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

}
