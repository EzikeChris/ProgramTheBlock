Program the Blockchain	Archive About Subscribe
Writing a Collateralized Loan Contract
MARCH 6, 2018 BY TODD PROEBSTING
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

This post will demonstrate how to write a smart contract that will administer an ether loan while holding ERC20 tokens as collateral. The post assumes you are familiar with techniques for how a contract deals with an ERC20 token contract, which we covered in our token sale post. The post introduces the technique of having a smart contract deploy a second contract to carry out future work.

Borrowing ether using ERC20 tokens as collateral is an example transaction that a smart contract can broker easily. To keep payments really simple, I will assume that loans are paid off with a single ether payment that must be made before a given deadline.

For instance, at the time of this writing, one REP token is worth about 0.05 ETH, so a lender might be happy to lend 0.03 ETH for a couple weeks to a borrower willing to transfer 1.0 REP as collateral. The lender would do this because the collateral is worth substantially more than the amount of the loan, so the lender would expect to come out okay if forced to repossess the collateral upon default.

I am going to use two different contracts to orchestrate these financial transactions:

The borrower will deploy a loan request contract that will handle the tokens-for-ether exchange that represents the start of the loan. This contract represents the borrower’s request to borrow ether on specified terms.
When a lender accepts the terms, a loan contract will be created. This loan contract holds the collateral tokens and enforces the terms of the loan until the borrower either pays off the loan or defaults by missing the payment deadline.
Why Two Contracts?
This design is a little more complicated than strictly necessary—it’s possible to handle this loan with a single contract that both initiates the loan and that handles its ultimate disposition. I’ve chosen to use the two-contract design for two reasons:

I wanted to illustrate a contract being deployed by another contract, which is a very powerful technique for decomposing smart contract processing.
I will reuse the Loan contract again in a later post. In that post, the decomposition will make the solution less complicated overall. I just wanted to introduce the concept when solving a simpler problem.
Making the Request
To handle the creation of a loan, a borrower will deploy a smart contract that can create a loan between the borrower and a lender. This LoanRequest contract is parameterized with the following values, which represent the terms of the loan:

The ERC20 token that the lender accepts as collateral.
The collateral amount, which is the unit amount of the token collateral.
The loan amount, which is the amount of wei the borrower is borrowing.
The payoff amount, which is the amount of wei that the borrower must pay to reclaim its tokens.
The loan duration is the amount of time the borrower has pay off its loan after receiving the loan.
Keeping track of these in the smart contract is straightforward:

contract LoanRequest {
    address public borrower = msg.sender;
    IERC20Token public token;
    uint256 public collateralAmount;
    uint256 public loanAmount;
    uint256 public payoffAmount;
    uint256 public loanDuration;

    function LoanRequest(
        IERC20Token _token,
        uint256 _collateralAmount,
        uint256 _loanAmount,
        uint256 _payoffAmount,
        uint256 _loanDuration
    )
        public
    {
        token = _token;
        collateralAmount = _collateralAmount;
        loanAmount = _loanAmount;
        payoffAmount = _payoffAmount;
        loanDuration = _loanDuration;
    }

    // ...
}
I’ve referenced an IERC20Token interface for working with the token. This was discussed in token sale post.

Accepting the Request
If someone is willing to lend ether given the terms of the LoanRequest contract, they can call lendEther. This function transfers the ether to the borrower and transfers the collateral tokens to a new Loan contract, which will enforce the terms of the loan. Below, I will show the implementation of the Loan contract, but for now I will just assume it exists:

Loan public loan;

event LoanRequestAccepted(address loan);

function lendEther() public payable {
    require(msg.value == loanAmount);
    loan = new Loan(
        msg.sender,
        borrower,
        token,
        collateralAmount,
        payoffAmount,
        loanDuration
    );
    require(token.transferFrom(borrower, loan, collateralAmount));
    borrower.transfer(loanAmount);
    emit LoanRequestAccepted(loan);
}
Explanation of the code above:

loan = new Loan(...) deploys a new Loan contract to enforce the terms of the loan.
token.transferFrom(...) transfers the token collateral from the borrower to the loan contract.
The loaned ether is sent to the borrower.
The emit LoanRequestAccepted(loan) logs the transaction, which can alert the borrower that his request was fulfilled and let them know the address of the loan contract.
At the conclusion of this function, the borrower holds the loaned ether, and the Loan contract holds the collateral tokens. Both parties can easily find the Loan contract thanks to the public loan state variable.

