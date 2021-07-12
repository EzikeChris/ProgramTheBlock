Program the Blockchain	Archive About Subscribe
Writing an ERC20 Pawnshop Contract
MARCH 13, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a pawnshop-like smart contract that will lend ether to anybody willing to provide ERC20 tokens as collateral. The post adopts and generalizes techniques that we covered in our collateralized-loan post.

The collateralized loan post described a simple take-it-or-leave-it borrower-driven offer. The borrower offered a set token amount as collateral with given loan terms and waited for a lender to meet those exact terms. The contract in this post will be lender-driven instead, and it will allow multiple borrowers. Each borrower will choose how many tokens to use as collateral and will receive ether proportionally. By serving multiple borrowers, the contract acts like a blockchain-based pawnshop.

The Pawnshop Contract
The PawnShop contract will handle the creation of loans to any account that puts up tokens as collateral. This contract will be parameterized with the following values:

The ERC20 token that the pawnshop accepts as collateral. To keep things simple, I assume that a pawnshop contract only accepts one kind of token.
The loan amount, which is the amount of wei per token unit that the pawnshop is willing to lend in exchange for holding tokens as collateral. This is given as a rational number—see the token market post for details.
The payoff amount, which is the amount of wei per token unit that the borrower must pay the pawnshop to reclaim its tokens. This is also given as a rational number.
The loan’s duration during which the borrower can pay off its loan.
Keeping track of these in the pawnshop is straightforward:

contract PawnShop is Mortal {
    struct Rational {
        uint256 numerator;
        uint256 denominator;
    }

    IERC20Token public token;
    Rational public loanWeiPerUnit;
    Rational public payoffWeiPerUnit;
    uint256 public loanDuration;

    function PawnShop(
        address lender,
        IERC20Token _token,
        uint256 loanNumerator,
        uint256 loanDenominator,
        uint256 payoffNumerator,
        uint256 payoffDenominator,
        uint256 _loanDuration
    )
        public
        payable
    {
        owner = lender;
        token = _token;
        loanWeiPerUnit = Rational(loanNumerator, loanDenominator);
        payoffWeiPerUnit = Rational(payoffNumerator, payoffDenominator);
        loanDuration = _loanDuration;
    }

    function multiply(Rational r, uint256 x) internal pure returns (uint256) {
        if (x == 0) { return 0; }
        uint256 v = x * r.numerator;
        assert(v / x == r.numerator);  // avoid overflow
        return v / r.denominator;
    }

    // ...
}
A few things to note about the code above:

I’ve referenced an IERC20Token interface for storing the address of the token. This was discussed in token sale post.
PawnShop inherits from Mortal (introduced previously), which means that it will have an owner, and that the owner can kill the contract at will.
The Mortal inheritance hides the fact that owner will automatically be set upon creation to the account that deployed the contract.
The Rational struct holds wei/unit values for the loan and ultimate payoff.
The Rational wei/unit values cannot be passed as structs due to (temporary?) limitations of the Solidity compiler, so they are passed as individual values that are reconstituted in the constructor.
The multiply routine implements multiplying by a rational number. The code checks for overflow to avoid a potential vulnerability.
Creating a Loan Contract
I will use the Loan contract unchanged from the collateralized-loan post to keep track of individual loans created by the pawnshop.

The PawnShop contract will fulfill loan requests with the pawnTokens function:

event LoanCreated(
    address loan,
    address indexed borrower,
    IERC20Token token,
    uint256 tokenAmount,
    uint256 etherDue,
    uint256 dueDate
);

function pawnTokens(uint256 unitQuantity) public {
    uint256 totalLoan = multiply(loanWeiPerUnit, unitQuantity);
    uint256 totalPayoff = multiply(payoffWeiPerUnit, unitQuantity);
    address loan = new Loan(owner, msg.sender, token, unitQuantity,
        totalPayoff, loanDuration);
    require(token.transferFrom(msg.sender, loan, unitQuantity));
    msg.sender.transfer(totalLoan);

    emit LoanCreated(loan, msg.sender, token, unitQuantity, totalPayoff,
        now+loanDuration);
}
Explanation of the code above:

