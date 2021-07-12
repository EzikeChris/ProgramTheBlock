Program the Blockchain	Archive About Subscribe
Flipping a Coin in Ethereum
MARCH 16, 2018 BY STEVE MARX
In this post, I’ll describe how two parties can bet on a coin flip in an Ethereum smart contract by using a simple commitment scheme.

Overview
In the real world, betting on a coin flip might happen like this:

Player 1 flips a coin and catches it on their arm, face down and covered. At this point, the outcome of the flip is already determined but kept secret.
Player 2 chooses “heads” or “tails.”
Player 1 reveals the outcome of the flip. If player 2 guessed it correctly, they win. Otherwise, player 1 wins.
I’ll model this interaction in Ethereum using a commitment scheme:

Player 1 will commit to a boolean value (representing “heads” or “tails”), keeping the chosen value secret.
Player 2 will guess at that boolean value.
Player 1 will reveal the original boolean value.
Committing with a Hash
There are many different commitment schemes, but the simplest and easiest to implement in an Ethereum smart contract uses a cryptographic hash function. To commit to a message, the committer just shares the hash of that message. When the message is later revealed, anyone can easily verify that its hash matches the hash shared earlier.

Cryptographic hash functions have a few important properties that make them suitable for commitment schemes:

They are deterministic, so a hash of a message can later be verified by hashing the message again.
It’s infeasible to find two different messages that hash to the same value, so a hash is truly a commitment to a single message.
It’s impossible to generate a message from its hash more efficiently than trying all possible messages.
That last point has a corollary: if the number of possible messages is small, it’s easy to reverse a hash. For the coin flip example, player 1 needs to commit to a boolean. Just hashing that boolean (hash(0) or hash(1)) would be trivial to reverse because there are only two possible inputs.

A simple way to make guessing infeasible is to add a large random nonce to the message being hashed. In the CoinFlip contract, I’ll hash a boolean along with a 32-byte nonce.

Offering a Bet
The first player offers a bet by deploying the CoinFlip contract.

