Program the Blockchain	Archive About Subscribe
Writing a Token Auction Contract
MARCH 20, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a smart contract that will auction off ERC20 tokens to the highest bidder. The post assumes you are familiar with techniques for how a contract deals with an ERC20 token contract, which we covered in our token sale post. The post will briefly touch on some of the challenges around conducting auctions on the blockchain.

There are many kinds of auctions, and this post will describe a contract that implements an English auction: bidders will alternate making higher and higher bids until there are no more bids, at which time the highest bid will be accepted in return for the good being sold.

Starting the Auction
An auction is typically parameterized by a few values:

The good being sold. For this contract, that will be a given ERC20 token.
The reserve price is the lowest acceptable bid.
The minimum increment is the smallest amount that each successive bid must increase by.
The timeout period is the amount of time that bidders have after a successful bid to make a new bid. If no successful bids are made during that period, then the auction terminates.
These values are easily captured in code:

pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract EnglishAuction {
    address seller;

    IERC20Token public token;
    uint256 public reservePrice;
    uint256 public minIncrement;
    uint256 public timeoutPeriod;

    uint256 public auctionEnd;

    function EnglishAuction(
        IERC20Token _token,
        uint256 _reservePrice,
        uint256 _minIncrement,
        uint256 _timeoutPeriod
    )
        public
    {
        token = _token;
        reservePrice = _reservePrice;
        minIncrement = _minIncrement;
        timeoutPeriod = _timeoutPeriod;

        seller = msg.sender;
        auctionEnd = now + timeoutPeriod;
    }

    // more to come...
}
The contract must, of course, keep track of who the seller is, which the constructor sets.

For simplicity, I am assuming that the auction starts immediately upon creation, so the original auctionEnd is set timeoutPeriod in the future.

This contract will operate on the assumption that the seller will transfer the tokens to it. The seller’s transfer is not part of the contract itself, however, and must be done after contract deployment. Bidders can check that the transfer has been done by querying the token’s balanceOf value that corresponds to the contract’s address. It is essential that bidders check this value so that they know how many tokens are guaranteed to be transferred to the winner.

Escrowed Funds
In a real-world auction, bidders are typically trusted to actually buy the auctioned good if they win the auction. Smart contracts, on the other hand, don’t typically trust participants to make good on their promises. Therefore, my auction contract will demand that all bids come with ether attached that will be used if the bid wins.

Escrowed bids guarantee that the funds are available for the winner to pay, but they complicate the smart contract because now losing bidders must be able to recover their escrowed funds. I will implement this with the simple pattern introduced in the banking post.

address highBidder;

mapping(address => uint256) public balanceOf;

function withdraw() public {
    require(msg.sender != highBidder);

    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
The balanceOf mapping tracks the ether available to be withdrawn by any account, and withdraw transfers that amount. The function does not allow withdrawals from the current high bidder because their funds are escrowed.

Note that the code does not check to see if the auction is over—losing bidders may withdraw their funds at any time.

Bids
A successful bid must meet the following requirements:

It must be made before the end of the auction.
It must be at least the reserve amount.
It must be at least the minimum increment over the current high bid. (Before any bids have been accepted, the high bid is considered to be zero.)
Bids must have ether attached. The bid function will assume that the bidder is bidding all the attached ether and any previously escrowed funds.

event Bid(address highBidder, uint256 highBid);

function bid(uint256 amount) public payable {
    require(now < auctionEnd);
    require(amount >= reservePrice);
    require(amount >= balanceOf[highBidder]+minIncrement);

    balanceOf[msg.sender] += msg.value;
    require(balanceOf[msg.sender] == amount);

    highBidder = msg.sender;

    auctionEnd = now + timeoutPeriod;

    emit Bid(highBidder, amount);
}
The amount parameter is not strictly necessary, but I’ve put it there to protect bidders from making mistakes regarding the sum of the attached ether and escrowed ether. The amount declares their intended bid.

One subtlety is that balanceOf[highBidder] is the amount of the high bid.

Auction End
An auction finishes in one of two states: with or without a winning bid. If the auction was unsuccessful, then the tokens need to be returned to the seller. Otherwise, the tokens need to be transferred to the winning bidder and the winning bid needs to be made available to the seller.

function resolve() public {
    require(now >= auctionEnd);

    uint256 t = token.balanceOf(this);
    if (highBidder == 0) {
        require(token.transfer(seller, t));
    } else {
        // transfer tokens to high bidder
        require(token.transfer(highBidder, t));

        // transfer ether balance to seller
        balanceOf[seller] += balanceOf[highBidder];
        balanceOf[highBidder] = 0;

        highBidder = 0;
    }
}
There are a few notable things about resolve:

The function did not try to transfer ether directly to the seller. That avoids potential problems if the seller is a badly behaving contract, which might prevent the high bidder from ever getting their tokens.
The function did not try to transfer ether to the seller via selfdestruct. This is because there may still be losing bidders who have not yet retrieved their funds.
Anybody can call resolve—it’s not limited to the seller or winning bidder.
The highBidder is set to zero to allow the seller to withdraw funds if they won their own auction. It also reduces gas costs.
If this contract used the indirect approve/transferFrom pattern, the resolve would have been more complicated because it would have required logic to refund ether to the winning bidder in the case where transferFrom fails due to lack of approval.

Summary
A smart contract can conduct an English auction.
To ensure payment, bids must include an advance payment, which can be refunded should the bid not prevail.
The Complete Contracts
englishauction.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract EnglishAuction {
    address seller;

    IERC20Token public token;
    uint256 public reservePrice;
    uint256 public minIncrement;
    uint256 public timeoutPeriod;

    uint256 public auctionEnd;

    function EnglishAuction(
        IERC20Token _token,
        uint256 _reservePrice,
        uint256 _minIncrement,
        uint256 _timeoutPeriod
    )
        public
    {
        token = _token;
        reservePrice = _reservePrice;
        minIncrement = _minIncrement;
        timeoutPeriod = _timeoutPeriod;

        seller = msg.sender;
        auctionEnd = now + timeoutPeriod;
    }

    address highBidder;

    mapping(address => uint256) public balanceOf;

    function withdraw() public {
        require(msg.sender != highBidder);

        uint256 amount = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    event Bid(address highBidder, uint256 highBid);

    function bid(uint256 amount) public payable {
        require(now < auctionEnd);
        require(amount >= reservePrice);
        require(amount >= balanceOf[highBidder]+minIncrement);

        balanceOf[msg.sender] += msg.value;
        require(balanceOf[msg.sender] == amount);

        highBidder = msg.sender;

        auctionEnd = now + timeoutPeriod;

        emit Bid(highBidder, amount);
    }

    function resolve() public {
        require(now >= auctionEnd);

        uint256 t = token.balanceOf(this);
        if (highBidder == 0) {
            require(token.transfer(seller, t));
        } else {
            // transfer tokens to high bidder
            require(token.transfer(highBidder, t));

            // transfer ether balance to seller
            balanceOf[seller] += balanceOf[highBidder];
            balanceOf[highBidder] = 0;

            highBidder = 0;
        }
    }
}
← Flipping a Coin in EthereumStorage Patterns: Stacks Queues and Deques →
  