Program the Blockchain	Archive About Subscribe
Implementing Harberger Tax Deeds
SEPTEMBER 19, 2018 BY TODD PROEBSTING
This post will demonstrate how to implement deeds that collect a “Harberger tax”. The recently published book, Radical Markets: Uprooting Capitalism and Democracy for a Just Society, proposed Harberger taxes for a number of applications. Since then Vitalik Buterin (here) and Simon de la Rouviere (here) have speculated on smart contract applicability.

A Harberger tax is a property tax that depends on an owner-determined, enforceable sales price. For instance, suppose that there is a 5%/year Harberger tax on real estate, and Alice owns a parcel subject to this tax. A Harberger tax regime requires Alice to state a price at which she is obligated to sell her parcel. As a consequence, Alice will owe 5% of that sales price every year as a property tax, and her parcel will be for sale at her stated price.

Obviously, Alice faces a tradeoff: higher prices create higher taxes but with less uncertainty about a future sale while lower prices create lower taxes with greater uncertainty about a future sale. This tension provides incentives for Alice to set her taxes (by setting her sales price) reasonably.

Deed Tokens
ERC20 token contracts create a supply of many fungible tokens—tokens are indistinguishable from each other. “Deed” tokens represent non-fungible tokens—each token represents some right or privilege different from those of other deed tokens. A popular example of deed tokens are the tokens that represent “CryptoKitties”.

ERC721 defines a standard for non-fungible tokens, but this post will not implement to that standard. Not only are Harberger-taxed deed tokens not a good fit for ERC721, but ERC721 presents lots of details that will distract from the essence of this post (i.e., how to implement Harberger taxes correctly and efficiently).

Our contract will track the account that receives tax payments, and the tax rate. This contract has a daily tax rate given as a rational number.

pragma solidity ^0.4.24;

contract HarbergerTax {
    address public taxRecipient;

    // Per day tax rate
    uint32 public taxNumerator;
    uint32 public taxDenominator;

    // more to come...
}
The contract tracks who owns each token, and the sales price the owner has set for that token. Tokens are identified by integers, which are indexes into the tokens array below.

struct Token {
    address owner;
    uint96 price;
}

Token[] public tokens;

constructor(
    uint48 numberOfTokens,
    uint32 _taxNumerator,
    uint32 _taxDenominator
) public {
    taxRecipient = msg.sender;
    tokens.length = numberOfTokens;
    taxNumerator = _taxNumerator;
    taxDenominator = _taxDenominator;
}
Accounting for Harberger Taxes
Harberger taxes are conceptually simple: taxes are proportional to the selling price and the duration that the deed is held. The contract will collect taxes on demand from prepaid balances maintained by deed holders.

This contract will maintain per-account ether balances from which taxes will be collected for all deeds owned by each account. This per-account balance design is in contrast to having per-deed balances. Because a single account may potentially own many deeds, a per-account balance is simpler for deed owners to manage because they only need to deposit into one balance rather than one balance per deed.

To collect taxes from an account, the contract must know the total of the sales prices of all deeds owned by each account and the time the taxes were paid through for that account.

struct Account {
    uint256 balance;
    uint144 sumOfPrices;
    uint112 paidThru;
}

mapping(address => Account) public accounts;
The taxes due will be proportional to that total and the time that’s passed. The contract also tracks each contract’s ether balance.

function taxesDue(address addr) public view returns (uint256) {
    Account storage a = accounts[addr];

    return a.sumOfPrices * (now - a.paidThru) * taxNumerator
        / taxDenominator / 1 days;
}
Because the Ethereum VM does not check for overflows, a smart contract must guard against them. Because sumOfPrices is a uint144, taxRateNumerator is a uint32, and now is the number of seconds since a recent time, there’s no chance the multiplication above will overflow when computing a uint256.

Maintaining an Ether Balance
Taxes are collected in arrears, which means that they are collected for time that has passed since the last collection. If adequate ether is not available when taxes are collected for an account, all that account’s tokens are at risk of being immediately foreclosed. A simple function enables direct deposits.

function deposit() public payable {
    accounts[msg.sender].balance += msg.value;
}
In addition, most functions are payable, which enables simultaneous deposits.

Foreclosure
When an account has no ether balance and is behind on taxes, the contract can foreclose on its tokens. Foreclosure reverts ownership to address(0) and sets the price to zero.

event Change(uint256 indexed id, address indexed to, address indexed from);

