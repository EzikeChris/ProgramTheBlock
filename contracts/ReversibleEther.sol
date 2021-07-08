Program the Blockchain
Archive About Subscribe
Reversible Ether
JUNE 9, 2018 BY STEVE MARX
In this post, I’ll develop an ERC20 token that acts as “reversible ether” as described by Ethereum’s creator, Vitalik Buterin:

Someone should come along and issue an ERC20 called "Reversible Ether" that is 1:1 backed by ether but has a DAO that can revert transfers within N days.

–VITALIK BUTERIN, APRIL 2018

This idea is intriguing. In the world of credit cards and banks, it’s often possible to reverse transactions in the case of mistakes or fraud. In the world of cryptocurrencies, every transaction is final and irreversible. Vitalik’s tweet about “reversible ether” suggests doing two things:

Wrap ether in a token that allows for reversals.
Use a decentralized autonomous organization (DAO) to decide by group consensus what transactions should be reversed.
In this post, I’ll focus on just the first challenge. I’ll show how an ERC20 token can keep track of pending transfers and allow a trusted third party to reverse them. My “reversible ether” implementation will be based on the EtherToken contract we introduced in our post about wrapping ether in an ERC20 token.

Parameterization
Like EtherToken, ReversibleEther accepts a name and symbol for the token. It also accepts an escrowDuration, which specifies how long a transfer stays “pending.”

During that escrow period, a transfer can be reversed by a trusted arbiter account. (Keep in mind that the arbiter account could very well be a smart contract that implements some sort of group consensus protocol.)

