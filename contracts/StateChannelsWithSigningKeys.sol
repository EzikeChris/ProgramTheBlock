Program the Blockchain
Archive About Subscribe
State Channels with Signing Keys
JULY 18, 2018 BY STEVE MARX
In this post, I’ll show how a temporary signing key can be used to improve the user experience of working with state channels.

State channels involve two parties exchanging off-chain signed messages. Those messages are typically signed with the participants’ Ethereum private keys. For security reasons, a DApp such as the one presented in Working with State Channels in JavaScript does not usually have have direct access to a user’s private key. Instead, it asks a web3 provider such as MetaMask to sign a message, and the user is presented with UI to approve the signature.

This flow can be cumbersome, requiring extra interactions from the user. This interaction with MetaMask for each signature can be avoided by signing messages directly in JavaScript with a temporary signing key.

You can try out the new version of the 21 game DApp to see the result.

Signing Key
State channels replace on-chain calls to smart contracts with digital signatures exchanged off-chain. The same Ethereum account is usually used for on-chain interactions and for off-chain signatures, but there’s no reason this has to be the case. All that matters is that the smart contract recognize the validity of the signature. Each participant can instead designate a different account that they will use to sign messages. The advantage of using a second account is that its private key can be known to JavaScript and thus used directly to sign messages without the help of something like MetaMask.

To support signing with a different key, I’ll need to make a few changes to the smart contract and to the JavaScript front end:

The JavaScript front end needs to generate a new private key and corresponding account to use for signing.
The smart contract needs to keep track of each participant’s signing account.
When signing messages, the front end needs to use the signing key to directly sign messages rather than invoking MetaMask.
When verifying a message, the signature must be checked against the expected signing account.
The rest of this post will go over the code changes in detail. The result is a new version of the 21 game DApp which doesn’t require the user to interact with MetaMask for each off-chain move.

Contract Changes
The smart contract needs to keep track of which accounts are being used for signatures:

mapping(address => address) signerFor;
Each participant’s signing account is passed to the smart contract as a parameter. The first player passes their account to the constructor, and the second player passes it to the join() function:

constructor(uint256 _timeoutInterval, address signer) public payable {
    // ...
    signerFor[player1] = signer;
}

function join(address signer) public payable {
    // ...
    signerFor[player2] = signer;
}
Finally, signatures need to be checked against the appropriate signing accounts in moveFromState():

// Old code:
// require(recoverSigner(message, sig) == opponentOf(msg.sender));

require(recoverSigner(message, sig) == signerFor[opponentOf(msg.sender)]);
Signing Keys in JavaScript
To support using separate signing accounts, the JavaScript front end needs to track two new pieces of state: signingKey and opponentSigner.

The signingKey is a private key generated locally in JavaScript 1:

this.signingKey = ethereumjs.Wallet.generate().getPrivateKeyString();
From the generated private key, a public address is computed and passed to the smart contract when starting or joining a game:

start: function () {
  // ...
  var signer = '0x' +
    ethereumjs.Util.privateToAddress(this.signingKey).toString("hex");
  TwentyOneContract.new(600, signer, // ...
},

join: function () {
  // ...
  var signer = '0x' +
    ethereumjs.Util.privateToAddress(that.signingKey).toString("hex");
  contract.join(signer, // ...
}
The opponent’s signing account is fetched from the smart contract with a call to signerFor. For example:

contract.signerFor(player2, function (err, player2Signer) {
  // ...
  that.opponentSigner = player2Signer;
}
Signing and Verifying Messages in JavaScript
Instead of using web3.personal.sign() to prompt the user to sign with MetaMask, the new DApp signs directly with the signing key:

var sig = ethereumjs.Util.ecsign(prefixed(message),
  ethereumjs.Util.toBuffer(this.signingKey));
var rpcSig = "0x" +
   ethereumjs.Util.setLengthLeft(sig.r, 32).toString("hex") +
   ethereumjs.Util.setLengthLeft(sig.s, 32).toString("hex") +
   ethereumjs.Util.toBuffer(sig.v).toString("hex");
When receiving a message, its signature must be checked against the opponent’s signing account in updateIfValid():

// Old code:
// if (signer !== this.opponent.toLowerCase()) return;

if (signer !== this.opponentSigner.toLowerCase()) return;
Security Trade-Off
By using a separate signing key, users of the DApp no longer have to approve each signature. This is a significant usability improvement, but it presents a tradeoff between usability and security. In the original version of the DApp, the user was always responsible for the final approval of any signature. Although only a hash of the data was presented to the user, they could theoretically recreate the message and verify that they were signing the move they actually wanted to make.

When using a separate signing key that is directly handled in JavaScript, the user no longer has the ability to see and approve each message that is being signed. In the example of betting on a game, this means malicious JavaScript code could quietly sign and transmit very bad moves, causing the player to lose the game and therefore their wager.

I believe that in the case of the original DApp, this tradeoff is clearly worth it. Seeing a binary hash doesn’t really allow users to make an informed decision about what to sign, so users already needed to trust the JavaScript code in practice. It’s arguably more secure to allow the app to sign arbitrary messages but only with a one-off account limited in scope to a single game.

Summary
Although state channels typically use the same account for on-chain transactions and off-chain signatures, this is not a requirement.
Using a separate signing key can improve a state channel’s user experience.
This usability improvement comes with a security tradeoff.
Full Source Code
The full updated smart contract is below. You can view the source code for the updated DApp in your browser.

twentyone-signing-keys.sol
pragma solidity ^0.4.23;

contract TwentyOneGame {
    address public player1;
    address public player2;
    uint256 public betAmount;
    bool public gameOver;

    mapping(address => address) public signerFor;

    struct GameState {
        uint8 seq;
        uint8 num;
        address whoseTurn;
    }
    GameState public state;

    uint256 public timeoutInterval;
    uint256 public timeout = 2**256 - 1;

    event GameStarted();
    event TimeoutStarted();
    event MoveMade(address player, uint8 seq, uint8 value);


    // Setup methods

    constructor(uint256 _timeoutInterval, address signer) public payable {
        player1 = msg.sender;
        signerFor[player1] = signer;
        betAmount = msg.value;
        timeoutInterval = _timeoutInterval;
    }

    function join(address signer) public payable {
        require(player2 == 0, "Game has already started.");
        require(!gameOver, "Game was canceled.");
        require(msg.value == betAmount, "Wrong bet amount.");

        player2 = msg.sender;
        signerFor[player2] = signer;
        state.whoseTurn = player1;

        emit GameStarted();
    }

    function cancel() public {
        require(msg.sender == player1, "Only first player may cancel.");
        require(player2 == 0, "Game has already started.");

        gameOver = true;
        msg.sender.transfer(address(this).balance);
    }


    // Play methods

    function move(uint8 seq, uint8 value) public {
        require(!gameOver, "Game has ended.");
        require(msg.sender == state.whoseTurn, "Not your turn.");
        require(value >= 1 && value <= 3,
            "Move out of range. Must be between 1 and 3.");
        require(state.num + value <= 21, "Move would exceed 21.");
        require(state.seq == seq, "Incorrect sequence number.");

        state.num += value;
        state.whoseTurn = opponentOf(msg.sender);
        state.seq += 1;

        // Clear timeout
        timeout = 2**256 - 1;

        if (state.num == 21) {
            gameOver = true;
            msg.sender.transfer(address(this).balance);
        }

        emit MoveMade(msg.sender, seq, value);
    }

    function moveFromState(uint8 seq, uint8 num, bytes sig, uint8 value) public {
        require(seq >= state.seq, "Sequence number cannot go backwards.");

        bytes32 message = prefixed(keccak256(address(this), seq, num));
        require(recoverSigner(message, sig) ==
            signerFor[opponentOf(msg.sender)]);

        state.seq = seq;
        state.num = num;
        state.whoseTurn = msg.sender;

        move(seq, value);
    }

    function opponentOf(address player) internal view returns (address) {
        require(player2 != 0, "Game has not started.");

        if (player == player1) {
            return player2;
        } else if (player == player2) {
            return player1;
        } else {
            revert("Invalid player.");
        }
    }


    // Timeout methods

    function startTimeout() public {
        require(!gameOver, "Game has ended.");
        require(state.whoseTurn == opponentOf(msg.sender),
            "Cannot start a timeout on yourself.");

        timeout = now + timeoutInterval;
        emit TimeoutStarted();
    }

    function claimTimeout() public {
        require(!gameOver, "Game has ended.");
        require(now >= timeout);

        gameOver = true;
        opponentOf(state.whoseTurn).transfer(address(this).balance);
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
In the full source code, the signing key is also persisted to the browser’s local storage. This prevents the key from being lost if the user refreshes the page or closes the browser. ↩
← Writing a Trivial Multisig WalletAnatomy of Transaction Data →
  