Program the Blockchain
Archive About Subscribe
Supporting Off-Chain Token Trading
JUNE 6, 2018 BY TODD PROEBSTING
This post will implement a token trading “clearinghouse” that will execute multiple signed trade offers simultaneously.

A clearinghouse accepts trade offers from multiple parties and works to execute transactions among those parties. A clearinghouse may also act as a market maker and directly trade with those parties. In this post, the trades will be exchanges of ERC20 tokens for other ERC20 tokens.

For example, the clearinghouse could execute a pair of perfectly matched trades like the following:

X wants to trade 1 P for 1 Q (where P and Q are different tokens)
Y wants to trade 1 Q for 1 P
A more interesting example would be the following:

X wants to trade 3 P’s for 3 Q’s
Y wants to trade 2 Q’s for 2 P’s
Z wants to trade 1 Q for 1 P
In that case, a clearinghouse could orchestrate a simultaneous three-way trade.

While the supported trades will only involve two tokens each, that doesn’t mean that an orchestrated trade could not be for many different tokens. For instance, the following three trades could be supported:

X wants to trade 1 R for 1 S
Y wants to trade 1 S for 1 T
Z wants to trade 1 T for 1 R
Trade Offers
Traders will send signed trade offers to the off-chain clearinghouse. Periodically, the clearinghouse will send some of those signed offers to the smart contract, which will then execute the proposed trades.

Signed trade offers have many components:

The token and amount of that token being offered.
The token and amount of that token expected to be received.
The expiration time after which this offer is no longer valid.
A unique nonce to prevent replay vulnerabilities.
The signature that proves the seller’s identity.
The mechanism for signing a message and subsequently validating it within a contract were described in our post on signed messages.

There are two components in this system: an off-chain clearinghouse that puts trades together and a smart contract that executes those trades. In this post, I’ll focus on just the smart contract.

Escrowed Tokens
This system will rely on escrowed tokens from sellers to back their trade offers. I use our escrow contract to manage the escrow mechanics. The Escrow contract handles token deposits and withdrawals for traders as well as for the clearinghouse’s owner.

pragma solidity ^0.4.24;

import "ierc20token.sol";
import "signature.sol";
import "escrow.sol";

