Program the Blockchain	Archive About Subscribe
Contracts Calling Arbitrary Functions
AUGUST 2, 2018 BY STEVE MARX
Solidity offers convenient high-level syntax for calling functions in other contracts, but this high-level syntax is only available when the target contract’s interface is known at compile time.

In this post, I’ll show how smart contracts can use low-level message passing to make arbitrary calls into other contracts. I’ll use this mechanism to enhance our trivial multisig wallet so that it can make function calls in addition to transferring ether.

High-Level Function Call Syntax
Before diving into the low-level mechanism, it’s worth reviewing Solidity’s high-level syntax for calling out to another contract. We’ve used this mechanism many times on this blog already. Here’s a very abridged example from our post Performing Multiple Actions Transactionally:

interface ITokenShop {
    function sell(uint256 amount) external;
}

contract Arbitrage {
    constructor (ITokenShop sellShop, uint256 amount) public {
        sellShop.sell(amount);
    }
}
The line sellShop.sell(amount) is where the external call happens. The Solidity compiler translates this high-level function call into low-level message passing. This is possible because the interface for ITokenShop is known at compile time, so the appropriate encoding logic can be emitted by the compiler.

The Low-Level call() Function
When the interface of the target contract is not known at compile time, Solidity’s high-level syntax is unavailable. For these scenarios, the address type includes a call() function.

call() can actually accept multiple parameters and do minimal ABI encoding at runtime. See the Solidity documentation for details.
call() accepts the raw message that is passed to the target contract. I showed how message data is constructed in my post Anatomy of Transaction Data. For now, I’ll assume that the data already exists:

address target = ...;
bytes memory data = ...;

bool result = target.call(data);
Note that call() returns a bool indicating whether the call succeeded. If the call reverts, this return value will be false. Otherwise, it will be true.

It’s possible to specify how much gas and how much ether are attached to the call:

target.call.gas(50000).value(1 ether)(data);
Using call() to Execute Arbitrary Function Calls
Our trivial multisig wallet uses the transfer() function to transfer ether to another address. To enable making arbitrary function calls, I’m going to use call() instead.

I need to add a new parameter for the message data, and this new parameter needs to be part of the signatures from the wallet owners:

function execute(
    ...
    bytes data,
    ...
)
    external
{
    bytes32 hash = prefixed(keccak256(abi.encodePacked(
        address(this), destination, value, data, nonce
    )));
Finally, I need to use call() to perform the function call, including transferring the specified amount of ether:

require(destination.call.value(value)(data));
Remember that if call() reverts, it returns false. I’m using require() to bubble that error up and revert the entire transaction if the call fails.

Summary
When the interface is known at compile time, Solidity provides nice high-level syntax for making external function calls.
When the interface is not known at compile time, the low-level call() function can be used to pass messages to other contracts.
A multisig wallet can be easily generalized to proxy arbitrary function calls using call() and encoded message data.
Full Source Code
multisig-execute.sol
pragma solidity ^0.4.24;

contract MultisigExecute {
    uint256 public nonce;     // (only) mutable state
    address[] public owners;  // immutable state

    constructor(address[] owners_) {
        owners = owners_;
    }

    function execute(
        address destination,
        uint256 value,
        bytes data,
        bytes32[] sigR,
        bytes32[] sigS,
        uint8[] sigV
    )
        external
    {
        bytes32 hash = prefixed(keccak256(abi.encodePacked(
            address(this), destination, value, data, nonce
        )));

        for (uint256 i = 0; i < owners.length; i++) {
            address recovered = ecrecover(hash, sigV[i], sigR[i], sigS[i]);
            require(recovered == owners[i]);
        }

        // If we make it here, all signatures are accounted for.
        nonce += 1;
        require(destination.call.value(value)(data));
    }

    function () payable {}

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", hash));
    }
}
← Anatomy of Transaction DataWriting a Penny Auction Contract →
  