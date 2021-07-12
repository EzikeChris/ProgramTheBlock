Program the Blockchain	Archive About Subscribe
Writing an ERC20 Token Contract
JANUARY 30, 2018 BY TODD PROEBSTING
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

This post will demonstrate how to write a simple, but complete, smart contract in Solidity that implements the ERC20 token standard. It assumes that you are familiar with concepts introduced in our post, What is an Ethereum Token?, which discussed how tokens are maintained as per-account balances and how those balances can be transferred between accounts.

The ERC20 token standard enables different tokens to be treated similarly in marketplaces and exchanges. It also enables contracts that handle tokens to be written once and used across many different tokens. For instance, the same contract might be able to handle the initial sale of different ERC20 tokens. This post is going to develop a very simple ERC20-compliant token contract, which (I hope) will help you understand the standard from a code-centric point of view.

You don’t need to be familiar with the standard to understand this post. Like most standards, some things are required and some are optional. The code below will implement everything, but we’ll point out the optional parts.

name and symbol (optional)
ERC20 token contracts may give their tokens a (string) name and a (string) symbol. Typically, the name is a short description of the token, and the symbol is a one word identifier. To be compliant, the name and symbol must be accessible via view functions with the following types:

// ERC20 optional functions
function name() view returns (string name)
function symbol() view returns (string symbol)
To implement those, I will use the Solidity shorthand of simply defining public variables by the same name with the same type (because Solidity will generate the corresponding getter automatically):

string public name;
string public symbol;
totalSupply (required)
ERC20 contracts must provide a similar view function that returns the current number of outstanding tokens. Again, I will use a public variable because Solidity will create the corresponding public getter:

uint256 public totalSupply;
Fixed-point Math: decimals (optional)
Neither the Ethereum Virtual Machine nor Solidity offer support for fixed-point numbers—they only support various flavors of integers. This presents a challenge when a contract would like to present others with the idea of a fractional unit. To do this, it is necessary to simulate fixed-point numbers explicitly.

This kind of simulation is already done with ether. When contracts pass around huge 256-bit integers to represent ether transfers, those numbers don’t actually directly represent ether—they represent wei. Recall that 1 ether equals 10^18 wei. This means that when a contract is given a uint256 value that represents a single ether, it is not passed the integer 1, it is passed the integer 1,000,000,000,000,000,000.

Many token contracts support fractional tokens, and they do so in precisely the same way by having a scaling factor. In ERC20 tokens, that scaling factor is denoted by the value of decimals, which indicates how many 0’s there are to the right of the decimal point the fixed-point representation of a token.

For instance, a contract that supports 1⁄100’s of tokens (e.g, 3.14, 2.72), would have decimals equal to 2. If decimals = 2, then the value stored to represent 3.14 would be 314.

ERC20 contracts support this with the optional view public function, decimals. Again, a public variable suffices:

uint8 public decimals;
Unlike the common use of 256-bit integers in Solidity programs, this only requires 8 bits because 8 bits worth of zeroes is a lot of zeroes.

For this contract, the fixed-point simulation requires only trivial additional code, which will appear below when the contract computes the totalSupply of tokens.

We should note that it appears that the accepted norm is to use decimals = 18.

Transfer Event (required)
Recall from our post that events are the convenient method the EVM provides for logging information for external consumers. ERC20 contracts are required to publish events whenever token transfer attempts succeed. The Transfer event publishes the from and to accounts as well as the token value transferred:

event Transfer(address indexed from, address indexed to, uint256 value);
Note that the from and to addresses are indexed to help event consumers efficiently monitor only those events they care about.

balanceOf (required)
ERC20 contracts maintain per-account token balances, which must be accessible via a public view function. Once again, Solidity makes this easy:

mapping (address => uint256) public balanceOf;
By now, this code should look familiar since we used it in our banking, crowdfunding, and simple token posts!

Finally, Some Code!
I’ll put the snippets above into a contract to make it more concrete. For this example, we’ll have the contract create 1,000,000 tokens and transfer all of those tokens to the contract’s creator account. I’ll add a small constructor that does that:

