Program the Blockchain	Archive About Subscribe
Anatomy of Transaction Data
JULY 25, 2018 BY STEVE MARX
[This blog post explains how transaction data is used to invoke smart contracts in Ethereum, but it is not necessary for learning Solidity programming. We write it for those of you who would like a deeper understanding of what is going on when a transaction is sent to a smart contract.]

In our previous post How Ethereum Transactions Work, we mentioned that the data field of a transaction encodes what (if any) smart contract function should be invoked. In this post, I’ll dive deeper into the specifics of the data field.

Smart Contracts Use Message Passing
Ethereum itself has no concept of a “function.” When a transaction is sent with a smart contract as the to address, the smart contract’s code is executed, and any data included in the transaction is made available to that code.

This technique is known as message passing. In a sense, every smart contract can be thought of as a single function that receives a single argument: a sequence of bytes. In Solidity, you can examine that raw sequence of bytes by accessing msg.data.

Solidity (and other languages) add the concept of “functions” on top of low-level message passing. This is essentially implemented as a big switch statement that invokes the right function based on the message data that was sent.

Function Selectors
Solidity uses the first four bytes of the message data to indicate which function to call. Specifically, the function selector is the first four bytes of the Keccak-256 hash of the function’s signature.

An example will help. The following is a standard function present in ERC20 token contracts:

function transfer(address to, uint256 value) public returns (bool success) {
    // ...
}
The canonical form of the function’s signature is the string transfer(address,uint256). (Note that parameter names and the return type are ignored when constructing the signature.)

The Keccak-256 hash of transfer(address,uint256) is, in hexadecimal, 0xa9059cbb2ab09eb219583f4a59a5d0623ade346d962bcd4e46b11da047c9049b.

The function selector is just the first four bytes of that hash: 0xa9059cbb.

Argument Encoding
After the four-byte function selector, Solidity treats the rest of the sent data as function arguments. The arguments are encoded according to the Application Binary Interface specification.

To ABI encode simple, statically-sized types, just pad with zeroes until each value is 32 bytes long:

The address 0x123456789a123456789a123456789a123456789a becomes 0x000000000000000000000000123456789a123456789a123456789a123456789a.
The number 5 becomes 0x0000000000000000000000000000000000000000000000000000000000000005.
For the full details of ABI encoding, I recommend the Solidity documentation.

Putting It All Together
The transaction data for the call transfer(0x123456789a123456789a123456789a123456789a, 5) is the concatenation of the following:

the function selector: 0xa9059cbb,
the padded address: 0x000000000000000000000000123456789a123456789a123456789a123456789a,
and the padded amount: 0x0000000000000000000000000000000000000000000000000000000000000005.
The full transaction data is then:

0xa9059cbb000000000000000000000000123456789a123456789a123456789a123456789a
0000000000000000000000000000000000000000000000000000000000000005
Using web3.js to Encode Transaction Data
Typically, there’s no need to manually encode transaction data. For most use cases, the encoding step is a transparent part of sending a transaction. For example, using web3.js:

contract.transfer("0x123456789a123456789a123456789a123456789a", 5);
For cases where the encoded transaction data is required, web3.js 0.2x.x provides the getData() function:

> contract.transfer.getData("0x123456789a123456789a123456789a123456789a", 5);
"0xa9059cbb000000000000000000000000123456789a123456789a123456789a123456789a0000000000000000000000000000000000000000000000000000000000000005"
(web3.js 1.0 beta has a similar function called encodeABI().)

Summary
Ethereum smart contracts work via message passing.
Function selectors tell Solidity code what function to execute.
Function arguments are ABI encoded and appended to message data.
Client libraries typically take care of the details of ABI encoding for you.
← State Channels with Signing KeysContracts Calling Arbitrary Functions →
  