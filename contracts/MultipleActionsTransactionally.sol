Program the Blockchain
Archive About Subscribe
Performing Multiple Actions Transactionally
JULY 6, 2018 BY TODD PROEBSTING
This post will demonstrate a simple technique for combining multiple actions into a single transaction. This will enable you to be certain that you get “all or nothing” execution of the combined actions. It builds on Ensuring the Effects of a Transaction.

Suppose that you want to execute two or more actions as a unit such that either all of them or none of them execute. How would you do that? The simplest way is to combine all of them into a single transaction. Like in the previous post, this can be done in the constructor of a contract:

contract CombineTransactions {

    constructor (
        // parameters needed to execute and check transaction
    )
        public
        payable  // if needed
    {
        // record initial state

        // perform action 1
        // perform action 2
        // ...
        // perform action N

        // validate final state

        selfdestruct(msg.sender)
    }
}
If any of those actions fail, or if the final state isn’t correct, then the whole transaction will fail, which will revert the effects of all preceding actions.

Example: Arbitrage
A classic situation where all-or-nothing execution is desirable is arbitrage. Arbitrage opportunities present themselves when you can buy something for less than you can sell it for—typically from different entities. Without all-or-nothing execution, you would run the risk of buying something and then no longer being able to sell it at an advantageous price.

For this example, I will reuse the ITokenShop interface from Ensuring the Effects of a Transaction:

interface ITokenShop {
    function token() external returns (IERC20Token);
    function buy() external payable;
    function sell(uint256 amount) external;
}
Suppose that you found two token shops, with one selling tokens for less than the other is paying for them. You have found an arbitrage opportunity that you’d probably like to exploit by buying tokens and then immediately selling them for a profit. Doing that in an all-or-nothing fashion makes the transaction risk free (except for gas costs):

contract Arbitrage {
    constructor (
        ITokenShop buyShop,
        ITokenShop sellShop,
        uint256 amount
    )
        public
        payable
    {
        // First buy tokens from the shop with the lower price.
        buyShop.buy.value(msg.value)();

        // Then sell tokens to the shop with the higher price.
        sellShop.token().approve(sellShop, amount);
        sellShop.sell(amount);

        // Make sure we made a profit.
        require(address(this).balance > msg.value);

        selfdestruct(msg.sender);
    }
}
The code above follows the pattern of performing multiple actions in a single transaction.

The require at the end makes sure that the transaction was profitable. This check is necessary because the buyShop or sellShop might have changed prices between when you checked the price and when this transaction is executed.

The Complete Contract
arbitrage.sol
pragma solidity ^0.4.24;

import "../common/ierc20token.sol";

interface ITokenShop {
    function token() external returns (IERC20Token);
    function buy() external payable;
    function sell(uint256 amount) external;
}

contract Arbitrage {
    constructor (
        ITokenShop buyShop,
        ITokenShop sellShop,
        uint256 amount
    )
        public
        payable
    {
        // First buy tokens from the shop with the lower price.
        buyShop.buy.value(msg.value)();

        // Then sell tokens to the shop with the higher price.
        sellShop.token().approve(sellShop, amount);
        sellShop.sell(amount);

        // Make sure we made a profit.
        require(address(this).balance > msg.value);

        selfdestruct(msg.sender);
    }
}
← Ensuring the Effects of a TransactionWriting a Trivial Multisig Wallet →
  