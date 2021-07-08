Program the Blockchain
Archive About Subscribe
Writing a Parimutuel Wager Contract
MAY 8, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a smart contract that implements parimutuel betting. The contract will accept and pay off bets on the outcome of a single proposition.

Parimutuel betting is a simple way of managing bets and paying off winners. For a given proposition, there are multiple mutually-exclusive outcomes to bet on, only one of which will win. For each possible outcome, a separate tally of bets is maintained. After determining the winning outcome, all of the wagered money is divided amongst those who bet correctly. The money awarded to a bettor is proportional to the fraction of the winning wagers that bettor represents. An example will help.

Suppose $1000 total is bet on the horses in a race, with $200 of that being bet on the winner. Furthermore, suppose that you bet $30 on the winner. Your bet represents 15% ($30/$200) of the winning bets, so you are entitled to 15% of all the money bet ($1000). Therefore, you would receive $150.

A Trusted “Oracle”
Unlike most of our smart contracts, this contract will require some off-blockchain information to pay off bets. Specifically, I am assuming that the bets are about off-chain events like political elections or sporting events.

One motivation for blockchains and smart contracts is distrust of non-chain entities. To resolve a bet about an external event, we must trust some off-chain entity to present the winning outcome. Such an entity is called an “oracle”.

Creating an independent, distributed, trusted oracle is beyond the scope of this post, so I’m going to just assume that bettors trust the contract’s owner to resolve bets correctly.

Parameterization
Bets are parameterized by a description of the proposition and a list of the possible outcomes. I use bytes32 rather than string for each outcome due to a Solidity limitation. (Solidity does not support an array of strings as a parameter to the constructor.)

contract ParimutuelContract {
    address public owner;

    string public proposition;
    bytes32[] public outcomes;
    uint256 public timeout;

    constructor(string _proposition, bytes32[] _outcomes, uint256 timeoutDelay)
        public
    {
        owner = msg.sender;
        proposition = _proposition;
        outcomes = _outcomes;
        timeout = now + timeoutDelay;
    }

    // more to come...
}
The proposition and outcomes values are purely descriptive. They are used by external entities to understand what proposition the contract represents. They are not used in the rest of the contract.

The timeout is used to safeguard bettors from the possibility that the owner never resolves the proposition and bets are never paid off. It is used in cancel below.

Bet Tracking
The contract can be in one of four states:

Open: the state when bets are accepted
Closed: the state after bets are accepted but before the winner is known
Resolved: the state after the winner is known during which bets are paid off
Cancelled: the state of having been cancelled. Any unresolved bet can be cancelled.
enum States { Open, Closed, Resolved, Cancelled }
States state = States.Open;
Betting
Bet outcomes are indicated using the index into the outcomes array corresponding to the desired outcome.

Tracking bets requires updating three running tallies:

betAmounts tracks per-bettor bets on individual outcomes.
totalPerOutcome tracks the total amount bet on each specific outcome.
total tracks the total amount bet.
mapping(address => mapping(uint256 => uint256)) public betAmounts;
mapping(uint256 => uint256) public totalPerOutcome;
uint256 public total;

function bet(uint256 outcome) public payable {
    require(state == States.Open);

    betAmounts[msg.sender][outcome] += msg.value;
    totalPerOutcome[outcome] += msg.value;
    total += msg.value;
    require(total < 2 ** 128);   // avoid overflow possibility
}
Note that the code limits the total amount bet. It does so to avoid a potential overflow in the computation of bet payoffs. The limit is conservative.

Closing Betting
Only the owner can close betting, which is simply a change to the state from Open to Closed.

function close() public {
    require(state == States.Open);
    require(msg.sender == owner);

    state = States.Closed;
}
Resolving the Bet
The owner resolves the bet by indicating the winning outcome. This also changes the state of the bet from Closed to Resolved. I could have allowed a direct transition from Open to Resolved, but this is simpler.

uint256 winningOutcome;

function resolve(uint256 _winningOutcome) public {
    require(state == States.Closed);
    require(msg.sender == owner);

    winningOutcome = _winningOutcome;
    state = States.Resolved;
}
Claiming Winnings
Once a winning outcome has been declared, claiming winnings is straightforward.

