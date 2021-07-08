Program the Blockchain
Archive About Subscribe
Supporting an Off-Chain Market Maker
JUNE 16, 2018 BY TODD PROEBSTING
This post will implement a token-trading “market maker” that will fulfill multiple signed prediction market wagers simultaneously. It will be a modest change to the clearinghouse contract presented earlier, and it will exploit the token-based prediction market contract unchanged.

Market makers (often known as “bookmakers”) strive to take many bets that will offset each other while collecting a percentage of the bets as their compensation. Typically, bookmakers take bets sequentially, ever mindful of whether the bets are offsetting each other. If the bets begin to represent a risk due to imbalance, the bookmaker may need to adjust their actions. For instance, they can change the odds to try to bring the booked bets into balance.

A bookmaker acts as a market maker by participating in bets themselves, typically in anticipation of future bets that will offset the current bets. By taking many bets concurrently, there is more opportunity to keep the books in balance (by rejecting bets if they clearly would skew the betting).

This contract will support an off-chain market maker for prediction markets. Exactly like the clearinghouse contract, trade offers (bets) will be proposed off-chain with signed messages.

Why Not Just Use the Clearinghouse Contract?
Given that the token-based prediction markets simply exchange tokens, and the clearinghouse contract handles off-chain token trading, why would a prediction market bookmaker need anything more? It’s because prediction market tokens can be bought and sold in bundles for a fixed price. A market maker can exploit this special property to accept bets that would otherwise have been impossible. An example will help.

Assume the following two independent prediction markets exist, with each winning token worth 1 (wrapped) ETH:

The NFC Championship, with two securities/tokens: COWBOYS and PACKERS.
The AFC Championship, with two securities: PATRIOTS and STEELERS.
Further, assume that the following two trades are proposed:

Alice would like to trade 1,000 COWBOYS tokens for 1,000 PATRIOTS tokens.
Bob would like to trade 1,000 PACKERS tokens for 1,000 STEELERS tokens.
A market maker contract can exploit the ability to buy and refund complete bundles of tokens to satisfy these exchanges by doing the following:

The market maker takes possession of the 1,000 COWBOYS and PACKERS tokens from Alice and Bob.
The market maker uses refundBundle on the NFC prediction market to exchange those for 1,000 wrapped ETH tokens.
The market maker uses buyBundle on the AFC prediction market to buy 1,000 AFC bundles (both PATRIOTS and STEELERS tokens) for those 1,000 wrapped ETH tokens.
The market maker distributes the 1,000 PATRIOTS tokens to Alice, and the 1,000 STEELERS tokens to Bob.
Without the contract’s ability to buy and refund bundles, it would have been impossible for the market maker to have orchestrated those trades directly.

Executing Trades
In the clearinghouse contract, multiple trades are executed in three steps:

All trades are validated.
Traded tokens are gathered.
Tokens are distributed.
The market maker contract for prediction markets will augment that with bundle buying and bundle refunding steps:

All trades are validated.
Traded tokens are gathered.
Bundles are refunded and bought.
Tokens are distributed.
The code for executeWagers below is the same as the clearinghouse’s executeOffers with the additional bundle buying/refunding step (and the corresponding parameters):

function executeWagers(
    address[] sellers,
    IERC20Token[] sellTokens,
    uint256[] sellAmounts,
    IERC20Token[] receiveTokens,
    uint256[] receiveAmounts,
    uint256[] timeLimits,
    uint256[] nonces,
    bytes32[] rs,
    bytes32[] ss,
    uint8[] vs,
    TokenPredictionMarket[] pms,
    int256[] bundleAmounts
)
    public
{
    require(msg.sender == owner);

    acceptOffers(
        sellers,
        sellTokens,
        sellAmounts,
        receiveTokens,
        receiveAmounts,
        timeLimits,
        nonces,
        rs,
        ss,
        vs
    );

    gatherOffers(sellers, sellTokens, sellAmounts);

    buyOrRefundBundles(pms, bundleAmounts);

    distributeOffers(sellers, receiveTokens, receiveAmounts);
}
The parameters for buying/refunding tokens use signed integers to represent amounts. Positive values represent buying bundles, and negative values represent refunds.

function buyOrRefundBundles(
    TokenPredictionMarket[] pms,
    int256[] amounts
)
    internal
{
    for (uint256 i = 0; i < pms.length; i++) {
        if (amounts[i] > 0) {
            buyBundle(pms[i], uint256(amounts[i]));
        } else {
            refundBundle(pms[i], uint256(-amounts[i]));
        }
    }
}
Buying Bundles
Buying bundles is straightforward. The contract approves transfer of payment tokens to the prediction market, it buys the bundle with those tokens, and then it puts all the bought tokens into the contract owner’s escrow accounts:

