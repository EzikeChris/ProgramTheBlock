Program the Blockchain
Archive About Subscribe
Writing a Trivial Multisig Wallet
JULY 11, 2018 BY TODD PROEBSTING
This post will demonstrate a very simple multisig wallet. This multisig wallet requires unanimous consent for the transfer of funds, and the consent is collected off-chain via signed messages.

Multisig wallets can include lots of complexity including many of the following capabilities:

Supporting N-of-M voting
Supporting delegation of votes
Supporting transferring of votes
Supporting arbitrary actions
Supporting multiple outstanding votes via on-chain bookkeeping
This post goes to the other extreme:

Votes must be unanimous
No delegation or transferring of votes
The only action is transferring ether
Voting is done off-chain with a single on-chain validation
This post borrows some techniques and inspiration from Exploring Simpler Ethereum Multisig Contracts. The code here is, however, even simpler.

Immutable List of Owners
This multisig wallet has multiple owners, who must all agree before funds are transferred from the wallet to a destination account. The owners are stored in an array:

contract UnanimousMultiSig {
    address[] public owners;  // immutable state

    constructor(address[] owners_) {
        owners = owners_;
    }

    // more to come
}
Off-Chain Consensus
Agreement is done off-chain via signed messages. The signed messages include four components:

The destination account that should receive the ether.
The ether value that should be transferred.
The message’s (R,S,V) signature.
The sequential nonce of the message. The nonce prevents a message replay vulnerability. Each successful transfer increments the nonce by one.
To cause a transfer, all of the owners must produce signed messages that agree on the destination, the value, and the nonce. (The nonce must be the expected nonce.)

Once messages are collected from all owners, anybody can present them to the wallet to invoke the transfer:

uint256 public nonce;     // (only) mutable state

function transfer(
    address destination,
    uint256 value,
    bytes32[] sigR,
    bytes32[] sigS,
    uint8[] sigV
)
    external
{
    bytes32 hash = prefixed(keccak256(abi.encodePacked(
        address(this), destination, value, nonce
    )));

    for (uint256 i = 0; i < owners.length; i++) {
        address recovered = ecrecover(hash, sigV[i], sigR[i], sigS[i]);
        require(recovered == owners[i]);
    }

    // If we make it here, all signatures are accounted for.
    nonce += 1;
    destination.transfer(value);
}
The code above includes one subtlety: the messages must be presented to the wallet in the same order as the owners were originally presented to the contract’s constructor.

The prefixed function is borrowed from Signing and Verifying Messages in Ethereum and can be found in the full source code below.

Summary
Simple multisig wallets can have straightforward implementations.
Collecting signed messages off-chain helps simplify on-chain work.
The Complete Contract
unanimous.sol
pragma solidity ^0.4.24;

contract UnanimousMultiSig {
    uint256 public nonce;     // (only) mutable state
    address[] public owners;  // immutable state

    constructor(address[] owners_) {
        owners = owners_;
    }

    function transfer(
        address destination,
        uint256 value,
        bytes32[] sigR,
        bytes32[] sigS,
        uint8[] sigV
    )
        external
    {
        bytes32 hash = prefixed(keccak256(abi.encodePacked(
            address(this), destination, value, nonce
        )));

        for (uint256 i = 0; i < owners.length; i++) {
            address recovered = ecrecover(hash, sigV[i], sigR[i], sigS[i]);
            require(recovered == owners[i]);
        }

        // If we make it here, all signatures are accounted for.
        nonce += 1;
        destination.transfer(value);
    }

    function () payable {}

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", hash));
    }
}
← Performing Multiple Actions TransactionallyState Channels with Signing Keys →
  