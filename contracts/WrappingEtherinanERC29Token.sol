Program the Blockchain
Archive About Subscribe
Wrapping Ether in an ERC20 Token
MAY 26, 2018 BY STEVE MARX
In this short post, I’ll show how ether can be “wrapped” in an ERC20-compatible token. This means ether can be used anywhere that an ERC20 token is expected.

Why Wrap Ether?
Ether is the native currency of Ethereum. It predates ERC20 and other token standards, so it doesn’t have the same interface. This can be the source of complexity in smart contracts. If a smart contract is to accept all types of currency, it must implement two interfaces: one for ether and one for ERC20 tokens.

“Wrapping” ether solves this problem by introducing a layer of indirection. Users can purchase ERC20-compatible “ether tokens” for native ether, at a 1:1 exchange rate. Then they can use those tokens with any smart contract that understands ERC20. Finally, the tokens can be exchanged back for ether, again at a 1:1 exchange rate.

The term “wrapping” comes from a token called W-ETH. That implementation is very similar to the contract presented in this post.

EtherToken
EtherToken inherits from BaseERC20Token, which can be found in our post on changing the total supply of ERC20 tokens.

The number of decimals is fixed at 18 to match ether. (One ether is 1018 wei.) The totalSupply begins at 0. This will be increased when users buy tokens for ether.

pragma solidity ^0.4.24;

import "baseerc20token.sol";

contract EtherToken is BaseERC20Token {
    constructor(string _name, string _symbol)
        BaseERC20Token(0, 18, _name, _symbol) public
    {
    }
Buying Tokens
Tokens can be purchased for ether at a 1:1 exchange rate:

function buy() public payable {
    balanceOf[msg.sender] += msg.value;
    totalSupply += msg.value;

    emit Transfer(address(0), msg.sender, msg.value);
}
The purchaser’s balance is increased, as is the total supply of tokens. Like in our MintableToken contract, a Transfer event from address 0 indicates that new tokens were created.

Selling Tokens
Tokens can be sold back to the contract in exchange for ether, again at a 1:1 rate:

function sell(uint256 amount) public {
    require(balanceOf[msg.sender] >= amount, "Insufficient balance.");

    balanceOf[msg.sender] -= amount;
    totalSupply -= amount;
    msg.sender.transfer(amount);

    emit Transfer(msg.sender, address(0), amount);
}
The Transfer event to address 0x0 indicates that tokens were destroyed.

Summary
Wrapping ether in an ERC20 token is convenient for handling both ether and ERC20 tokens in the same contract.
W-ETH is an existing implementation that you can use.
Building such a token yourself requires only adding buy() and sell() functions to a typical ERC20 token implementation.
Full Source Code
ethertoken.sol
pragma solidity ^0.4.24;

import "baseerc20token.sol";

contract EtherToken is BaseERC20Token {
    constructor(string _name, string _symbol)
        BaseERC20Token(0, 18, _name, _symbol) public
    {
    }

    function buy() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;

        emit Transfer(address(0), msg.sender, msg.value);
    }

    function sell(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance.");

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        msg.sender.transfer(amount);

        emit Transfer(msg.sender, address(0), amount);
    }
}
← Writing a Prediction Market ContractEscrowing ERC20 Tokens →
  