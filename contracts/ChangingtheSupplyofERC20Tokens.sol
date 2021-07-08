Program the Blockchain
Archive About Subscribe
Changing the Supply of ERC20 Tokens
MAY 16, 2018 BY TODD PROEBSTING
[EDIT 2018-05-25] This post has been edited to introduce a BaseERC20Token contract.

This short post will add dynamic control of the total supply of tokens to the previously introduced simple ERC20 tokens.

Our previous ERC20 tokens made the simplifying assumption that the token’s total supply did not change. I’m going to relax that assumption in this post by allowing the owner to increase the token supply with a “mint” function. Similarly, “burn” and “burnFrom” functions can decrease the total supply.

Future posts will make use of the ability to dynamically create and destroy tokens.

Setting the Initial Token Supply
The new MintableToken contract will inherit from a BaseERC20Token contract and augment that with functions to mint and burn tokens. BaseERC20Token is a fully parameterized version of the SimpleERC20Token contract. The full source code can be found at the end of this post.

pragma solidity ^0.4.23;

import "baseerc20token.sol";

contract MintableToken is BaseERC20Token {
    address public owner = msg.sender;

    constructor(
        uint256 _totalSupply,
        uint8 _decimals,
        string _name,
        string _symbol
    ) BaseERC20Token(_totalSupply, _decimals, _name, _symbol) public
    {
    }

    // more to come
}
Minting Tokens
The contract’s owner can create new tokens by calling mint. This increases the total token supply and grants ownership of the new tokens to the specified recipient:

function mint(address recipient, uint256 amount) public {
    require(msg.sender == owner);
    require(totalSupply + amount >= totalSupply); // Overflow check

    totalSupply += amount;
    balanceOf[recipient] += amount;
    emit Transfer(address(0), recipient, amount);
}
Burning Tokens
Anyone can destroy a portion or all of the tokens they own by calling burn. The specified amount is removed not only from the caller’s token balance but also from the token’s total supply:

function burn(uint256 amount) public {
    require(amount <= balanceOf[msg.sender]);

    totalSupply -= amount;
    balanceOf[msg.sender] -= amount;
    emit Transfer(msg.sender, address(0), amount);
}
By convention, burning tokens emits a Transfer event with the address 0x0 as the recipient.

It’s often useful to be able to burn tokens on behalf of another account. The burnFrom function borrows logic from ERC20’s transferFrom:

function burnFrom(address from, uint256 amount) public {
    require(amount <= balanceOf[from]);
    require(amount <= allowance[from][msg.sender]);

    totalSupply -= amount;
    balanceOf[from] -= amount;
    allowance[from][msg.sender] -= amount;
    emit Transfer(from, address(0), amount);
}
Summary
This contract supports dynamic changes to the total supply of tokens.
This contract exploits inheritance to extend the BaseERC20Token contract.
Full Source Code
baseerc20token.sol
mintable.sol
pragma solidity ^0.4.23;

import "baseerc20token.sol";

contract MintableToken is BaseERC20Token {
    address public owner = msg.sender;

    constructor(
        uint256 _totalSupply,
        uint8 _decimals,
        string _name,
        string _symbol
    ) BaseERC20Token(_totalSupply, _decimals, _name, _symbol) public
    {
    }

    function mint(address recipient, uint256 amount) public {
        require(msg.sender == owner);
        require(totalSupply + amount >= totalSupply); // Overflow check

        totalSupply += amount;
        balanceOf[recipient] += amount;
        emit Transfer(address(0), recipient, amount);
    }

    function burn(uint256 amount) public {
        require(amount <= balanceOf[msg.sender]);

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function burnFrom(address from, uint256 amount) public {
        require(amount <= balanceOf[from]);
        require(amount <= allowance[from][msg.sender]);

        totalSupply -= amount;
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, address(0), amount);
    }
}
← State Channels for Two-Player GamesUsing Tokens for Parimutuel Wagers →
  