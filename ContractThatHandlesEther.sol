Program the Blockchain	Archive About Subscribe
Writing a Contract That Handles Ether
DECEMBER 15, 2017 BY TODD PROEBSTING
This post will demonstrate how to write a simple, but complete, smart contract in Solidity that accepts and distributes ether. It assumes that you have read our previous post, Writing a Very Simple Smart Contract.

Accounts Own Ether
Both kinds of Ethereum accounts (smart contracts and Externally-Owned Accounts) can own ether. Given an account’s address, its current ether balance can be accessed in Solidity as address.balance. A smart contract can access its own balance as address(this).balance. The following contract’s getBalance() function returns the current balance of ether that it owns:

pragma solidity ^0.4.17;

contract CommunityChest {
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
While getBalance demonstrates the use of address(this).balance, the function is not strictly necessary because it’s always possible for anybody (or any smart contract) to directly access another account’s ether balance using that other account’s address.

Deposit
To allow other accounts to deposit and withdraw ether from this smart contract, we will add a couple of routines. Let’s start with a deposit() function that deposits ether:

pragma solidity ^0.4.17;

contract CommunityChest {
    function deposit() payable public {
        // nothing to do!
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
Here’s a quick explanation of the code above:

The payable modifier represents the ability of this deposit() function to accept the ether that the message’s sender attached to a transaction message.
The function requires no explicit action to accept the attached ether—attached ether is implicitly transferred to the smart contract.
Because of the implicit transfer, the deposit() function is surprisingly simple.

While deposit() can be trivially implemented like it was above, it’s a better practice to have the function take as a parameter the amount to be transferred and then to test that that’s the actual amount transferred. This allows the contract to reject transactions that may be erroneous:

pragma solidity ^0.4.17;

contract CommunityChest {
    function deposit(uint256 amount) payable public {
        require(msg.value == amount);
        // nothing else to do!
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
Here’s a quick explanation of the code above:

msg.value represents the ether that the message’s sender attached to a transaction message.
require(msg.value == amount); tests that the amount attached to the message (msg.value) is the amount that the sender passed as an argument. If a require fails, then the whole transaction fails and there are no side effects.
This last bullet highlights a fundamental design choice for contracts—each transaction either completes fully with all the state changes logged, or the transaction is aborted with absolutely no side effects. This pattern is exploited repeatedly when developing more complex contracts.

Withdraw
One important property of smart contracts is that there is absolutely no way to withdraw ether from a contract other than through execution of some function that the contract exposes. There are no “backdoors” that can allow the contract author or deployer to withdraw ether without going through the contract’s exposed functions. This is one fundamental reason why a well-written contract can be trusted to handle ether on behalf of users—the users can see the code and, therefore, the means by which owned ether will be used by the contract.

So, let’s implement a simple withdraw() function that will withdraw all the contract’s ether and give it to whatever account calls the withdraw() function:

community.sol
pragma solidity ^0.4.17;

contract CommunityChest {
    function withdraw() public {
        msg.sender.transfer(address(this).balance);
    }

    function deposit(uint256 amount) payable public {
        require(msg.value == amount);
        // nothing else to do!
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
Here’s a quick explanation of the code above:

msg.sender represents the address of the account that initiated this transaction.
address.transfer(amount) transfers amount (in ether) to the account represented by address.
The code above illustrates that transferring ether from a contract to another account is done with a single call to transfer(amount). Of course, the contract must own an adequate supply of ether to make the requested transfer; otherwise, the system will abort the transaction.

transfer() vs send()
In addition to the transfer() function for transferring ether, Solidity also offers a send() function. We discourage using send(), however, because it can be a little dangerous to use.

If transfer() encounters a problem, it will raise an exception, which will cause the transaction to abort. This will typically only happen if the transfer ran out of gas (as described in the previous section). Aborting the transaction under this circumstance is good/safe because you probably don’t want the transaction to complete under the false assumption that it has actually transferred ether.

send() returns true or false depending on whether it succeeded or failed in transferring ether, but it never aborts. If the smart contract does not check the return value, or if it does not correctly handle failure, the smart contract may get into an inconsistent (and irreparable) state. Therefore, we encourage the use of transfer() over send() for transferring ether out of a smart contract.

Solidity’s “Fallback Function”
Solidity has a novel construct called a “fallback function”, which is also used by smart contracts to accept ether transfers. Note the lack of a function name in the following code:

function() payable {
    // nothing to do
}
While this is a commonly used construct, we discourage its use, so we will not demonstrate it further here. Be Careful When Using the Solidity Fallback Function explains why.

Summary
Ethereum smart contracts can accept ether transfers in and make ether transfers out.
Contracts can access their current ether balance with address(this).balance.
Contract functions require the payable modifier to accept transfers in.
Contract can determine the amount of ether attached to an invocation using msg.value.
Contracts can transfer ether out using the transfer(amount) function. Contracts can also use the send(amount) function, but one should be careful to check its return value and to take the appropriate actions if it fails.
Contracts can accept direct ether transfers with the fallback function function() payable. We discourage its use, however.
← Building Decentralized Apps With Ethereum and JavaScriptBe Careful When Using the Solidity Fallback Function →
  