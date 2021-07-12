Program the Blockchain	Archive About Subscribe
Writing a Sealed-Bid Auction Contract
MARCH 27, 2018 BY TODD PROEBSTING
This post will demonstrate how to implement a first-price sealed-bid auction of ERC20 tokens. The post assumes you are familiar with techniques introduced in our posts on English auctions and revealing secrets.

First-price sealed-bid auctions proceed in a three-step process:

During a bidding period, each bidder submits a secret bid.
After the bidding period, all of the previously-secret bids are revealed.
The high bidder wins the auction in exchange for their entire bid amount.
To implement this as a smart contract, the code will follow that process, employing techniques we’ve previously introduced. For instance, the contract will use cryptographic hashes to submit secret bids.

We also want bids to have ether attached to ensure that the winning bid will, in fact, follow through with the purchase. This presents a challenge, however, because the amount of ether attached is not a secret on the blockchain. Therefore, the contract will require that bids have ether attached that equals or exceeds their secret bid.

Starting the Auction
A first-price sealed-bid auction is parameterized by a few values:

The good being sold. For this contract, that will be a given ERC20 token.
The reserve price is the lowest acceptable bid.
The bidding period is the amount of time during which bidders may submit bids.
In a real-world auction, bidders submit bids in sealed envelopes, and those bids are revealed by opening envelopes, which doesn’t require any cooperation from the bidders. In Ethereum, a bidder submits a hash of their bid, and then they must present the actual bid, which is verified against the hash they previously provided. Hence, the contract needs to give them some time to do that. To implement this as a smart contract, we also need another parameter:

The reveal period is the amount of time after the bidding closes that bidders can reveal their bids.
These values are easily captured in code:

pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract EnglishAuction {
    address seller;

    IERC20Token public token;
    uint256 public reservePrice;
    uint256 public endOfBidding;
    uint256 public endOfRevealing;

    function EnglishAuction(
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
    }

    // more to come...
}
Just like the English auction, this contract will operate on the assumption that the seller will transfer the tokens to it. Bidders should verify the transfer before placing bids, of course.

Bids and Escrowed Funds
Bidding requires the contract to log both the sealed bid (hash) and the amount of ether attached to the bid.

mapping(address => uint256) public balanceOf;
mapping(address => bytes32) public hashedBidOf;

function bid(bytes32 hash) public payable {
    require(now < endOfBidding);

    hashedBidOf[msg.sender] = hash;
    balanceOf[msg.sender] += msg.value;
    require(balanceOf[msg.sender] >= reservePrice);
}
A real-world sealed-bid auction typically allows only one bid. I’ve generalized that above to allow new bids that overwrite previous bids. All attached ether to multiple bids is accumulated.

Revealing Bids
The hash of a bid is computed with a random nonce exactly as introduced in the coin-flipping post. Bidders reveal their bids by providing both their bid and their nonce.

As bids are revealed, the contract will keep track of the high bidder and their bid, and it will adjust the balanceOf amounts so that it tracks non-escrowed ether. The current winning bid will also be reflected as the balanceOf[seller] so that it will be available to the seller after the auction.

address public highBidder = msg.sender;
uint256 public highBid;

function reveal(uint256 amount, uint256 nonce) public {
    require(now >= endOfBidding && now < endOfRevealing);

    require(keccak256(amount, nonce) == hashedBidOf[msg.sender]);

    require(amount >= reservePrice);
    require(amount <= balanceOf[msg.sender]);

    if (amount > highBid) {
        // return escrowed bid to previous high bidder
        balanceOf[seller] -= highBid;
        balanceOf[highBidder] += highBid;

        highBid = amount;
        highBidder = msg.sender;

        // transfer new high bid from high bidder to seller
        balanceOf[highBidder] -= highBid;
        balanceOf[seller] += highBid;
    }
}
The code above maintains the following invariants upon exit, which make withdrawing funds and claiming tokens trivial:

