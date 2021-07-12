Program the Blockchain	Archive About Subscribe
Be Careful When Using the Solidity Fallback Function
DECEMBER 16, 2017 BY TODD PROEBSTING
This post will discuss Solidity’s anonymous “fallback function”, which is a commonly used mechanism for accepting ether transfers. This post expands a topic briefly mentioned in the post, Writing a Contract That Handles Ether. Below, we explain what this function does and why we encourage caution when using it.

A smart contract developed with Solidity has an Application Binary Interface (ABI) that describes the public functions exposed by that smart contract. This ABI enables others to determine how to send a properly formatted transaction to a public function of a smart contract with confidence that the transaction will result in the proper code being executed. Each public function has a function selector, which is encoded as a 4-byte address within the contract. The prologue code in a smart contract checks the transaction’s function selector for validity and transfers execution to the appropriate function.

Transactions Without Valid Function Selectors
What happens if a transaction doesn’t include an expected function selector? Solidity allows programmers to specify a parameterless, anonymous “fallback function” that will handle every transaction attempted on a nonexistent function selector. (The term “fallback” here refers to the idea that if the contract doesn’t know what to do with a given transaction’s function selector, it will “fall back” on executing this function.)

There are some very advanced applications of such a fallback function, but there is one simple and common use—to allow trivial transactions to transfer ether to a smart contract:

pragma solidity ^0.4.19;

contract Fallback {

    function() payable {
        // nothing to do
    }

}
Here’s a quick explanation of the code above:

function() represents an anonymous, parameterless fallback function.
Because of the payable modifier, it can accept ether.
A payable fallback function to accept an ether transfer is a very common pattern in Solidity programs.

Fallback Functions Can Be Dangerous
It is possible to put code in the body of this function, but it’s generally considered bad practice to put anything beyond very short, simple logic. The reason is important and unique to smart contracts: you don’t want this function to fail because it runs out of gas. This is a concern because many account-to-account direct transfers of ether are given a default amount of gas, which is actually quite small. To avoid running out of gas, it’s important that the function’s code use less gas than this default amount. As a rule of thumb, you will have just enough gas to log an event, but not enough to write data to storage.

Payable fallback functions may also be dangerous to anybody who attaches ether to a transaction on the wrong account. For instance, imagine attaching ether to a “bid” transaction mistakenly sent to account 0x123 when it was supposed to go to account 0x789. If the contract at 0x123 has a payable fallback function, the sender will likely have no way to recover that ether. If account 0x123 did not have a payable fallback function, this transaction would have simply failed, and no damage would have been done.

When you can dictate to callers what function they call, like when building a DApp, you should avoid the fallback function. You should instead use a named function like buy(), bid(), or deposit() to help avoid costly mistakes by consumers.

When Is a Fallback Function Necessary?
Unfortunately, it may be necessary for a smart contract to assume account-to-account transfers will be done with direct transfers that require a fallback function. This is because the transferring account may need to make transfers to both Externally-Owned Accounts (EOAs) and to other smart contracts. EOAs can only accept direct transfers, so the transferring account must use use direct transfers. This means that any contract that wants to accept such transfers must be prepared for direct transfers by having a fallback function. Without that function, the transfer would fail, and it would be impossible for the contract to accept ether from the other contract.

Summary
Contracts can accept direct ether transfers with the payable fallback function, function() payable.
When possible, it’s best to avoid including a payable fallback function. This helps to prevent people from sending ether to your contract by mistake.
When a contract has to act the same as an EOA in terms of accepting ether (e.g. when it’s going to “withdraw” ether from another contract), then it needs to have a payable fallback function to accept the ether.
The fallback function is often invoked as a simple transfer with very limited gas, so minimize how much code your fallback function includes.
← Writing a Contract That Handles EtherTesting and Deploying Smart Contracts with Remix →
  