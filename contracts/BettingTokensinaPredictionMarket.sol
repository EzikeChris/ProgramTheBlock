Program the Blockchain
Archive About Subscribe
Betting Tokens In A Prediction Market
JUNE 12, 2018 BY TODD PROEBSTING
This post will describe how to implement a prediction market where bets are for ERC20 tokens rather than ether.

My previous post on prediction markets supported betting ether. For some applications, it’s important to have the betting currency be ERC20 tokens, so I’m going to alter that previous implementation to accept tokens rather than ether. Note that it’s possible to wrap ether in a token, so this new contract will be strictly more general than the previous one.

Just like the previous prediction market contract, this contract will inherit the routines of the WagerBase contract, so all I need to do is to create the appropriate constructor and routines that accept and pay off bets. It’s a good idea to be familiar with that post before going further here.

Token-Based Prediction Market
Like the ether-based prediction market contract, this contract requires a proposition and possible outcomes. This contract also requires which ERC20 token will be the wagered token (as opposed to ether).

pragma solidity ^0.4.24;

import "wagerbase.sol";
import "ierc20token.sol";

contract TokenPredictionMarket is WagerBase {
    IERC20Token public wagertoken;

    constructor(
        string _proposition,
        bytes32[] _outcomes,
        bytes32[] _symbols,
        uint256 timeoutDelay,
        IERC20Token _wagertoken
    )
        // Just forward the parameters to the base constructor.
        WagerBase(_proposition, _outcomes, _symbols, timeoutDelay)
        public
    {
        wagertoken = _wagertoken;
    }
Buying Bundles
Outcome tokens are now bought in exchange for wagered tokens. The bettor must have approved the transfer of those wagered tokens prior to calling buyBundle:

function buyBundle(uint256 amount) public {
    require(wagertoken.transferFrom(msg.sender, address(this), amount),
        "failed wagertoken transfer");

    for (uint256 i = 0; i < outcomes.length; i++) {
        tokens[i].mint(msg.sender, amount);
    }
}
The bundle to tokens are minted for the purchase.

Refunding Bundles
Complete bundles of outcome tokens can be exchanged for wagered tokens. The bettor must approve the outcome tokens for transfer before calling refundBundle. Tokens representing each outcome are burned. The wagered tokens are transferred directly back to msg.sender.

function refundBundle(uint256 amount) public {
    for (uint256 i = 0; i < outcomes.length; i++) {
        tokens[i].burnFrom(msg.sender, amount);
    }

    require(wagertoken.transfer(msg.sender, amount),
        "failed wagertoken transfer");
}
Claiming Winnings
Once the contract is in the Resolved state, the winning tokens can be redeemed for wagered tokens. The bettor must have approved the transfer of the winning tokens prior to calling claim.

function claim() public {
    require(state == States.Resolved);

    uint256 amount = tokens[winningOutcome].balanceOf(msg.sender);
    tokens[winningOutcome].burnFrom(msg.sender, amount);

    require(wagertoken.transfer(msg.sender, amount),
        "failed wagertoken transfer");
}
Winning tokens are burned so that they may not be redeemed again.

Summary
Accepting a token is more general than accepting ether, because ether can be wrapped in an ERC20 token.
WagerBase is the basis for this token-wagering prediction market contract.
The bet-handling routines are nearly identical to their ether-handling cousins.
Full Source
wagertokenpredictionmarket.sol
pragma solidity ^0.4.24;

import "wagerbase.sol";
import "ierc20token.sol";

contract TokenPredictionMarket is WagerBase {
    IERC20Token public wagertoken;

    constructor(
        string _proposition,
        bytes32[] _outcomes,
        bytes32[] _symbols,
        uint256 timeoutDelay,
        IERC20Token _wagertoken
    )
        // Just forward the parameters to the base constructor.
        WagerBase(_proposition, _outcomes, _symbols, timeoutDelay)
        public
    {
        wagertoken = _wagertoken;
    }

    function buyBundle(uint256 amount) public {
        require(wagertoken.transferFrom(msg.sender, address(this), amount),
            "failed wagertoken transfer");

        for (uint256 i = 0; i < outcomes.length; i++) {
            tokens[i].mint(msg.sender, amount);
        }
    }

    function refundBundle(uint256 amount) public {
        for (uint256 i = 0; i < outcomes.length; i++) {
            tokens[i].burnFrom(msg.sender, amount);
        }

        require(wagertoken.transfer(msg.sender, amount),
            "failed wagertoken transfer");
    }

    function claim() public {
        require(state == States.Resolved);

        uint256 amount = tokens[winningOutcome].balanceOf(msg.sender);
        tokens[winningOutcome].burnFrom(msg.sender, amount);

        require(wagertoken.transfer(msg.sender, amount),
            "failed wagertoken transfer");
    }
}
← Reversible EtherSupporting an Off-Chain Market Maker →
  