function claim() public {
    require(state == States.Resolved);

    uint256 amount = betAmounts[msg.sender][winningOutcome] * total
        / totalPerOutcome[winningOutcome];
    betAmounts[msg.sender][winningOutcome] = 0;
    msg.sender.transfer(amount);
}
Note that we can be certain that the multiplication cannot overflow because of the limit on total enforced in bet.

Cancelling the Bet
An unresolved bet can be cancelled under either of two conditions:

The owner can cancel an unresolved bet at any time.
Anybody can cancel an unresolved bet after the timeout.
function cancel() public {
    require(state != States.Resolved);
    require(msg.sender == owner || now > timeout);

    state = States.Cancelled;
}
Bettors must be able to reclaim bets made prior to cancellation. To keep things simple, the contract does not keep track of the total amount bet by each bettor. Therefore, refunds must be requested on a per-outcome basis.

function refund(uint256 outcome) public {
    require(state == States.Cancelled);

    uint256 amount = betAmounts[msg.sender][outcome];
    betAmounts[msg.sender][outcome] = 0;
    msg.sender.transfer(amount);
}
Incentives
I ignored the fact that gambling establishments typically keep a portion of the bets for themselves. Such a vig would not introduce significant complexity to this contract. The claim function would need to scale down payments, and the remainder would need to be paid to the owner.

While a vig-less contract may seem desirable, it has one significant drawback: the owner has no tangible incentive to actually resolve the proposition. Compensating the owner only after they resolve the proposition would give them incentive to do so. It would also give them incentive to resolve the proposition truthfully. Someone who regularly creates propositions needs to maintain an honest reputation to encourage future participation.

Summary
The smart contract supports parimutuel betting.
The contract goes through multiple states, which are tracked explicitly with enum values.
The contract relies on its owner to transition between states and to resolve the proposition.
The contract employs a timeout to guard against a perpetually unresolved proposition.
The Complete Contract
parimutuel.sol
pragma solidity ^0.4.23;

contract ParimutuelContract {
    address public owner;

    string public proposition;
    bytes32[] public outcomes;
    uint256 public timeout;

    constructor(string _proposition, bytes32[] _outcomes, uint256 timeoutDelay)
        public
    {
        owner = msg.sender;
        proposition = _proposition;
        outcomes = _outcomes;
        timeout = now + timeoutDelay;
    }

    enum States { Open, Closed, Resolved, Cancelled }
    States state = States.Open;

    mapping(address => mapping(uint256 => uint256)) public betAmounts;
    mapping(uint256 => uint256) public totalPerOutcome;
    uint256 public total;

    uint256 winningOutcome;

    function bet(uint256 outcome) public payable {
        require(state == States.Open);

        betAmounts[msg.sender][outcome] += msg.value;
        totalPerOutcome[outcome] += msg.value;
        total += msg.value;
        require(total < 2 ** 128);   // avoid overflow possibility
    }

    function close() public {
        require(state == States.Open);
        require(msg.sender == owner);

        state = States.Closed;
    }

    function resolve(uint256 _winningOutcome) public {
        require(state == States.Closed);
        require(msg.sender == owner);

        winningOutcome = _winningOutcome;
        state = States.Resolved;
    }

    function claim() public {
        require(state == States.Resolved);

        uint256 amount = betAmounts[msg.sender][winningOutcome] * total
            / totalPerOutcome[winningOutcome];
        betAmounts[msg.sender][winningOutcome] = 0;
        msg.sender.transfer(amount);
    }

    function cancel() public {
        require(state != States.Resolved);
        require(msg.sender == owner || now > timeout);

        state = States.Cancelled;
    }

    function refund(uint256 outcome) public {
        require(state == States.Cancelled);

        uint256 amount = betAmounts[msg.sender][outcome];
        betAmounts[msg.sender][outcome] = 0;
        msg.sender.transfer(amount);
    }
}
← Two-Player Games in EthereumState Channels for Two-Player Games →
  