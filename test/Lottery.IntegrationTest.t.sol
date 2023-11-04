// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LotteryToken.sol";
import "../src/Lottery.sol";

contract LotteryIntegrationTest is Test {

    Lottery public lottery;
    LotteryToken public lotteryToken;

    address private deployer = address(222);
    address private foundation = address(333);

    function setUp() public {
        vm.startPrank(deployer);
        lotteryToken = new LotteryToken();
        vm.warp(1684116000); // 2023-05-15 10:00:00
        lottery = new Lottery(address(lotteryToken));

        lottery.setFoundation(foundation);
        lotteryToken.grantRole(lotteryToken.MINTER_ROLE(), address(lottery)); // give the mint role to lottery contract
        vm.stopPrank();
    }

    function test_ColdStartWeek1() public {
        // 0. Check Owner is Foundation
        assertEq(lottery.foundation(), foundation);

        // 1.1 Check Current Draw info

        // 1.2 Mock 10 users to buy the tickets

        // 1.3 Mock 1 user to buy multiple tickets

        // 1.4 Check Pool Fund

        // 1.5 Mock Time to draw end

        // 1.6 Check user able to buy ticket after end time

        // 2.0 Mock Time to New Draw Start

        // 2.1 Mock 100 users to buy the tickets

        // 1.7 Open the Last Draw by Foundation

        // 1.8 Check the Foundation Balance

        // 1.9 Check the Prize of last Draw

        // 1.10 Check the rolling prize pool

        // 1.11 Mock user to Claim the Prize

        // 2.2 Check Pool Fund after the 2nd draw

        // 2.3 Mock Time to draw end

        // 2.4 Open the 2nd Draw by Foundation

        // 2.5 Check the Foundation Balance

        // 2.6 Check the Prize of 2nd Draw

        // 2.7 Check the rolling prize pool

    }


}
