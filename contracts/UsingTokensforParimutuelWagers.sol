Program the Blockchain
Archive About Subscribe
Using Tokens for Parimutuel Wagers
MAY 18, 2018 BY TODD PROEBSTING
This post describes an alternative implementation of parimutuel wagering to my original post. This implementation will use ERC20 tokens to represent wagers.

Tokens for Outcomes
The original contract used a mapping to keep track of how much each account had wagered on each outcome. The new contract will delegate that bookkeeping to mintable ERC20 token contracts that represent the outcomes.

For each outcome, there will be a different token. To bet on an outcome, a bettor buys tokens representing that outcome from the parimutuel contract. These tokens are minted on demand. To claim their winnings once the bet is settled, a bettor sells tokens back to the parimutuel contract. These tokens are then burned.

Parameterization
The token-based parimutuel contract is very similar to the original. It’s parameterized in the same way, with descriptions of the proposition and outcomes. The constructor also accepts an array of “symbols” that are used for ERC20 tokens. The constructor’s significant difference is that it must deploy token contracts for each of the possible outcomes:

contract TokenizedParimutuelContract {
    address public owner;

    string public proposition;
    bytes32[] public outcomes;
    bytes32[] public symbols;
    uint256 public timeout;
    MintableToken[] public tokens;

    constructor(
        string _proposition,
        bytes32[] _outcomes,
        bytes32[] _symbols,
        uint256 timeoutDelay
    )
        public
    {
        owner = msg.sender;
        proposition = _proposition;
        outcomes = _outcomes;
        symbols = _symbols;
        timeout = now + timeoutDelay;

        for (uint256 i = 0; i < _outcomes.length; i++) {
            tokens.push(new MintableToken(0, 18, toString(_outcomes[i]),
                toString(_symbols[i])));
        }
    }
See the full source code at the end of the post for the implementation of toString.

Betting
Betting is nearly identical to the previous contract. The difference is that wagers are tracked by minting tokens for the bettor:

function bet(uint256 outcome) public payable {
    require(state == States.Open);

    tokens[outcome].mint(msg.sender, msg.value);
    totalPerOutcome[outcome] += msg.value;
    total += msg.value;
    require(total < 2 ** 128);   // avoid overflow possibility
}
Claiming Winnings
Once a winning outcome has been declared, anyone can exchange winning tokens for ether. First, the token holder must approve a transfer of the tokens to the parimutuel contract. Then the bettor can call claim which burns the redeemed tokens so that they can never be redeemed again.

function claim() public {
    require(state == States.Resolved);

    uint256 amount = tokens[winningOutcome].balanceOf(msg.sender);
    uint256 value = amount * total / totalPerOutcome[winningOutcome];
    tokens[winningOutcome].burnFrom(msg.sender, amount);
    msg.sender.transfer(value);
}
Note that we can be certain that the multiplication cannot overflow because of the limit on total enforced in bet.

Refunding a Cancelled Bet
If a bet is cancelled, token holders can claim a refund. Ether is returned and tokens are burned:

function refund(uint256 outcome) public {
    require(state == States.Cancelled);

    uint256 amount = tokens[outcome].balanceOf(msg.sender);
    tokens[outcome].burnFrom(msg.sender, amount);
    msg.sender.transfer(amount);
}
Other Functions
The other functions of the original contract (close, resolve, and cancel) are unchanged in this new contract.

Token Comparison
Using mintable ERC20 tokens provides one advantage over the previous contract—it allows wagers to be bought and sold without any needed support from the parimutuel contract itself. This is useful to people who would like to hedge their bets after the proposition has closed but before it has been resolved.

This token-based implementation has one disadvantage compared to the original—it limits the number of outcomes to the number of tokens that can be deployed by the constructor. The original contract could conceivably have supported 2256-1 different outcomes. (To avoid running out of gas, the outcomes array would have to be ignored.)

The Complete Contract
tokenizedparimutuel.sol
pragma solidity ^0.4.23;

import "mintabletoken.sol";

contract TokenizedParimutuelContract {
    address public owner;

    string public proposition;
    bytes32[] public outcomes;
    bytes32[] public symbols;
    uint256 public timeout;
    MintableToken[] public tokens;

    constructor(
        string _proposition,
        bytes32[] _outcomes,
        bytes32[] _symbols,
        uint256 timeoutDelay
    )
        public
    {
        owner = msg.sender;
        proposition = _proposition;
        outcomes = _outcomes;
        symbols = _symbols;
        timeout = now + timeoutDelay;

        for (uint256 i = 0; i < _outcomes.length; i++) {
            tokens.push(new MintableToken(0, 18, toString(_outcomes[i]),
                toString(_symbols[i])));
        }
    }

    function toString(bytes32 b) internal pure returns (string) {
        // Convert a null-terminated bytes32 to a string.

        uint256 length = 0;
        while (length < 32 && b[length] != 0) {
            length += 1;
        }

        bytes memory bytesString = new bytes(length);
        for (uint256 j = 0; j < length; j++) {
            bytesString[j] = b[j];
        }

        return string(bytesString);
    }

    enum States { Open, Closed, Resolved, Cancelled }
    States state = States.Open;

    mapping(uint256 => uint256) public totalPerOutcome;
    uint256 public total;

    uint256 winningOutcome;

    function bet(uint256 outcome) public payable {
        require(state == States.Open);

        tokens[outcome].mint(msg.sender, msg.value);
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

        uint256 amount = tokens[winningOutcome].balanceOf(msg.sender);
        uint256 value = amount * total / totalPerOutcome[winningOutcome];
        tokens[winningOutcome].burnFrom(msg.sender, amount);
        msg.sender.transfer(value);
    }

    function cancel() public {
        require(state != States.Resolved);
        require(msg.sender == owner || now > timeout);

        state = States.Cancelled;
    }

    function refund(uint256 outcome) public {
        require(state == States.Cancelled);

        uint256 amount = tokens[outcome].balanceOf(msg.sender);
        tokens[outcome].burnFrom(msg.sender, amount);
        msg.sender.transfer(amount);
    }
}
← Changing the Supply of ERC20 TokensWriting a Prediction Market Contract →
  