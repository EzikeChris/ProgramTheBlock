Program the Blockchain
Archive About Subscribe
Writing a Prediction Market Contract
MAY 22, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a smart contract that implements a prediction market. The contract will leverage much of the logic in my token-based parimutuel betting contract.

Token-Based Design
A prediction market is a way to bet on a future event by creating “contingent securities” that represent the possible outcomes. Once the outcome is determined, shares of the correct security have a predetermined value and the rest of the securities are worthless. An example will help.

A prediction market could be set up to forecast which NFL football team will win the Super Bowl. For this, there would be be 32 different securities, with each NFL team associated with shares of its own security. Bettors would buy and sell shares of these securities knowing that only the shares of a single security will have value. For all of my examples, I will assume that a winning share is worth 1 ETH.

The simplest prediction markets rely on three ideas:

Bettors can buy a “bundle” that consists of an equal number of shares of every security. If a winning share is worth 1 ETH, then a bundle containing one share of every security costs 1 ETH. Note that this exchange is perfect in the sense that the prediction market collects 1 ETH per bundle and will ultimately owe exactly 1 ETH for the share of the winning security/outcome.
Bettors can buy and sell individual shares at mutually agreed upon prices.
Once the outcome is known, bettors can redeem winning shares for 1 ETH.
Similarities to Token-Based Parimutuel Wagering
Prediction markets and parimutuel wagering have a lot in common and only a few differences:

Both are parameterized by the same values: a proposition and a number of possible outcomes.
Both can be in the same Open, Closed, Resolved or Cancelled states.
Both can have outcomes represented by ERC20 tokens.
Both ultimately reward only one token.
In parimutuel betting, outcome tokens are bought individually from the contract. In prediction markets, complete bundles are bought from the contract.
In parimutuel betting, payoffs have a modestly complex computation based on proportional ownership of tokens. In prediction markets, the payoff is 1:1 (ether to tokens).
Basically, everything from the token-based parimutuel post can be reused for a prediction market contract except for the routines that handle ether: bet, claim, and refund. I have put all the common code in a base contract called WagerBase, which is included at the end of this post. I will describe the new ether-handling routines for a prediction market fully.

Buying Bundles
Bettors buy complete bundles, 1:1 for the ether provided:

function buyBundle() public payable {
    for (uint256 i = 0; i < outcomes.length; i++) {
        tokens[i].mint(msg.sender, msg.value);
    }
}
Note that buyBundle does not need to be limited to the Open state. This is because every outcome is being purchased, and the winning token will only pay 1:1, so there’s no way to gain an advantage by buying late.

Refunding Bundles
Bettors can also sell complete bundles back to the contract:

function refundBundle(uint256 amount) public {
    for (uint256 i = 0; i < outcomes.length; i++) {
        tokens[i].burnFrom(msg.sender, amount);
    }
    msg.sender.transfer(amount);
}
Note that refundBundle is also not limited to any particular contract state (e.g., Open, Closed, etc.).

The ability to refund complete bundles is helpful to bettors who might bet on different outcomes as the prices of the underlying tokens change. In the process of doing that, they might find themselves with complete bundles and not want to wait until the market is resolved to cash in on those complete bundles.

Claiming Winnings
After the proposition has been resolved, winning tokens can be redeemed 1:1 for ether:

function claim() public {
    require(state == States.Resolved);

    uint256 amount = tokens[winningOutcome].balanceOf(msg.sender);
    tokens[winningOutcome].burnFrom(msg.sender, amount);
    msg.sender.transfer(amount);
}
Cancellations
If a prediction market is cancelled, participants should be able to get a refund for their purchased tokens. A complete bundle always has a clear value, but what about individual tokens that aren’t part of a bundle? I see three options for how to handle this:

Don’t do anything special. Complete bundles can already be refunded. Bettors can always cooperate to create complete bundles that can be refunded, and they will have an incentive to do so.
Refund proportionally. A simple scheme would be to provide refunds based on an equal division. If there are N outcomes, then each token can be refunded for 1/N ETH.
Designate a Cancellation Outcome. The contract creator could designate particular token as the “Cancellation Token” and resolve the contract in favor of that token. This means that cancellation would simply be another outcome that bettors could choose to bet on.
I’ve chosen to do nothing special. Bettors can still get refunds with a little cooperation, and this option is the easiest to implement correctly.

Summary
Prediction markets can be implemented with ERC20 tokens.
Prediction markets and token-based parimutuel wagering are very similar and can share a great deal of code.
The Complete Contracts
prediction.sol
pragma solidity ^0.4.23;

import "wagerbase.sol";

contract PredictionMarket is WagerBase {
    constructor(
        string _proposition,
        bytes32[] _outcomes,
        bytes32[] _symbols,
        uint256 timeoutDelay
    )
        // Just forward the parameters to the base constructor.
        WagerBase(_proposition, _outcomes, _symbols, timeoutDelay)
        public
    {
    }

    function buyBundle() public payable {
        for (uint256 i = 0; i < outcomes.length; i++) {
            tokens[i].mint(msg.sender, msg.value);
        }
    }

    function refundBundle(uint256 amount) public {
        for (uint256 i = 0; i < outcomes.length; i++) {
            tokens[i].burnFrom(msg.sender, amount);
        }
        msg.sender.transfer(amount);
    }

    function claim() public {
        require(state == States.Resolved);

        uint256 amount = tokens[winningOutcome].balanceOf(msg.sender);
        tokens[winningOutcome].burnFrom(msg.sender, amount);
        msg.sender.transfer(amount);
    }
}
wagerbase.sol
pragma solidity ^0.4.23;

import "mintabletoken.sol";

contract WagerBase {
    address public owner;

    string public proposition;
    bytes32[] public outcomes;
    bytes32[] public symbols;
    uint256 public timeout;
    MintableToken[] public tokens;

    constructor(
        string _proposition,
        bytes32[] _outcomes,
        bytes32[] _symbols,
        uint256 timeoutDelay
    )
        public
    {
        owner = msg.sender;
        proposition = _proposition;
        outcomes = _outcomes;
        symbols = _symbols;
        timeout = now + timeoutDelay;

        for (uint256 i = 0; i < _outcomes.length; i++) {
            tokens.push(new MintableToken(0, 18, toString(_outcomes[i]),
                toString(_symbols[i])));
        }
    }

    function toString(bytes32 b) internal pure returns (string) {
        // Convert a null-terminated bytes32 to a string.

        uint256 length = 0;
        while (length < 32 && b[length] != 0) {
            length += 1;
        }

        bytes memory bytesString = new bytes(length);
        for (uint256 j = 0; j < length; j++) {
            bytesString[j] = b[j];
        }

        return string(bytesString);
    }

    enum States { Open, Closed, Resolved, Cancelled }
    States state = States.Open;

    uint256 winningOutcome;

    function close() public {
        require(state == States.Open);
        require(msg.sender == owner);

        state = States.Closed;
    }

    function resolve(uint256 _winningOutcome) public {
        require(state == States.Closed);
        require(msg.sender == owner);

        winningOutcome = _winningOutcome;
        state = States.Resolved;
    }

    function cancel() public {
        require(state != States.Resolved);
        require(msg.sender == owner || now > timeout);

        state = States.Cancelled;
    }

    function outcomeCount() public view returns (uint256) {
        return outcomes.length;
    }
}
← Using Tokens for Parimutuel WagersWrapping Ether in an ERC20 Token →
  