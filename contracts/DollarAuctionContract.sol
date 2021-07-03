Program the Blockchain	Archive About Subscribe
Writing a Dollar Auction Contract
AUGUST 16, 2018 BY TODD PROEBSTING
This post will implement a “dollar auction” contract for ERC20 tokens. It will be a modest change to the English auction contract.

A dollar auction requires that the highest and second-highest bidders each pay their bid amounts, although only the highest bidder receives the bid-for prize. (Originally, dollar auctions were so-named because it was a dollar bill that was being auctioned. Their fundamental characteristic, however, is the risk of being the second-highest bidder and getting nothing for your bid.)

Dollar auctions are not really practical for anything other than demonstrating how irrational people can be. They are, however, well-defined and relatively simple, so they make a good subject for implementation as a smart contract.

Auction State
Like our English Auction contract, the penny auction contract will auction off tokens, and the auction ends after no bids have been received for a given timeout period.

Unlike the English auction, the dollar auction keeps track of the top two highest bids. This dollar auction does not have a reserve price.

contract DollarAuction {
    address public seller;

    IERC20Token public token;
    uint256 public minIncrement;
    uint256 public timeoutPeriod;

    uint256 public auctionEnd;

    address public highBidder;
    uint256 public highBid;

    address public secondBidder;
    uint256 public secondBid;

    constructor(
        IERC20Token _token,
        uint256 _minIncrement,
        uint256 _timeoutPeriod
    )
        public
    {
        token = _token;
        minIncrement = _minIncrement;
        timeoutPeriod = _timeoutPeriod;

        seller = msg.sender;
        auctionEnd = now + timeoutPeriod;
        highBidder = seller;
    }

    // more to come
}
The constructor initializes highBidder to the seller’s account to simplify handling the case where there are no bids.

Ether Balances
Like the English Auction contract, this contract will keep track of every account’s available ether balance:

mapping(address => uint256) public balanceOf;

function withdraw() public {
    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
Bidding
Bidding in a dollar auction requires tracking the top two highest bids and adjusting all of the ether balances appropriately.

event Bid(address highBidder, uint256 highBid);

function bid(uint256 amount) public payable {
    require(now < auctionEnd);
    require(amount >= highBid+minIncrement);
    require(msg.sender != highBidder);

    balanceOf[msg.sender] += msg.value;

    uint256 increase = amount - secondBid;
    balanceOf[seller] += increase;
    balanceOf[secondBidder] += secondBid;
    require(balanceOf[msg.sender] >= amount);
    balanceOf[msg.sender] -= amount;
    secondBid = highBid;
    secondBidder = highBidder;

    highBidder = msg.sender;
    highBid = amount;
    auctionEnd = now + timeoutPeriod;
    emit Bid(highBidder, amount);
}
The code above merits some explanation:

The initial require statements make sure that a bid is acceptable.
The bulk of the code adjusts the ether balances to account for the previous high bidder now being the second-highest bidder. It’s worth noting that all of the adjustments to balanceOf offset each other.
The seller’s balance is updated by the increase of the current bid over the second-highest bid.
The require(balanceOf[msg.sender] >= amount); statement could not have been placed with the earlier require statements because it’s possible that msg.sender was the previous second-highest bidder. In that case, the sender’s ether balance wouldn’t be accurate until after secondBidder’s balance is updated.
Claiming Tokens
The winning bidder claims their tokens with resolve.

function resolve() public {
    require(now >= auctionEnd);

    uint256 t = token.balanceOf(this);
    require(token.transfer(highBidder, t));
}
Summary
Smart contracts can easily implement “dollar auctions”.
Dollar auctions are similar to English auctions, with the added complication of tracking the second-highest bidder.
The Complete Contract
dollar.sol
pragma solidity ^0.4.24;

import "../common/ierc20token.sol";

contract DollarAuction {
    address public seller;

    IERC20Token public token;
    uint256 public minIncrement;
    uint256 public timeoutPeriod;

    uint256 public auctionEnd;

    address public highBidder;
    uint256 public highBid;

    address public secondBidder;
    uint256 public secondBid;

    constructor(
        IERC20Token _token,
        uint256 _minIncrement,
        uint256 _timeoutPeriod
    )
        public
    {
        token = _token;
        minIncrement = _minIncrement;
        timeoutPeriod = _timeoutPeriod;

        seller = msg.sender;
        auctionEnd = now + timeoutPeriod;
        highBidder = seller;
    }

    mapping(address => uint256) public balanceOf;

    function withdraw() public {
        uint256 amount = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    event Bid(address highBidder, uint256 highBid);

    function bid(uint256 amount) public payable {
        require(now < auctionEnd);
        require(amount >= highBid+minIncrement);
        require(msg.sender != highBidder);

        balanceOf[msg.sender] += msg.value;

        uint256 increase = amount - secondBid;
        balanceOf[seller] += increase;
        balanceOf[secondBidder] += secondBid;
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        secondBid = highBid;
        secondBidder = highBidder;

        highBidder = msg.sender;
        highBid = amount;
        auctionEnd = now + timeoutPeriod;
        emit Bid(highBidder, amount);
    }

    function resolve() public {
        require(now >= auctionEnd);

        uint256 t = token.balanceOf(this);
        require(token.transfer(highBidder, t));
    }
}
← Writing a Penny Auction ContractImplementing Harberger Tax Deeds →
  