contract SimpleERC20Token {
    mapping (address => uint256) public balanceOf;

    string public name = "Simple ERC20 Token";
    string public symbol = "SET";
    uint8 public decimals = 18;

    uint256 public totalSupply = 1000000 * (uint256(10) ** decimals);

    event Transfer(address indexed from, address indexed to, uint256 value);

    function SimpleERC20Token() public {
        // Initially assign all tokens to the contract's creator.
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    // more stuff to come
}
The constructor above does a few notable things:

I hardcoded values for name, symbol, decimals, and totalSupply. Obviously, these could have been constructor parameters, or even computed values, but this example is intentionally simple.
The computation of totalSupply required scaling due to the use of fixed-point numbers.
Although the ERC20 standard doesn’t explicitly require it, it is considered a best practice to log a Transfer event indicating the “transfer” from address 0 of tokens to the creator’s account (msg.sender).
transfer (required)
ERC20 tokens can be transferred directly from their owner’s account to any other account with a public transfer function:

function transfer(address to, uint256 value) public returns (bool success) {
    require(balanceOf[msg.sender] >= value);

    balanceOf[msg.sender] -= value;           // deduct from sender's balance
    balanceOf[to] += value;                  // add to recipient's balance

    emit Transfer(msg.sender, to, value);
    return true;
}
This (required) transfer function includes some things demanded by the standard:

transfer requires that the sender/owner has enough tokens to fulfill the transfer. It will not do a partial transfer.
Successful transfers must log the appropriate Transfer event.
transfer must return a bool value representing a successful transfer.
Please note that the ERC20 token standard is actually silent on whether transfer should revert when msg.sender doesn’t have sufficient tokens, or if it should simply return false. (It must do one of the two.) I have chosen to have it revert, which seems like a safer choice.

Delegated Transfer Functionality
Up to now, the ERC20 standard operations are pretty much what you might expect: inspect balances, directly transfer balances, etc. In addition to these operations, the standard requires support for a delegated transfer. In this model, the owner account of tokens can delegate the authority to transfer some of its tokens to another account. This idea is a bit subtle: the owner isn’t transferring the tokens to another account, but rather allowing that other account to transfer tokens to whomever it wishes. This facilitates exchange-brokered token transfers.

Delegated transfers in ERC20 are orchestrated with the following required pieces:

a delegation function (approve)
the subsequent indirect transfer function (transferFrom)
some state to remember what’s been delegated to whom (allowance)
an event that logs when delegations succeed (Approval)
Approval Event (required)
ERC20 requires an event to log the successful approval of a delegated token transfer, which logs the owner, the delegated spender, and the amount:

event Approval(address indexed owner, address indexed spender, uint256 value);
Just like the Transfer event, the account addresses are indexed parameters to aid event consumers.

allowance (required)
Because separate transactions delegate token transfer approval and actually transfer those tokens, it’s necessary to keep track of which accounts have delegated how much token authority to which other accounts. Fortunately, this can be done trivially with a nested mapping:

mapping(address => mapping(address => uint256)) public allowance;
This declaration of allowance is more complicated that we’ve seen before. The declaration includes a mapping within a mapping, which simply means that every address in the outer mapping will map to a distinct mapping, which will then map addresses to integers. It’s easiest to think of this a two-dimensional mapping, which maps pairs of addresses to integers. This notion is clearer when you see the getter that the Solidity compiler creates for this:

function allowance(address owner, address spender)
    view
    returns (uint256 remaining)
(That’s the function required by the ERC20 standard. I’m exploiting the fact that Solidity will generate that automatically from my allowance declaration.)

approve (required)
The ERC20 delegation function, approve, can be quite short:

function approve(address spender, uint256 value) public returns (bool success) {
    allowance[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
}
A few notes on the code above:

It’s msg.sender’s account that is delegating a transfer, as can be seen in the adjustment to allowance.
A sender can approve a delegated transfer that exceeds their actual token balance. Because the transfer wouldn’t happen until transferFrom is called, the check for adequate balance is deferred until then. Therefore, all approvals can succeed.
Even though all approvals can succeed, the function is still required to return true.
approve must log its parameters with an Approval event.
transferFrom
ERC20’s transferFrom function is the most complicated function in ERC20. transferFrom is called by the delegated-to account in order to transfer tokens to another account.

function transferFrom(address from, address to, uint256 value)
    public
    returns (bool success)
{
    require(value <= balanceOf[from]);
    require(value <= allowance[from][msg.sender]);

    balanceOf[from] -= value;
    balanceOf[to] += value;
    allowance[from][msg.sender] -= value;
    emit Transfer(from, to, value);
    return true;
}
There’s a lot going on above:

require(value <= balanceOf[from]) guarantees that the delegator actually owns enough tokens to satisfy the transfer request.
require(value <= allowance[from][msg.sender]) guarantees that the spender is actually authorized to transfer that many tokens from the delegator’s balance.
allowance[from][msg.sender] -= value; reduces the number of tokens the spender is allowed to transfer on behalf of the delegator.
Just like for the transfer function, a successful transfer must log a Transfer event.
As before, if an attempt is made to transfer too many tokens, I’ve chosen to revert the transaction rather than return false.
Summary
ERC20 token contracts must support direct and indirect token transfers.
ERC20 token contracts optionally support names, symbols, and decimal fixed-point scaling.
The Whole ERC20 Contract
erc20.sol
pragma solidity ^0.4.21;

contract SimpleERC20Token {
    // Track how many tokens are owned by each address.
    mapping (address => uint256) public balanceOf;

    string public name = "Simple ERC20 Token";
    string public symbol = "SET";
    uint8 public decimals = 18;

    uint256 public totalSupply = 1000000 * (uint256(10) ** decimals);

    event Transfer(address indexed from, address indexed to, uint256 value);

    function SimpleERC20Token() public {
        // Initially assign all tokens to the contract's creator.
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value);

        balanceOf[msg.sender] -= value;  // deduct from sender's balance
        balanceOf[to] += value;          // add to recipient's balance
        emit Transfer(msg.sender, to, value);
        return true;
    }

    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 value)
        public
        returns (bool success)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        public
        returns (bool success)
    {
        require(value <= balanceOf[from]);
        require(value <= allowance[from][msg.sender]);

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
}
← What is an Ethereum Token?Writing a Token Sale Contract →
  