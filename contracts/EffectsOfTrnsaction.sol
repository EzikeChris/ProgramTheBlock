Program the Blockchain
Archive About Subscribe
Ensuring the Effects of a Transaction
JUNE 28, 2018 BY TODD PROEBSTING
This post will demonstrate a simple technique for ensuring that a transaction had the desired effects.

The Challenge
Suppose that you learn of a contract that purports to do something desirable, but you’re just not sure that it actually does what it is supposed to. What can you do to protect yourself?

Obviously, you can (and should) examine the contract’s code. You might find trusted auditors who can vouch for the code’s effect. But you may still be left with some concerns because the contract’s promises seem just too good to be true. Fortunately, it’s pretty easy to validate that a transaction had the desired effect before committing to it.

The technique is simple: create a special-purpose contract that performs the desired action and then revert if the desired effects did not take place.

An Example
Suppose that you want to buy a quantity of an ERC20 token. You find a contract that sell those tokens at a good price. You want to buy the tokens and be certain that the contract actually sells them at the correct price. This example will show you how to do that.

I’m going to assume this interface for the token seller:

interface ITokenShop {
    function token() external returns (IERC20Token);
    function buy() external payable;
    function sell(uint256 amount) external;
}
To execute a checked token purchase, the validating contract needs to know the address of the token seller, the token type, and the expected amount of tokens to be purchased. The ether to purchase the tokens will be attached to the deployment transaction.

contract Validator {

    constructor (
        ITokenShop ts,
        IERC20Token token,
        uint256 expectedAmount
    )
        public
        payable
    {
        // record the sender's beginning token balance
        uint256 before = token.balanceOf(msg.sender);

        // this contract buys the tokens
        ts.buy.value(msg.value)();

        // transfer the tokens to the sender
        token.transfer(msg.sender, expectedAmount);

        // check that the sender's final balance has increased
        // by expectedAmount
        require(token.balanceOf(msg.sender) == before+expectedAmount);

        selfdestruct(msg.sender);
    }
}
Note that this is a single-use contract. It has no functions other than the constructor, so everything happens at the time of deployment.

The constructor executes the purchase and checks that the number of tokens the sender owns increases appropriately. If not, the require fails and the transaction reverts. If it reverts, the sender only loses the gas needed to execute this transaction.

There is one subtlety above regarding the purchase of the tokens. This contract buys the tokens for itself using the buy function of the token seller. Because the purpose of the contract is to buy tokens for the sender, this contract must also transfer those tokens to the sender.

The contract self-destructs to save gas.

Simple Pattern
The contract above is a specific example of a very simple pattern that can be used for situations where you want to be certain of the effects of a given contract:

contract Validator {

    constructor (
        // parameters needed to execute and check transaction
    )
        public
        payable  // if needed
    {
        // record initial state

        // perform action

        // validate final state

        selfdestruct(msg.sender)
    }
}
A couple notes about this pattern:

The initial and final states are not typically the final states of this contract. More commonly, they are the initial and final states of the sender.
This transaction may include code after the desired action to transfer assets from the contract to the sender.
The Complete Contract
validator.sol
pragma solidity ^0.4.24;

import "../common/ierc20token.sol";

interface ITokenShop {
    function token() external returns (IERC20Token);
    function buy() external payable;
    function sell(uint256 amount) external;
}

contract Validator {

    constructor (
        ITokenShop ts,
        IERC20Token token,
        uint256 expectedAmount
    )
        public
        payable
    {
        // record the sender's beginning token balance
        uint256 before = token.balanceOf(msg.sender);

        // this contract buys the tokens
        ts.buy.value(msg.value)();

        // transfer the tokens to the sender
        token.transfer(msg.sender, expectedAmount);

        // check that the sender's final balance has increased
        // by expectedAmount
        require(token.balanceOf(msg.sender) == before+expectedAmount);

        selfdestruct(msg.sender);
    }
}
← Working with State Channels in JavaScriptPerforming Multiple Actions Transactionally →
  