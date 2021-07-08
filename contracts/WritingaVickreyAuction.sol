Program the Blockchain
Archive About Subscribe
Writing a Vickrey Auction Contract
APRIL 3, 2018 BY TODD PROEBSTING
This post will demonstrate how to implement a Vickrey auction. The post assumes you are familiar with techniques introduced in my post on sealed-bid auctions.

Without going into a lot of detail, there are many advantages to auctions in which the amount paid by the winner is not their bid, but rather the next highest bid. Such auctions are often called “second-price auctions” or “Vickrey auctions” (after the person who studied them).

Initialization, Bidding and Claiming Tokens
With the exception of determining the final selling price, implementing a second-price auction is essentially the same as implementing a first-price sealed-bid auctions. The following are identical:

Both auctions are parameterized by the same values: the token, the reserve price, a bidding period, and a revealing period.
Both auctions accept secret bids that are hashes of the actual bid and a random nonce.
Both auctions require attached ether that is at least as great as the secret bid.
pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract VickreyAuction {
    address seller;

    IERC20Token public token;
    uint256 public reservePrice;
    uint256 public endOfBidding;
    uint256 public endOfRevealing;

    address public highBidder;
    uint256 public highBid;
    uint256 public secondBid;

    mapping(address => bool) public revealed;

    function VickreyAuction(
        IERC20Token _token,
        uint256 _reservePrice,
        uint256 biddingPeriod,
        uint256 revealingPeriod
    )
        public
    {
        token = _token;
        reservePrice = _reservePrice;

        endOfBidding = now + biddingPeriod;
        endOfRevealing = endOfBidding + revealingPeriod;

        seller = msg.sender;

        highBidder = seller;
        highBid = reservePrice;
        secondBid = reservePrice;

        // the seller can't bid, but this simplifies withdrawal logic
        revealed[seller] = true;
    }

    // more code here
}
The storage variables and constructor above are straightforward and similar to the sealed bid auction with just a few additions:

Storage variables for the highest and second-highest bids are declared and initialized. They are both initialized to the reserve price. These phony starting values simplify maintaining these values correctly as bids are revealed.
The revealed mapping keeps track of which accounts have revealed their bids.
The code initializes revealed[seller] to true, which will be exploited later in the withdrawal code.
The code for accepting sealed bids and that for claiming tokens is nearly identical to the analogous code in the sealed-bid auction:

mapping(address => uint256) public balanceOf;
mapping(address => bytes32) public hashedBidOf;

function bid(bytes32 hash) public payable {
    require(now < endOfBidding);
    require(msg.sender != seller);

    hashedBidOf[msg.sender] = hash;
    balanceOf[msg.sender] += msg.value;
    require(balanceOf[msg.sender] >= reservePrice);
}

function claim() public {
    require(now >= endOfRevealing);

    uint256 t = token.balanceOf(this);
    require(token.transfer(highBidder, t));
}
The bid code rejects bids from the seller, which eliminates the possibility that the seller can make a strategic bid, not reveal the bid, and yet get the associated ether refunded. This possibility would have existed because the contract’s constructor initialized revealed[seller] to true despite no actual revelation taking place.

Revelation
Any contract that has a reveal phase must deal with failures to reveal, either implicitly or explicitly. It’s important that the contract enforce the desired policy.

In the sealed-bid auction, the ether attached to unrevealed bids was simply refunded to the bidder. For the Vickrey auction contract, I will implement a much stricter policy—only ether attached to revealed losing bids will be refunded. Ether attached to unrevealed bids will be forfeited forever. This gives bidders a strong incentive to reveal their bids. It also gives the seller a strong disincentive from submitting phony bids (via another account) to manipulate the final settling price.

During the revelation period, the Vickrey auction must track both the highest bid (and bidder) as well as the second highest bid. As each bid is processed, the contract will transfer ether balances (in balanceOf) to reflect the results of the bidding so far. Those transfers will be done with the transfer helper routine:

function transfer(address from, address to, uint256 amount) private {
    balanceOf[to] += amount;
    balanceOf[from] -= amount;
}
The contract tracks which accounts have revealed their bids in revealed. Bidders are only allowed to reveal their bid once. This restriction avoids having to reason about the correctness of the code in the event of repeated reveals. Forbidding something is easier than reasoning about it.

function reveal(uint256 amount, uint256 nonce) public {
    require(now >= endOfBidding && now < endOfRevealing);

    require(keccak256(amount, nonce) == hashedBidOf[msg.sender]);

    require(!revealed[msg.sender]);
    revealed[msg.sender] = true;

    if (amount > balanceOf[msg.sender]) {
        // insufficient funds to cover bid amount, so ignore it
        return;
    }

    if (amount >= highBid) {
        // undo the previous escrow
        transfer(seller, highBidder, secondBid);

        // update the highest and second highest bids
        secondBid = highBid;
        highBid = amount;
        highBidder = msg.sender;

        // escrow an amount equal to the second highest bid
        transfer(highBidder, seller, secondBid);
    } else if (amount > secondBid) {
        // undo the previous escrow
        transfer(seller, highBidder, secondBid);

        // update the second highest bid
        secondBid = amount;

        // escrow an amount equal to the second highest bid
        transfer(highBidder, seller, secondBid);
   }
}
After every call to reveal, the following invariants hold:

