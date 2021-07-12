Program the Blockchain	Archive About Subscribe
Writing a Token Sale Contract
FEBRUARY 2, 2018 BY STEVE MARX
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

In this post, I’ll build a simple smart contract that sells a limited supply of an Ethereum-based token for a fixed price. To understand this post, you’ll need to be familiar with ERC20 Tokens.

Interacting with Other Smart Contracts
The token sale smart contract will accept ether as payment and transfer tokens to the buyer in exchange. The token that will be transferred is implemented in a separate smart contract. To support calling into the token contract, I need to first tell Solidity what functions that contract supports.

An interface in Solidity is similar to the same concept in other programming languages. It describes what functions are available in a contract. The following code defines a minimal interface for ERC20-compatible tokens. Note that I don’t have to declare all the functions an ERC20 token has—just the ones I’m going to use.

interface IERC20Token {
    function balanceOf(address owner) public returns (uint256);
    function transfer(address to, uint256 amount) public returns (bool);
    function decimals() public returns (uint256);
}
I can now cast any address to type IERC20Token and then call the above functions on it, like so:

IERC20Token tokenContract = IERC20Token(0x123abc...);
uint256 decimals = tokenContract.decimals();
In the sale contract, I’ll pass the address of the token contract as a constructor parameter rather than hard-code it.

Supply and Price
Although token sales come in many shapes and sizes, in this post I’m focusing on a simple fixed-price sale of a limited supply of tokens. The contract needs to know, then, how many tokens it has available for sale and the unit price of each token.

One of the simplest ways to keep track of the supply is to use the contract’s token balance. After deploying the sale contract, I’ll call transfer(contractAddress, amountToSell) on the token contract. Once I’ve transferred tokens to it, the sale contract can use tokenContract.balanceOf(this) to see how many tokens are available to be sold.

The price needs to be set at deployment time, so in addition to the address of the token contract, I’ll add a constructor parameter for the price:

contract TokenSale {
    IERC20Token public tokenContract;  // the token being sold
    uint256 public price;              // the price, in wei, per token
    address owner;

    function TokenSale(IERC20Token _tokenContract, uint256 _price) public {
        owner = msg.sender;
        tokenContract = _tokenContract;
        price = _price;
    }
}
Two things to notice in the above code:

When I deploy the contract, I’ll pass an address as the first argument, and Solidity will cast it for me to type IERC20Token.
I’m keeping track of the owner (the account that deployed the contract). The owner account is special in that it will be allowed to end the sale and retrieve the collected ether.
Selling Tokens
Now that the contract has tokens to sell and a price at which to sell them, it’s time to write the core logic of the contract. It may be helpful to read Writing a Contract That Handles Ether if you haven’t already:

uint256 public tokensSold;

event Sold(address buyer, uint256 amount);

function buyTokens(uint256 numberOfTokens) public payable {
    require(msg.value == safeMultiply(numberOfTokens, price));

    uint256 scaledAmount = safeMultiply(numberOfTokens,
            uint256(10) ** tokenContract.decimals());

    require(tokenContract.balanceOf(this) >= scaledAmount);

    emit Sold(msg.sender, numberOfTokens);
    tokensSold += numberOfTokens;

    require(tokenContract.transfer(msg.sender, scaledAmount));
}
Here’s a brief explanation of the above code:

To help prevent mistakes, the function accepts as a parameter how many tokens are being purchased and then checks that the correct amount of ether was sent.
Recall from Writing an ERC20 Token Contract that in order to support fixed point math on tokens, “1 token” is represented in the token contract as a value of 10^decimals, where decimals is how many decimal places after the zero the contract supports. I convert the number of tokens to this scaled number in scaledAmount.
safeMultiply (defined below) is used to guard against integer overflows if someone maliciously passes in a very high value for numberOfTokens.
The second require statement checks to make sure the contract has a sufficient number of tokens to complete the sale.
tokensSold and the Sold event are there for UI purposes. They make it easy for a front end application to monitor the progress of the sale.
Because the ERC20 token standard allows tokens to return false on failure, rather than reverting, the final require is necessary to ensure the buyer actually receives their tokens.
Ending the Sale
In this sale contract, the owner will be allowed to end the sale at any time. All unsold tokens will be transferred to the owner, as will all collected ether.

function endSale() public {
    require(msg.sender == owner);

    // Send unsold tokens to the owner.
    require(tokenContract.transfer(owner, tokenContract.balanceOf(this)));

    msg.sender.transfer(address(this).balance);
}
This function transfers all remaining tokens as well as all ether collected. Because the contract holds no more tokens, any subsequent calls to buyTokens will fail.

Summary
Contracts can call functions in other contracts, but to do so they must declare the target contract’s interface.
Care must be taken to scale ERC20 token amounts appropriately according to their number of decimals.
Full Source Code
tokenSale.sol
pragma solidity ^0.4.21;

interface IERC20Token {
    function balanceOf(address owner) public returns (uint256);
    function transfer(address to, uint256 amount) public returns (bool);
    function decimals() public returns (uint256);
}

contract TokenSale {
    IERC20Token public tokenContract;  // the token being sold
    uint256 public price;              // the price, in wei, per token
    address owner;

    uint256 public tokensSold;

    event Sold(address buyer, uint256 amount);

    function TokenSale(IERC20Token _tokenContract, uint256 _price) public {
        owner = msg.sender;
        tokenContract = _tokenContract;
        price = _price;
    }

    // Guards against integer overflows
    function safeMultiply(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        } else {
            uint256 c = a * b;
            assert(c / a == b);
            return c;
        }
    }

    function buyTokens(uint256 numberOfTokens) public payable {
        require(msg.value == safeMultiply(numberOfTokens, price));

        uint256 scaledAmount = safeMultiply(numberOfTokens,
            uint256(10) ** tokenContract.decimals());

        require(tokenContract.balanceOf(this) >= scaledAmount);

        emit Sold(msg.sender, numberOfTokens);
        tokensSold += numberOfTokens;

        require(tokenContract.transfer(msg.sender, scaledAmount));
    }

    function endSale() public {
        require(msg.sender == owner);

        // Send unsold tokens to the owner.
        require(tokenContract.transfer(owner, tokenContract.balanceOf(this)));

        msg.sender.transfer(address(this).balance);
    }
}
← Writing an ERC20 Token ContractWriting A Simple Dividend Token Contract →
  