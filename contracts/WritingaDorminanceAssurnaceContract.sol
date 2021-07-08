Program the Blockchain
Archive About Subscribe
Writing a Dominant Assurance Contract
MAY 1, 2018 BY TODD PROEBSTING
This post will demonstrate how to write a smart contract that implements a “dominant assurance contract”. It assumes that you have read our previous post on vanilla assurance contracts.

Fundraising via assurance contracts like Kickstarter campaigns often suffer from low participation where people who value the proposed good don’t contribute funds because they anticipate the goal being met without their contribution, or because they doubt success and don’t want to participate in a failing effort. Nonparticipation raises the risk that a campaign will fail. Alex Tabarrok invented “dominant assurance contracts” to address this concern.

Dominant assurance contracts require a patron to stake money that is paid to participants of a failed campaign. This payoff is proportional to the original pledge. For instance, if a patron stakes a 10% payoff, then all participants of a failed campaign would be refunded 110% of their contributions. The motivation is that participants now benefit no matter what—either they get a bonus if the campaign fails, or the valued good is produced if the campaign succeeds.

Staking the Payoff
The previous assurance contract post demonstrated how simple it is to implement an assurance contract with a smart contract. Modifying that code to implement a dominant assurance contract requires just a modest amount more logic.

The contract will be parameterized by the length of the campaign in days, the goal amount, and the percentage payoff to participants if the goal is not attained.

contract DominantAssuranceContract {
    address public owner;
    uint256 public deadline;
    uint256 public goal;
    uint8 public percentagePayoff;
    mapping(address => uint256) public balanceOf;
    uint256 public totalPledges;

    constructor(uint256 numberOfDays, uint256 _goal, uint8 _percentagePayoff) public payable {
        owner = msg.sender;
        deadline = now + (numberOfDays * 1 days);
        goal = _goal;
        percentagePayoff = _percentagePayoff;
        balanceOf[msg.sender] = msg.value;
    }

    // more to come...
}
The smart contract will track a few simple values:

totalPledges will track the total amount pledged. In the previous simple assurance contract, I relied on address(this).balance for tracking pledges, but I can’t do that here because the owner must escrow ether for future payoffs, if needed.
The balanceOf mapping will track the amount of ether to be refunded to accounts in the case of a failed campaign. Initially, balanceOf[owner] will be set to all the escrowed ether transferred when the contract is deployed. That amount will be decreased as pledges are made.
Pledges
The contract accepts pledges and associated ether:

function pledge(uint256 amount) public payable {
    require(now < deadline, "The campaign is over.");
    require(msg.value == amount, "The amount is incorrect.");
    require(msg.sender != owner, "The owner cannot pledge.");

    uint256 payoff = amount * percentagePayoff / 100;
    if (payoff > balanceOf[owner]) {
        payoff = balanceOf[owner];
    }
    balanceOf[owner] -= payoff;
    balanceOf[msg.sender] += amount+payoff;
    totalPledges += amount;
}
The contract accounts for the pledged ether by updating both totalPledges and balanceOf[msg.sender]. It also accounts for the implied payoff amount by transferring ether balance from the owner to the sender.

I’ve disallowed pledges from the owner to avoid having to reason about the correctness of balanceOf[owner] with respect to funding payoffs. The owner can always pledge from another account if they choose.

It’s possible for the contract to run out of payoff funds, so the contract avoids an underflow risk by checking the available owner balance. This risk exists in two scenarios: when more than the expected amount is pledged, or when insufficient payoff is escrowed. The former is great news (but needs to be handled), and the latter may be by design as I discuss later.

Post-Campaign
The logic for handling post-campaign transfers is exactly the same as in the simple assurance contract:

function claimFunds() public {
    require(now >= deadline, "The campaign is not over.");
    require(totalPledges >= goal, "The funding goal was not met.");
    require(msg.sender == owner, "Only the owner may claim funds.");

    msg.sender.transfer(address(this).balance);
}

function getRefund() public {
    require(now >= deadline, "The campaign is still active.");
    require(totalPledges < goal, "Funding goal was met.");

    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    msg.sender.transfer(amount);
}
While the logic is the same, it’s actually a bit more subtle with respect to the payoffs.

claimFunds is simple because all funds, whether pledged or escrowed payoffs, go to the owner when the campaign is successful.
getRefund is simple because the complicated work of keeping track of the pledges and payoffs is done in pledge. Similarly, any remaining/excess escrowed payoff funds will appear in balanceOf[owner], which means that the owner can also use getRefund to claim that excess.
Insufficient Payoff Escrow (Feature)
Note that the constructor did not require the owner to escrow ether sufficient to cover a failed campaign. Because the storage variables are public, it’s trivial to determine the sufficiency of the escrowed ether (in balanceOf[owner]).

This gives patrons the flexibility to deploy a contract with only a partially funded payoff. This would mean that early pledgers would be entitled to a failure payoff, but late pledgers would not. That may be an interesting design point for campaigns that want to encourage early pledges.

Summary
Dominant assurance contracts can easily be implemented with smart contracts.
The payoff feature presents little extra complexity.
The Complete Contract
dominant.sol
pragma solidity ^0.4.23;

contract DominantAssuranceContract {
    address owner;
    uint256 deadline;
    uint256 goal;
    uint8 percentagePayoff;
    mapping(address => uint256) public balanceOf;
    uint256 totalPledges;

    constructor(uint256 numberOfDays, uint256 _goal, uint8 _percentagePayoff) public payable {
        owner = msg.sender;
        deadline = now + (numberOfDays * 1 days);
        goal = _goal;
        percentagePayoff = _percentagePayoff;
        balanceOf[msg.sender] = msg.value;
    }

    function pledge(uint256 amount) public payable {
        require(now < deadline, "The campaign is over.");
        require(msg.value == amount, "The amount is incorrect.");
        require(msg.sender != owner, "The owner cannot pledge.");

        uint256 payoff = amount * percentagePayoff / 100;
        if (payoff > balanceOf[owner]) {
            payoff = balanceOf[owner];
        }
        balanceOf[owner] -= payoff;
        balanceOf[msg.sender] += amount+payoff;
        totalPledges += amount;
    }

    function claimFunds() public {
        require(now >= deadline, "The campaign is not over.");
        require(totalPledges >= goal, "The funding goal was not met.");
        require(msg.sender == owner, "Only the owner may claim funds.");

        msg.sender.transfer(address(this).balance);
    }

    function getRefund() public {
        require(now >= deadline, "The campaign is still active.");
        require(totalPledges < goal, "Funding goal was met.");

        uint256 amount = balanceOf[msg.sender];
        balanceOf[msg.sender] = 0;
        msg.sender.transfer(amount);
    }
}
← Avoiding Integer Overflows: SafeMath Isn't EnoughTwo-Player Games in Ethereum →
  