// Possibly foreclose on token[id]
function forecloseIfPossible(uint256 id) public {
    Token storage t = tokens[id];
    Account storage a = accounts[t.owner];

    // Owner must be broke and behind on taxes to foreclose
    if (a.balance == 0 && a.paidThru < now && a.sumOfPrices > 0) {
        a.sumOfPrices -= t.price;
        emit Change(id, 0, t.owner);
        delete(tokens[id]);
    }
}
Collecting Taxes
Collecting taxes from an account with an adequate ether balance is straightforward. The ether is transferred to the taxRecipient, and the timestamp (paidThru) is updated.

// Collect taxes due from account.
// Return true if taxes fully paid, false otherwise
function collectTaxes(address addr) public returns (bool) {
    Account storage a = accounts[addr];

    uint256 taxes = taxesDue(addr);
    if (taxes <= a.balance) {
        a.paidThru = uint112(now);
        accounts[taxRecipient].balance += taxes;
        a.balance -= taxes;
        return true;
    } else {
        ... // see below
    }
}
When there’s an inadequate balance, the contract collects the entire balance and adjusts the paidThru timestamp proportionally. For instance, if the account owes three days of taxes, but the balance only covers two days worth, then the timestamp is adjusted forward by two days.

// Collect taxes due from account.
// Return true if taxes fully paid, false otherwise
function collectTaxes(address addr) public returns (bool) {
    Account storage a = accounts[addr];

    uint256 taxes = taxesDue(addr);
    if (taxes <= a.balance) {
        ... // see above
    } else {
        // Adjust paidThru proportionally (overflow check unnecessary)
        a.paidThru += uint112((now - a.paidThru) * a.balance / taxes);

        // Collect entire balance for partially-paid taxes
        accounts[taxRecipient].balance += a.balance;
        a.balance = 0;
        return false;
    }
}
The routine also returns a bool value that is true if and only if the taxes were collected in full.

Buying a Token
Buying tokens is parameterized by the token to be bought, the maximum price the sender is willing to pay, and the sales price the buyer will accept in the future for the token.

Before executing the sale, the contract first collects any taxes due from the seller and the buyer. If the seller’s balance was insufficient to cover the seller’s taxes, then it is possible to foreclose on this token, which would make its price zero for the buyer.

function buy(
    uint256 id,
    uint256 max,
    uint96 price
)
    public
    payable
{
    accounts[msg.sender].balance += msg.value;

    Token storage t = tokens[id];

    // Collect taxes from token's owner and possibly foreclose on token[id].
    collectTaxes(t.owner);

    // Foreclosure may change price and seller.
    forecloseIfPossible(id);
    address seller = t.owner;

    if (seller != msg.sender) {
        require(max >= t.price, "price is too high");

        // Collect taxes due from buyer before checking their balance
        collectTaxes(msg.sender);
        require(accounts[msg.sender].balance >= t.price,
            "insufficient funds");

        // Transfer purchase price
        accounts[seller].balance += t.price;
        accounts[msg.sender].balance -= t.price;

        t.owner = msg.sender;
    }
    // Adjust buyer's and seller's sumOfPrices
    accounts[seller].sumOfPrices -= t.price;
    accounts[msg.sender].sumOfPrices += price;

    t.price = price;

    emit Change(id, msg.sender, seller);
}
Notes on the code above:

The maximum price is specified to guard against a buyer inadvertently buying a token whose price has increased between the time the buyer learned the (old) price and the time the transaction is actually accepted.
Buying a property requires adjusting the buyer’s and the seller’s sumOfPrices.
Changing the Price
A token owner may want to change the token’s price, which will have the effect of changing future taxes. The owner can do this by simply buying the token (from their self) while specifying the new price.

Withdrawing Ether
Accounts can withdraw ether, but only after paying any past taxes.

function withdraw(uint256 amount) public {
    collectTaxes(msg.sender);

    require(accounts[msg.sender].balance >= amount, "insufficient funds");

    accounts[msg.sender].balance -= amount;
    msg.sender.transfer(amount);
}
Changing the Tax Recipient
This contract adopts the approve/transfer pattern for changing the tax recipient. The current recipient designates the new recipient, and the new recipient transfers the role to itself.

address public newRecipient;

function approveRecipient(address _newRecipient) public {
    require(msg.sender == taxRecipient, "must be taxRecipient");
    newRecipient = _newRecipient;
}

function transferRecipient() public {
    require(msg.sender == newRecipient, "must be approved");
    taxRecipient = msg.sender;
    newRecipient = 0;
}
The current recipient can change approvals prior to a transfer with a subsequent call to approveRecipient.