The code above is deceptively simple, and it hides a few very important details, which must be noted:

What if the borrower failed to approve the token transfer? If the transfer wasn’t approved, then the transferFrom will fail, and the whole transaction will be aborted, which means the borrower will not lose their ether.
If the transaction fails, and the borrower doesn’t get ether, what happens to its tokens? Nothing happens to them. The borrower only approved a transfer, and the transfer didn’t happen.
What happens if a lender never arrives and the borrower no longer wants to get the loan? The borrower is free to cancel the token transfer approval at any time before a lender arrives.
Enforcing the Loan Terms
The Loan contract enforces the terms of the loan. Its constructor just stores the parameters of the loan:

contract Loan {
    address public lender;
    address public borrower;
    IERC20Token public token;
    uint256 public collateralAmount;
    uint256 public payoffAmount;
    uint256 dueDate;

    function Loan(
        address _lender,
        address _borrower,
        IERC20Token _token,
        uint256 _collateralAmount,
        uint256 _payoffAmount,
        uint256
        loanDuration
    )
        public
    {
        lender = _lender;
        borrower = _borrower;
        token = _token;
        collateralAmount = _collateralAmount;
        payoffAmount = _payoffAmount;
        dueDate = now + loanDuration;
    }

    // ...
}
The Loan contract allows the borrower to reclaim its tokens by paying off the loan during the loan period. Should the borrower fail to pay off the loan before the due date, it allows the lender to repossess the forfeited tokens:

event LoanPaid();

function payLoan() public payable {
    require(now <= dueDate);
    require(msg.value == payoffAmount);

    require(token.transfer(borrower, collateralAmount));
    emit LoanPaid();
    selfdestruct(lender);
}

function repossess() public {
    require(now > dueDate);

    require(token.transfer(lender, collateralAmount));
    selfdestruct(lender);
}
Both routines above use selfdestruct to terminate the contract, which has beneficial gas consequences and transfers any ether to the lender. The LoanPaid event is there to signal the lender that their ether is available.

Summary
A smart contract can exploit the ERC20 standard to facilitate using tokens as loan collateral.
A smart contract can itself deploy smart contracts, which is a powerful technique for decomposing a problem.
The Complete Contracts
loan.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract Loan {
    address public lender;
    address public borrower;
    IERC20Token public token;
    uint256 public collateralAmount;
    uint256 public payoffAmount;
    uint256 public dueDate;

    function Loan(
        address _lender,
        address _borrower,
        IERC20Token _token,
        uint256 _collateralAmount,
        uint256 _payoffAmount,
        uint256 loanDuration
    )
        public
    {
        lender = _lender;
        borrower = _borrower;
        token = _token;
        collateralAmount = _collateralAmount;
        payoffAmount = _payoffAmount;
        dueDate = now + loanDuration;
    }

    event LoanPaid();

    function payLoan() public payable {
        require(now <= dueDate);
        require(msg.value == payoffAmount);

        require(token.transfer(borrower, collateralAmount));
        emit LoanPaid();
        selfdestruct(lender);
    }

    function repossess() public {
        require(now > dueDate);

        require(token.transfer(lender, collateralAmount));
        selfdestruct(lender);
    }
}
collateral.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";
import "./loan.sol";

contract LoanRequest {
    address public borrower = msg.sender;
    IERC20Token public token;
    uint256 public collateralAmount;
    uint256 public loanAmount;
    uint256 public payoffAmount;
    uint256 public loanDuration;

    function LoanRequest(
        IERC20Token _token,
        uint256 _collateralAmount,
        uint256 _loanAmount,
        uint256 _payoffAmount,
        uint256 _loanDuration
    )
        public
    {
        token = _token;
        collateralAmount = _collateralAmount;
        loanAmount = _loanAmount;
        payoffAmount = _payoffAmount;
        loanDuration = _loanDuration;
    }

    Loan public loan;

    event LoanRequestAccepted(address loan);

    function lendEther() public payable {
        require(msg.value == loanAmount);
        loan = new Loan(
            msg.sender,
            borrower,
            token,
            collateralAmount,
            payoffAmount,
            loanDuration
        );
        require(token.transferFrom(borrower, loan, collateralAmount));
        borrower.transfer(loanAmount);
        emit LoanRequestAccepted(loan);
    }
}
← Building Long-Lived Payment ChannelsUnderstanding Ethereum Smart Contract Storage →
  