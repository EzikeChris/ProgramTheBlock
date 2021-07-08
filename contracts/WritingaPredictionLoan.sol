Program the Blockchain
Archive About Subscribe
Writing a Periodic Loan Contract
APRIL 24, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a smart contract that will administer an ether loan while holding ERC20 tokens as collateral. My previous post on a collateralized loan contract assumed that there would be just a single loan payment. This post will generalize that to a more typical structure where the loan requires equal payments at regularly-spaced intervals at a fixed interest rate.

Periodic loans are characterized by a few simple values:

The remaining principal balance amount, which represents the amount of borrowed ether that remains owed to the lender. This typically decreases with each loan payment. This begins as the original loan amount.
The period (or interval) between required loan payments. A typical period might be 30 days.
The minimum periodic payment amount, which is the amount of ether the borrower is required to transfer to the lender each pay period. (The last payment may be less than the minimum.)
The per-period interest rate, which is the fraction of the loan balance that is owed as interest each pay period.
Collateral tokens that will be forfeited for each missed payment.
pragma solidity ^0.4.23;

import "./ierc20token.sol";

contract PeriodicLoan {
    struct Rational {
        uint256 numerator;
        uint256 denominator;
    }

    address lender;
    address borrower;

    Rational public interestRate;

    uint256 public dueDate;
    uint256 paymentPeriod;

    uint256 public remainingBalance;
    uint256 minimumPayment;

    IERC20Token token;
    uint256 collateralPerPayment;

    constructor(
        address _lender,
        address _borrower,
        uint256 interestRateNumerator,
        uint256 interestRateDenominator,
        uint256 _paymentPeriod,
        uint256 _minimumPayment,
        uint256 principal,
        IERC20Token _token,
        uint256 units
    )
        public
    {
        lender = _lender;
        borrower = _borrower;
        interestRate = Rational(interestRateNumerator, interestRateDenominator);
        paymentPeriod = _paymentPeriod;
        minimumPayment = _minimumPayment;
        remainingBalance = principal;
        token = _token;
        collateralPerPayment = units;

        uint256 x = minimumPayment * collateralPerPayment;
        require(x / collateralPerPayment == minimumPayment,
            "minimumPayment * collateralPerPayment overflows");

        dueDate = now + paymentPeriod;
    }

    // more yet to come
}
The code above is very similar to the collateralized loan contract with the addition of the interest rate, payment amount, and payment period values.

Note also that the creation of this loan contract, the transfer of tokens to the loan contract, and the transfer of ether to the borrower will be done by a different smart contract. This contract will assume that those amounts were correctly transferred. (Here is the Wikipedia page with useful formulas for loan payments.)

Loan Payments
Loan payments consist of an interest component and a principal component, which can be computed simply:

interest = interest rate * balance
principal = payment – interest
new balance = old balance – principal
Collateral
Periodic loans in the physical world typically have one big indivisible chunk of collateral like a car or house. In that world, loans must be very complicated to deal with penalties for missed payments including the possibility of forfeiting the collateral for delinquency. Fortunately, we can avoid all of that complexity when tokens are used as collateral in a smart contract.

In the collateralized loan contract all the tokens were transferred at once. If the one loan payment was made, then all of the tokens were transferred back to the borrower, but they were all forfeited if the loan payment wasn’t made. I will generalize that idea.

In the periodic loan, each pay period will result in a transfer of a fraction of the collateral tokens. If the payment was made correctly, then some tokens will be returned to the borrower. Otherwise, they will be transferred to the lender.

The amount of collateral to transfer is easy to compute. The loan is parameterized with collateralPerPayment, which represents the amount of collateral that will be returned or forfeited based on a minimumPayment. If the borrower pays an amount different than the minimum, the amount of collateral returned is adjusted proportionally. For instance, paying twice the minimum will result in twice as many tokens returned.

function calculateComponents(uint256 amount)
    internal
    view
    returns (uint256 interest, uint256 principal)
{
    interest = multiply(remainingBalance, interestRate);
    require(amount >= interest);
    principal = amount - interest;
    return (interest, principal);
}

