Program the Blockchain	Archive About Subscribe
Writing an Estate Planning Contract
FEBRUARY 20, 2018 BY TODD PROEBSTING
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

This post will demonstrate how to write a smart contract that transfers your ether to a beneficiary after you die. It assumes that you have read our previous post on dealing with time on the blockchain.

Suppose that you want to bequeath your ether to a beneficiary after you die. How would you transfer access to your ether in a trustless fashion? The answer, of course, is with a smart contract! The smart contract will be responsible for many operations:

The contract will hold ether on your behalf while you are alive, allowing you to make deposits and withdrawals freely.
The contract will include a mechanism for determining (with some confidence) that you are dead.
The contract will allow your beneficiary access to the ether after you are deemed dead.
Contract Inheritance
I am going to use this opportunity to introduce a common Solidity programming practice called “inheritance”, which enables one contract to inherit functions, modifiers and variables from another contract. This is very similar to inheritance in many object-oriented languages.

There are many common patterns in Solidity programs that are typically expressed via inheritance. Two common patterns are contracts having owners (with special privileges), and contracts allowing their owners to kill the contract:

contract Ownable {
    address owner = msg.sender;
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract Mortal is Ownable {
    function kill() public onlyOwner {
        selfdestruct(msg.sender);
    }
}

contract Estate is Mortal {
    // ...
}
The code above uses inheritance to provide my Estate contract with the variables, modifiers, and functions of the Ownable and Mortal contracts (i.e., owner, onlyOwner, and kill.)

Beneficiary
In addition to having an owner account, the Estate contract has a beneficiary account. The beneficiary stands to inherit the contract from the owner after the owner has died. Just as some contract functionality is restricted to the owner, some will be restricted to the beneficiary:

contract Estate is Mortal {

    address beneficiary;
    modifier onlyBeneficiary {
        require(msg.sender == beneficiary);
        _;
    }

    // ...
}
Am I Dead Or Not?
The interesting challenge this contract must address is how to determine if its owner has died. This is difficult because death happens off the blockchain, so the contract needs a way to learn of an off-chain event. Rather than solving that problem, I am going to employ a proxy test for death—the lack of a “heartbeat” during a given period of time.

Specifically, the design will be one where the beneficiary asserts that the owner has died, and then the owner must provide a “heartbeat” transaction within a waiting period. If the owner makes the heartbeat before the period expires, then he hasn’t died. If not, then the contract considers him dead, and it will transfer ownership to the beneficiary upon request.

To monitor the state of the assertions of death and the period of the challenge, the contract will maintain two time values:

uint256 waitingPeriodLength;    // Duration of challenge period
uint256 endOfWaitingPeriod;     // End of challenge period
The waitingPeriodLength period is the length of time after the beneficiary asserts death that must be waited for the owner to possibly prove they are alive. endOfWaitingPeriod is the time of the end of that waiting period.

To keep things simple, I will use a sentinel value for endOfWaitingPeriod that is so far out in the future as to be unimaginable. This will be the value when the beneficiary has not asserted that the owner is dead.

I will define a heartbeat modifier that will reset the endOfWaitingPeriod value to that end-of-ages time. The modifier will be used on every routine where the owner proves he is alive:

modifier heartbeat {
    _;
    endOfWaitingPeriod = 10 ** 18;  // approximate age of the universe
}
The heartbeat modifier is a little unusual because it will add the code to the end of the function it modifies. This will allow heartbeat to be used later in the claimInheritance function that tests the (current) value of endOfWaitingPeriod upon entry.

Now that we have all the scaffolding in place, I can show the simple constructor:

function Estate(address _beneficiary, uint256 _waitingPeriodLength)
    public
    heartbeat
{
    beneficiary = _beneficiary;
    waitingPeriodLength = _waitingPeriodLength;
}
The constructor directly sets the beneficiary and waitingPeriodLength variables as well as setting endOfWaitingPeriod via the heartbeat modifier.

Asserting Death
The beneficiary can assert that the owner has died with the assertDeath function:

event Challenge(uint256 endOfWaitingPeriod);

function assertDeath() public onlyBeneficiary {
    endOfWaitingPeriod = now + waitingPeriodLength;
    emit Challenge(now);
}
assertDeath sets endOfWaitingPeriod out in the future by waitingPeriodLength seconds from now. If the owner doesn’t interact with the contract to reset endOfWaitingPeriod (via heartbeat), then the beneficiary can claim ownership.

As a convenience to the (possibly not dead) owner, assertDeath logs an event that the owner can monitor.

Claiming Ownership
The beneficiary can claim ownership and set his beneficiary with claimInheritance:

function claimInheritance(address newBeneficiary)
    public
    onlyBeneficiary
    heartbeat
{
    require(now >= endOfWaitingPeriod); // waiting period expired

    owner = beneficiary;
    beneficiary = newBeneficiary;
}
One subtlety to claimInheritance is its use the heartbeat modifier. That is needed to reset the endOfWaitingPeriod to its sentinel value for the new owner.

In deciding what the contract should do after the owner died, I had a design choice. I chose to have the smart contract’s ownership change, but I could just as easily have had the contract self-destruct and send the ether to the beneficiary. I chose changing ownership because it seemed elegant to me because the new owner may face the same estate planning challenge as the previous owner.

Holding Ether Balances
Of course, it’s important for the contract’s owner to be able to access his ether while alive. The contract has a simple mechanism for the owner to deposit and withdraw funds.

function deposit() public payable onlyOwner heartbeat {
    // nothing else to do
}

function withdraw(uint256 amount) public onlyOwner heartbeat {
    msg.sender.transfer(amount);
}
The deposit and withdraw routines do a few subtle things:

Both routines capture much of their functionality in the onlyOwner and heartbeat modifiers.
Because both routines are limited to the owner, it makes sense for both to serve as heartbeats (and update endOfWaitingPeriod to its sentinel value). In fact, a deposit of zero ether acts as a simple, low-gas heartbeat for the owner.
withdraw does not check whether the contract has sufficient ether because that check will be done by the transfer function.
The Complete Contract
estate.sol
pragma solidity ^0.4.21;

contract Ownable {
    address owner = msg.sender;
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract Mortal is Ownable {
    function kill() public onlyOwner {
        selfdestruct(msg.sender);
    }
}

contract Estate is Mortal {
    address beneficiary;
    modifier onlyBeneficiary {
        require(msg.sender == beneficiary);
        _;
    }

    uint256 waitingPeriodLength;
    uint256 endOfWaitingPeriod;
    modifier heartbeat {
        _;
        endOfWaitingPeriod = 10 ** 18;  // approximate age of universe
    }

    function Estate(address _beneficiary, uint256 _waitingPeriodLength)
        public
        heartbeat
    {
        beneficiary = _beneficiary;
        waitingPeriodLength = _waitingPeriodLength;
    }

    function deposit() public payable onlyOwner heartbeat { }

    function withdraw(uint256 amount) public onlyOwner heartbeat {
        msg.sender.transfer(amount);
    }

    event Challenge(uint256 timestamp);

    function assertDeath() public onlyBeneficiary {
        endOfWaitingPeriod = now + waitingPeriodLength;
        emit Challenge(now);
    }

    function claimInheritance(address newBeneficiary)
        public
        onlyBeneficiary
        heartbeat
    {
        require(now >= endOfWaitingPeriod);

        owner = msg.sender;
        beneficiary = newBeneficiary;
    }
}
← Signing and Verifying Messages in EthereumWriting a Simple Payment Channel →
  