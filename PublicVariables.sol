Program the Blockchain	Archive About Subscribe
Making Smart Contracts with Public Variables
JANUARY 2, 2018 BY STEVE MARX
State variables in Solidity, like functions, have a notion of visibility. By default, they are not marked as “public,” but this is a somewhat confusing concept in the context of a public blockchain, where all data can be read by anyone. In this post, I’ll give an overview of state variable visibility and explain why and how to mark a state variable as public.

Nothing is Hidden
The nature of a public blockchain like Ethereum is that all data is replicated on all nodes. When you run a full Ethereum node, you download the entire history of the blockchain from other nodes, starting from block #0 (the “genesis block”). Those blocks contain every transaction that has ever occurred in Ethereum. In fact, the security of the blockchain relies on the fact that all of these transactions are permanently, immutably, stored.

Due to the public nature of the Ethereum blockchain, it is impossible for a smart contract to contain truly hidden data. This is doubly true of state variables, because Ethereum provides a simple API to read them! Let’s revisit the Counter contract from Writing a Contract That Handles Ether:

pragma solidity ^0.4.19;

contract Counter {
    uint256 count;  // persistent contract storage

    function Counter(uint256 _count) public {
        count = _count;
    }

    function increment() public {
        count += 1;
    }

    function getCount() public view returns (uint256) {
        return count;
    }
}
Note that the default visibility for state variables in Solidity is internal (more on that later), so count is not public. The getCount function provides me with an easy way to read it, but even without that function, it’s trivial to read. This code using web3.js (when connected to Ropsten) will do the trick:

web3.eth.getStorageAt('0xf15090c01bec877a122b567e5552504e5fd22b79', 0,
  function (err, count) {
    console.log("Current count: " + parseInt(count, 16));
  });

// Output:
// Current count: 6
web3.eth.getStorageAt reads the storage for a contract by direct address lookup. It so happens that statically-sized state variables are laid out in storage starting at address 0, and the variable we’re looking for is the first one, so 0 is the correct address. See Layout of State Variables in Storage from the Solidity documentation for the details of storage layout. Determining the location of any state variable from the Solidity source is straightforward. Even obfuscated bytecode without the source doesn’t make it too hard to find a piece of data.

State Variable Visibility in Solidity
If all data is already public, why are there any options for state variable visibility other than public? To fully answer that question, it’s important to differentiate between two frames of reference:

An external actor, inspecting the contents of the blockchain.
Smart contract code, running inside the Ethereum Virtual Machine.
I’ve established that an external actor, including the JavaScript front end for a DApp, can read any data in the blockchain, but marking a state variable as public makes it considerably easier to access.

Getters for Public State Variables
Getters for arrays and mappings take an index parameter and return the specified value. For the full details of how getters work for complex types, see the Solidity documentation for getters.
Solidity automatically generates functions for reading public state variables called “getters.” A getter has the same name as the corresponding state variable and simply returns its value. Getters are view functions, so they can be called without paying for gas. Here’s an updated version of our Counter contract, this time using a public state variable:

pragma solidity ^0.4.19;

contract Counter {
    uint256 public count;

    function Counter(uint256 _count) public {
        count = _count;
    }

    function increment() public {
        count += 1;
    }
}
The public keyword indicates that the count state variable should have a getter. The getCount() function has been removed because it’s no longer needed. The generated function count() takes its place.

In my previous post Building Decentralized Apps With Ethereum and JavaScript, I wrote JavaScript to call getCount(). It can now call count() instead:

// Used to be counter.getCount.call(...)
counter.count.call(function (err, result) { ... });
This is just as convenient for a developer as the hand-written getCount() function, but it requires less code in the smart contract.

Hiding Data From Other Contracts
Now let’s consider our second frame of reference: a contract running inside the Ethereum Virtual Machine. Contracts can only communicate with each other via message passing, and they cannot directly read the storage of another contract. This is analogous to typical object-oriented programming. Although you, the programmer, can run a debugger and inspect anything in memory, at the programming language level, objects are able to enforce the use of a well-defined interface through data hiding.

Solidity provides data hiding through the use of private and internal visibility. private variables are only accessible to the declaring contract itself, and internal variables (the default) are accessible to the declaring contract and any contracts derived from it. public variables can be read via their getters by any contract.

Note that this still does not provide security around non-public variables. A developer can easily read the variable and send it to another contract via a transaction. Non-public variables are more about programming discipline than security.

When to Make a State Variable Public
You need to make state variables public (or write your own getters) if you want other contracts to be able to read them. You should make state variables public if you want to be able to read them easily from JavaScript or another programming language outside of Ethereum.

Summary
All data in the Ethereum blockchain is inherently public.
State variables are particularly easy to read, regardless of whether they’re marked public.
For state variables marked public, the Solidity compiler generates a getter with the same name.
Contracts can hide data from each other by using private and internal variables, but this does not provide security.
Resources
The Visibility and Getters section of the Solidity documentation is a great resource for learning more about this topic.

← How Ethereum Transactions WorkWriting a Banking Contract →
  