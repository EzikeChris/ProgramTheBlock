Program the Blockchain
Archive About Subscribe
Working with State Channels in JavaScript
JUNE 23, 2018 BY STEVE MARX
In this post, I’ll show how to build a JavaScript front end for a two-player game based on state channels.

This post is a continuation of my previous posts “Two-Player Games in Ethereum” and “State Channels for Two-Player Games.” This post assumes that you’ve read and understood those.

Overview
In a typical DApp, the role of the front end is to provide a friendly user interface for a smart contract. Data displayed comes directly from the smart contract’s state, and interactive UI elements result in function calls to the smart contract.

For a DApp based on state channels, the front end is more involved. In addition to interacting with the smart contract, it must handle off-chain interactions with another user. The state displayed is an aggregate of off-chain and on-chain information, and most interactions are peer-to-peer with an untrusted adversary.

The JavaScript front end in this post will do the following:

Deploy a new game contract or join an existing game as a second player.
Communicate moves to the other player via signed messages.
Track the current game state, including off-chain progress as well as the smart contract’s state.
Send transactions to the smart contract when necessary: either to end the game or to deal with timeouts.
Technology Used
The 21 game DApp uses web3.js version 0.2x.x. At the time of this writing, 1.0 is still in beta and not very compatible with MetaMask.

The DApp uses Vue.js to handle displaying data and responding to HTML events. I’m going to omit most of that plumbing in this post and focus on the Ethereum-specific concepts. In the code below, the this variable points to a Vue instance, and updates to its members result in updates to the HTML.

For exchanging messages between opponents, the DApp uses PubNub, a simple realtime communication platform. In particular, I’m using pub/sub over Websockets to exchange messages in the game. Again, I’m going to omit some details about PubNub in the code in this post.

If you want to see the details I’m omitting, the full source code for the DApp can be seen by using the “view source” feature in your browser.

Starting a New Game
The first player starts a new game by pressing the “Deploy contract” button. This has the effect of deploying the contract and setting up some event handlers:

var bytecode = "...";
var abi = [...];

TwentyOneContract = web3.eth.contract(abi);

...

start: function () {
  var that = this;

  // Deploy the contract, using a 10-minute timeout interval and a 0.01
  // ether wager.
  TwentyOneContract.new(600, {
    data: bytecode,
    gas: 2000000,
    value: web3.toWei(0.01, "ether"),
  }, function (err, contract) {

    if (err) return error(err);
    that.contract = contract;

    // Once the contract has been deployed...
    if (contract.address) {
      // Subscribe to messages and events.
      that.subscribe();

      log("Deployment succeeded. Contract address: " + contract.address);

      // Listen for when the game is started.
      that.contract.GameStarted(function () {
        that.contract.player2(function (err, opponent) {
          // Update our local state to reflect our opponent's address and
          // the fact that it's our turn.
          that.opponent = opponent;
          that.whoseTurn = that.account;
        });
      });
    } else {
      log("Deploying contract. Transaction hash: " + contract.transactionHash);
    }
  });
},

subscribe: function () {
  var that = this;
  this.contract.allEvents(function (err, event) {
    that.fetchContractState();
  });

  pubnub.subscribe({
    channels: ['21-' + this.contract.address],
  });
},
Here are a few notes about the above code:

A new contract is deployed for each game.
The bytecode and ABI come from the Solidity compiler. (I used Remix.)
The code listens for a GameStarted event, which happens when a second player joins the game.
The subscribe() function starts listening to a PubNub channel named after the contract’s address. PubNub channels do not require explicit creation. This function also listens for any changes from the contract and calls fetchContractState(), which will be described later in this post.
The callback for TwentyOneContract.new is called twice: first when the transaction is sent, and second when the transaction has been mined. The if (contract.address) conditional makes use of the contract only after it’s been deployed.
When the contract is deployed, its address is displayed to the user. They need to share this address with another user so that user can join the game. This can be done by email, text message, etc.

Joining an Existing Game
A player can join an existing game if they know the game contract’s address. The following code invokes the smart contract’s join() function:

join: function () {
  var address = this.$refs.address.value;

  var that = this;
  var contract = TwentyOneContract.at(address);

  contract.join({ value: web3.toWei(0.01, "ether") }, function (err, hash) {
    if (err) return error(err);

    waitForReceipt(hash, function (receipt) {
      if (receipt.status === "0x01") {
        log("Game joined.");
        that.contract = contract;
        that.opponent = player1;
        that.whoseTurn = player1;
        that.subscribe();
      }
    });
  });
},
Note that the code in the DApp is a bit more sophisticated than this. It also handles the case of resuming a game when the player is already participating. It checks the state of the contract to detect this case and then updates the local state to match the latest contract state.

