Program the Blockchain	Archive About Subscribe
Writing a Very Simple Smart Contract
DECEMBER 8, 2017 BY TODD PROEBSTING
This article will demonstrate how to write a simple, but complete, smart contract in Solidity that maintains and updates persistent state. The demonstration will begin with an even simpler contract, which is progressively enhanced in two steps. Future articles will build on these ideas to construct more complicated and interesting smart contracts.

A Trivial Contract
While it is legal to write a contract that does nothing, that’s not particularly interesting. Slightly more interesting would be a contract that simply represents a single integer value (77):

pragma solidity ^0.4.17;

contract Trivial {
    function getValue() public view returns (uint256) {
        return 77;
    }
}
Here’s a quick explanation of the code above:

pragma solidity ^0.4.17 asserts the version of Solidity compiler that is expected.
contract Trivial declares the name of this contract.
function getValue() declares a function named “getValue” that has no parameters.
public declares that this function may be invoked by an external transaction.
view asserts that this function has no side effects.
returns (uint256) declares that this function returns a 256-bit unsigned integer value.
return 77 will cause the function to return the integer value 77 to the caller.
Most of that is typical of modern programming languages, except for the view declaration. The view declaration is surprisingly important in Solidity contracts because view functions can be executed for free.

The distributed system that maintains the Ethereum blockchain is made up of a network of many nodes. To maintain the blockchain requires that each of these nodes run a virtual machine that executes any invoked contract functions. In Ethereum, smart contract function execution requires payment (in Ether), which is called “gas”.

Each transaction is submitted with gas to cover the cost of its execution. Every instruction the virtual machine executes consumes some gas, which means that a transaction might run out of gas prior to completing. If that happens, then the transaction is completely aborted—no persistent changes happen as a consequence of that aborted transaction.

Interestingly, view functions have the unique property that they do not require any gas. For this reason, any public function without side effects should be declared as a view function.

A Contract With Persistent State
The Trivial contract presented some basic Solidity functionality. This next example extends that example by making the return value something that is part of the contract’s persistent storage.

pragma solidity ^0.4.17;

contract State {
    uint256 state;  // persistent contract storage

    function State(uint256 _state) public {
        state = _state;
    }

    function getValue() public view returns (uint256) {
        return state;
    }
}
The code above introduces the following new techniques:

uint256 state; declares a contract-level variable named “state” of type uint256. All contract-level variables are persistent—with their associated values maintained between function/transaction executions. (Changes to these variables only persist if the function terminates successfully.)
function State(uint256 _state) public declares the initialization (aka constructor) function for this contract. We know it is the initialization code because it has the same name (State) as the contract itself. This code is executed exactly once, when the contract is initially deployed. This constructor takes a single parameter, which is supplied by the transaction that is deploying the contract.
Deploying this State contract using the argument 99 for the initializor, would execute function State resulting in the state variable persistently holding the value 99. All subsequent invocations of getValue() would return 99.

The transaction deploying the contract would require some gas payment, but calls to getValue() would not (because it is a view function).

A Contract With Changing State
Of course, persistent state that never changes value is not particularly useful. To demonstrate how to change state, we will add a single function that will increment the stored value to create a (persistent) counter.

counter.sol
pragma solidity ^0.4.17;

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
Aside from changing some names from the previous contract, this example simply adds an increment() function. There are two notable things about this new function:

The function’s visibility is public, which makes it invocable by anybody.
The function is not a view function because it has the (persistent) side effect of changing the value of the contract’s count variable.
Because increment() is not a view function, invoking transactions must come with gas to pay for execution.
Summary
Ethereum smart contracts represent persistent code and data on the Ethereum blockchain.
Once deployed, a contract exists forever, and any public function can be invoked by anybody.
Through the use of persistent state, contracts can maintain values between function executions.
Some, but not all, functions cost gas (ether) to be executed.
If a function fails to terminate normally, it will have no persistent side effect (ie, persistent storage is unchanged from the values held when the function started execution).
← What Is a Smart Contract?Building Decentralized Apps With Ethereum and JavaScript →
  