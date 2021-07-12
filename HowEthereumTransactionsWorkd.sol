Program the Blockchain	Archive About Subscribe
How Ethereum Transactions Work
DECEMBER 29, 2017 BY STEVE MARX AND TODD PROEBSTING
[This blog post explains a little bit about how transactions work in Ethereum, but it is not necessary for learning Solidity programming. We write it for those of you who’d like a little deeper understanding of what is going on when a transaction is attempted.]

Smart contracts are interesting because of the side-effects they can have—including transferring ether—when executing transactions. How exactly are transactions constructed and sent to the network?

Sending a Transaction to the Network
To make any change to the Ethereum blockchain, a transaction must be sent. A transaction is a cryptographically-signed message that specifies what change is to be made, and it is sent to any node in the network. Based on Ethereum’s rules of consensus, the network then agrees that the transaction is a valid one, and it is included in a block that is added to the blockchain.

The message that makes up the transaction is an RLP-encoded array that specifies the details of the transaction. The following values are encoded:

recipient – The account address to which the transaction is being sent.
value – The amount of ether to transfer from the sender to the recipient. This amount may be zero.
data – Optional arbitrary binary data. During contract deployment, this is where the contract’s bytecode is sent. When calling a function on a contract, this specifies which function should be called and with what arguments. For simple transfers of ether, the data portion of the transaction is typically omitted.
gas limit – The maximum amount of gas that can be consumed by the transaction.
gas price – The amount the sender will pay for each unit of gas.
nonce – A sequence number called a “nonce”. The sequence number is per sender and must match the next available sequence number exactly.
signature – Data that identifies and authenticates the transaction’s sender.
Internal Transactions
“Externally owned accounts” are accounts typically owned by people. Smart contracts are the the other type of account. See this post for more details.
The above description of a transaction assumes that it originates from an externally owned account. In fact, all Ethereum transactions are sent from externally owned accounts. Contracts can also send ether and invoke functions in other contracts, but this mechanism is properly called a “message.” Unfortunately, it is often referred to as an internal transaction, which leads to some confusion.

A message sent by a contract differs from a true transaction in two ways: it does not include a cryptographic signature, and it is not included directly in the blockchain. Rather, it is part of the side effects of the original transaction that was sent to the contract from an externally owned account.

Calling Smart Contract Functions
In Solidity, every public function that can change state is invocable via a transaction. From the vantage of a programmer, the invocation requires three components: the address of the contract, which function is to be invoked, and the values of the arguments to that function (if any).

Note that our definition of a transaction makes no (direct) mention of functions or arguments. That’s because the Ethereum Virtual Machine does not have a notion of functions or arguments. Instead, those are encoded during the compilation process into lower level primitives for the EVM. The function’s signature and its arguments are encoded into the “data” in the transaction request. (For more on the encoding details, please explore the resources at the end of this post.)

The Nonce
The sequence number “nonce” is a security measure in the Ethereum system that prevents replay attacks on transactions. The sequence number is per sender. The fact that the network requires each subsequent transaction request to have a unique sequence number from all previously executed transactions (from this sender) means that no transaction can be replayed.

Summary
All actions that modify the Ethereum blockchain use transactions.
Transactions addressed to smart contracts include encoded data that identifies what function should be invoked and its arguments (if any).
Transactions include a promise to pay a limited amount of ether for gas, and they may also include a transfer of ether to the recipient.
The use of a nonce and a cryptographic signature guarantees that only authorized transactions are performed.
Fortunately, the support tooling around the Ethereum network hides many of the low-level details from users. Users, for the most part, can stick with high-level abstractions like contract addresses, function names, argument values, etc.

Resources
An excellent, but much more technically detailed, explanation can be found in How To Decipher A Smart Contract Method Call.

The definitive explanation is in the Yellow Paper.

← Checking the Sender in a Smart ContractMaking Smart Contracts with Public Variables →
  