contract CoinFlip {
    address public player1;
    bytes32 public player1Commitment;

    uint256 public betAmount;

    function CoinFlip(bytes32 commitment) public payable {
        player1 = msg.sender;
        player1Commitment = commitment;
        betAmount = msg.value;
    }
By deploying the contract, the first player escrows their bet and commits to a boolean value representing heads or tails. The commitment is the keccak-256 hash of the boolean value and a 32-byte nonce. The boolean and nonce are kept secret and used later in the reveal phase.

As an example, the commitment hash could be computed using Node.js and ethereumjs-abi as follows:

const abi = require('ethereumjs-abi');
const crypto = require('crypto');

// This could come from user input or be randomly generated.
const secretChoice = true;

const nonce = "0x" + crypto.randomBytes(32).toString('hex');

const hash = "0x" + abi.soliditySHA3(
  ["bool", "uint256"],
  [secretChoice, nonce]).toString('hex');
Taking a Bet
The second player takes the bet by calling takeBet.

address public player2;
bool public player2Choice;

uint256 public expiration = 2**256 - 1;  // effectively infinite

function takeBet(bool choice) public payable {
    require(player2 == 0);
    require(msg.value == betAmount);

    player2 = msg.sender;
    player2Choice = choice;

    expiration = now + 24 hours;
}
A brief explanation of the above code:

The expiration starts off at 2256-1, the maximum value for a uint256.
Only one account is allowed to take the bet. require(player2 == 0) ensures that no other account has already taken the bet.
The second player must match the first player’s bet.
The second player bets on either heads or tails by simply passing a boolean. There’s no need to keep this value a secret, as the first player has already committed to their choice.
When the second player takes the bet, a timeout is started. The first player has until the end of that timeout to reveal their secret, after which their bet is forfeit. Without this timeout, the first player could refuse to reveal a losing secret and prevent the second player from collecting their winnings.
Revealing the Flip
Once the second player has made their bet, the first player can settle the bet by revealing the original choice (heads or tails) and nonce. The two combined are the preimage of the commitment hash.

function reveal(bool choice, uint256 nonce) public {
    require(player2 != 0);
    require(now < expiration);

    require(keccak256(choice, nonce) == player1Commitment);

    if (player2Choice == choice) {
        player2.transfer(address(this).balance);
    } else {
        player1.transfer(address(this).balance);
    }
}
A brief explanation of the above code:

reveal can only be called once the bet is taken and only before the expiration has been reached.
The choice and nonce must satisfy the commitment made when the contract was deployed. This ensures that the first player cannot cheat.
player2 wins if they successfully chose the same value as player1. Otherwise, player1 wins.
All ether is immediately transferred to the winner.
You may be surprised to see that there are no restrictions on which account can call this function. Only the correct original choice will produce the commitment hash, so it doesn’t matter who supplies it.

Refusing to Reveal
If the first player refuses to reveal their choice, their bet is forfeit. The second player can claim their prize by calling claimTimeout.

function claimTimeout() public {
    require(now >= expiration);

    player2.transfer(address(this).balance);
}
As with reveal, it doesn’t matter who calls this function.

Canceling a Bet
If no one takes the bet, it should be possible for the first player to cancel the bet and reclaim their ether.

function cancel() public {
    require(msg.sender == player1);
    require(player2 == 0);

    betAmount = 0;
    msg.sender.transfer(address(this).balance);
}
A brief explanation of the above code:

The two requires ensure that only the first player can cancel the offered bet and that they can only do so if no one has taken the bet yet.
betAmount = 0 ensures that if someone sends ether to takeBet after the offer has been canceled, their bet will be rejected.
Why Not Use selfdestruct?
It’s tempting to use selfdestruct to distribute ether and clean up the contract when the bet is settled or canceled. However, this could lead to an unfortunate race condition.

When a contract calls selfdestruct, its code is deleted. This makes it work much like an externally owned account (EOA). Any transaction sent to it will be accepted, including those with attached ether.

The following scenario is an example of why this is a problem:

Player 1 deploys a new CoinFlip contract.
Player 2 submits a transaction to call takeBet.
While that transaction is still pending, player 1 calls cancel. (Imagine that cancel is implemented with selfdestruct.)
Player 2’s takeBet transaction arrives.
Because the contract has been destroyed, there’s no code to revert that late transaction. The ether attached is transferred to the contract and locked in there forever.

As a generalization, it’s a bad idea to use selfdestruct on a contract that accepts ether.

Summary
A commitment scheme is a way to commit to a secret choice and reveal it later without the possibility of changing it.
Hash functions can be reversed only by guessing the preimage.
A nonce is a good way to ensure that a hash preimage cannot be guessed.
It’s important to consider what happens if the committer refuses to reveal their secret.
Full Source Code
coinflip.sol
pragma solidity ^0.4.21;

contract CoinFlip {
    address public player1;
    bytes32 public player1Commitment;

    uint256 public betAmount;

    address public player2;
    bool public player2Choice;

    uint256 public expiration = 2**256-1;

    function CoinFlip(bytes32 commitment) public payable {
        player1 = msg.sender;
        player1Commitment = commitment;
        betAmount = msg.value;
    }

    function cancel() public {
        require(msg.sender == player1);
        require(player2 == 0);

        betAmount = 0;
        msg.sender.transfer(address(this).balance);
    }

    function takeBet(bool choice) public payable {
        require(player2 == 0);
        require(msg.value == betAmount);

        player2 = msg.sender;
        player2Choice = choice;

        expiration = now + 24 hours;
    }

    function reveal(bool choice, uint256 nonce) public {
        require(player2 != 0);
        require(now < expiration);

        require(keccak256(choice, nonce) == player1Commitment);

        if (player2Choice == choice) {
            player2.transfer(address(this).balance);
        } else {
            player1.transfer(address(this).balance);
        }
    }

    function claimTimeout() public {
        require(now >= expiration);

        player2.transfer(address(this).balance);
    }
}
← Writing an ERC20 Pawnshop ContractWriting a Token Auction Contract →
  