function calculateCollateral(uint256 payment)
    internal
    view
    returns (uint256 units)
{
    uint256 product = collateralPerPayment * payment;
    require(product / collateralPerPayment == payment, "payment causes overflow");
    units = product / minimumPayment;
    return units;
}
Payment Processing
There is a symmetry between accepting loan payments and handling missed payments. In both cases, there is an adjustment to the remaining principal balance and a corresponding transfer of tokens. The only difference is that the tokens are returned to the borrower after a payment, but they are forfeited to the lender after a missed payment. Both also advance the due date of the next payment:

function processPeriod(uint256 interest, uint256 principal, address recipient) internal {
    uint256 units = calculateCollateral(interest+principal);

    remainingBalance -= principal;

    dueDate += paymentPeriod;

    require(token.transfer(recipient, units));
}
Please note that the code above does the token transfer last, which follows the Checks-Effects-Interactions pattern to avoid potential reentrancy vulnerabilities.

Accepting Payments
Given the ability to compute interest, principal, and collateral amounts corresponding to any expected payment, we are most of the way to handling loan payments. The only additional consideration is the need to handle the final loan payment. While it’s possible to create loan terms where all payments will be identical, it’s sometimes convenient to have “round” payments—like exactly 1 ETH—and then have the final payment be some fractional amount.

function makePayment() public payable {
    require(now <= dueDate);

    uint256 interest;
    uint256 principal;
    (interest, principal) = calculatePrincipal(msg.value);

    require(principal <= remainingBalance);
    require(msg.value >= minimumPayment || principal == remainingBalance);

    processPeriod(interest, principal, borrower);
}


function withdraw() public {
    lender.transfer(address(this).balance);
}
The code above does just a few things:

It checks that the payment was made on time.
It computes the principal amount that corresponds to the payment.
It checks that the principal does not exceed the remaining balance because this would amount to a gift to the lender.
It does not special case the odd final payment amount other than relaxing the require statement.
processPeriod is called specifying that the borrower should receive the collateral tokens.
The code does not transfer the ether directly to avoid problems with a misbehaving lender. Instead, the lender can withdraw ether at any time.
Missed Payments
function missedPayment() public {
    require(now > dueDate);

    uint256 interest;
    uint256 principal;
    (interest, principal) = calculatePrincipal(minimumPayment);

    if (principal > remainingBalance) {
        principal = remainingBalance;
    }

    processPeriod(interest, principal, lender);
}
The code for handling a missed payment is straightforward:

The code computes the principal component of the missed payment. This assumes the payment was the minimum amount, which is true for all but, possibly, the last payment. The conditional handles the boundary condition when the principal remaining is less than the principal component of a minimum payment.
processPeriod is called specifying the lender as the recipient of the forfeited tokens.
missedPayment can be called by anybody. This is important to the borrower because they may need to call missedPayment in order to advance dueDate in order to make a subsequent payment.

Excess Collateral
This smart contract allows borrowers to pay more than the minimum, which will ultimately lead to less total paid because of avoided interest. If used, this feature will lead to excess collateral owned by the loan contract after it’s been fully paid off. This collateral belongs to the borrower. The simplest way to handle that is to allow excess tokens to be claimed when the remainingBalance is zero:

function returnCollateral() public {
    require(remainingBalance == 0);

    uint256 amount = token.balanceOf(this);
    require(token.transfer(borrower, amount));
}
Keeping It Simple
In the spirit of keeping it simple, this contract makes one huge simplifying assumption. Did you see it?

How does this contract handle the borrower missing multiple payments in a row? It does nothing special! If N payments are missed in a row, then missedPayment must be called N times before the contract will accept another payment. Sure, the astute reader could probably add a loop somewhere to handle this case, but then they’d have to think hard about the correctness of that loop. Loop correctness is hard, but I didn’t have to think (much) to be sure the current code works!