function buyBundle(
    TokenPredictionMarket pm,
    uint256 amount
)
    internal
{
    // approve transfer of payment tokens
    IERC20Token wt = pm.wagertoken();
    wt.approve(pm, amount);
    escrowBalance[owner][wt] -= amount;

    // buy the bundle
    pm.buyBundle(amount);

    // transfer bundle from this to owner and adjust escrow
    uint256 length = pm.outcomeCount();
    for (uint256 i = 0; i < length; i++) {
        IERC20Token t = IERC20Token(pm.tokens(i));
        escrowBalance[owner][t] += amount;
    }
}
Refunding Bundles
Similar logic holds for the refunding of bundles:

function refundBundle(
    TokenPredictionMarket pm,
    uint256 amount
)
    internal
{
    // approve transfer of bundle and adjust escrow
    uint256 length = pm.outcomeCount();
    for (uint256 i = 0; i < length; i++) {
        IERC20Token t = IERC20Token(pm.tokens(i));
        t.approve(pm, amount);
        escrowBalance[owner][t] -= amount;
    }

    // refund the bundle
    pm.refundBundle(amount);

    // account for the received tokens in owner's escrow account
    IERC20Token wt = pm.wagertoken();
    escrowBalance[owner][wt] += amount;
}
Summary
An off-chain market maker for prediction markets can be supported with a smart contract.
The smart contract is a simple adaptation of the clearinghouse contract.
The market maker can exploit the buying and refunding of bundles to accept more bets.
The Complete Contract
bookmaker.sol
pragma solidity ^0.4.24;

import "clearinghouse.sol";
import "wagertokenpredictionmarket.sol";

contract Bookmaker is Clearinghouse {

    constructor (uint256 _escrowTime)
        Clearinghouse(_escrowTime)
        public
    {
    }

    function buyBundle(
        TokenPredictionMarket pm,
        uint256 amount
    )
        internal
    {
        // approve transfer of payment tokens
        IERC20Token wt = pm.wagertoken();
        wt.approve(pm, amount);
        escrowBalance[owner][wt] -= amount;

        // buy the bundle
        pm.buyBundle(amount);

        // transfer bundle from this to owner and adjust escrow
        uint256 length = pm.outcomeCount();
        for (uint256 i = 0; i < length; i++) {
            IERC20Token t = IERC20Token(pm.tokens(i));
            escrowBalance[owner][t] += amount;
        }
    }

    function refundBundle(
        TokenPredictionMarket pm,
        uint256 amount
    )
        internal
    {
        // approve transfer of bundle and adjust escrow
        uint256 length = pm.outcomeCount();
        for (uint256 i = 0; i < length; i++) {
            IERC20Token t = IERC20Token(pm.tokens(i));
            t.approve(pm, amount);
            escrowBalance[owner][t] -= amount;
        }

        // refund the bundle
        pm.refundBundle(amount);

        // transfer the received tokens to owner
        IERC20Token wt = pm.wagertoken();
        escrowBalance[owner][wt] += amount;
    }

    function buyOrRefundBundles(
        TokenPredictionMarket[] pms,
        int256[] amounts
    )
        internal
    {
        for (uint256 i = 0; i < pms.length; i++) {
            if (amounts[i] > 0) {
                buyBundle(pms[i], uint256(amounts[i]));
            } else {
                refundBundle(pms[i], uint256(-amounts[i]));
            }
        }
    }

    function executeWagers(
        address[] sellers,
        IERC20Token[] sellTokens,
        uint256[] sellAmounts,
        IERC20Token[] receiveTokens,
        uint256[] receiveAmounts,
        uint256[] timeLimits,
        uint256[] nonces,
        bytes32[] rs,
        bytes32[] ss,
        uint8[] vs,
        TokenPredictionMarket[] pms,
        int256[] bundleAmounts
    )
        public
    {
        require(msg.sender == owner);

        acceptOffers(
            sellers,
            sellTokens,
            sellAmounts,
            receiveTokens,
            receiveAmounts,
            timeLimits,
            nonces,
            rs,
            ss,
            vs
        );

        gatherOffers(sellers, sellTokens, sellAmounts);

        buyOrRefundBundles(pms, bundleAmounts);

        distributeOffers(sellers, receiveTokens, receiveAmounts);
    }
}
← Betting Tokens In A Prediction MarketWorking with State Channels in JavaScript →
  