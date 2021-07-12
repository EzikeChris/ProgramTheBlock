Program the Blockchain	Archive About Subscribe
Verifying Contract Source Code
JANUARY 16, 2018 BY STEVE MARX
For a deployed smart contract to be trusted, its source code should be available for inspection. This post explains why source code for smart contracts should be published and how someone can verify that published source code corresponds to a given deployed smart contract.

Trusting Smart Contracts
The power of smart contracts is that they’re “trustless.” Once deployed, a smart contract is immutable and tamper-proof. It is guaranteed to execute exactly the code that was written. That guarantee, however, is only meaningful if you know what code is being executed.

Everything on the blockchain is public, including smart contracts’ bytecode, but bytecode is low-level and quite difficult to understand. The source code, written in Solidity, is much more useful. If you want other people to trust your smart contracts, you should publish the source code, and before you interact with someone else’s smart contract, you should examine their source code.

This raises an important question: what prevents a malicious developer from publishing fake source code for their contract?

Verifying Source Code
As you may recall from our recent post How Smart Contract Deployment Works, the transaction that deploys a smart contract has a payload that is derived from the compiled source code and any constructor parameters. This process is fully deterministic, so if you compile the same source code with the same compiler and apply the same constructor parameters, you’ll get the exact same payload.

This repeatable process is the key to verifying the correspondence between Solidity source code and a deployed smart contract. When publishing your source code, you need to provide all the necessary information to recreate the deployment payload. In addition to the source code itself, you need to share what compiler settings you used, what version of the compiler you used, and what constructor parameters you applied. Anyone can then generate the corresponding deployment payload, and then they can find the transaction on the blockchain that created the smart contract in question. If the two payloads match, then the provided source code was, in fact, what was used to deploy that smart contract.

This process is a bit cumbersome, so most people choose to delegate this responsibility to a third party.

Publishing and Finding Source Code on Etherscan
Etherscan doesn’t check for an exact match of the full payload data. It specifically checks the compiled bytecode and the constructor parameters. The payload also contains metadata that includes hashes of each source file. By ignoring this metadata, Etherscan can verify source code with changes to whitespace or comments.
Etherscan is a highly-regarded set of tools and services for reading information from the Ethereum blockchain. Among other things, they provide source code verification as a service. Anyone can use their verify contract code tool to associate source code with any deployed contract. The tool will build the deployment payload, verify that the payload matches what’s found on the blockchain, and only then associate the payload with the contract. As long as people trust Etherscan to perform this verification process correctly, they don’t need to go through the verification steps themselves.
If Etherscan has verified source code for a deployed contract, you can find that code in the “Contract Source” tab when viewing the contract’s address. For example, the Counter Example DApp is published to the Ropsten test network. I verified its source code, so you can view the source code on Etherscan.

Because of the deterministic nature of this process, you don’t need to verify the source code again if you deploy a new smart contract using the same source code, the same compiler settings, and the same constructor parameters. Etherscan associates the source code with the deployment payload, not the individual contract address, so you’ll see the source code immediately after you deploy.

Summary
Smart contracts can’t truly be trusted unless their source code is available.
Source code needs to be verified to make sure it’s what was actually compiled and deployed.
Source code verification is possible because the deployment payload is deterministic.
Etherscan offers smart contract code verification as a service to make the process easier.
← Writing a Contract That Handles TimeWriting a Crowdfunding Contract (a la Kickstarter) →
  