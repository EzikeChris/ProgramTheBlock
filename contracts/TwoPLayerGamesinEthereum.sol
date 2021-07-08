Program the Blockchain
Archive About Subscribe
Two-Player Games in Ethereum
MAY 4, 2018 BY STEVE MARX
This is the first post in a series about building efficient two-player games in Ethereum. This post will demonstrate a simple, but complete, smart contract that implements a variant of “the 21 game.”

The Game
For this first contract, I wanted to keep the game logic as simple as possible, so I chose the 21 game. I made up a slight variant:

The number starts at 0.
Two players take turns increasing the number by between 1 and 3 (inclusive).
The player who reaches 21 wins.
An example of a valid game might look like this: 0, 1, 5, 7, 9, 10, 13, 16, 17, 19, 21. 1

For the smart contract version, the two players are going to wager on the outcome of the game. They must each contribute an equal amount of ether, and all of the ether goes to the winner.

Handling the Game State
The contract must track a small amount of game state. The state variables player1 and player2 track the two participants, betAmount tracks the amount of ether (in wei) wagered, state tracks the number being increased on the way to 21 and whose turn it is next.

I’ll describe timeout and timeoutInterval later in this post.

contract TwentyOneGame {
    address public player1;
    address public player2;
    uint256 public betAmount;
    bool public gameOver;

    struct GameState {
        uint8 num;
        address whoseTurn;
    }
    GameState public state;

    uint256 public timeoutInterval;
    uint256 public timeout = 2**256 - 1;

    constructor(uint256 _timeoutInterval) public payable {
        player1 = msg.sender;
        betAmount = msg.value;
        timeoutInterval = _timeoutInterval;
    }
Starting the Game
The account that deployed the contract is known as player1. To establish itself as player2, an account calls join() and matches player1’s wager. Any time before a second player has joined, player1 may call cancel() to cancel the game and recover their wager:

event GameStarted();

function join() public payable {
    require(player2 == 0, "Game has already started.");
    require(!gameOver, "Game was canceled.");
    require(msg.value == betAmount, "Wrong bet amount.");

    player2 = msg.sender;
    state.whoseTurn = player1;

    emit GameStarted();
}

function cancel() public {
    require(msg.sender == player1, "Only first player may cancel.");
    require(player2 == 0, "Game has already started.");

    gameOver = true;
    msg.sender.transfer(address(this).balance);
}
Moving the Game Forward
Players take turns by increasing num until 21 is reached. The smart contract is responsible for tracking the game state and enforcing the rules of the game:

Players must take turns.
Players must increase the number by between 1 and 3 (inclusive).
The number cannot exceed 21.
The first player to reach 21 wins.
A player who abandons the game forfeits.
To enforce that last rule, I’ll employ a timeout. Regular readers of this blog will note that we use timeouts a lot—e.g. in posts about auctions, coin flips, and payment channels.

Timeouts come up so often because smart contracts cannot force someone to act; they can only punish inaction. Without a timeout, a player who thought they were going to lose would have no incentive to continue playing, and the winning player would be unable to claim their ether.

The parameter timeoutInterval specifies how many seconds each player is allowed before they must make a move, and timeout tracks when that period expires. The timeout is only started when a player feels it’s needed.

The move() function is called by each player to take their turn:

event MoveMade(address player, uint8 value);

function move(uint8 value) public {
    require(!gameOver, "Game has ended.");
    require(msg.sender == state.whoseTurn, "Not your turn.");
    require(value >= 1 && value <= 3,
        "Move out of range. Must be between 1 and 3.");
    require(state.num + value <= 21, "Move would exceed 21.");

    state.num += value;
    state.whoseTurn = opponentOf(msg.sender);

    // Clear timeout
    timeout = 2**256 - 1;

    if (state.num == 21) {
        gameOver = true;
        msg.sender.transfer(address(this).balance);
    }

    emit MoveMade(msg.sender, value);
}
Here’s a brief explanation of move():

The require statements make sure the move is a valid one.
The game state is updated to reflect the new total and whose turn it is.
The timeout is reset.
If the game is over, the winning player receives their prize.
An event is emitted to help the players know when it’s their turn.
If a player feels their opponent is taking too long to make their move, they can start the timeout process. This sets timeout and emits an event:

function startTimeout() public {
    require(!gameOver, "Game has ended.");
    require(state.whoseTurn == opponentOf(msg.sender),
        "Cannot start a timeout on yourself.");

    timeout = now + timeoutInterval;
    emit TimeoutStarted();
}
If the timeout is reached, this indicates that the player whose turn it is has abandoned the game. They forfeit, making the other player the winner:

function claimTimeout() public {
    require(!gameOver, "Game has ended.");
    require(now >= timeout);

    gameOver = true;
    opponentOf(state.whoseTurn).transfer(address(this).balance);
}
Summary
A smart contract can enforce the rules of a two-player game.
Timeouts are needed to punish non-participation.
Future Posts
This post is the first in a series. The next post will use state channels to avoid having to make each move on the blockchain, and a subsequent post will show how to build a JavaScript front-end for the game.

Full Source Code
twentyone.sol
pragma solidity ^0.4.23;

contract TwentyOneGame {
    address public player1;
    address public player2;
    uint256 public betAmount;
    bool public gameOver;

    struct GameState {
        uint8 num;
        address whoseTurn;
    }
    GameState public state;

    uint256 public timeoutInterval;
    uint256 public timeout = 2**256 - 1;

    event GameStarted();
    event TimeoutStarted();
    event MoveMade(address player, uint8 value);


    // Setup methods

    constructor(uint256 _timeoutInterval) public payable {
        player1 = msg.sender;
        betAmount = msg.value;
        timeoutInterval = _timeoutInterval;
    }

    function join() public payable {
        require(player2 == 0, "Game has already started.");
        require(!gameOver, "Game was canceled.");
        require(msg.value == betAmount, "Wrong bet amount.");

        player2 = msg.sender;
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

    function move(uint8 value) public {
        require(!gameOver, "Game has ended.");
        require(msg.sender == state.whoseTurn, "Not your turn.");
        require(value >= 1 && value <= 3,
            "Move out of range. Must be between 1 and 3.");
        require(state.num + value <= 21, "Move would exceed 21.");

        state.num += value;
        state.whoseTurn = opponentOf(msg.sender);

        // Clear timeout
        timeout = 2**256 - 1;

        if (state.num == 21) {
            gameOver = true;
            msg.sender.transfer(address(this).balance);
        }

        emit MoveMade(msg.sender, value);
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
}
Although this post does not address the strategy of the game, you might be interested to note that the first player (the one who kicked things off with “1”) played a perfect strategy. Played correctly, the first player should always win. ↩
← Writing a Dominant Assurance ContractWriting a Parimutuel Wager Contract →
  