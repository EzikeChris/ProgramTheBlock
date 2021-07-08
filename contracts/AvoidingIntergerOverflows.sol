Program the Blockchain
Archive About Subscribe
Avoiding Integer Overflows: SafeMath Isn't Enough
APRIL 27, 2018 BY STEVE MARX
This post describes what an integer overflow is and how to avoid them in smart contracts.

What is an Integer Overflow?
Fixed-size integers have a range of values they can represent. For example, an 8-bit unsigned integer can store values between 0 and 255 (28-1). When the result of some arithmetic falls outside that supported range, an integer overflow occurs. 1

On the Ethereum Virtual Machine (EVM), the consequence of an integer overflow is that the most significant bits of the result are lost. For example, when working with 8-bit unsigned integers, 255 + 1 = 0. This is easier to see in binary, where 1111 1111 + 0000 0001 should be 1 0000 0000, but because only 8 bits are available, the leftmost bit is lost, resulting in a value of 0000 0000.

Intuitively, the effect of an integer overflow can be thought of as the value “wrapping around.”

Examples of Integer Overflows
Solidity uses fixed-size integers of various sizes. In the examples below, I’ve used only 256-bit integers, the largest integer types Solidity supports. Integer overflow in the EVM can occur during addition, subtraction, multiplication, and exponentiation.

Unsigned Integer Overflows
256-bit unsigned integers can store a minimum value of 0 and a maximum value of 2256-1:

uint256 u;                    // range: [0, 2**256)

u = 2**256 - 1;
assert(u + 1 == 0);           // should be 2**256

u = 4;
assert(u - 5 == 2**256 - 1);  // should be -1

u = 2**255;
assert(u * 2 == 0);           // should be 2**256

u = 2**128;
assert(u**2 == 0);            // should be 2**256
Signed Integer Overflows
256-bit signed integers can store a minimum value of -2255 and a maximum value of 2255-1:

int256 s;                     // range: [-2**255, 2**255)

s = 2**255 - 1;
assert(s + 1 == -2**255);     // should be 2**255

s = -2**255;
assert(s - 1 == 2**255-1);    // should be -2**255-1

s = 2**254;
assert(s * 2 == -2**255);     // should be 2**255
Mitigating Integer Overflows
Unlike some computer architectures, the EVM provides no indication that an overflow has occurred. It’s up to you to write code that detects overflow conditions and handles them appropriately.

One approach to integer overflows is to perform the arithmetic, check the result, and revert the transaction if an overflow occurred. For example, here’s a safeAdd function:

function safeAdd(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    require(c >= a);
}
If an integer overflow occurred, then c will be less than a, and the require will revert the transaction.

This approach is taken by the widely-used SafeMath library from OpenZeppelin.

SafeMath Isn’t Enough
Using functions like those provided in the SafeMath library ensure that your contract doesn’t use the result of an integer overflow, but they might leave your contract unusable. Here’s a simple example:

using SafeMath for uint256;

uint256 price = 2 ether;
uint256 quantity = 2**200;

function purchase() public payable {
    require(msg.value < price.mul(quantity));
    // ...
}
Because 2 ether * 2200 overflows, the call to mul will always revert the transaction, so no purchase can be made.

We recently encountered this difficulty in our post about periodic loans. This code in calculateCollateral is roughly equivalent to SafeMath’s mul function:

uint256 product = collateralPerPayment * payment;
require(product / collateralPerPayment == payment, "payment causes overflow");
This is a good mitigation, but there’s still a problem. There’s a required minimum payment. If that payment causes an overflow, then there’s no way to pay off the loan. To avoid this situation, we added an overflow check to the constructor:

uint256 x = minimumPayment * collateralPerPayment;
require(x / collateralPerPayment == minimumPayment,
    "minimumPayment * collateralPerPayment overflows");
The result of the multiplication isn’t used. The check is purely there to ensure that the contract cannot be deployed with parameters that will render it unusable.

batchOverflow
Making its rounds this week is an integer overflow bug that has been dubbed “batchOverflow.” The following is a slight simplification of the erroneous code found in several ERC20 token contracts. This function allows a token holder to send tokens to multiple recipients:

// DO NOT USE!
function batchTransfer(address[] receivers, uint256 value) public {
    uint256 amount = receivers.length * value;
    require(balances[msg.sender] >= amount);

    balances[msg.sender] = balances[msg.sender].sub(amount);
    for (uint256 i = 0; i < receivers.length; i++) {
        balances[receivers[i]] = balances[receivers[i]].add(value);
    }
}
The require is meant to ensure the sender has a sufficient balance to cover the transfers, but note that amount is the product of two values controlled by the caller. If someone were to pass 2 addresses and a value of 2255, then amount would overflow to 0. The require would verify that the sender’s balance was at least 0, and the recipients’ token balances would be increased.

Note that the use of SafeMath’s sub to reduce the sender’s balance doesn’t help here because amount is 0, so that subtraction has no overflow.

Summary
Arithmetic using fixed-sized integers can cause overflows, resulting in mathematically incorrect results.
To abort overflows, use a library like SafeMath.
To avoid overflows altogether, do parameter validation up front.
Test Your Knowledge
Now that you understand integer overflows and how to spot them, test your knowledge in the Capture the Ether “math” category. More than one of those challenges requires exploiting an integer overflow.

Sometimes the term “integer underflow” is used when the result is specifically below the supported range. ↩
← Writing a Periodic Loan ContractWriting a Dominant Assurance Contract →
  