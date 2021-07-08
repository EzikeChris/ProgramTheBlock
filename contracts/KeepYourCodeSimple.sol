Program the Blockchain
Archive About Subscribe
Keep Your Code Simple
APRIL 17, 2018 BY STEVE MARX
This post will explain the importance of writing simple code in the context of smart contracts, where bugs can be very expensive.

Achieving Correctness
Perhaps it goes without saying, but a bug in a smart contract can have serious consequences. The Parity multisig wallet initialization bug alone is estimated to have frozen over $150 million dollars worth of ether. The DAO hack put $50 million dollars in jeopardy and led to the creation of the Ethereum Classic fork.

Anyone who has written code before knows that writing bug-free code is no small feat. One of my favorite quotes about this challenge comes from renowned computer scientist Tony Hoare:

There are two ways of constructing a software design: One way is to make it so simple that there are obviously no deficiencies, and the other way is to make it so complicated that there are no obvious deficiencies. The first method is far more difficult.

–TONY HOARE, 1980

The Withdraw Pattern: a Case Study
When transferring ether from a smart contract, a common pattern is “the withdraw pattern.” Rather than transfer ether immediately, the ether is made available for future withdrawal by the recipient.

The reason for this pattern is that transfers can fail, and it’s a good example of how to simplify your code to avoid bugs. Consider the bid function of an auction contract that doesn’t use the withdraw pattern:

// Don't do this!
function bid() public payable {
    require(msg.value > highBid);

    // Return bid to previous high bidder.
    highBidder.transfer(highBid);

    highBidder = msg.sender;
    highBid = msg.value;
}
This function is simple, but it has a well-known vulnerability. The high bidder can be a smart contract that refuses incoming ether. This means the transfer call will fail, and the bidder can never be beaten no matter how low their bid.

It’s tempting to fix this by using send, which returns a boolean status rather than reverting on failure. Replacing transfer with send in the previous code would mean a failure is ignored:

// Don't do this either!

// Return bid to previous high bidder, ignoring failures.
highBidder.send(highBid);
It seems at first like this takes care of the problem, because a high bidder causing a failure is only hurting themselves. However, this is heading down the path of “so complicated that there are no obvious deficiencies.” The code itself isn’t terribly complicated, but reasoning about it is. Someone reading the code needs to consider all the ways send can fail and what happens in those cases.

There’s a flaw in the send version of the code. The recipient of the send isn’t the only one who can cause the transfer to fail. The new bidder can, for example, create a deep call stack before calling bid. When the maximum stack depth is exceeded, the transfer will fail and the previous high bidder will not receive their ether.

Okay, things are getting a bit more complicated. This version detects a failed transfer and makes the funds available for explicit withdrawal by the recipient later:

// Maybe this works?

mapping(address => uint256) balances;

function bid() public payable {
    require(msg.value > highBid);

    // Return bid to previous high bidder.
    if (!highBidder.send(highBid)) {
        // If ether wasn't transferred, keep track of it.
        balances[highBidder] += highBid;
    }

    highBidder = msg.sender;
    highBid = msg.value;
}

// This is used to withdraw funds when a transfer fails.
function withdraw() public {
    // Follow the Checks-Effects-Interactions pattern.
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;
    msg.sender.transfer(amount);
}
At this point, I believe that the code is correct. Ether is either transferred during the bid process or it’s tracked in balances for later withdraw. I’ve corrected the code, but I’ve made the code more complicated. Not all corrections are equal, and it’s important not to settle for a complicated solution like this.

The following code is simpler. Rather than use two different code paths for success and failure, all transfers happen the same way in the same place:

// Withdraw pattern

mapping(address => uint256) balances;

function bid() public payable {
    require(msg.value > highBid);

    // Return bid to previous high bidder.
    balances[highBidder] += highBid;

    highBidder = msg.sender;
    highBid = msg.value;
}

function withdraw() public {
    // Follow the Checks-Effects-Interactions pattern.
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;
    msg.sender.transfer(amount);
}
All interaction with other contracts/accounts is in a single withdraw function, where I’m confident the Checks-Effects-Interactions pattern keeps me safe from reentrancy attacks.

Less Thinking
Making your code “so simple that there are obviously no deficiencies” is not just about making the code shorter or having fewer functions. Note that the final version of the code above is longer and has more functions than the original. The key is that it’s easier to reason about. I get to think less, which gives me a better chance of getting things right.

A place where we recently got this wrong was in our post on Flipping a Coin in Ethereum. I thought it was interesting that claimTimeout could be called by anyone after the expiration time passed, but an astute reader pointed out that because expiration (at the time) was initially 0, claimTimeout could be called as soon as the contract was created. This would result in the first player losing their ether. The code is now fixed, but it would have been better to just restrict who could call claimTimeout. Then I wouldn’t have to think about the various cases at all.

We did better in our recent post on Vickrey auctions, where we forbade bidding by the seller to avoid unnecessary complications.

Resources
The Solidity documentation covers two patterns used in this post:

the withdraw pattern
the Checks-Effects-Interactions pattern
The quote from Tony Hoare comes from his 1980 Turing Award Lecture The Emperor’s Old Clothes.

← Writing a Pawnshop Bazaar ContractStorage Patterns: Pagination →
  