balanceOf[X] represents the ether amount account X will be able withdraw given the bids seen so far.
highBidder represents the account making the highest bid given the bids seen so far. (If there were no successful bids, then this has the default value, which is the seller’s account.)
highBid represents the highest amount bid given the bids seen so far. (If there have been no successful bids, then this represents its default value, which is the reserve price.)
secondBid represents the amount that the high bidder will pay given the bids seen so far. (If there have been no successful bids, then this represents its default value, which is the reserve price.)
The initialization of highBid and secondBid to the reserve price is a subtle technique, and it deserves some explanation for the possible cases:

If there are no revealed bids at or above the reserve price, then reveal has no effect. This means highBidder will still be the seller’s account, and therefore the seller can withdraw their tokens.
If there is exactly one revealed bid at or above the reserve price, then highBid will be equal to that amount, and the amount paid will be the reserve price. This is the correct behavior for a Vickrey auction. (Note that the “undo the previous escrow” has no effect here because highBidder was initialized to seller, so the secondBid amount is added and subtracted from the same entry in balanceOf.)
If there is more than one revealed bid at or above the reserve price, then highBid will be the highest bid, and secondBid will be the second highest bid. The amount paid will be the second highest, which is correct as well.
Withdrawal
Withdrawal is nearly identical to the sealed-bid auction. The only change is that we require that a bidder have revealed their bid.

function withdraw() public {
    require(now >= endOfRevealing);
    require(revealed[msg.sender]);

    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
Note that the constructor initialized revealed[seller] to true in anticipation of the seller withdrawing their ether after the auction.

Summary
This Vickrey auction contract uses the previously demonstrated techniques of using hashes for secrets, and attaching ether to secret bids.
To encourage bid revelation, the contract causes non-revealers to forfeit their ether.
Maintaining the highest and second highest bids is straightforward, although initializing them to the reserve price is subtle.
The Complete Contracts
vickreyauction.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract VickreyAuction {
    address seller;

    IERC20Token public token;
    uint256 public reservePrice;
    uint256 public endOfBidding;
    uint256 public endOfRevealing;

    address public highBidder;
    uint256 public highBid;
    uint256 public secondBid;

    mapping(address => bool) public revealed;

    function VickreyAuction(
        IERC20Token _token,
        uint256 _reservePrice,
        uint256 biddingPeriod,
        uint256 revealingPeriod
    )
        public
    {
        token = _token;
        reservePrice = _reservePrice;

        endOfBidding = now + biddingPeriod;
        endOfRevealing = endOfBidding + revealingPeriod;

        seller = msg.sender;

        highBidder = seller;
        highBid = reservePrice;
        secondBid = reservePrice;

        // the seller can't bid, but this simplifies withdrawal logic
        revealed[seller] = true;
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => bytes32) public hashedBidOf;

    function bid(bytes32 hash) public payable {
        require(now < endOfBidding);
        require(msg.sender != seller);

        hashedBidOf[msg.sender] = hash;
        balanceOf[msg.sender] += msg.value;
        require(balanceOf[msg.sender] >= reservePrice);
    }

    function claim() public {
        require(now >= endOfRevealing);

        uint256 t = token.balanceOf(this);
        require(token.transfer(highBidder, t));
    }

    function transfer(address from, address to, uint256 amount) private {
        balanceOf[to] += amount;
        balanceOf[from] -= amount;
    }

    function reveal(uint256 amount, uint256 nonce) public {
        require(now >= endOfBidding && now < endOfRevealing);

        require(keccak256(amount, nonce) == hashedBidOf[msg.sender]);

        require(!revealed[msg.sender]);
        revealed[msg.sender] = true;

        if (amount > balanceOf[msg.sender]) {
            // insufficient funds to cover bid amount, so ignore it
            return;
        }

        if (amount >= highBid) {
            // undo the previous escrow
            transfer(seller, highBidder, secondBid);

            // update the highest and second highest bids
            secondBid = highBid;
            highBid = amount;
            highBidder = msg.sender;

            // escrow an amount equal to the second highest bid
            transfer(highBidder, seller, secondBid);
        } else if (amount > secondBid) {
            // undo the previous escrow
            transfer(seller, highBidder, secondBid);

            // update the second highest bid
            secondBid = amount;

            // escrow an amount equal to the second highest bid
            transfer(highBidder, seller, secondBid);
       }
    }

    function withdraw() public {
        require(now >= endOfRevealing);
        require(revealed[msg.sender]);

        uint256 amount = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}
← Storage Patterns: Doubly Linked ListCapture the Ether: the Game of Smart Contract Security →
  