Summary
Deed tokens represent non-fungible rights/privileges.
Harberger-taxed tokens can be implemented simply with a smart contract, which manages tax collection and token sales.
This implementation relies on per-account bookkeeping to compute and collect taxes.
The Complete Contract
harberger.sol
pragma solidity ^0.4.24;

contract HarbergerTax {
    address public taxRecipient;

    // Per day tax rate
    uint32 public taxNumerator;
    uint32 public taxDenominator;

    struct Token {
        address owner;
        uint96 price;
    }

    Token[] public tokens;

    constructor(
        uint48 numberOfTokens,
        uint32 _taxNumerator,
        uint32 _taxDenominator
    ) public {
        taxRecipient = msg.sender;
        tokens.length = numberOfTokens;
        taxNumerator = _taxNumerator;
        taxDenominator = _taxDenominator;
    }

    struct Account {
        uint256 balance;
        uint144 sumOfPrices;
        uint112 paidThru;
    }

    mapping(address => Account) public accounts;

    function taxesDue(address addr) public view returns (uint256) {
        Account storage a = accounts[addr];

        return a.sumOfPrices * (now - a.paidThru) * taxNumerator
            / taxDenominator / 1 days;
    }

    event Change(uint256 indexed id, address indexed to, address indexed from);

    // Possibly foreclose on token[id]
    function forecloseIfPossible(uint256 id) public {
        Token storage t = tokens[id];
        Account storage a = accounts[t.owner];

        // Owner must be broke and behind on taxes to foreclose
        if (a.balance == 0 && a.paidThru < now && a.sumOfPrices > 0) {
            a.sumOfPrices -= t.price;
            emit Change(id, 0, t.owner);
            delete(tokens[id]);
        }
    }

    // Collect taxes due from account.
    // Return true if taxes fully paid, false otherwise
    function collectTaxes(address addr) public returns (bool) {
        Account storage a = accounts[addr];

        uint256 taxes = taxesDue(addr);
        if (taxes <= a.balance) {
            a.paidThru = uint112(now);
            accounts[taxRecipient].balance += taxes;
            a.balance -= taxes;
            return true;
        } else {
            // Adjust paidThru proportionally (overflow check unnecessary)
            a.paidThru += uint112((now - a.paidThru) * a.balance / taxes);

            // Collect entire balance for partially-paid taxes
            accounts[taxRecipient].balance += a.balance;
            a.balance = 0;
            return false;
        }
    }

    // Try to buy token for no more than 'max'
    function buy(
        uint256 id,
        uint256 max,
        uint96 price
    )
        public
        payable
    {
        accounts[msg.sender].balance += msg.value;

        Token storage t = tokens[id];

        // Collect taxes from token's owner and possibly foreclose on token[id].
        collectTaxes(t.owner);

        // Foreclosure may change price and seller.
        forecloseIfPossible(id);
        address seller = t.owner;

        if (seller != msg.sender) {
            require(max >= t.price, "price is too high");

            // Collect taxes due from buyer before checking their balance
            collectTaxes(msg.sender);
            require(accounts[msg.sender].balance >= t.price,
                "insufficient funds");

            // Transfer purchase price
            accounts[seller].balance += t.price;
            accounts[msg.sender].balance -= t.price;

            t.owner = msg.sender;
        }
        // Adjust buyer's and seller's sumOfPrices
        accounts[seller].sumOfPrices -= t.price;
        accounts[msg.sender].sumOfPrices += price;

        t.price = price;

        emit Change(id, msg.sender, seller);
    }

    function deposit() public payable {
        accounts[msg.sender].balance += msg.value;
    }

    function withdraw(uint256 amount) public {
        collectTaxes(msg.sender);

        require(accounts[msg.sender].balance >= amount, "insufficient funds");

        accounts[msg.sender].balance -= amount;
        msg.sender.transfer(amount);
    }

    function tokenCount() public view returns (uint256) {
        return tokens.length;
    }

    address public newRecipient;

    function approveRecipient(address _newRecipient) public {
        require(msg.sender == taxRecipient, "must be taxRecipient");
        newRecipient = _newRecipient;
    }

    function transferRecipient() public {
        require(msg.sender == newRecipient, "must be approved");
        taxRecipient = msg.sender;
        newRecipient = 0;
    }
}
← Writing a Dollar Auction ContractIntroduction to Ethereum Payment Channels Video →
  