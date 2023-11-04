// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/LotteryToken.sol";

contract LotteryTokenTest is Test {

    LotteryToken public lotteryToken;

    function setUp() public {
        lotteryToken = new LotteryToken();
    }

    function test_MintTicket() public {
        address a = address(1);
        uint256 seq = 100;
        bytes32 ticketHash = keccak256(abi.encodePacked(a, "202320", seq));
        lotteryToken.safeMint(a, uint256(ticketHash));
        assertEq(lotteryToken.balanceOf(a), 1);
        console.log(lotteryToken.tokenURI(uint256(ticketHash)));
    }

    function test_TransferTicket() public {
        address a = address(2);
        address b = address(3);
        // mint
        uint256 seq = 100;
        uint256 ticketHash = uint256(keccak256(abi.encodePacked(a, "202320", seq)));
        lotteryToken.safeMint(a, ticketHash);
        assertEq(lotteryToken.balanceOf(a), 1);

        // transfer
        vm.prank(a);
        lotteryToken.safeTransferFrom(a, b, ticketHash);
        assertEq(lotteryToken.balanceOf(a), 0);
        assertEq(lotteryToken.balanceOf(b), 1);
        assertEq(lotteryToken.ownerOf(ticketHash), b);
        assertEq(lotteryToken.tokenOfOwnerByIndex(b, 0), ticketHash);
    }
}
