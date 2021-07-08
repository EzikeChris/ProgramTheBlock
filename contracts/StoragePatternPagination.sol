Program the Blockchain
Archive About Subscribe
Storage Patterns: Pagination
APRIL 20, 2018 BY STEVE MARX
This post will show how to support pagination for returning large data sets from a smart contract. It builds on concepts introduced in my post on doubly-linked lists.

When to Paginate
When large amounts of data are involved, it may not be possible for a smart contract to return an entire data set at once. Pagination is a way for a caller to make multiple smaller requests to retrieve the data. Some callers may not need the entire data set, in which case it’s useful to be able to retrieve a subset.

There are two potential limits to how much data a smart contract can return at once: gas limits and execution time. For a function call that’s part of a transaction (e.g. from another smart contract), gas is often a limiting factor. Each byte of data returned from the call consumes gas, as does iterating through the data set. Even if the caller is willing to supply a huge amount of gas, there is a block gas limit, which is the maximum amount of gas a single block can consume. If a transaction exceeds this limit, it can never be mined into a block.

For view functions being called from outside the EVM (e.g. from JavaScript in a web app), gas is not a limiting factor because there is no transaction being executed. The node processing the call does the computation locally and returns the result. Each node gets to set its own processing limits—typically limiting execution time. If the call takes too long, it will fail.

When a data set may be large enough to approach either of these limits, use pagination.

Using Cursors
There are many valid API designs for pagination, but using a cursor is probably the most flexible. When a client requests a page of data, the server—in this case a smart contract—returns the requested data as well as a cursor. The cursor is an opaque value that the client needs to pass in its next request. This opaque value specifies where enumeration should continue.

Paging Through an Array
The following code supports appending to an array and enumerating that array using a very simple cursor: the index of the first item being requested.

arraypagination.sol
pragma solidity ^0.4.22;

contract ArrayPagination {
    bytes32[] arr;

    function add(bytes32 data) public {
        arr.push(data);
    }

    function fetchPage(uint256 cursor, uint256 howMany)
    public
    view
    returns (bytes32[] values, uint256 newCursor)
    {
        uint256 length = howMany;
        if (length > arr.length - cursor) {
            length = arr.length - cursor;
        }

        values = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            values[i] = arr[cursor + i];
        }

        return (values, cursor + length);
    }
}
Here’s a brief explanation of the fetchPage function:

howMany indicates how many items should be returned. If there aren’t enough remaining items in the array, the function will return fewer items.
cursor is the aforementioned cursor. It simply indicates the starting index for enumeration. The first call should pass 0, and subsequent calls should pass the returned newCursor.
If cursor is outside the bounds of the array, the array access will throw an error.
In the array example, the cursor is just an index into the array. The client could ignore the returned newCursor and simply calculate the right cursor by counting how many items it had already received. In the next section, I’ll show an example where this is not the case, and the cursor truly needs to be returned from the smart contract.

Paging Through a Linked List
In a linked list, each node stores a link to the next node in the list. There is no way to jump straight to the nth item in the list. In my post about doubly-linked lists in Solidity, I built a doubly-linked list where nodes are stored in an array, and the node’s index in the array is its unique identifier. This means it’s possible to directly access a node by ID.

A node’s ID a good candidate for a cursor. When a page is requested, the returned cursor will be the ID of the next node in the list (the first node the client has not yet seen).

The following code is adapted from the doubly-linked list post but with one small change. Instead of using bytes as the payload type, I’ve used bytes32.1 The last function, fetchPage, is new:

doublylinkedlistpagination.sol
pragma solidity ^0.4.22;

contract DoublyLinkedListPagination {
    struct Node {
        bytes32 data;
        uint256 prev;
        uint256 next;
    }

    // nodes[0].next is head, and nodes[0].prev is tail.
    Node[] public nodes;

    constructor () public {
        // sentinel
        nodes.push(Node(bytes32(0), 0, 0));
    }

    function insertAfter(uint256 id, bytes32 data)
    public
    returns (uint256 newID)
    {
        // 0 is allowed here to insert at the beginning.
        require(id == 0 || isValidNode(id));

        Node storage node = nodes[id];

        nodes.push(Node({
            data: data,
            prev: id,
            next: node.next
        }));

        newID = nodes.length - 1;

        nodes[node.next].prev = newID;
        node.next = newID;
    }

    function insertBefore(uint256 id, bytes32 data)
    public
    returns (uint256 newID)
    {
        return insertAfter(nodes[id].prev, data);
    }

    function remove(uint256 id) public {
        require(isValidNode(id));

        Node storage node = nodes[id];

        nodes[node.next].prev = node.prev;
        nodes[node.prev].next = node.next;

        delete nodes[id];
    }

    function isValidNode(uint256 id) internal view returns (bool) {
        // 0 is a sentinel and therefore invalid.
        // A valid node is the head or has a previous node.
        return id != 0 && (id == nodes[0].next || nodes[id].prev != 0);
    }

    function fetchPage(uint256 cursor, uint256 howMany)
    public
    view
    returns (bytes32[] values, uint256 length, uint256 newCursor)
    {
        require(cursor == 0 || isValidNode(cursor));

        uint256 currentIndex = cursor;
        if (currentIndex == 0) {
            // cursor == 0 means the start of the list
            currentIndex = nodes[0].next;
        }

        // The returned array will always have howMany items, but they may not
        // all be valid if more items were requested than are remaining in the
        // list. The length return value specifies how much of the returned
        // array is valid.
        values = new bytes32[](howMany);

        uint256 i = 0;
        while (i < howMany && currentIndex != 0) {
            Node storage node = nodes[currentIndex];

            values[i] = node.data;
            currentIndex = node.next;
            i += 1;
        }

        length = i;
        newCursor = currentIndex;

        return (values, length, newCursor);
    }
}
Here’s a brief explanation of the fetchPage function:

Like in the array example, fetchPage accepts parameters cursor and howMany.
A cursor of 0 indicates that the client wants to start at the beginning of the list. That means starting at nodes[0].next, which is the head of the doubly-linked list.
Arrays kept in memory cannot be resized, so it’s necessary to declare their length up front. Before enumeration, it’s impossible to know the correct length, so an array of size howMany is returned along with an extra return value length that indicates how much of the array is valid data.
The newCursor return value is the index of the next node in the list. A client passes that to resume enumeration.
Getting a Consistent Snapshot
Pagination often has a downside when it comes to concurrency. It can be difficult for clients to deal with data changing during the course of enumeration. For example, in the linked list case, the node indicated by the cursor could be deleted, making the next call to fetchPage fail.

Ethereum provides a nice workaround for these issues. When calling a view function from client software, it’s possible to specify a block number to execute the call in the context of that block. By making each call with the same block number, a client can work with a consistent snapshot of the data.

Summary
Pagination is necessary when gas or execution time limits prevent a client from reading the entirety of a large data set at once.
Cursors are a flexible way to support pagination.
Clients should treat cursors as opaque.
A cursor should allow enumeration to be resumed efficiently.
To guarantee a consistent snapshot, clients should consider specifying the same block number for all calls while paging through data.
Solidity doesn’t (without an experimental new encoder) support returning dynamically-sized arrays of dynamically-sized arrays, making a return type of bytes[] impossible. ↩
← Keep Your Code SimpleWriting a Periodic Loan Contract →
  