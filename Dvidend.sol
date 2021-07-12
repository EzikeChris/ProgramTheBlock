Program the Blockchain	Archive About Subscribe
Writing A Simple Dividend Token Contract
FEBRUARY 7, 2018 BY TODD PROEBSTING
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

Tokens can provide rights or privileges to their owners. One of the most natural is the right to share proportionally in an income stream. This post will demonstrate how to write an ERC20-compliant contract that can divide ether dividends proportionally amongst token owners. This post combines ideas from our ERC20 token post, and our banking post.

This post will ignore some complications that arise from the lack of support for fixed-point numbers in the Ethereum Virtual Machine. (Specifically, I will assume that decimals==0 in the token contract.) I will address those issues in a future post.

Smart Contract Limitations
A recurring challenge in smart contract development is the high gas cost of iteration. This challenge is apparent when it comes to paying dividends. When a dividend is deposited, it must be evenly distributed among all token owners. However, there may be millions of token owners, and iterating over all of them would be tremendously expensive. Because such iteration is infeasible, contracts often need to defer such computation until it can be done on a per-item basis.

To that end, the contract will track the status of dividends owed to each account. Dividends associated with a particular account will always be in one of three states:

Already paid/transferred to the account.
Already credited to the account, but not yet transferred.
Not yet credited to the account, but the contract has sufficient information to compute the credit when needed.
All new dividends owed to an account start in the “not yet credited” state. Once that account is part of a transfer or withdrawal, the contract will compute the amount owed and credit it to the account, which moves the amount to the “credited but not transferred” status. Actual withdrawals move those credits to the final “transferred” state.

The contract will use the following values to determine the remaining amount due to each token owner:

uint256 public dividendPerToken;

mapping(address => uint256) dividendBalanceOf;

mapping(address => uint256) dividendCreditedTo;
dividendPerToken is the cumulative amount of ether per token that has been deposited in this contract. For instance, if there are 100 tokens, and the contract had collected 200 ether since its creation, then dividendPerToken would represent 2 ether per token. Note that this value is never decreased and is completely independent of any withdrawals made by token owners.
dividendBalanceOf is a mapping that represents the amount of ether credited to each account but not yet transferred to that account. Withdrawals reduce this amount.
dividendCreditedPerToken is a mapping that represents the cumulative amount of ether per token that has been previously credited to the account (i.e. added to dividendBalanceOf).
These three values track the three states of dividend payments to each account, and all values are stored in wei.

Augmenting the Simple ERC20 Token Contract
The simple ERC20 token contract requires a few changes to support dividends:

The functions that transfer tokens must be augmented to update the amounts owed to each account. The contract will do this by updating the account’s dividendCreditedPerToken and dividendBalanceOf.
The contract must accept dividend deposits, and per-account withdrawals.
Transfer Functions
Any token transfer must update the per-account dividendCreditedTo and dividendBalanceOf values. The dividendCreditedTo will be adjusted to the current (global) dividendPerToken value. That change represents the value that needs to be credited to dividendBalanceOf.

function update(address account) internal {
    uint256 owed =
        dividendPerToken - dividendCreditedTo[account];
    dividendBalanceOf[account] += balanceOf[account] * owed;
    dividendCreditedTo[account] = dividendPerToken;
}
This update function gets an account’s values up to date with respect to any dividends that were received since the last time the account was accessed. After that, the contract simply needs to update both the sender and receiver’s per-account balances in the transfer functions:

function transfer(address to, uint256 value) public returns (bool success) {
    require(balanceOf[msg.sender] >= value);

    update(msg.sender);  // <-- added to simple ERC20 contract
    update(to);          // <-- added to simple ERC20 contract

    balanceOf[msg.sender] -= value;
    balanceOf[to] += value;

    emit Transfer(msg.sender, to, value);
    return true;
}

function transferFrom(address from, address to, uint256 value)
    public
    returns (bool success)
{
    require(value <= balanceOf[from]);
    require(value <= allowance[from][msg.sender]);

    update(from);        // <-- added to simple ERC20 contract
    update(to);          // <-- added to simple ERC20 contract

    balanceOf[from] -= value;
    balanceOf[to] += value;
    allowance[from][msg.sender] -= value;
    emit Transfer(from, to, value);
    return true;
}
Deposit and Withdrawal
The deposit function accepts ether and updates the global dividendPerToken:

function deposit() public payable {
    dividendPerToken += msg.value / totalSupply;  // ignoring the remainder
}
If msg.value / totalSupply produces a remainder, then ether is lost forever. We will address this deficiency in a future post.

Withdrawal simply needs to update the the dividend owed, and then transfer it:

function withdraw() public {
    update(msg.sender);
    uint256 amount = dividendBalanceOf[msg.sender];
    dividendBalanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
Two things to note above:

update(msg.sender) is responsible for making sure dividendBalanceOf is up to date with respect to any dividends collected since the last update to msg.sender’s balances.
As we’ve described before, it’s essential to zero out dividendBalanceOf before doing the transfer.
Summary
ERC20 token contracts can distribute dividends proportional to token ownership.
Smart contracts that need to update per-account values across all accounts need to do so in a deferred, as-needed way to avoid iterating over all accounts.
The Whole Contract
simpleDividend.sol
pragma solidity ^0.4.21;

contract SimpleDividendToken {

    string public name = "Simple Dividend Token";
    string public symbol = "SDIV";

    // This code assumes decimals is zero---do not change.
    uint8 public decimals = 0;   //  DO NOT CHANGE!

    uint256 public totalSupply = 1000000 * (uint256(10) ** decimals);

    mapping(address => uint256) public balanceOf;

    function SimpleDividendToken() public {
        // Initially assign all tokens to the contract's creator.
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    mapping(address => uint256) dividendBalanceOf;

    uint256 public dividendPerToken;

    mapping(address => uint256) dividendCreditedTo;

    function update(address account) internal {
        uint256 owed =
            dividendPerToken - dividendCreditedTo[account];
        dividendBalanceOf[account] += balanceOf[account] * owed;
        dividendCreditedTo[account] = dividendPerToken;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value);

        update(msg.sender);  // <-- added to simple ERC20 contract
        update(to);          // <-- added to simple ERC20 contract

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        public
        returns (bool success)
    {
        require(value <= balanceOf[from]);
        require(value <= allowance[from][msg.sender]);

        update(from);        // <-- added to simple ERC20 contract
        update(to);          // <-- added to simple ERC20 contract

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function deposit() public payable {
        dividendPerToken += msg.value / totalSupply;  // ignoring remainder
    }

    function withdraw() public {
        update(msg.sender);
        uint256 amount = dividendBalanceOf[msg.sender];
        dividendBalanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

    function approve(address spender, uint256 value)
        public
        returns (bool success)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

}
← Writing a Token Sale ContractEnd to End: Initial Coin Offering →
  