Interesting Variations
One of the nice things about smart contracts is that they enable interesting variations on traditional models by simply implementing the variation in the code of the contract. The contract above represents a pretty traditional multi-period loan with respect to payment structure and interest computations. (The only novel aspect is the returning of fractions of the collateral with each payment, which is enabled by the typical design of ERC20 tokens.)

Variations that would represent modest changes to this contract:

Rather than having a minimum payment, the contract could require a minimum amount of principal above the interest due.
The contract could add a penalty amount to the principal balance for each missed payment (in addition to forfeiting collateral tokens).
The contract could include a grace period during which a late payment is accepted with a small penalty, but no forfeited collateral.
The contract could disallow payments in excess of the payment amount, which would disallow pre-payment of principal balance.
Summary
Smart contracts can implement loans that require multiple payments.
ERC20 token collateral enable a flexible repayment and forfeiture policy.
The Full Contract
periodicloan.sol
pragma solidity ^0.4.23;

import "./ierc20token.sol";

contract PeriodicLoan {
    struct Rational {
        uint256 numerator;
        uint256 denominator;
    }

    address lender;
    address borrower;

    Rational public interestRate;

    uint256 public dueDate;
    uint256 paymentPeriod;

    uint256 public remainingBalance;
    uint256 minimumPayment;

    IERC20Token token;
    uint256 collateralPerPayment;

    constructor(
        address _lender,
        address _borrower,
        uint256 interestRateNumerator,
        uint256 interestRateDenominator,
        uint256 _paymentPeriod,
        uint256 _minimumPayment,
        uint256 principal,
        IERC20Token _token,
        uint256 units
    )
        public
    {
        lender = _lender;
        borrower = _borrower;
        interestRate = Rational(interestRateNumerator, interestRateDenominator);
        paymentPeriod = _paymentPeriod;
        minimumPayment = _minimumPayment;
        remainingBalance = principal;
        token = _token;
        collateralPerPayment = units;

        uint256 x = minimumPayment * collateralPerPayment;
        require(x / collateralPerPayment == minimumPayment,
            "minimumPayment * collateralPerPayment overflows");

        dueDate = now + paymentPeriod;
    }

    function multiply(uint256 x, Rational r) internal pure returns (uint256) {
        return x * r.numerator / r.denominator;
    }

    function calculateComponents(uint256 amount)
        internal
        view
        returns (uint256 interest, uint256 principal)
    {
        interest = multiply(remainingBalance, interestRate);
        require(amount >= interest);
        principal = amount - interest;
        return (interest, principal);
    }

    function calculateCollateral(uint256 payment)
        internal
        view
        returns (uint256 units)
    {
        uint256 product = collateralPerPayment * payment;
        require(product / collateralPerPayment == payment, "payment causes overflow");
        units = product / minimumPayment;
        return units;
    }

    function processPeriod(uint256 interest, uint256 principal, address recipient) internal {
        uint256 units = calculateCollateral(interest+principal);

        remainingBalance -= principal;

        dueDate += paymentPeriod;

        require(token.transfer(recipient, units));
    }

    function makePayment() public payable {
        require(now <= dueDate);

        uint256 interest;
        uint256 principal;
        (interest, principal) = calculateComponents(msg.value);

        require(principal <= remainingBalance);
        require(msg.value >= minimumPayment || principal == remainingBalance);

        processPeriod(interest, principal, borrower);
    }

    function withdraw() public {
        lender.transfer(address(this).balance);
    }

    function missedPayment() public {
        require(now > dueDate);

        uint256 interest;
        uint256 principal;
        (interest, principal) = calculateComponents(minimumPayment);

        if (principal > remainingBalance) {
            principal = remainingBalance;
        }

        processPeriod(interest, principal, lender);
    }

    function returnCollateral() public {
        require(remainingBalance == 0);

        uint256 amount = token.balanceOf(this);
        require(token.transfer(borrower, amount));
    }
}
← Storage Patterns: PaginationAvoiding Integer Overflows: SafeMath Isn't Enough →
  