Tracking Smart Contract State
For a state-channel based DApp, state changes can come from two places: the smart contract or messages received off-chain. The front end needs to handle both.

The local state includes the following:

account is the player’s address.
opponent is the opponent’s address.
contract is the deployed game contract.
seq is the last valid sequence number known to this client.
num is the game’s “number” associated with seq.
whoseTurn indicates whose turn is next.
pendingMove is the unacknowledged last move by account. It is null if no move is pending.
signature is the signature from the opponent’s last message.
timeout is when the current timeout, if any, expires. If there is no current timeout, this has the value of maxuint (2256 - 1).
latePlayer indicates which account must respond to the timeout.
gameOver indicates whether the game is over.
The fetchContractState() function reads the current state from the smart contract and updates the local state accordingly. Note that because state changes come from two places, there can be conflicts. These conflicts are resolved by using the game’s sequence number. A state change can be ignored if it has a lower sequence number than the local state:

fetchContractState: function () {
  var that = this;

  // Fetch the state from the contract.
  this.contract.state(function (err, state) {
    if (err) return error(err);

    var seq = state[0].toNumber();
    var num = state[1].toNumber();
    var whoseTurn = state[2];

    // Only update if the sequence number has increased.
    if (seq > that.seq) {
      that.seq = seq;
      that.num = num;
      that.whoseTurn = whoseTurn;
      that.pendingMove = null;
      that.signature = null;
    }

    // Fetch the timeout status from the contract.
    that.contract.timeout(function (err, timeout) {
      if (err) return error(err);

      if (timeout.equals(maxuint)) {
        // A value of 2^256-1 indicates no timeout.
        that.timeout = null;
        that.latePlayer = null;
      } else {
        that.timeout = timeout.toNumber();
        that.latePlayer = whoseTurn;
      }
    });

    // Check whether the game is over.
    that.contract.gameOver(function (err, gameOver) {
      if (err) return error(err);

      that.gameOver = gameOver;
    });
  });
},
Tracking Off-Chain State
When a player makes a move, it is sent via a PubNub message. The message includes the move that was made as well as a signature of the resulting state. If a received move and its signature are valid, the local state must be updated to reflect the move:

updateIfValid: function (move, signature) {
  if (this.whoseTurn !== this.opponent) return;
  if (move < 1 || move > 3) return;

  var num = this.num;
  var seq = this.seq;

  // First apply our pending move.
  if (this.pendingMove) {
    seq += 1;
    num += this.pendingMove;
  }

  seq += 1;
  num += move;

  if (num > 21) return;
  var message = prefixed(this.stateHash(seq, num));
  var signer = recoverSigner(message, signature);
  if (signer !== this.opponent.toLowerCase()) return;

  this.seq = seq;
  this.num = num;
  this.whoseTurn = this.account;
  this.pendingMove = null;
  this.signature = signature;
},
prefixed() and recoverSigner() are borrowed from our post “Writing a Simple Payment Channel.”

stateHash() computes the hash for a given game state:

stateHash: function (seq, number) {
  return "0x" + ethereumjs.ABI.soliditySHA3(
    ["address", "uint8", "uint8"],
    [this.contract.address, seq, number],
  ).toString("hex");
},
Here’s a brief explanation of the above code:

A move is only valid if it’s that player’s turn, the move is between 1 and 3, the resulting number does not exceed 21, and the signature is valid.
Invalid moves are silently ignored.
All moves are based on the latest state, including any pending move.
The idea of a “pending move” requires some explanation. It’s most easily understood in the context of an in-progress game:

The off-chain game state is: { seq: 3, num: 7, signature: ... }. (The signature is from my opponent and matches that state.)
I send my opponent a message with the move 3.
Due to a networking error, my opponent never sees that message and eventually starts a timeout via the smart contract.
To avoid forfeiting the game, I must respond to the timeout by calling moveFromState() on the smart contract. That function requires three things: the state I’m moving from, a signature from my opponent matching that state, and the move I would like to make.

If after step 2, I updated my local state to { seq: 4, num: 10 }, then I no longer have the information I need to call moveFromState(). Instead, I use the concept of a pending move and update the state to { seq: 3, num: 7, signature: ..., pendingMove: 3 }.

With that information, I can successfully call moveFromState() and resume the game.

If my opponent had seen my move and made their own move in response, I would just need to apply the pending move before processing theirs. This is exactly what updateIfValid() does.

Making Moves
A move can be made either on-chain, by sending a transaction, or off-chain, by sending a signed message to the opponent. By default, messages are sent off-chain to avoid transaction delays and expense. A message is sent on-chain in only two cases:

It’s the winning move. Sending a transaction is necessary here to claim the ether prize.
There’s a timeout running against this player. Calling move() on the smart contract clears the timeout and avoids forfeiting the game.
The JavaScript move() function checks for those cases and either sends an on-chain transaction or transmits a signed message via PubNub:

move: function (n) {
  var that = this;

  var message = this.stateHash(this.seq + 1, this.num + n);

  if (this.num + n === 21 || this.latePlayer === this.account) {
    // Send move to the contract if it's the winning move or there's a
    // timer running against us.
    this.contractMove(n);
  } else {
    // Otherwise send a signed message to our opponent.
    web3.personal.sign(
      message,
      web3.eth.defaultAccount,
      function (err, signature) {
        if (err) return error(err);

        pubnub.publish({
          channel: '21-' + that.contract.address,
          message: {
            move: n,
            signature: signature,
          },
        });

        that.whoseTurn = that.opponent;
        that.pendingMove = n;
      });
  }
},
Note that off-chain messages require updating pendingMove, as described in the previous section.

The contractMove() function handles sending a move to the smart contract with a transaction. The contract supports two different functions for submitting a move:

move() makes a move based on the current state known to the contract.
moveFromState() updates the contract with the latest signed state from the opponent and then makes a move on top of that.
The following code uses the appropriate contract method by checking whether the local state contains a signature or not. If there’s a signature, moveFromState() is called. If there is no signature, it means the most recent local state from the smart contract, so move() can be called directly:

contractMove: function (n, cb) {
  var that = this;

  function callback(err, hash) {
    if (err) return error(err);

    waitForReceipt(hash, function (receipt) {
      if (receipt.status === "0x01") {
        log("Move made.");
        if (cb) {
          cb();
        }
        that.fetchContractState();
      } else {
        error("Failed to submit move.");
      }
    });
  }

  if (this.signature) {
    this.contract.moveFromState(this.seq, this.num, this.signature, n,
      callback);
  } else {
    this.contract.move(this.seq, n, callback);
  }
},
Dealing with Timeouts
If a player stops making moves when it’s their turn, this is considered a forfeit. A timer is used to enforce this rule.

Three operations deal with timeouts:

A player can start a timeout when it’s their opponent’s turn.
A player can claim a timeout once it’s expired.
A player can stop a timeout by making a move.
To start a timeout, the player must first ensure that the contract knows it’s their opponent’s turn. To do that, they need to send their pending move (if any) to the smart contract before invoking startTimeout():

moveAndStartTimeout: function () {
  var that = this;

  function startTimeout() {
    that.contract.startTimeout(function (err, hash) {
      if (err) return error(err);

      waitForReceipt(hash, function (receipt) {
        if (receipt.status === "0x01") {
          log("Timeout started.");
        } else {
          log("Transaction failed.");
        }
      });

      that.fetchContractState();
    });
  }

  if (this.pendingMove) {
    log("Making latest move on-chain...");
    this.contractMove(this.pendingMove, startTimeout);
  } else {
    startTimeout();
  }
},
Once the timeout has expired, the winning player can call claimTimeout() to collect their winnings:

claimTimeout: function () {
  var that = this;

  this.contract.claimTimeout(function (err, hash) {
    if (err) return error(err);

    waitForReceipt(hash, function (receipt) {
      if (receipt.status === "0x01") {
        log("Timeout claimed.");
      } else {
        log("Transaction failed.");
      }
      that.fetchContractState();
    });
  });
},
No special code is required to stop a timeout, because this is already dealt with in the move() function from the previous section.

Canceling a Game
While waiting for an opponent to join, the player who started the game is allowed to cancel it:

cancelGame: function () {
  var that = this;

  this.contract.cancel(function (err, hash) {
    if (err) return error(err);

    waitForReceipt(hash, function (receipt) {
      if (receipt.status === "0x01") {
        log("Game canceled.");
        that.fetchContractState();
      }
    });
  });
},
Full Source Code
You can use “view source” in your browser to see the full code for the 21 game DApp.

To play the game by yourself, I recommend using two different browsers (e.g. Chrome and Firefox), rather than just two windows or tabs. This is because MetaMask’s account selection is per browser, so you’ll find yourself having to switch back and forth between accounts with each move. Using two different browsers means you can easily use a separate account with each.

Future Work
This code works, but there are a couple areas for improvement:

Retry logic: Right now, if a networking issue interrupts communication, the players have no choice but to make at least one on-chain transaction to resume the game. A simple fix would be to resend messages periodically until they’re acknowledged by the opponent.
Signature confirmation: Every move requires additional user interaction to sign a message. In the case of MetaMask, this is a popup that the user must click on. If the user is willing to trust the DApp code to a limited extent, it’s possible to avoid this by signing with a temporary generated account instead. I will explore this idea in a future post.
← Supporting an Off-Chain Market MakerEnsuring the Effects of a Transaction →
  