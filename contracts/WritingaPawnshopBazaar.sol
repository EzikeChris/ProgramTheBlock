Program the Blockchain
Archive About Subscribe
Writing a Pawnshop Bazaar Contract
APRIL 13, 2018 BY TODD PROEBSTING
In our pawnshop post, we built a contract that creates loans between a lender and multiple borrowers using ERC20 tokens as collateral.

This post will demonstrate a token bazaar contract which creates and tracks many pawnshops on behalf of many lenders.

Introduction
The PawnShop contract supports a single lender who accepts a single ERC20 token as collateral. Each lender who wants to do this needs to deploy their own PawnShop contract.

This works, but it makes it hard for potential borrowers to find a PawnShop. Further, a borrower who trusts the PawnShop contract code we presented will still need to check each PawnShop to make sure it’s running the same code.

To solve this problem, we can create a single token bazaar contract that does two things:

It creates new PawnShops using identical code for each.
It tracks all the created PawnShops and makes them discoverable to new borrowers.
The Pawnshop Bazaar Contract
The contract uses techniques from the marketplace post for creating, recording, and logging new pawnshops:

bazaar.sol
pragma solidity ^0.4.21;

import "./pawnshop.sol";

contract PawnShopBazaar {
    mapping(address => PawnShop[]) public pawnShops;

    event PawnShopCreated(PawnShop pawnshop, address indexed lender)

    function create(
        address token,
        uint256 loanNumerator,
        uint256 loanDenominator,
        uint256 payoffNumerator,
        uint256 payoffDenominator,
        uint256 loanDuration
    )
        public
    {
        PawnShop ps = new PawnShop(
            msg.sender,
            token,
            loanNumerator,
            loanDenominator,
            payoffNumerator,
            payoffDenominator,
            loanDuration
        );
        pawnShops[token].push(ps);
        emit PawnShopCreated(ps, msg.sender);
    }
}
This code does the following things:

create deploys a new PawnShop contract, which is owned by the lender/sender and is parameterized as they request.
The new pawnshop is added to a publicly accessible list of pawnshops, which is indexed by token for convenience.
The new pawnshop’s creation is announced with the PawnShopCreated event. The event is indexed by lender so that the lender can easily recognize the pawnshop’s creation and keep track of its address.
While that’s all the code that is needed, there are a few subtleties to note:

The lender needs to record the address of any pawnshops they create, and they should then monitor the LoanCreated events that it produces.
There is no way to delete a pawnshop from the bazaar contract. While this functionality could be trivially added, no pawnshop owner would have an incentive to pay the gas to do this.
While the bazaar contract can create pawnshops, it does not fund them, so the lender should deposit ether in the created pawnshop so that it can make loans.
Because the state variable pawnShops is marked public, a getter function is generated, allowing prospective borrowers to browse through the pawnshops accepting a specific ERC20 token.
The PawnShop contract’s state variables are all public. This is how potential borrowers can know the terms being offered.
Summary
By using the existing PawnShop contract and by leveraging the TokenMarketPlace techniques, a very short smart contract can create a bazaar that allows anybody to create a pawnshop to offer collateralized loans.

This example demonstrates the power of contracts that deploy contracts. The PawnShopBazaar contract does little more than create PawnShop contracts for lenders, and those PawnShop contracts deploy individual Loan contracts as needed when borrowers and lenders make a deal. Contracts that deploy contracts that deploy contracts—pretty cool.

← Capture the Ether: the Game of Smart Contract SecurityKeep Your Code Simple →
  