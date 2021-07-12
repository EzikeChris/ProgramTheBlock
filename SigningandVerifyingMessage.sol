Program the Blockchain	Archive About Subscribe
Signing and Verifying Messages in Ethereum
FEBRUARY 17, 2018 BY STEVE MARX
Cryptographic signatures are a powerful primitive in Ethereum. Signatures are used to authorize transactions, but they’re a more general tool that’s available to smart contracts. Signatures can be used to prove to a smart contract that a certain account approved a certain message.

In this post, I’ll build a simple smart contract that lets me transmit ether in an unusual way. Instead of calling a function myself to initiate a payment, I’ll let the receiver of the payment do that—and therefore pay the transaction fee! Only authorized payments will be allowed, thanks to cryptographic signatures that I will make and send off-chain (e.g. via email).

Paying someone with the ReceiverPays contract works a lot like writing a check. The person receiving the payment gets to take money directly out of my bank account, but only if they have a valid check bearing my signature.


Overview
The ReceiverPays contract holds ether on behalf of its owner and allows that ether to be withdrawn when authorized by a cryptographic signature:

The owner deploys ReceiverPays, attaching enough ether to cover the payments that will be made.
The owner authorizes a payment by cryptographically signing a message with their private key.
The owner sends the signed message to the designated recipient. The message does not need to be kept secret, and the mechanism for sending it doesn’t matter. It can be sent via email, instant message, or even a public forum.
The recipient claims their payment by presenting the signed message to the smart contract. The smart contract verifies its authenticity and then releases the funds.
Creating the Signature
Signing a message with a private key does not require interacting with the Ethereum network. It can be done completely offline, and every major programming language has the necessary cryptographic libraries to do it. The signature algorithm Ethereum has built-in support for is the Elliptic Curve Digital Signature Algorithm (EDCSA)

For this post, I’ll focus on signing messages in the web browser using web3.js and MetaMask.

There are still a number of ways to sign messages using web3.js, and, unfortunately, different methods sign data in incompatible ways. Members of the community are actively working to standardize on a new way to sign messages (EIP-712) that has a number of other security benefits. For now, though, my advice is to stick with the most standard format of signing, as specified by the eth_sign JSON-RPC method:

The sign method calculates an Ethereum specific signature with: sign(keccak256("\x19Ethereum Signed Message:\n" + len(message) + message))).

By adding a prefix to the message makes the calculated signature recognisable as an Ethereum specific signature. This prevents misuse where a malicious DApp can sign arbitrary data (e.g. transaction) and use the signature to impersonate the victim.

MetaMask’s UI shows the user the message they’re signing, but since here the message is a hash, it will never be meaningful to the user. This is one of the issues that EIP-712 is intended to solve.
At least in MetaMask, this algorithm is followed best by the web3.js function web3.personal.sign, so I recommend using that:
// Hashing first makes a few things easier.
var hash = web3.sha3("message to sign");
web3.personal.sign(hash, web3.eth.defaultAccount, function () { ... });
Recall that the prefix includes the length of the message. Hashing first means the message will always be 32 bytes long, which means the prefix is always the same. This makes life easier, particularly on the Solidity side, as I’ll demonstrate later in this post.

What to Sign
For a signature to represent authorization to take some action, it’s important that the message specify exactly what’s being authorized. For a contract that fulfills payments, the signed message must include the address of the recipient and the amount that is to be transferred. In addition, the message should include data that protects against replay attacks.

Avoiding Replay Attacks
A replay attack is when a signature is used again (“replayed”) to claim authorization for a second action. For our example, it would be a serious security flaw if the recipient of a payment could submit the same signature again to receive a second payment. Just as in Ethereum transactions themselves, messages typically include a nonce to protect against replay attacks. The smart contract checks that no nonce is reused:

mapping(uint256 => bool) usedNonces;

function claimPayment(uint256 amount, uint256 nonce, bytes sig) public {
    require(!usedNonces[nonce]);
    usedNonces[nonce] = true;

    // ...
}
There’s another kind of replay attack that we need to protect against. Suppose I deploy the ReceiverPays smart contract, make some payments, and then destroy the contract. Later, I would like to make more payments, so I decide to deploy the RecipientPays smart contract again. The new deployed instance of the contract doesn’t know about the used nonces from the previous deployment, so it will happily pay in response to any of the old signatures again.

A simple way to protect against this type of replay attack is to make sure the message includes the contract’s address. The new contract will reject all signatures that reference the wrong (old) address.

Packing Arguments
Now that I’ve identified what information to include in the signed message, I’m ready to put the message together, hash it, and sign it. Solidity’s keccak256/sha3 function hashes multiple arguments by first concatenating them in a tightly packed form. For the hash generated on the client to match the one generated in the smart contract, the arguments must be concatenated in the same way.

