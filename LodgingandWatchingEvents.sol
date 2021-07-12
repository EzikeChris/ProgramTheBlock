Program the Blockchain	Archive About Subscribe
Logging and Watching Solidity Events
JANUARY 24, 2018 BY STEVE MARX
[EDIT 2018-03-13] This post has been updated to use Solidity 0.4.21 event syntax.

Events are a way for smart contracts written in Solidity to log that something has occurred. Interested observers, notably JavaScript front ends for decentralized apps, can watch for events and react accordingly. In this post, I’ll show you how to log events from a Solidity smart contract and watch those events in JavaScript. The code in this post builds on the example from the earlier post, Building Decentralized Apps With Ethereum and JavaScript.

Solidity Events
Events in Solidity are declared with the event keyword, and logging an event is done with the emit keyword. Events can be parameterized. The following code is adapted from the Counter example introduced in Writing a Very Simple Smart Contract:

counter-with-events.sol
pragma solidity ^0.4.21;

contract Counter {
    uint256 public count = 0;

    event Increment(address who);   // declaring event

    function increment() public {
        emit Increment(msg.sender); // logging event
        count += 1;
    }
}
The code above introduces the following techniques:

event Increment(address who) declares a contract-level event that takes a single parameter of type address which indicates what address performed the increment operation.
emit Increment(msg.sender) logs the previously declared event with msg.sender as its argument.
By convention, event names begin with uppercase letters. This distinguishes them from functions.

Listening to Events in JavaScript
The following JavaScript code listens for the Increment event and updates the UI accordingly. It is adapted from the code in Building Decentralized Apps With Ethereum and JavaScript:

counter = web3.eth.contract(abi).at(address);

counter.Increment(function (err, result) {
  if (err) {
    return error(err);
  }

  log("Count was incremented by address: " + result.args.who);
  getCount();
});

getCount();
Here’s a brief explanation of the above code:

contract.Increment(...) starts listening for the Increment event, and is parameterized with the callback function.
getCount() is a function that fetches the latest count and updates the UI.
You can see this function in action in the “Counter Example With Events” demo. Unlike in the original example, now the UI is automatically updated any time the counter is incremented. If you open the app in multiple windows or even on different devices, you will see that incrementing the counter in any instance of the app triggers an update in all of them.

Indexed Parameters
Up to three of an event’s parameters can be marked as indexed. An indexed parameter can be used to efficiently filter events. The following code enhances the previous example to track many counters, each identified by a numeric ID:

multicounter.sol
pragma solidity ^0.4.21;

contract Multicounter {
    mapping (uint256 => uint256) public counts;

    event Increment(uint256 indexed which, address who);

    function increment(uint256 which) public {
        emit Increment(which, msg.sender);
        counts[which] += 1;
    }
}
Here’s a brief explanation of the above code:

counts replaces the previous count with a mapping of IDs to counts.
event Increment(uint256 indexed which, address who) adds an indexed parameter which to indicate which counter was incremented.
emit Increment(which, msg.sender) logs the event with both arguments.
Filtering Events in JavaScript
The “Multicounter” demo uses the previous Solidity contract and allows the user to watch and manipulate any counter by entering a numeric counter ID. This may seem a bit contrived, but imagine a contract that implements many instances of a two-person game. The participants in the game would be interested only in events for their specific game, so a game ID could be used as an event filter.

The following code is invoked in the Multicounter demo when the user switches to a new counter ID. It filters for events with the new ID as the which parameter:

log("Switching to counter '" + counterId + "'.");

if (event !== null) {
  // Stop listening to events with the old ID.
  event.stopWatching();
}
event = counter.Increment({ which: counterId }, function (err, result) {
  if (err) {
    return error(err);
  }

  log("Counter " + result.args.which + " was incremented by address: "
      + result.args.who);
  getCount();
});

getCount();
Here’s a brief explanation of the above code:

The first parameter to Increment specifies a filter. Only events matching the filter will trigger the callback function. The simplest type of a filter is used here: a dictionary mapping parameter names to values.
event = counter.Increment(...) captures an event object. This can be used to stop and start listening to the event.
event.stopWatching() stops monitoring for events with the old counter ID.
Event Limitations
Events are built on top of a lower level log interface in Ethereum. Although you typically won’t deal with log messages directly, it’s important to understand their limitations.

Logs are structured as up to four “topics” and a “data” field. The first topic is used to store the hash of the event’s signature, which leaves only three topics for indexed parameters. Topics are required to be 32 bytes long, so if you use an array for an indexed parameter (including types string and bytes), the value will first be hashed to fit into 32 bytes. Non-indexed parameters are stored in the data field and do not have a size limit.

Logs, and therefore events, are not accessible from within the Ethereum virtual machine (EVM). This means that contracts cannot read their own logs or the logs of other contracts.

Summary
Solidity provides a way to log events during transactions.
Decentralized app (DApp) front ends can subscribe to these events.
indexed parameters provide an efficient means for filtering events.
Events are limited by the underlying log mechanism upon which they are built.
Resources
The Solidity documentation on events
The web3.js documentation on events
View the page source for the “Counter With Events” demo and the “Multicounter” demo
← Writing a Crowdfunding Contract (a la Kickstarter)What is an Ethereum Token? →
  