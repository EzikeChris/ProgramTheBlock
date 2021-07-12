Program the Blockchain	Archive About Subscribe
Building Long-Lived Payment Channels
MARCH 2, 2018 BY STEVE MARX
[EDIT 2018-12-10] Since publishing this post, We’ve added a related video explanation of payment channels.

[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

In Writing a Simple Payment Channel, I introduced payment channels as a way to reduce the number of Ethereum transactions required for repeated payments between the same two parties. This post will improve upon that post’s SimplePaymentChannel contract to make it suitable for long-lived payment channels, such as might be used to pay an employee an hourly wage over the course of their career.

Introduction
The SimplePaymentChannel from Writing a Simple Payment Channel works well for payments made over a short period of time, but it has three limitations in the context of long-lived channels:

The sender must escrow all ether up front.
The recipient can make only a single withdrawal.
The timing of the channel closure is fixed when the channel is created.
I’ll make three changes to the SimplePaymentChannel contract to address these shortcomings:

Allow the sender to escrow a minimal amount of ether up front and add more funds as needed.
Allow the recipient to withdraw ether as needed before closing the channel.
Allow the sender to initiate channel closure so they can recover unspent funds in a reasonable timeframe.
Minimizing the Escrowed Funds
Payment channels hold escrowed funds to guarantee that a valid, signed payment message will be honored. Recipients will accept a message saying “I owe you a total of n ether,” if and only if the channel contract has escrowed n ether.

Because it’s trivial to check the channel’s current balance, it’s reasonable to allow multiple deposits to the channel:

function deposit() public payable { }
With this addition, the sender no longer needs to escrow all funds up front. However, each deposit requires an Ethereum transaction—and thus a transaction fee—so the sender must make a tradeoff between smaller, more frequent deposits and larger, less frequent ones.

Allowing Early Withdrawals
In the SimplePaymentChannel, the recipient can only make a single withdrawal, which closes the channel. A little bookkeeping enables multiple withdrawals without closing the channel. Recall that a withdrawal is done by presenting a signed IOU from the sender to the channel contract:

uint256 public withdrawn;  // How much the recipient has already withdrawn.

function withdraw(uint256 amountAuthorized, bytes signature) public {
    require(msg.sender == recipient);

    require(isValidSignature(amountAuthorized, signature));

    // Make sure there's something to withdraw (guards against underflow)
    require(amountAuthorized > withdrawn);
    uint256 amountToWithdraw = amountAuthorized - withdrawn;

    withdrawn += amountToWithdraw;
    msg.sender.transfer(amountToWithdraw);
}
A brief explanation of the above code:

The withdrawn state variable tracks how much ether the recipient has already withdrawn.
The recipient withdraws the total amount that’s been authorized so far minus the amount already withdrawn.
Finally, I need to make a small change to the close function to take into account the amount already withdrawn:

function close(uint256 amount, bytes signature) public {
    require(msg.sender == recipient);
    require(isValidSignature(amount, signature));

    // Guard against underflow.
    require(amount >= withdrawn);
    recipient.transfer(amount - withdrawn);

    selfdestruct(sender);
}
As in the previous section, this new ability introduces a tradeoff. The recipient can now access funds early by using the withdraw function, but each withdrawal requires an Ethereum transaction.

Allowing the Sender to Close the Channel
The SimplePaymentChannel introduced in Writing a Simple Payment Channel has an expiration time built in, and only the recipient can close the channel earlier than that. This is a problem for long-lived payment channels because it means the sender has no way to recover escrowed, unspent funds without the recipient’s cooperation.

To support long-lived payment channels, I’ll allow the sender to initiate channel closure. The recipient will then have some time to claim any funds they’re owed, after which the sender can access whatever’s left. With this new mechanism, there’s no need to have a fixed expiration at all.

// How much time the recipient has to respond when the sender initiates
// channel closure.
uint256 public closeDuration;

// When the payment channel closes. Initially effectively infinite.
uint256 public expiration = 2**256-1;

function LongLivedPaymentChannel(address _recipient, uint256 _closeDuration)
    public
    payable
{
    sender = msg.sender;
    recipient = _recipient;
    closeDuration = _closeDuration;
}
The preceding code sets up the state variables that are used for sender-initiated channel closure:

The closeDuration specifies, in seconds, how long the recipient will have to claim their funds after the sender initiates a close. It is set in the contract’s constructor.
The expiration is when the sender is allowed to close the channel. Initially, there’s effectively no expiration.
To initiate channel closure, the sender calls startSenderClose:

event StartSenderClose();

function startSenderClose() public {
    require(msg.sender == sender);
    emit StartSenderClose();
    expiration = now + closeDuration;
}
Here’s a brief explanation of the above code:

The expiration is set to closeDuration seconds in the future.
The recipient can watch for the StartSenderClose event so they know when it’s time to collect what they’re owed by closing the channel.
If the timeout is reached before the recipient closes the channel, the sender can close it and claim all remaining funds:

// If the timeout is reached without the recipient closing the channel, then
// the ether is released back to the sender.
function claimTimeout() public {
    require(now >= expiration);
    selfdestruct(sender);
}
Summary
For long-lived payment channels, it’s desirable to maximize availability of funds for both the sender and the recipient.
At any given time, the sender only needs to have enough funds escrowed to cover the amount already committed to the recipient.
At any given time, the recipient can withdraw up to the amount they’re owed.
Sender-initiated channel closure ensures that the sender can recover unpaid funds in a reasonable timeframe.
Full Source Code
longLivedPaymentChannel.sol
pragma solidity ^0.4.21;

contract LongLivedPaymentChannel {
    address public sender;      // The account sending payments.
    address public recipient;   // The account receiving the payments.
    uint256 public withdrawn;   // How much the recipient has already withdrawn.

    // How much time the recipient has to respond when the sender initiates
    // channel closure.
    uint256 public closeDuration;
    // When the payment channel closes. Initially effectively infinite.
    uint256 public expiration = 2**256-1;

    function LongLivedPaymentChannel(address _recipient, uint256 _closeDuration)
        public
        payable
    {
        sender = msg.sender;
        recipient = _recipient;
        closeDuration = _closeDuration;
    }

    function isValidSignature(uint256 amount, bytes signature)
        internal
        view
        returns (bool)
    {
        bytes32 message = prefixed(keccak256(this, amount));

        // Check that the signature is from the payment sender.
        return recoverSigner(message, signature) == sender;
    }

    // The recipient can close the channel at any time by presenting a signed
    // amount from the sender. The recipient will be sent that amount, and the
    // remainder will go back to the sender.
    function close(uint256 amount, bytes signature) public {
        require(msg.sender == recipient);
        require(isValidSignature(amount, signature));

        require(amount >= withdrawn);
        recipient.transfer(amount - withdrawn);

        selfdestruct(sender);
    }

    event StartSenderClose();

    function startSenderClose() public {
        require(msg.sender == sender);
        emit StartSenderClose();
        expiration = now + closeDuration;
    }

    // If the timeout is reached without the recipient closing the channel, then
    // the ether is released back to the sender.
    function claimTimeout() public {
        require(now >= expiration);
        selfdestruct(sender);
    }

    function deposit() public payable {
        require(msg.sender == sender);
    }

    function withdraw(uint256 amountAuthorized, bytes signature) public {
        require(msg.sender == recipient);

        require(isValidSignature(amountAuthorized, signature));

        // Make sure there's something to withdraw (guards against underflow)
        require(amountAuthorized > withdrawn);
        uint256 amountToWithdraw = amountAuthorized - withdrawn;

        withdrawn += amountToWithdraw;
        msg.sender.transfer(amountToWithdraw);
    }

    function splitSignature(bytes sig)
        internal
        pure
        returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverSigner(bytes32 message, bytes sig)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256("\x19Ethereum Signed Message:\n32", hash);
    }
}
← Writing a Token Market ContractWriting a Collateralized Loan Contract →
  