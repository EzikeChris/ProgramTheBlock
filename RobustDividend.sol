Program the Blockchain	Archive About Subscribe
Writing A Robust Dividend Token Contract
FEBRUARY 13, 2018 BY TODD PROEBSTING
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

The simple dividend token post made one big simplifying assumption—it assumed that there were few token units compared to the number of wei in a typical dividend deposit. This assumption meant that the contract could ignore the fact that integer divisions could result in some wei being forever wasted. This post will demonstrate how to write an ERC20-compliant token contract that is robust to that problem.

Floating-point Scaling
Ether values are typically expressed in wei, which means they are really huge numbers. (Recall that there are 1018 wei/ether.) ERC20 contracts typically use similarly scaled representations of token amounts, with 10decimals units/token. Operating on scaled values represents a challenge when doing division because all Solidity divisions are integer divisions. (Recall that the previous simple dividend token restricted decimals to zero to avoid significant problems due to integer division.)

If a contract needs to calculate the wei/unit of a particular dividend, it would be natural to just divide the dividend (in wei) by the total supply of tokens (in units). Unfortunately, this could create a problem if the division yielded a large remainder that would effectively be lost. For instance, suppose a dividend of 1 ether were to be divided amongst 1,000,000 tokens with decimals=18. Doing this directly would imply dividing 1018 wei by 1024 token units. This integer division would result in 0 wei/unit. The division would yield a remainder of 1 ether that would be lost if precautions aren’t taken.

To avoid this lost remainder problem, my robust dividend contract will do two things:

The contract will scale the wei values up sufficiently to make division problems much less significant.
The contract will keep track of any remainders and add them back into subsequent computations whenever possible.
Scaling Values
Fortunately, 256-bit integers provide lots of room for scaling up wei values. 2256 is approximately 1077. 18 of those 77 zeros are used to represent one ether, so we still have 59 zeros of scaling left.

To keep this contract simple, I will hardwire a scaling of 108. I chose 108 because there are 106 tokens for a total of 1024 token units. With a scaling factor of 108, dividing the total supply of token units into 0.01 ether will result in 1 scaled wei/unit to be distributed.

uint256 public scaling = uint256(10) ** 8;
This contract will simply use scaled values in place of the unscaled values in the simple dividend token. So, I’ve changed variable names to include the scaled prefix as appropriate:

uint256 public scaledDividendPerToken;

mapping(address => uint256) public scaledDividendBalanceOf;

mapping(address => uint256) public scaledDividendCreditedPerToken;
Other than being scaled, those values are identical to the similarly-named values in the simple dividend token contract.

Deposit and Withdrawal
Deposits and withdrawals need to convert to and from scaled values. They also need to handle the fact that integer division can leave a remainder—the contract should track those remainders so that they are not lost.

Withdrawal simply needs to update the amount of dividend owed, retain any remainder from the scaling division, and then transfer the amount:

function withdraw() public {
    update(msg.sender);
    uint256 amount = scaledDividendBalanceOf[msg.sender] / scaling;
    scaledDividendBalanceOf[msg.sender] %= scaling;  // retain the remainder
    msg.sender.transfer(amount);
}
The deposit function computes the scaled wei/unit to distribute and add it to the global scaledDividendPerToken. That computation must take into account any previously undistributed (scaled) wei, and it must update that quantity as well.

uint256 public scaledRemainder = 0;

function deposit() public payable {
    // scale the deposit and add the previous remainder
    uint256 available = (msg.value * scaling) + scaledRemainder;

    scaledDividendPerToken += available / totalSupply;

    // compute the new remainder
    scaledRemainder = available % totalSupply;
}
Summary
Floating-point division requires careful planning to avoid too much loss of precision.
Floating-point division requires careful attention to any remainders that may get lost.
The Whole Contract
robustDividend.sol
pragma solidity ^0.4.21;

contract RobustDividendToken {

    string public name = "Robust Dividend Token";
    string public symbol = "DIV";
    uint8 public decimals = 18;

    uint256 public totalSupply = 1000000 * (uint256(10) ** decimals);

    mapping(address => uint256) public balanceOf;

    function RobustDividendToken() public {
        // Initially assign all tokens to the contract's creator.
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    uint256 public scaling = uint256(10) ** 8;

    mapping(address => uint256) public scaledDividendBalanceOf;

    uint256 public scaledDividendPerToken;

    mapping(address => uint256) public scaledDividendCreditedTo;

    function update(address account) internal {
        uint256 owed =
            scaledDividendPerToken - scaledDividendCreditedTo[account];
        scaledDividendBalanceOf[account] += balanceOf[account] * owed;
        scaledDividendCreditedTo[account] = scaledDividendPerToken;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => mapping(address => uint256)) public allowance;

    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value);

        update(msg.sender);
        update(to);

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        public
        returns (bool success)
    {
        require(value <= balanceOf[from]);
        require(value <= allowance[from][msg.sender]);

        update(from);
        update(to);

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    uint256 public scaledRemainder = 0;

    function deposit() public payable {
        // scale the deposit and add the previous remainder
        uint256 available = (msg.value * scaling) + scaledRemainder;

        scaledDividendPerToken += available / totalSupply;

        // compute the new remainder
        scaledRemainder = available % totalSupply;
    }

    function withdraw() public {
        update(msg.sender);
        uint256 amount = scaledDividendBalanceOf[msg.sender] / scaling;
        scaledDividendBalanceOf[msg.sender] %= scaling;  // retain the remainder
        msg.sender.transfer(amount);
    }

    function approve(address spender, uint256 value)
        public
        returns (bool success)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

}
← End to End: Initial Coin OfferingSigning and Verifying Messages in Ethereum →
  