You can find browser builds of ethereumjs-abi in the ethereumjs/browser-builds repository.
The ethereumjs-abi library provides a function called soliditySHA3 that mimics the behavior of Solidity’s keccak256 function. It accepts an array of values as well as an array of their Solidity types so it can serialize the values accordingly.

Web3.js 1.0.0-beta includes a similar function called soliditySha3, but at the time of this writing, that version is still unreleased and therefore lacking in compatibility with other tools, including MetaMask.
Putting it all together, here’s a JavaScript function that creates the proper signature for the ReceiverPays example:
// recipient is the address that should be paid.
// amount, in wei, specifies how much ether should be sent.
// nonce can be any unique number, used to prevent replay attacks.
// contractAddress is used to prevent cross-contract replay attacks.
function signPayment(recipient, amount, nonce, contractAddress, callback) {
  var hash = "0x" + ethereumjs.ABI.soliditySHA3(
    ["address", "uint256", "uint256", "address"],
    [recipient, amount, nonce, contractAddress]
  ).toString("hex");

  web3.personal.sign(hash, web3.eth.defaultAccount, callback);
}
Recovering the Message Signer in Solidity
In general, ECDSA signatures consist of two parameters, r and s. Signatures in Ethereum include a third parameter, v, which provides additional information that can be used to recover which account’s private key was used to sign the message. This same mechanism is how Ethereum determines which account sent a given transaction.

Solidity provides a built-in function ecrecover that accepts a message along with the r, s, and v parameters and returns the address that was used to sign the message.

Extracting the Signature Parameters
Signatures produced by web3.js are the concatenation of r, s, and v, so a necessary first step is splitting those parameters back out. This process can be done on the client, but I find it more convenient to do it inside the smart contract. This means only one signature parameter needs to be sent rather than three.

Unfortunately, splitting apart a bytes array into component parts is a little messy. I’m making use of inline assembly to do the job:

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
Here’s a brief explanation of that code:

Dynamically-sized arrays (including bytes) are represented in memory by a 32-byte length followed by the actual data. The code here starts reading data at byte 32 to skip past that length. The require at the top of the function ensures the signature is the correct length.
r and s are 32 bytes each and together make up the first 64 bytes of the signature.
v is the 65th byte, which can be found at byte offset 96 (32 bytes for the length, 64 bytes for r and s). The mload opcode loads 32 bytes at a time, so the function then needs to extract just the first byte of the word that was read. This is what byte(0, ...) does.
Computing the Message Hash
In addition to the r, s, and v parameters from the signature, recovering the message signer requires knowledge of the message that was signed. The message hash needs to be recomputed from the sent parameters along with the known prefix.

It may seem tempting at first to just have the caller pass in the message that was signed, but that would only prove that some message was signed by the owner. The smart contract needs to know exactly what parameters were signed, and so it must recreate the message from the parameters and use that for signature verification:

// Builds a prefixed hash to mimic the behavior of eth_sign.
function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256("\x19Ethereum Signed Message:\n32", hash);
}

function claimPayment(uint256 amount, uint256 nonce, bytes sig) public {
    require(!usedNonces[nonce]);
    usedNonces[nonce] = true;

    // This recreates the message that was signed on the client.
    bytes32 message = prefixed(keccak256(msg.sender, amount, nonce, this));

    require(recoverSigner(message, sig) == owner);

    msg.sender.transfer(amount);
}
Finally, the implementation of recoverSigner is straightforward:

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
Summary
Signed messages provide a way to authenticate a message to a smart contract.
Signed messages may need a nonce to protect against replay attacks.
Signed messages may need to include the contracts’s address to protect against replay attacks.
Until a better signature standard is adopted, I recommend following the behavior of the eth_sign JSON-RPC method.
Full Source Code
receiverPays.sol
pragma solidity ^0.4.20;

contract ReceiverPays {
    address owner = msg.sender;

    mapping(uint256 => bool) usedNonces;

    // Funds are sent at deployment time.
    function ReceiverPays() public payable { }


    function claimPayment(uint256 amount, uint256 nonce, bytes sig) public {
        require(!usedNonces[nonce]);
        usedNonces[nonce] = true;

        // This recreates the message that was signed on the client.
        bytes32 message = prefixed(keccak256(msg.sender, amount, nonce, this));

        require(recoverSigner(message, sig) == owner);

        msg.sender.transfer(amount);
    }

    // Destroy contract and reclaim leftover funds.
    function kill() public {
        require(msg.sender == owner);
        selfdestruct(msg.sender);
    }


    // Signature methods

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
        return keccak256("\x19Ethereum Signed Message:\n32", hash);
    }
}
← Writing A Robust Dividend Token ContractWriting an Estate Planning Contract →
  