contract Clearinghouse is Escrow, Signature {
    address owner;

    constructor (uint256 _escrowTime)
        Escrow(_escrowTime)
        public
    {
        owner = msg.sender;
    }
In addition to configuring escrow duration, the constructor also records the owner of the contract. Only the owner can submit signed trades to be executed.

Clearinghouse inherits from Signature, which provides routines for handling signed messages. Its source code is provided at the end of this post.

Validating a Sale Offer
The only difference between validating a signed message in this contract and the technique we described previously is the encoding of the signature. Previously, we used a single byte sequence containing the r, s, and v components, but now I’m going to keep those values separate. (I’m doing so to overcome a Solidity limitation, which I’ll point out when it’s relevant.)

mapping(address => mapping(uint256 => bool)) public usedNonces;

function validateOffer(
    address seller,
    IERC20Token sellToken,
    uint256 sellAmount,
    IERC20Token receiveToken,
    uint256 receiveAmount,
    uint256 timeLimit,
    uint256 nonce,
    bytes32 r,
    bytes32 s,
    uint8 v
)
    public
    view
{
    require(now < timeLimit, "Offer has expired.");
    require(!usedNonces[seller][nonce], "Duplicate nonce.");

    bytes32 message = prefixed(
        keccak256(abi.encodePacked(
            address(this),
            sellToken,
            sellAmount,
            receiveToken,
            receiveAmount,
            timeLimit,
            nonce
        ))
    );
    require(ecrecover(message, v, r, s) == seller, "Invalid signature.");
}
A valid message meets three criteria:

The trade must not have expired.
The trade must have an unused nonce.
The trade offer’s signature must be validated.
Single Sale
A clearinghouse typically executes many trades simultaneously, and this contract will support that. But first I want to show how to execute a single signed trade offer. A single trade is between the seller and the clearinghouse:

function executeOffer(
    address seller,
    IERC20Token sellToken,
    uint256 sellAmount,
    IERC20Token receiveToken,
    uint256 receiveAmount,
    uint256 timeLimit,
    uint256 nonce,
    bytes32 r,
    bytes32 s,
    uint8 v

)
    public
{
    require(msg.sender == owner, "Only the owner can execute offers.");

    validateOffer(
        seller,
        sellToken,
        sellAmount,
        receiveToken,
        receiveAmount,
        timeLimit,
        nonce,
        r,
        s,
        v
    );

    usedNonces[seller][nonce] = true;

    transfer(seller, owner, sellToken, sellAmount);
    transfer(owner, seller, receiveToken, receiveAmount);
}
A few things to note about the single trade:

Only owner can submit a signed trade.
The offer must be validated.
The transfer function, which is inherited from Escrow, checks that there are sufficient tokens available and then transfers them.
Simultaneous Sales
The examples at the beginning of the post demonstrated the power of submitting simultaneous trades. This contract will support simultaneous trades in a single transaction. Interestingly, processing multiple trades is not as simple as just iterating over the trades and executing them sequentially.

An example will make it clear why sequential trading won’t work. Recall the example where X wants to trade 1 P for 1 Q and Y wants to do the reverse. A clearinghouse could broker such a trade because X can provide 1 P to Y, and Y can provide 1 Q to X. But, it would be impossible for the clearinghouse to complete either trade fully before starting the other trade because the clearinghouse might not own any P or Q tokens.

How would a real world clearinghouse execute this trade between X and Y? It would first get 1 P from X and then it would get 1 Q from Y. After that, it would distribute the Q to X and the P to Y. That is, it would execute the trades in two phases, first accumulating all the tokens being offered, and then distributing all the tokens being received.

This contract will validate all the offers, then gather all the tokens before distributing them:

function executeOffers(
    address[] sellers,
    IERC20Token[] sellTokens,
    uint256[] sellAmounts,
    IERC20Token[] receiveTokens,
    uint256[] receiveAmounts,
    uint256[] timeLimits,
    uint256[] nonces,
    bytes32[] rs,
    bytes32[] ss,
    uint8[] vs
)
    public
{
    require(msg.sender == owner, "Only the owner can execute offers.");

    acceptOffers(
        sellers,
        sellTokens,
        sellAmounts,
        receiveTokens,
        receiveAmounts,
        timeLimits,
        nonces,
        rs,
        ss,
        vs
    );
    gatherOffers(sellers, sellTokens, sellAmounts);
    distributeOffers(sellers, receiveTokens, receiveAmounts);
}
Note that the function takes many arrays of simple values, including the r, s, and v values. It would be more convenient to pass those all in arrays of structs or packed values, but Solidity doesn’t yet support that. That’s why they are unpacked.

The first phase validates all the offers and marks their nonces as used:

function acceptOffers(
    address[] sellers,
    IERC20Token[] sellTokens,
    uint256[] sellAmounts,
    IERC20Token[] receiveTokens,
    uint256[] receiveAmounts,
    uint256[] timeLimits,
    uint256[] nonces,
    bytes32[] rs,
    bytes32[] ss,
    uint8[] vs
)
    internal
{
    for (uint256 i = 0; i < sellers.length; i++) {
        validateOffer(
            sellers[i],
            sellTokens[i],
            sellAmounts[i],
            receiveTokens[i],
            receiveAmounts[i],
            timeLimits[i],
            nonces[i],
            rs[i],
            ss[i],
            vs[i]
        );

        usedNonces[sellers[i]][nonces[i]] = true;
    }
}
Gathering all the offered tokens is a simple loop over the offers, transferring them to owner:

function gatherOffers(
    address[] sellers,
    IERC20Token[] sellTokens,
    uint256[] sellAmounts
)
    internal
{
    for (uint256 i = 0; i < sellers.length; i++) {
        transfer(sellers[i], owner, sellTokens[i], sellAmounts[i]);
    }
}
Distributing tokens to the sellers is also a simple loop, this time transferring from owner:

function distributeOffers(
    address[] sellers,
    IERC20Token[] receiveTokens,
    uint256[] receiveAmounts
)
    internal
{
    for (uint256 i = 0; i < sellers.length; i++) {
        transfer(owner, sellers[i], receiveTokens[i], receiveAmounts[i]);
    }
}
Clearinghouse Participation
The clearinghouse can participate in trading implicitly. If the accepted trades do not fully offset each other, it’s the clearinghouse contract that must make up the difference. This is what happens in the single-trade function above, but it can just as easily happen in the multiple-trade function as well.

Sometimes, accepted trades will work out in the clearinghouse’s favor. Suppose the following trades are offered to the clearinghouse:

X offers to trade 1 P for 1 Q
Y offers to trade 2 Q’s for 1 P
If the clearinghouse presents these two trades to the contract, both X and Y will get their respective tokens, but the clearinghouse will own the extra Q afterwards!

Why Escrow?
This contract could have been written without escrowed tokens. It could have relied instead on ERC20’s approve and transferFrom functions for transferring tokens between parties. This would have presented a vulnerability that I wanted to avoid: a transferFrom might fail if tokens became unavailable. If a transferFrom failed in a multiple-trade transaction, then all the trades would fail, and I wanted to avoid this possibility.

Summary
A “clearinghouse” combines 3rd-party trades, which may not have been acceptable individually.
A clearinghouse may act as a market maker and participate in trading.
Signed messages enable the clearinghouse to operate off-chain except for the final simultaneous trading.
Escrowed tokens enable the clearinghouse to be certain that trading will succeed.
The Complete Contract
clearinghouse.sol
pragma solidity ^0.4.24;

import "ierc20token.sol";
import "signature.sol";
import "escrow.sol";

contract Clearinghouse is Escrow, Signature {
    address owner;

    constructor (uint256 _escrowTime)
        Escrow(_escrowTime)
        public
    {
        owner = msg.sender;
    }

    mapping(address => mapping(uint256 => bool)) public usedNonces;

    function validateOffer(
        address seller,
        IERC20Token sellToken,
        uint256 sellAmount,
        IERC20Token receiveToken,
        uint256 receiveAmount,
        uint256 timeLimit,
        uint256 nonce,
        bytes32 r,
        bytes32 s,
        uint8 v
    )
        public
        view
    {
        require(now < timeLimit, "Offer has expired.");
        require(!usedNonces[seller][nonce], "Duplicate nonce.");

        bytes32 message = prefixed(
            keccak256(abi.encodePacked(
                address(this),
                sellToken,
                sellAmount,
                receiveToken,
                receiveAmount,
                timeLimit,
                nonce
            ))
        );
        require(ecrecover(message, v, r, s) == seller, "Invalid signature.");
    }

    function executeOffer(
        address seller,
        IERC20Token sellToken,
        uint256 sellAmount,
        IERC20Token receiveToken,
        uint256 receiveAmount,
        uint256 timeLimit,
        uint256 nonce,
        bytes32 r,
        bytes32 s,
        uint8 v

    )
        public
    {
        require(msg.sender == owner, "Only the owner can execute offers.");

        validateOffer(
            seller,
            sellToken,
            sellAmount,
            receiveToken,
            receiveAmount,
            timeLimit,
            nonce,
            r,
            s,
            v
        );

        usedNonces[seller][nonce] = true;

        transfer(seller, owner, sellToken, sellAmount);
        transfer(owner, seller, receiveToken, receiveAmount);
    }


    function acceptOffers(
        address[] sellers,
        IERC20Token[] sellTokens,
        uint256[] sellAmounts,
        IERC20Token[] receiveTokens,
        uint256[] receiveAmounts,
        uint256[] timeLimits,
        uint256[] nonces,
        bytes32[] rs,
        bytes32[] ss,
        uint8[] vs
    )
        internal
    {
        for (uint256 i = 0; i < sellers.length; i++) {
            validateOffer(
                sellers[i],
                sellTokens[i],
                sellAmounts[i],
                receiveTokens[i],
                receiveAmounts[i],
                timeLimits[i],
                nonces[i],
                rs[i],
                ss[i],
                vs[i]
            );

            usedNonces[sellers[i]][nonces[i]] = true;
        }
    }

    function gatherOffers(
        address[] sellers,
        IERC20Token[] sellTokens,
        uint256[] sellAmounts
    )
        internal
    {
        for (uint256 i = 0; i < sellers.length; i++) {
            transfer(sellers[i], owner, sellTokens[i], sellAmounts[i]);
        }
    }

    function distributeOffers(
        address[] sellers,
        IERC20Token[] receiveTokens,
        uint256[] receiveAmounts
    )
        internal
    {
        for (uint256 i = 0; i < sellers.length; i++) {
            transfer(owner, sellers[i], receiveTokens[i], receiveAmounts[i]);
        }
    }

    function executeOffers(
        address[] sellers,
        IERC20Token[] sellTokens,
        uint256[] sellAmounts,
        IERC20Token[] receiveTokens,
        uint256[] receiveAmounts,
        uint256[] timeLimits,
        uint256[] nonces,
        bytes32[] rs,
        bytes32[] ss,
        uint8[] vs
    )
        public
    {
        require(msg.sender == owner, "Only the owner can execute offers.");

        acceptOffers(
            sellers,
            sellTokens,
            sellAmounts,
            receiveTokens,
            receiveAmounts,
            timeLimits,
            nonces,
            rs,
            ss,
            vs
        );
        gatherOffers(sellers, sellTokens, sellAmounts);
        distributeOffers(sellers, receiveTokens, receiveAmounts);
    }
}
signature.sol
pragma solidity ^0.4.24;

contract Signature {    
    function splitSignature(bytes sig)
    internal
    pure
    returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes sig)
    internal
    pure
    returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", hash));
    }
}
← Storage Patterns: SetReversible Ether →
  