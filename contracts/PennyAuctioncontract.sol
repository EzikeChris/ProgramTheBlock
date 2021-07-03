Program the Blockchain	Archive About Subscribe
Writing a Penny Auction Contract
AUGUST 8, 2018 BY TODD PROEBSTING
This post will implement a bidding fee auction (aka “penny auction”) contract for ERC20 tokens. It will be a modest change to the English auction contract.

Penny auctions are an interesting twist on typical English auctions. In an English auction, bidders can bid any amount greater than the last high bid subject to some minimum increment. And, there is no fee to bid.

In a penny auction, bids are restricted to a fixed increment over the current high bid, and there is a fee to bid. Typically, the increments are small relative to the fee. For instance, the increment might be a penny and the fee a dollar.

Auction State
Like our English Auction contract, the penny auction contract will auction off tokens, and the auction ends after no bids have been received for a given timeout period.

Unlike the English auction, the penny auction collects a fee for each bid and enforces a fixed bid increment. This penny auction does not have a reserve price.

contract PennyAuction {
    address seller;

    IERC20Token public token;
    uint256 public bidIncrement;
    uint256 public timeoutPeriod;
    uint256 public bidFee;

    uint256 public auctionEnd;

    address public highBidder;
    uint256 public highBid;

    constructor(
        IERC20Token _token,
        uint256 _bidIncrement,
        uint256 _bidFee,
        uint256 _timeoutPeriod
    )
        public
    {
        token = _token;
        bidIncrement = _bidIncrement;
        bidFee = _bidFee;
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
Processing penny auction bids is straightforward:

event Bid(address highBidder, uint256 highBid);

function bid() public payable {
    require(now < auctionEnd);
    require(msg.sender != highBidder);

    balanceOf[msg.sender] += msg.value;

    require(balanceOf[msg.sender] >= highBid + bidIncrement + bidFee);

    balanceOf[seller] += bidIncrement + bidFee;
    balanceOf[highBidder] += highBid;
    balanceOf[msg.sender] -= highBid + bidIncrement + bidFee;

    highBid += bidIncrement;
    highBidder = msg.sender;
    auctionEnd = now + timeoutPeriod;
    emit Bid(highBidder, highBid);
}
A few notable things about the code above:

The bulk of the work is in adjusting the ether balances for the seller, the previous high bidder and the sender (new high bidder).
The ether adjustments transfer the increment and the fee to the seller, which means that ether is available for withdrawal immediately.
The contract doesn’t allow a bidder to bid against themselves.
Claiming Tokens
The winning bidder claims their tokens with resolve.

function resolve() public {
    require(now >= auctionEnd);

    uint256 t = token.balanceOf(this);
    require(token.transfer(highBidder, t));
}
Summary
Penny auctions are similar to English auctions with the addition of a bid fee and a fixed bid increment.
The English auction contract requires only slight modification to support a penny auction.
The Complete Contract
penny.sol
pragma solidity ^0.4.24;

import "./ierc20token.sol";

contract PennyAuction {
    address seller;

    IERC20Token public token;
    uint256 public bidIncrement;
    uint256 public timeoutPeriod;
    uint256 public bidFee;

    uint256 public auctionEnd;

    address public highBidder;
    uint256 public highBid;

    constructor(
        IERC20Token _token,
        uint256 _bidIncrement,
        uint256 _bidFee,
        uint256 _timeoutPeriod
    )
        public
    {
        token = _token;
        bidIncrement = _bidIncrement;
        bidFee = _bidFee;
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

    function bid() public payable {
        require(now < auctionEnd);
        require(msg.sender != highBidder);

        balanceOf[msg.sender] += msg.value;

        require(balanceOf[msg.sender] >= highBid + bidIncrement + bidFee);

        balanceOf[seller] += bidIncrement + bidFee;
        balanceOf[highBidder] += highBid;
        balanceOf[msg.sender] -= highBid + bidIncrement + bidFee;

        highBid += bidIncrement;
        highBidder = msg.sender;
        auctionEnd = now + timeoutPeriod;
        emit Bid(highBidder, highBid);
    }

    function resolve() public {
        require(now >= auctionEnd);

        uint256 t = token.balanceOf(this);
        require(token.transfer(highBidder, t));
    }
}
← Contracts Calling Arbitrary FunctionsWriting a Dollar Auction Contract →
  