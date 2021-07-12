Program the Blockchain	Archive About Subscribe
Storage Patterns: Stacks Queues and Deques
MARCH 23, 2018 BY STEVE MARX
In this post, I’ll show how a few common data structures can be implemented in Solidity. I recommend first reading our post “Understanding Ethereum Smart Contract Storage.”

Stack
A stack is a “last-in, first-out” (LIFO) data structure with the operations push and pop. This is a natural fit for Solidity’s dynamically-sized arrays, but note that Solidity does not (yet) provide a pop operation. The below is an implementation of a stack of bytes:

stack.sol
pragma solidity ^0.4.21;

contract Stack {
    bytes[] stack;

    function push(bytes data) public {
        stack.push(data);
    }

    function pop() public returns (bytes data) {
        data = stack[stack.length - 1];

        stack.length -= 1;
    }
}
A few things to note in the above code:

If the array is empty, bounds checking will cause pop to revert the transaction.
Decreasing the length of a dynamically-sized array has a side effect of zeroing the “removed” items. This is why there’s no need for a delete stack[stack.length - 1].
Queue
A queue is a “first-in, first-out” (FIFO) data structure with the operations enqueue and dequeue. It’s reasonable to implement this with a dynamically-sized array, but a mapping may be a better choice:

queue.sol
pragma solidity ^0.4.21;

contract Queue {
    mapping(uint256 => bytes) queue;
    uint256 first = 1;
    uint256 last = 0;

    function enqueue(bytes data) public {
        last += 1;
        queue[last] = data;
    }

    function dequeue() public returns (bytes data) {
        require(last >= first);  // non-empty queue

        data = queue[first];

        delete queue[first];
        first += 1;
    }
}
A brief explanation of the above code:

Items are stored at consecutive indices in the queue mapping. The first used index will be 1.
first indicates the first valid index in the queue. It starts at 1 so I can use 0 for last.
last indicates the last valid index in the queue. It starts at 0 because there are initially no valid indices.
Unlike in the stack contract, where decreasing the array size took care of it, this contract needs to call delete to clear storage when an element is dequeued.
Dynamically-sized arrays and mappings in Solidity are not very different. They both map keys to values. Arrays are limited to uint256 keys, and they do bounds checking. Dynamically-sized arrays also record their length and perform some automated cleanup when that length is adjusted.

In the stack implementation, I made use of the bounds checking and automatic cleanup. In the case of a queue, both of those things need to be done manually, at least on the “left” side of the queue. For that reason, a mapping seemed like a more natural fit to me.

Deque
A deque (sometimes “dequeue” or “double-ended queue”) is a generalization of a queue that allows insertion and deletion from both ends. It supports the operations pushLeft, pushRight, popLeft, and popRight:

deque.sol
pragma solidity ^0.4.21;

contract Deque {
    mapping(uint256 => bytes) deque;
    uint256 first = 2**255;
    uint256 last = first - 1;

    function pushLeft(bytes data) public {
        first -= 1;
        deque[first] = data;
    }

    function pushRight(bytes data) public {
        last += 1;
        deque[last] = data;
    }

    function popLeft() public returns (bytes data) {
        require(last >= first);  // non-empty deque

        data = deque[first];

        delete deque[first];
        first += 1;
    }

    function popRight() public returns (bytes data) {
        require(last >= first);  // non-empty deque

        data = deque[last];

        delete deque[last];
        last -= 1;
    }
}
This code is much like the queue implementation except that the queue can grow in both directions. To maximize how much room is available to grow, first is initialized to 2255, exactly half way through the 256-bit space available for indices.

Summary
With a basic understanding of Solidity storage, simple data structures can be implemented with very little code.
Dynamically-sized arrays and mappings are quite similar. In many cases, either can be used, and the decision comes down to what makes the code easier to read.
Further Reading
The Hidden Costs of Arrays compares Solidity arrays and mappings.
← Writing a Token Auction ContractWriting a Sealed-Bid Auction Contract →
  