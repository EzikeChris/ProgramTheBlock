Program the Blockchain	Archive About Subscribe
What Is a Smart Contract?
DECEMBER 6, 2017 BY TODD PROEBSTING
An Ethereum “smart contract” is a computer program that has been deployed to the Ethereum blockchain, where it will exist forever. Deployed smart contracts represent many different capabilities:

A deployed contract can maintain an ether balance—it can hold ether independently of whoever wrote the contract and of whoever deployed the contract.
A deployed contract has persistent storage that maintains state between code invocations.
A deployed contract executes code to perform “transactions” that are sent to it via one of the contract’s public functions.
Solidity and the Ethereum Virtual Machine
The most popular language for writing smart contracts is Solidity, which we will use for examples on this blog. Solidity is a JavaScript-like language with some special functionality tailored to writing contracts. Solidity programs are compiled into bytecode for the Ethereum Virtual Machine (EVM), which is implemented by the nodes of an Ethereum network.

Like everything on the blockchain, deployed contracts are public. Anybody can inspect the bytecode of a contract before interacting with it. This ability to inspect a contract before interacting with it enables people to verify that the contract does what its author says it does.

The lifecycle of a contract is pretty simple: somebody writes and deploys the contract to the blockchain, and then anybody can send transactions to the contract. This is not as insecure as it might sound because every attempted transaction has a “sender”, and a contract can base its actions on who that sender is, thus enabling per-sender authorizations and security.

Every deployed contract has an address, which is a unique 160-bit integer that will subsequently be used for all references to that contract.

Accounts and Transactions
Ethereum has two kinds of “accounts”, which maintain ether balances: contracts and “externally owned accounts” (EOAs). It’s simplest to think of EOAs as accounts that represent a personal balance for a person. EOAs do not have associated code—just an ether balance as well as a public/private key pair. Contracts have associated code and an ether balance, but they do not have a key pair. After deployment, all a contract can do is respond to transactions sent by other accounts (either contracts or EOAs).

When one account sends a transaction to a smart contract, the appropriate code is executed as part of the process for committing changes to the blockchain. The committed changes will be the (intended) side effects of running that contract. These side effects are typically changes to the internal state of the contract and transfers of ether between that contract and another account. Transactions are executed on all nodes in the network when a block is committed to the blockchain, which is part of the reason we can trust the results of their execution will be recorded.

The execution of code associated with smart contracts along with the permanent maintenance of the corresponding state changes represent a cost to the Ethereum system. Therefore, the execution of smart contracts requires paying a transaction fee. The measurement unit for these computations is called “gas”. Every transaction includes the amount the sender is willing to pay for that gas (in ether), and a limit on how much gas can be spent. Once the transaction completes, the sender pays the transaction fee of the used gas multiplied by the specified gas price. Every single execution step of a contract’s code burns a little gas. If there’s inadequate gas to complete execution, then the transaction is aborted, no changes happen, but the sender still pays for the gas that was consumed.

Summary
Smart contracts are fully-programmable agents that can exploit the guarantees of a trustworthy blockchain and cryptocurrency. Many of the next posts to this blog will be an introduction to smart contracts through progressively more complex and involved examples that will exploit smart contract’s unique capabilities.

Other resources
Understanding Ethereum Smart Contracts
ethdocs.org
Writing a Very Simple Smart Contract →
  