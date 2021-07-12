Program the Blockchain	Archive About Subscribe
Writing a Crowdfunding Contract (a la Kickstarter)
JANUARY 19, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a smart contract that controls a crowdfunding effort in the spirit of Kickstarter. It assumes that you have read our previous posts on banking and time.

Kickstarter crowdfunding efforts are “assurance contracts”, which enable projects to raise money from a group of people based on a simple concept: during a fixed crowdfunding period of time, funders pledge funds in an attempt to raise a total amount that meets a fixed goal amount. If pledges meet the goal before the period expires, the funds are transferred to the project so that it may proceed. If pledges are insufficient when the period expires, the funds are refunded to the funders.

Parameterizing the Crowdfunding Contract
This smart contract is parameterized by two values:

The crowdfunding period (in days). (This is very similar to the time post.)
The goal amount (in wei).
The contract keeps track of the owner/crowdfunding account, and it keeps track of the total amount pledged by each account. (This is very similar to the banking post.)

contract Crowdfunding {
    address owner;
    uint256 deadline;
    uint256 goal;
    mapping(address => uint256) public pledgeOf;

    function Crowdfunding(uint256 numberOfDays, uint256 _goal) public {
        owner = msg.sender;
        deadline = now + (numberOfDays * 1 days);
        goal = _goal;
    }

    // ...to be filled in soon...
}
Accepting Pledges
Accepting a pledge is pretty straightforward as well. The function is parameterized by the value attached. (This parameter is checked as a safety measure to avoid accidentally attaching the wrong amount.) It updates the amount pledged by the sending account and determines if the funding goal has been met.

For simplicity’s sake, this contract will strictly divide time into two distinct periods: the fundraising period and the withdrawal period. During the fundraising period, the contract will accept pledges, but it will not allow withdrawals. During the withdrawal period, the contract will not accept pledges, but it will allow withdrawals.

function pledge(uint256 amount) public payable {
    require(now < deadline);                // in the fundraising period
    require(msg.value == amount);

    pledgeOf[msg.sender] += amount;
}
Withdrawing Funds
Funds can only be withdrawn after the deadline passes. As described above, who can withdraw funds depends on whether or not the goal was met.

To separate the logic guarding who can withdraw funds when, I’ve split the functionality into two routines: claimFunds (for the owner), and getRefund (for the funders):

function claimFunds() public {
    require(address(this).balance >= goal); // funding goal is met
    require(now >= deadline);               // in the withdrawal period
    require(msg.sender == owner);

    msg.sender.transfer(address(this).balance);
}

function getRefund() public {
    require(address(this).balance < goal);  // funding goal not met
    require(now >= deadline);               // in the withdrawal period

    uint256 amount = pledgeOf[msg.sender];
    pledgeOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
The code above includes a few notable things:

Whenever transferring funds out of a contract, it’s really important for a contract to make sure the conditions are correct. Both claimFunds and getRefund check multiple conditions.
The getRefund routine sets the account’s pledgeOf value to 0 before doing the transfer. This is a safety precaution, which is described fully in the banking post.
There is a subtlety to the address(this).balance < goal test in getRefund. Each successful refund will change the value of address(this).balance, which will affect subsequent refund attempts. It is important that such changes not affect future tests of the success of the crowdfunding. In this case that invariant is maintained because refunds decrease address(this).balance, which means that address(this).balance < goal will remain true.
Summary
By (carefully) combining techniques for keeping track of time and per-account balances, a small smart contract can implement a Kickstarter-like crowdfunding.

The Complete Contract
crowdfunding.sol
pragma solidity ^0.4.19;

contract Crowdfunding {
    address owner;
    uint256 deadline;
    uint256 goal;
    mapping(address => uint256) public pledgeOf;

    function Crowdfunding(uint256 numberOfDays, uint256 _goal) public {
        owner = msg.sender;
        deadline = now + (numberOfDays * 1 days);
        goal = _goal;
    }

    function pledge(uint256 amount) public payable {
        require(now < deadline);                // in the fundraising period
        require(msg.value == amount);

        pledgeOf[msg.sender] += amount;
    }

    function claimFunds() public {
        require(address(this).balance >= goal); // funding goal met
        require(now >= deadline);               // in the withdrawal period
        require(msg.sender == owner);

        msg.sender.transfer(address(this).balance);
    }

    function getRefund() public {
        require(address(this).balance < goal);  // funding goal not met
        require(now >= deadline);               // in the withdrawal period

        uint256 amount = pledgeOf[msg.sender];
        pledgeOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}
← Verifying Contract Source CodeLogging and Watching Solidity Events →
  