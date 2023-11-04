// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ILotteryToken.sol";

/**
 * Function buyTicket, claimReward, buy/close window,
 *
 */
contract Lottery is Ownable, ReentrancyGuard {

    event BuyTicket(address indexed from, uint256 indexed ticketId, uint256 value);
    event ClaimTicket(address indexed from, uint256 indexed ticketId, uint256 value);
    event Draw(string drawNo, bytes32 btcHash);
    event DrawRollover(string drawNo, uint256 remain);
    event Prize(uint256 indexed tier, uint256 indexed ticketId, uint256 value);

    using Counters for Counters.Counter;

    address public immutable lotteryToken; // Lottery Token Address

    Counters.Counter private _tokenIdTracker; // Lottery Counter

    uint256 public ticketPrice = 2 ether; // Ticket Price

    string public currentDraw;
    uint256 public currentBuyWindowStart;
    uint256 public currentBuyWindowEnd;

    mapping(string => uint256[]) public drawTickets; // Lottery Tickets, Draw No -> Tickets

    mapping(string => bytes32) public drawn; // Lottery Draw, Draw No -> Empty(false)/BTC Hash(true)

    mapping(string => uint256) public pools; // Lottery Pools, Draw No -> Total Prize

    uint256 public rollingPrizePool; // Lottery Pool with rolling prize when last draw less than 55 tickets

    mapping(uint256 => uint256) public prizes; // Lottery Rewards, NFT ID -> Prize Amount

    address payable public foundation;

    constructor(address lotteryToken_) {
        lotteryToken = lotteryToken_;

        // Init the buy window
        _initWindow(block.timestamp);
    }

    receive() external payable {
        buyTicket();
    }

    function buyTicket() public payable returns (uint256) {
        require(msg.value == ticketPrice, "Lottery: Wrong Ticket Price");

        return _buyTicket();
    }

    function buyMultipleTickets(uint256 num) public payable {
        require(num <= 10, "Lottery: Wrong Ticket Price");
        require(msg.value == ticketPrice * num, "Lottery: Wrong Ticket Price");

        for (uint256 i = 0; i < num; i++) {
            _buyTicket();
        }
    }

    function _buyTicket() private returns (uint256) {
        require(_checkBuyWindow(block.timestamp), "Lottery: Not Buy Window");

        address from = _msgSender();
        // generate ticket id
        uint256 ticketId = uint256(keccak256(abi.encodePacked(from, currentDraw, _tokenIdTracker.current())));
        ILotteryToken(lotteryToken).safeMint(from, ticketId); // mint ticket
        _tokenIdTracker.increment();

        // add draw list
        drawTickets[currentDraw].push(ticketId);

        // add money into current pool
        pools[currentDraw] += ticketPrice;

        emit BuyTicket(from, ticketId, ticketPrice);
        return ticketId;
    }

    function claimPrize(uint256 ticketId) public nonReentrant {
        address from = _msgSender();
        require(ILotteryToken(lotteryToken).ownerOf(ticketId) == from, "Lottery: Wrong Ticket Ownership");
        uint256 prize = prizes[ticketId];
        require(prize > 0, "Lottery: No Prize");

        ILotteryToken(lotteryToken).safeTransferFrom(from, address(0xdead), ticketId); // transfer ticket to dead address

        Address.sendValue(payable(from), prize); // send prize
        emit ClaimTicket(from, ticketId, prize);
    }

    function draw(string calldata drawNo, bytes32 btcHash) public onlyOwner {
        require(drawn[drawNo] == 0x00, "Lottery: Already Drawn");

        uint256[] storage tickets = drawTickets[drawNo];
        if (tickets.length != 0) {
            uint256 totalPrize = pools[drawNo];
            // send 30% to foundation
            uint256 adminFund = totalPrize * 3 / 10;
            Address.sendValue(foundation, adminFund); // send admin fund
            // distribute the prizes
            uint256 prize = totalPrize - adminFund + rollingPrizePool;
            uint256 remainPool = prize;
            uint256 awardTicket = tickets.length < 55 ? tickets.length : 55; // max 55 tickets
            for (uint256 i = 0; i < awardTicket; i++) {
                uint256 winnerIdx = uint256(keccak256(abi.encodePacked((uint256(btcHash) + i)))) % tickets.length;
                while (prizes[tickets[winnerIdx]] != 0) {
                    winnerIdx = winnerIdx == tickets.length - 1 ? 0 : winnerIdx + 1;
                }
                uint256 winnerPrize = calcPrize(prize, i);
                prizes[tickets[winnerIdx]] = winnerPrize; // set prize
                emit Prize(i, tickets[winnerIdx], winnerPrize);
                remainPool -= winnerPrize;
            }
            rollingPrizePool = remainPool; // update rolling prize pool
            emit DrawRollover(drawNo, rollingPrizePool);
        }

        drawn[drawNo] = btcHash; // update drawn
        emit Draw(drawNo, btcHash);
    }

    function calcPrize(uint256 fund, uint256 tier) public pure returns (uint256) {
        require(tier < 55, "Lottery: No Prize");

        uint256 prize = fund;
        if (tier == 0) {
            prize *= 25;
        } else if (tier == 1) {
            prize *= 10;
        } else if (tier == 2 || tier == 3 || tier == 4) {
            prize *= 5;
        }
        return prize / 100;
    }

    function setTicketPrice(uint256 newTicketPrice) public onlyOwner {
        ticketPrice = newTicketPrice;
    }

    function setFoundation(address newFoundation) public onlyOwner {
        foundation = payable(newFoundation);
    }

    function _checkBuyWindow(uint256 blockTimeStamp) private returns (bool) {
        if (blockTimeStamp >= currentBuyWindowStart && blockTimeStamp <= currentBuyWindowEnd) {
            return true;
        } else {
            return _initWindow(blockTimeStamp);
        }
    }

    function _initWindow(uint256 blockTimeStamp) private returns (bool) {
        // fetch the draw
        (string memory drawNo, uint256 buyStart, uint256 buyEnd) = getDrawNumber(blockTimeStamp);
        // if draw == currentDraw, do nothing
        // else open a new draw window
        if (keccak256(abi.encodePacked(drawNo)) != keccak256(abi.encodePacked(currentDraw))) {
            // New Draw
            currentDraw = drawNo;
            currentBuyWindowStart = buyStart;
            currentBuyWindowEnd = buyEnd;
            return true;
        }
        return false;
    }

    uint256 private constant start_timestamp = 1683072000; // 2023-05-03 00:00:00
    uint256 private constant start_year = 2023;
    uint256 private constant start_week = 17;

    function getDrawNumber(uint256 blockTimeStamp) public pure returns (string memory, uint256, uint256) {
        uint256 secondsSinceEpoch = blockTimeStamp - start_timestamp;
        uint256 currentWeek = secondsSinceEpoch / 1 weeks + start_week;

        uint256 year = start_year + currentWeek / 52;
        uint256 week = currentWeek % 52 + 1;

        string memory result = Strings.toString(year);
        if (week < 10) {
            result = string.concat(result, "0");
        }
        uint256 weekTime = start_timestamp + (currentWeek - start_week) * 1 weeks;
        uint256 buyStart = weekTime + 4 hours;
        uint256 buyEnd = weekTime + 1 weeks - 2 hours;

        return (string.concat(result, Strings.toString(week)), buyStart, buyEnd);
    }
}