contract ReversibleEther is EtherToken {
    address arbiter;
    uint256 escrowDuration;

    constructor(string _name, string _symbol, uint256 _escrowDuration)
        EtherToken(_name, _symbol)
        public
    {
        arbiter = msg.sender;
        escrowDuration = _escrowDuration;
    }
Two Balances and ERC20 Compatibility
Most ERC20 tokens have a straightforward notion of account balances: when a token is transferred to an account, that account’s balance increases by one token. That token can immediately be spent by transferring it to another account.

A reversible ether token can’t work that way. When a token is transferred, it is not immediately available to be spent. The transfer might be reversed until some escrow period has passed, e.g. 30 days.

My reversible ether implementation will keep track of two balances for each account. The first balance is just the typical ERC20 balanceOf. It is immediately updated for each token transfer.

The second balance is called availableBalanceOf, and it tracks what portion of an account’s balanceOf is currently available to be spent:

// balanceOf is inherited from EtherToken

mapping(address => uint256) public availableBalanceOf;
There are a number of ways to keep track of these balances, but using a balanceOf that is immediately updated on each transfer maximizes compatibility with the ERC20 token standard.

Buying and Selling Reversible Ether
ReversibleEther inherits buy() and sell() functions from EtherToken, but those functions need to be overridden to adjust availableBalanceOf correctly:

function buy() public payable {
    super.buy();
    availableBalanceOf[msg.sender] += msg.value;
}

function sell(uint256 amount) public {
    require(availableBalanceOf[msg.sender] >= amount, "Insufficient funds.");

    super.sell(amount);
    availableBalanceOf[msg.sender] -= amount;
}
Keeping Track of Pending Transfers
A token transfer immediately updates balanceOf, as in a typical ERC20 transfer, but it does not update availableBalanceOf. Instead, pending transfers are tracked in a global array and a per-recipient set:

struct PendingTransfer {
    address from;
    address to;
    uint256 amount;
    uint256 finalTimestamp;
    uint256 setIndex;  // index into pendingTransferSet[to]
}

// global array of pending transfers
PendingTransfer[] public pendingTransfers;

// per-recipient set of pending transfer (for ease of enumeration)
mapping(address => uint256[]) public pendingTransferSet;
Here’s a brief explanation of the code above:

The finalTimestamp keeps track of when the transfer can be considered final. After this time, it cannot be reversed.
pendingTransfers is a global array of all pending transfers. As pending transfers are deleted, the array will become sparse. Slots are never reused, so this array gives each transfer a unique and unchanging ID.
setIndex and pendingTransferSet are used together to implement a set, as described in my recent post “Storage Patterns: Set.” This makes it easy for a recipient to enumerate their pending transfers.
The internal helper function startTransfer() updates the appropriate data structures with the incoming transfer:

event Pending(address indexed from, address indexed to, uint256 index);

function startTransfer(address from, address to, uint256 value) internal {
    require(availableBalanceOf[from] >= value, "Insufficient funds.");
    availableBalanceOf[from] -= value;

    // Add to set of pending transfers for the recipient.
    uint256 newIndex = pendingTransfers.length;
    pendingTransferSet[to].push(newIndex);

    // Add to global array of pending transfers.
    pendingTransfers.push(PendingTransfer({
        from: from,
        to: to,
        amount: value,
        finalTimestamp: now + escrowDuration,
        setIndex: pendingTransferSet[to].length - 1
    }));

    emit Pending(from, to, newIndex);
}
Here’s a brief explanation of the above code:

The sender’s availableBalanceOf is checked and updated to reflect the transfer. (balanceOf is updated through the typical ERC20 transfer functions.)
The recipient’s pendingTransferSet is updated to include the ID of the new pending transfer.
The new pending transfer is appended to pendingTransfers.
finalTimestamp is set to escrowDuration in the future.
An event is emitted to make it easy for clients to know that the transfer is now pending.
The standard transfer() and transferFrom() inherited from EtherToken need to be overridden to call startTransfer():

function transfer(address to, uint256 value) public returns (bool) {
    startTransfer(msg.sender, to, value);
    return super.transfer(to, value);
}

function transferFrom(address from, address to, uint256 value)
    public
    returns (bool)
{
    startTransfer(from, to, value);
    return super.transferFrom(from, to, value);
}
Note that EtherToken’s implementations of transfer() and transferFrom() are guaranteed to either revert or return true. Otherwise, I would need to check their return values.

Finalizing Transfers
Once the escrow period has elapsed, a pending transfer can be considered final. The finalizeTransfer() function updates the recipient’s availableBalanceOf and removes the transfer from the pending transfer data structures:

event Finalized(address indexed from, address indexed to, uint256 index);
function finalizeTransfer(uint256 index) public {
    PendingTransfer storage pending = pendingTransfers[index];

    require(now >= pending.finalTimestamp);

    availableBalanceOf[pending.to] += pending.amount;
    emit Finalized(pending.from, pending.to, index);

    deletePendingTransfer(index);
}
Note that anyone can call this function, but it will likely be called by the recipient of the transfer. The pendingTransferSet makes it easy for a recipient to enumerate all their pending transfers and finalize those that are ready.

deletePendingTransfer() is a helper function that is responsible for cleaning up the data structures. Notably, it implements the swapping algorithm from “Storage Patterns: Set.”

function deletePendingTransfer(uint256 index) internal {
    PendingTransfer storage pending = pendingTransfers[index];

    uint256 setIndex = pending.setIndex;
    uint256[] storage set = pendingTransferSet[pending.to];

    // Swap with last element.
    uint256 lastValue = set[set.length - 1];
    set[setIndex] = lastValue;
    pendingTransfers[lastValue].setIndex = setIndex;

    // Shrink the set and delete the pending transfer.
    set.length -= 1;
    delete pendingTransfers[index];
}
Reversing Transfers
During the escrow period, it’s possible for the trusted third-party arbiter to reverse the transfer:

event Reversed(address indexed from, address indexed to, uint256 index);
function reversePendingTransfer(uint256 index) public {
    require(msg.sender == arbiter);

    PendingTransfer storage pending = pendingTransfers[index];

    require(now < pending.finalTimestamp);

    balanceOf[pending.to] -= pending.amount;
    balanceOf[pending.from] += pending.amount;
    // All changes to balanceOf should emit ERC20 Transfer events.
    emit Transfer(pending.to, pending.from, pending.amount);

    availableBalanceOf[pending.from] += pending.amount;
    emit Reversed(pending.from, pending.to, index);

    deletePendingTransfer(index);
}
Here’s a brief explanation of that code:

Only the arbiter is allowed to reverse transfers.
Transfers can only be reversed during the escrow period.
Reversing a transfer updates balanceOf for both accounts.
An ERC20 Transfer event is emitted to reflect the change in balances.
The recipient’s availableBalanceOf increases, because those funds are immediately available for spending.
The Reversed event makes it easy for clients to observe the reversal.
deletePendingTransfer() is used again here to clean up the pending transfer data structures.
Summary
Reversible ether is a “wrapped ether” token that allows transfers to be reversed within a given escrow period.
To support reversals, the token must keep track of two balances: the total amount of tokens owned and the amount currently available for spending.
When building a token with new semantics, it’s important to consider compatibility with existing standards and tools.
Full Source Code
reversibleether.sol
pragma solidity ^0.4.24;

import "ethertoken.sol";

contract ReversibleEther is EtherToken {
    address arbiter;
    uint256 escrowDuration;

    constructor(string _name, string _symbol, uint256 _escrowDuration)
        EtherToken(_name, _symbol)
        public
    {
        arbiter = msg.sender;
        escrowDuration = _escrowDuration;
    }

    // balanceOf is inherited from EtherToken

    mapping(address => uint256) public availableBalanceOf;

    function buy() public payable {
        super.buy();
        availableBalanceOf[msg.sender] += msg.value;
    }

    function sell(uint256 amount) public {
        require(availableBalanceOf[msg.sender] >= amount, "Insufficient funds.");

        super.sell(amount);
        availableBalanceOf[msg.sender] -= amount;
    }

    struct PendingTransfer {
        address from;
        address to;
        uint256 amount;
        uint256 finalTimestamp;
        uint256 setIndex;  // index into pendingTransferSet[to]
    }

    // global array of pending transfers
    PendingTransfer[] public pendingTransfers;

    // per-recipient set of pending transfer (for ease of enumeration)
    mapping(address => uint256[]) public pendingTransferSet;

    event Pending(address indexed from, address indexed to, uint256 index);

    function startTransfer(address from, address to, uint256 value) internal {
        require(availableBalanceOf[from] >= value, "Insufficient funds.");
        availableBalanceOf[from] -= value;

        // Add to set of pending transfers for the recipient.
        uint256 newIndex = pendingTransfers.length;
        pendingTransferSet[to].push(newIndex);

        // Add to global array of pending transfers.
        pendingTransfers.push(PendingTransfer({
            from: from,
            to: to,
            amount: value,
            finalTimestamp: now + escrowDuration,
            setIndex: pendingTransferSet[to].length - 1
        }));

        emit Pending(from, to, newIndex);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        startTransfer(msg.sender, to, value);
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value)
        public
        returns (bool)
    {
        startTransfer(from, to, value);
        return super.transferFrom(from, to, value);
    }

    event Finalized(address indexed from, address indexed to, uint256 index);
    function finalizeTransfer(uint256 index) public {
        PendingTransfer storage pending = pendingTransfers[index];

        require(now >= pending.finalTimestamp);

        availableBalanceOf[pending.to] += pending.amount;
        emit Finalized(pending.from, pending.to, index);

        deletePendingTransfer(index);
    }

    function deletePendingTransfer(uint256 index) internal {
        PendingTransfer storage pending = pendingTransfers[index];

        uint256 setIndex = pending.setIndex;
        uint256[] storage set = pendingTransferSet[pending.to];

        // Swap with last element.
        uint256 lastValue = set[set.length - 1];
        set[setIndex] = lastValue;
        pendingTransfers[lastValue].setIndex = setIndex;

        // Shrink the set and delete the pending transfer.
        set.length -= 1;
        delete pendingTransfers[index];
    }

    event Reversed(address indexed from, address indexed to, uint256 index);
    function reversePendingTransfer(uint256 index) public {
        require(msg.sender == arbiter);

        PendingTransfer storage pending = pendingTransfers[index];

        require(now < pending.finalTimestamp);

        balanceOf[pending.to] -= pending.amount;
        balanceOf[pending.from] += pending.amount;
        // All changes to balanceOf should emit ERC20 Transfer events.
        emit Transfer(pending.to, pending.from, pending.amount);

        availableBalanceOf[pending.from] += pending.amount;
        emit Reversed(pending.from, pending.to, index);

        deletePendingTransfer(index);
    }

    function pendingTransferCount(address addr)
        public
        view
        returns (uint256)
    {
        return pendingTransferSet[addr].length;
    }
}
← Supporting Off-Chain Token TradingBetting Tokens In A Prediction Market →
  