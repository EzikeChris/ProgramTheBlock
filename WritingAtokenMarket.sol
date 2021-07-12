Program the Blockchain	Archive About Subscribe
Writing a Token Market Contract
FEBRUARY 27, 2018 BY TODD PROEBSTING
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

This post will demonstrate how to write a smart contract that creates a token marketplace, where people can buy and sell ERC20 tokens. The smart contract acts like eBay by enabling sellers to list tokens for sale, and then brokering sales to buyers. This post relies on concepts introduced in our post on ERC20 tokens.

ERC20 token owners may want to sell some of their tokens. Of course, it would be natural to sell the tokens for ether and to conduct that sale via a smart contract. To help buyers find sellers, a single marketplace contract allows sellers to list tokens for sale—in a given quantity and for a given price—and then brokers sales when approached by buyers.

My marketplace contract will support three essential transactions:

Sellers can list a token for sale. The listing will include the quantity available and the price/unit.
Buyers can buy a token advertised in a given listing. The purchase quantity can be any amount up to the total available in the listing, and the price will be computed based on the listing’s price/unit.
Sellers can cancel an existing listing. Cancellation doesn’t affect any previously made sales, but it will prevent any subsequent sales.
(More) Floating Point Woes
Solidity’s lack of support for floating point numbers presents challenges when pricing tokens. It’s natural to give prices in wei per token unit, but sometimes integer values are insufficient. For instance, it is impossible to express 1.5 wei/unit or 0.0001 wei/unit with a simple integer value.

In this contract, I’m going to use a very simple technique—the contract will use a rational number expressed as numerator/denominator, where both numerator and denominator are 256-bit unsigned integers. This will give plenty of precision to express any reasonable price.

Solidity structs
Each listing is composed of five related values: the seller’s address, the token’s address, the quantity available (in units), and the wei/unit price given as a rational number.

Solidity supports a struct datatype for grouping data together:

struct Listing {
    address seller;
    IERC20Token token;
    uint256 unitsAvailable;

    // wei/unit price as a rational number
    uint256 priceNumerator;
    uint256 priceDenominator;
}
Solidity’s structs are very similar to C’s and Go’s as a means for treating related data as a unit.

Solidity Arrays
The marketplace contract must keep track of all the sellers’ listings, and it will do so in a dynamically-sized array. Solidity arrays are indexed from 0:

Listing[] listings;
Once a listing is added to the array, it will be referenced by its location (index) in the listings array. Future purchase and cancellation transactions will refer to the listing’s index.

Listing Tokens for Sale
Adding a listing to the marketplace contract is very straightforward: the contract will create a new listing struct with the appropriate values and append it to the end of the listings array.

In addition to storing the listing, the contract will log an event to announce the listing change to the outside world. The event will include the seller’s address and the listing’s index. The seller’s address is indexed to help the seller determine the indices of its listing(s).

event ListingChanged(address indexed seller, uint256 indexed index);

function list(
    IERC20Token token,
    uint256 units,
    uint256 numerator,
    uint256 denominator
) public {
    Listing memory listing = Listing({
        seller: msg.sender,
        token: token,
        unitsAvailable: units,
        priceNumerator: numerator,
        priceDenominator: denominator
    });
    listings.push(listing);
    emit ListingChanged(msg.sender, listings.length-1);
}
The code above introduces three new Solidity features:

Listing memory x declares a Listing struct that will reside in memory, which is temporary, rather than having it reside in persistent storage.
Listing(...) creates a new Listing struct with named fields set to the argument values.
listings.push(x) adds an element to the end of the listing array.
This contract will use the ERC20 token approve/transferFrom pattern for delegating token transfers. So, the buyer must approve the marketplace contract to transfer the listed tokens prior to any buyers attempting to buy those tokens. The marketplace contract never checks that the appropriate approve has happened—it simply assumes it has.

Buying Tokens
Making a purchase is also straightforward: the buyer indicates the index of the listing to be used, and the quantity to purchase. The buyer must also attach the appropriate amount of ether to the transaction:

function buy(uint256 index, uint256 units) public payable {
    Listing storage listing = listings[index];

    require(listing.unitsAvailable >= units);
    listing.unitsAvailable -= units;
    require(listing.token.transferFrom(listing.seller, msg.sender, units));

    uint256 cost = (units * listing.priceNumerator) /
        listing.priceDenominator;
    require(msg.value == cost);
    listing.seller.transfer(cost);

    emit ListingChanged(listing.seller, index);
}
The code does three things:

The code checks that the tokens requested are available, updates the amount available, and transfers the tokens to the buyer.
The code computes the total cost of the transaction, checks that the buyer attached that amount of ether, and transfers the ether to the seller.
The code logs an event, which can alert the seller or a DApp to the purchase.
The statement, Listing storage listing = listings[index], exploits the fact that storage variables are references to persistent storage. This means that any changes to the fields of listing will actually be to the underlying listings[index] struct.

Note that while the marketplace contract never explicitly checked that the seller had approved the transfer, the buy transaction will fail if the transferFrom does not succeed.

Cancelling a Listing
A seller may cancel a listing at any time. Cancellation will simply delete—zero out—the fields of the listing struct.

function cancel(uint256 index) public {
    require(listings[index].seller == msg.sender);
    delete(listings[index]);
    emit ListingChanged(msg.sender, index);
}
Summary
The ERC20 token standard enables a marketplace contract to broker sales of many different tokens on behalf of many different sellers.
Solidity supports structs for grouping related values.
Solidity supports dynamically-sized arrays for 0-indexed lists of values.
To compensate for the Ethereum Virtual Machine’s lack of support for floating point numbers, a contract can use rational numbers with explicit numerators and denominators.
The Complete Contracts
The complete code for the TokenMarket contract is below. I’ve used Solidity’s import directive to indicate that the code for IERC20Token interface will be loaded from a separate file.

ierc20token.sol
pragma solidity ^0.4.21;

interface IERC20Token {
    function totalSupply() external constant returns (uint);
    function balanceOf(address tokenlender) external constant returns (uint balance);
    function allowance(address tokenlender, address spender) external constant returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenlender, address indexed spender, uint tokens);
}
tokenmarket.sol
pragma solidity ^0.4.21;

import "./ierc20token.sol";

contract TokenMarket {
    struct Listing {
        address seller;
        IERC20Token token;
        uint256 unitsAvailable;

        // wei/unit price as a rational number
        uint256 priceNumerator;
        uint256 priceDenominator;
    }

    Listing[] public listings;

    event ListingChanged(address indexed seller, uint256 indexed index);

    function list(
        IERC20Token token,
        uint256 units,
        uint256 numerator,
        uint256 denominator
    ) public {
        Listing memory listing = Listing({
            seller: msg.sender,
            token: token,
            unitsAvailable: units,
            priceNumerator: numerator,
            priceDenominator: denominator
        });

        listings.push(listing);
        emit ListingChanged(msg.sender, listings.length-1);
    }

    function cancel(uint256 index) public {
        require(listings[index].seller == msg.sender);
        delete(listings[index]);
        emit ListingChanged(msg.sender, index);
    }

    function buy(uint256 index, uint256 units) public payable {
        Listing storage listing = listings[index];

        require(listing.unitsAvailable >= units);
        listing.unitsAvailable -= units;
        require(listing.token.transferFrom(listing.seller, msg.sender, units));

        uint256 cost = (units * listing.priceNumerator) /
            listing.priceDenominator;
        require(msg.value == cost);
        listing.seller.transfer(cost);

        emit ListingChanged(listing.seller, index);
    }
}
← Writing a Simple Payment ChannelBuilding Long-Lived Payment Channels →
  