balanceOf[seller] represents the amount the seller will be able to withdraw given the bids seen so far.
balanceOf[X] represents the ether amount account X will be able withdraw given the bids seen so far.
highBidder represents the account making the highest bid given the bids seen so far.
Given those invariants, when revealing completes, all accounts—seller and bidders—may withdraw their balanceOf amount.

The code also employs one (very?) subtle feature: highBidder is initialized to msg.sender, which is the account that creates the auction (i.e, the seller). This default value is overwritten by the first successful bid, so it’s only important if there are no successful bids on this auction. This will be exploited below in claim.

The bid code allows seller-initiated bids, and reveal handles them correctly. It’s generally considered bad for sellers to bid in their own auction, but I’ve chosen to allow them because forbidding them would be futile. (It would be trivial for the seller to transfer ether to another account and bid from there.)

Withdrawal
function withdraw() public {
    require(now >= endOfRevealing);

    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
Claiming
After the reveal period, the high bidder can claim their tokens:

function claim() public {
    require(now >= endOfRevealing);

    uint256 t = token.balanceOf(this);
    token.transfer(highBidder, t);
}
This routine trivially handles any auction for which there was a successful bid. More subtly, it also handles returning the tokens to the seller when there are no successful bids because highBidder’s default value is, in fact, that of the seller.

The high bidder can also claim any excess ether—the difference between their bid and the amount attached to the bid(s)—using withdraw.

Failing to Reveal Policy
Any contract that has a reveal phase must deal with failures to reveal, either implicitly or explicitly. It’s important that the contract enforce the desired policy.

As written, this contract does nothing explicit with respect to accounts that fail to reveal their bids.

What happens to the ether that was attached to an unrevealed bids? Ether attached to an unrevealed bid can be withdrawn after the revealing period—just as if it were attached to a losing bid.
What if the unrevealed bid would have won the auction? This is bad for the seller, obviously, because they would receive less ether. The bidder, too, suffers because they don’t get to claim the tokens at a price that they presumably would have wanted.
Can this be exploited by strategic bidding? Yes—a bidder could make multiple bids at different prices and only reveal the lowest winning bid. This is not entirely bad because they would still have to beat the bids revealed by other bidders. This strategy has merits because it allows this auction to result in a winning bid approximating a second-price auction. (It does, however, require the strategic bidder to use multiple accounts and to escrow ether for each of those bids.)
Summary
A smart contract can conduct a first-price sealed-bid auction.
The auction uses cryptographic hashes to implement sealed bids.
The Complete Contract
sealedbidauction.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract SealedBidAuction {
    address seller;

    IERC20Token public token;
    uint256 public reservePrice;
    uint256 public endOfBidding;
    uint256 public endOfRevealing;

    function SealedBidAuction(
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
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => bytes32) public hashedBidOf;

    function bid(bytes32 hash) public payable {
        require(now < endOfBidding);

        hashedBidOf[msg.sender] = hash;
        balanceOf[msg.sender] += msg.value;
        require(balanceOf[msg.sender] >= reservePrice);
    }

    address public highBidder = msg.sender;
    uint256 public highBid;

    function reveal(uint256 amount, uint256 nonce) public {
        require(now >= endOfBidding && now < endOfRevealing);

        require(keccak256(amount, nonce) == hashedBidOf[msg.sender]);

        require(amount >= reservePrice);
        require(amount <= balanceOf[msg.sender]);

        if (amount > highBid) {
            // return escrowed bid to previous high bidder
            balanceOf[seller] -= highBid;
            balanceOf[highBidder] += highBid;

            highBid = amount;
            highBidder = msg.sender;

            // transfer new high bid from high bidder to seller
            balanceOf[highBidder] -= highBid;
            balanceOf[seller] += highBid;
        }
    }

    function withdraw() public {
        require(now >= endOfRevealing);

        uint256 amount = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function claim() public {
        require(now >= endOfRevealing);

        uint256 t = token.balanceOf(this);
        token.transfer(highBidder, t);
    }
}
← Storage Patterns: Stacks Queues and DequesStorage Patterns: Doubly Linked List →
  