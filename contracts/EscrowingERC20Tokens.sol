Program the Blockchain
Archive About Subscribe
Escrowing ERC20 Tokens
MAY 30, 2018 BY TODD PROEBSTING
[EDIT 2018-06-05] This post has been edited to introduce a transfer function.

This post describes a simple contract to escrow ERC20 tokens for a period of time. Keeping tokens (or ether) in escrow is a common pattern in smart contracts.

Escrow is particularly important for off-chain components that work with signed messages. Such a component often needs certainty that a token transfer promised via a signature can be fulfilled.

A simple procedure for escrowing tokens is as follows:

An account approves a token transfer to the trusted smart contract.
The smart contract transfers those tokens to itself, holding them in escrow.
An account cannot withdraw escrowed tokens without first signaling the desire to end escrow.
The escrow period ends a fixed amount of time after the signal to end escrow.
Once the escrow period ends, the account may withdraw any remaining tokens.
The pattern above was exploited in the payment channel post, for instance, where ether was kept in escrow rather than ERC20 tokens.

Cancellation Period
This contract is parameterized with the escrow duration. When an account wishes to withdraw its tokens, this is how long it must wait before the withdrawal is allowed.

contract Escrow {
    uint256 public escrowTime;

    constructor(uint256 _escrowTime) public {
        escrowTime = _escrowTime;
    }

    // more to come
}
Tracking Per-Token Balances and Expirations
To make the escrow fully general, the contract does not assume a specific ERC20 token, so a single account may escrow different tokens at the same time. For each (account, token) pair, the contract tracks its balance and the time when escrow expires:

mapping(address => mapping(address => uint256)) public escrowBalance;
mapping(address => mapping(address => uint256)) public escrowExpiration;
Deposit
Depositing tokens works with the familiar ERC20 pattern of approve()/transferFrom(). Once the depositor has approved the transfer, they can call deposit() to move the tokens into the escrow contract. The escrow expiration time is initialized to the maximum allowed time, making it effectively infinite.

function deposit(IERC20Token token, uint256 amount) public {
    require(token.transferFrom(msg.sender, this, amount));
    escrowBalance[msg.sender][token] += amount;
    escrowExpiration[msg.sender][token] = 2**256-1;
}
Withdrawal
Withdrawing tokens is a two-step process. First, the withdrawal is started. This sets the escrowExpiration time to escrowTime in the future and emits an event announcing the updating expiration time:

event StartWithdrawal(address indexed account, address token, uint256 time);

function startWithdrawal(IERC20Token token) public {
    uint256 expiration = now + escrowTime;
    escrowExpiration[msg.sender][token] = expiration;
    emit StartWithdrawal(msg.sender, token, expiration);
}
After the escrow time has expired, all of the (remaining) escrowed tokens can be transferred back to their original owner:

function withdraw(IERC20Token token) public {
    require(now > escrowExpiration[msg.sender][token],
        "Funds still in escrow.");

    uint256 amount = escrowBalance[msg.sender][token];
    escrowBalance[msg.sender][token] = 0;
    require(token.transfer(msg.sender, amount));
}
Transferring Tokens
Contracts require escrowed tokens to assure the ability to transfer those tokens. Therefore, the contract supports a transfer function that enables transferring tokens between accounts. This routine would only be called by a subcontract of Escrow.

function transfer(
    address from,
    address to,
    IERC20Token token,
    uint256 tokens
)
    internal
{
    require(escrowBalance[from][token] >= tokens, "Insufficient balance.");

    escrowBalance[from][token] -= tokens;
    escrowBalance[to][token] += tokens;
}
Escrowing Ether
This contract supports escrowing any ERC20 tokens, but it does not directly help escrow ether. One can, however, wrap ether in an ERC20 token to effectively escrow ether with this contract.

Summary
Escrow is a common pattern in smart contracts, especially those with off-chain components.
This contract can escrow any tokens of all ERC20 types for any account.
This contract doesn’t do anything other than escrow tokens—its value is in being incorporated in a contract that needs escrow functionality.
The Complete Contract
escrow.sol
pragma solidity ^0.4.24;

import "./ierc20token.sol";

contract Escrow {
    uint256 public escrowTime;

    constructor(uint256 _escrowTime) public {
        escrowTime = _escrowTime;
    }

    mapping(address => mapping(address => uint256)) public escrowBalance;
    mapping(address => mapping(address => uint256)) public escrowExpiration;

    function deposit(IERC20Token token, uint256 amount) public {
        require(token.transferFrom(msg.sender, this, amount));
        escrowBalance[msg.sender][token] += amount;
        escrowExpiration[msg.sender][token] = 2**256-1;
    }

    event StartWithdrawal(address indexed account, address token, uint256 time);

    function startWithdrawal(IERC20Token token) public {
        uint256 expiration = now + escrowTime;
        escrowExpiration[msg.sender][token] = expiration;
        emit StartWithdrawal(msg.sender, token, expiration);
    }

    function withdraw(IERC20Token token) public {
        require(now > escrowExpiration[msg.sender][token],
            "Funds still in escrow.");

        uint256 amount = escrowBalance[msg.sender][token];
        escrowBalance[msg.sender][token] = 0;
        require(token.transfer(msg.sender, amount));
    }

    function transfer(
        address from,
        address to,
        IERC20Token token,
        uint256 tokens
    )
        internal
    {
        require(escrowBalance[from][token] >= tokens, "Insufficient balance.");

        escrowBalance[from][token] -= tokens;
        escrowBalance[to][token] += tokens;
    }
}
← Wrapping Ether in an ERC20 TokenStorage Patterns: Set →
  