unitQuantity is the amount (in units) of tokens that the borrower wishes to use as collateral.
address loan = new Loan(...) deploys a new Loan contract for this loan.
token.transferFrom(...) transfers the tokens from the borrower to the loan contract.
The loaned ether is sent to the borrower.
The LoanCreated event signals to the borrower and lender that the loan has been created and lets them know the address of the deployed Loan contract. (The borrower needs the address to pay off the loan, and the lender may need it to repossess the tokens.)
The code above is deceptively simple, and it hides a few very important details, which must be noted:

How does the borrower know that the contract has enough ether to pay it? If the contract had insufficient funds, the msg.sender.transfer(totalLoan) would fail, which would cause the whole transaction to fail.
If the transaction fails, and the borrower doesn’t get ether, what happens to its tokens? Nothing happens to them. The borrower only approved a transfer, and the transfer didn’t happen.
Once the Loan contract has been deployed, it functions exactly as described in the collateralized-loan post, and it has no subsequent interactions with the PawnShop contract.

Note
I made PawnShop mortal so that the owner could choose to kill it and recoup any leftover ether. This is essential to protecting the owner’s ability to stop making loans if the value of the the tokens changes significantly.

An important concern whenever you see a contract that can be killed is whether or not that functionality creates unexpected consequences. In this scenario, the question is whether killing the pawnshop contract creates any problems with already-deployed loan contracts.

Inspecting the Loan contract code makes it clear that the Loan contracts do not depend in any way on the continued existence of the PawnShop contract.

Summary
The PawnShop contract allows a single lender to offer loans on fixed terms to potentially many borrowers.
Borrowers choose how many tokens to offer as collateral and receive ether proportionally.
Rational numbers support arbitrary rates in the loan terms.
The Complete Contract
The complete code for the PawnShop contract is below. I’ve used Solidity’s import directive to indicate that the code for IERC20Token and Loan will be loaded from separate files. (They were presented in the collateralized-loan post.)

pawnshop.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";
import "./loan.sol";

contract Ownable {
    address owner = msg.sender;
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract Mortal is Ownable {
    function kill() public onlyOwner {
        selfdestruct(msg.sender);
    }
}

contract PawnShop is Mortal {
    struct Rational {
        uint256 numerator;
        uint256 denominator;
    }

    IERC20Token public token;
    Rational public loanWeiPerUnit;
    Rational public payoffWeiPerUnit;
    uint256 public loanDuration;

    function PawnShop(
        address lender,
        IERC20Token _token,
        uint256 loanNumerator,
        uint256 loanDenominator,
        uint256 payoffNumerator,
        uint256 payoffDenominator,
        uint256 _loanDuration
    )
        public
        payable
    {
        owner = lender;
        token = _token;
        loanWeiPerUnit = Rational(loanNumerator, loanDenominator);
        payoffWeiPerUnit = Rational(payoffNumerator, payoffDenominator);
        loanDuration = _loanDuration;
    }

    function multiply(Rational r, uint256 x) internal pure returns (uint256) {
        if (x == 0) { return 0; }
        uint256 v = x * r.numerator;
        assert(v / x == r.numerator);  // avoid overflow
        return v / r.denominator;
    }

    event LoanCreated(
        address loan,
        address indexed borrower,
        IERC20Token token,
        uint256 tokenAmount,
        uint256 etherDue,
        uint256 dueDate
    );

    function pawnTokens(uint256 unitQuantity) public {
        uint256 totalLoan = multiply(loanWeiPerUnit, unitQuantity);
        uint256 totalPayoff = multiply(payoffWeiPerUnit, unitQuantity);
        address loan = new Loan(owner, msg.sender, token, unitQuantity,
            totalPayoff, loanDuration);
        require(token.transferFrom(msg.sender, loan, unitQuantity));
        msg.sender.transfer(totalLoan);

        emit LoanCreated(loan, msg.sender, token, unitQuantity, totalPayoff,
            now+loanDuration);
    }

    function deposit() public payable {}  // enable owner to add more ether
}
← Understanding Ethereum Smart Contract StorageFlipping a Coin in Ethereum →
  