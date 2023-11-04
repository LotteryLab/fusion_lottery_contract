// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/LotteryToken.sol";

contract LotteryTest is Test {
    event BuyTicket(address indexed from, uint256 indexed ticketId, uint256 value);

    address private owner = address(999);

    address private foundation = address(888);

    Lottery public lottery;
    LotteryToken public lotteryToken;

    function setUp() public {
        vm.startPrank(owner);
        lotteryToken = new LotteryToken();
        vm.warp(1683338400); // 2023-05-06 10:00:00
        lottery = new Lottery(address(lotteryToken));

        lotteryToken.grantRole(lotteryToken.MINTER_ROLE(), address(lottery)); // give the mint role to lottery contract

        lottery.setFoundation(foundation);
        vm.stopPrank();
    }

    function test_DeployBuyWindow() public {
        assertEq(lottery.currentDraw(), "202318");
        assertEq(lottery.currentBuyWindowStart(), 1683086400);
        assertEq(lottery.currentBuyWindowEnd(), 1683669600);
    }

    function test_BuyTicket() public {
        address user = address(1);
        vm.deal(user, 2 ether);

        // Buy Ticket Event
        vm.expectEmit(true, true, false, true, address(lottery));
        uint256 ticketId = uint256(keccak256(abi.encodePacked(user, lottery.currentDraw(), uint256(0))));
        emit BuyTicket(user, ticketId, 2 ether);

        vm.prank(user);
        lottery.buyTicket{value: 2 ether}();

        // balance moved
        assertEq(address(lottery).balance, 2 ether);
        assertEq(user.balance, 0 ether);
        assertEq(lotteryToken.balanceOf(address(1)), 1); // NFT minted

        // draw updated
        assertNotEq(lottery.drawTickets(lottery.currentDraw(), 0), 0);
        assertEq(lottery.pools(lottery.currentDraw()), 2 ether);
    }

    function test_BuyMultipleTicket() public {
        address user = address(1);
        vm.deal(user, 20 ether);

        // Buy Ticket Event
        vm.expectEmit(true, true, false, true, address(lottery));
        uint256 ticketId = uint256(keccak256(abi.encodePacked(user, lottery.currentDraw(), uint256(0))));
        emit BuyTicket(user, ticketId, 2 ether);

        vm.prank(user);
        lottery.buyMultipleTickets{value: 20 ether}(10);

        // balance moved
        assertEq(address(lottery).balance, 20 ether);
        assertEq(user.balance, 0 ether);
        assertEq(lotteryToken.balanceOf(address(1)), 10); // NFT minted

        // draw updated
        assertNotEq(lottery.drawTickets(lottery.currentDraw(), 0), 0);
        assertEq(lottery.pools(lottery.currentDraw()), 20 ether);
    }

    function test_RevertNotBuyWindow_BuyTicket() public {
        vm.warp(1683640801); // 2023-05-09 22:00:01
        vm.expectRevert("Lottery: Not Buy Window");
        lottery.buyTicket{value: 2 ether}();
    }

    function test_RevertWrongPrice_BuyTicket() public {
        vm.expectRevert("Lottery: Wrong Ticket Price");
        lottery.buyTicket{value: 1 ether}();
    }

    function test_Draw() public {
        address user = address(1);
        vm.deal(user, 2 ether);
        vm.prank(user);
        uint256 ticket1 = lottery.buyTicket{value: 2 ether}();

        address user2 = address(2);
        vm.deal(user2, 2 ether);
        vm.prank(user2);
        uint256 ticket2 = lottery.buyTicket{value: 2 ether}();

        vm.prank(owner);
        lottery.draw("202318", hex"000000000000000000030939094d57c25369fbed9b6bafe94896de37f47d77f5");

        assertEq(lottery.drawn("202318"), hex"000000000000000000030939094d57c25369fbed9b6bafe94896de37f47d77f5");
        assertEq(foundation.balance, 1.2 ether);
        assertEq(lottery.rollingPrizePool(), 1.82 ether);
        assertEq(lottery.prizes(ticket1), 0.7 ether);
        assertEq(lottery.prizes(ticket2), 0.28 ether);

        vm.expectRevert("Lottery: Already Drawn");
        vm.prank(owner);
        lottery.draw("202318", hex"000000000000000000030939094d57c25369fbed9b6bafe94896de37f47d77f5");
    }

    function test_ClaimPrize() public {
        address user = address(1);
        vm.deal(user, 2 ether);
        vm.prank(user);
        uint256 ticket1 = lottery.buyTicket{value: 2 ether}();

        vm.prank(owner);
        lottery.draw("202318", hex"000000000000000000030939094d57c25369fbed9b6bafe94896de37f47d77f5");
        assertEq(foundation.balance, 0.6 ether);

        assertEq(lottery.prizes(ticket1), 0.35 ether);

        vm.prank(user);
        lotteryToken.approve(address(lottery), ticket1);

        vm.prank(user);
        lottery.claimPrize(ticket1);
        assertEq(user.balance, 0.35 ether);
    }

    function test_CalcPrize() public {
        uint256 fund = 3500 ether;

        assertEq(lottery.calcPrize(fund, 0), 875 ether);
        assertEq(lottery.calcPrize(fund, 1), 350 ether);
        assertEq(lottery.calcPrize(fund, 2), 175 ether);
        assertEq(lottery.calcPrize(fund, 3), 175 ether);
        assertEq(lottery.calcPrize(fund, 4), 175 ether);
        assertEq(lottery.calcPrize(fund, 5), 35 ether);
        assertEq(lottery.calcPrize(fund, 54), 35 ether);

        vm.expectRevert("Lottery: No Prize");
        lottery.calcPrize(fund, 55);
    }

    function test_DrawNumber() public {
        uint256 currentTimestamp = 1704146400; // 2024-01-01 22:00:00
        (string memory drawNo, uint256 buyStart, uint256 buyEnd) = lottery.getDrawNumber(currentTimestamp);
        assertEq(drawNo, "202352");
        assertEq(buyStart, 1703649600);
        assertEq(buyEnd, 1704232800);
    }

    function test_DrawNumberFor1Year() public {
        uint256 deployTimestamp = 1683338400; // 2023-05-06 10:00:00
        for (uint i = 0; i < 52; i++) {
            (, uint256 buyStart, uint256 buyEnd) = lottery.getDrawNumber(deployTimestamp);
            assertEq(buyStart, 1683072000 + i * 1 weeks + 4 hours);
            assertEq(buyEnd, 1683072000 + (i + 1) * 1 weeks - 2 hours);
            deployTimestamp += 1 weeks;
        }
    }

    function test_ModifyPrice() public {
        assertEq(lottery.ticketPrice(), 2 ether);
        vm.prank(owner);
        lottery.setTicketPrice(1);
        assertEq(lottery.ticketPrice(), 1);
    }

    function test_RevertNotOwner_ModifyPrice() public {
        vm.prank(address(1));
        vm.expectRevert("Ownable: caller is not the owner");
        lottery.setTicketPrice(1);
    }
}
