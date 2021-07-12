Program the Blockchain	Archive About Subscribe
Storage Patterns: Doubly Linked List
MARCH 30, 2018 BY STEVE MARX
In this post, I’ll build a doubly linked list in Solidity. A doubly linked list supports efficient insertion and deletion of nodes anywhere within an ordered list. I’ll be building on concepts introduced in “Understanding Ethereum Smart Contract Storage” and “Storage Patterns: Stacks, Queues, and Deques”.

The Nodes
In addition to the data being stored, each node in a doubly linked list has pointers to the previous and next node in the list:

contract DoublyLinkedList {
    struct Node {
        bytes data;
        uint256 prev;
        uint256 next;
    }
Note that the prev and next fields are of type uint256. There are no pointer types in Solidity, so each node in the list is given a unique ID, and the prev and next fields refer to those IDs. I’m using a dynamically-sized array to keep track of nodes, and a node’s index in the array is its ID:

// nodes[0].next is head, and nodes[0].prev is tail.
Node[] public nodes;

function DoublyLinkedList() public {
    // sentinel
    nodes.push(Node(new bytes(0), 0, 0));
}
The first element of the array is reserved as a sentinel. Its next link points to the head of the list, and its prev link points to the tail. Technically, what I’m building here is a circular doubly linked list where one element is a sentinel. If you were to keep following next or prev links, you would pass through the sentinel and back to the other end of the list.

Inserting a Node
A doubly-linked list supports insertion at arbitrary points within the list. When inserting into the list, a new node needs to be created, and the prev and next links in the neighboring nodes need to be updated:

function insertAfter(uint256 id, bytes data) public returns (uint256 newID) {
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
A brief explanation of the above code:

Node storage node declares a reference to a Node in storage. This is used here to make reading and writing that node’s fields easier.
nodes.push is essentially an allocation. It adds a new node to the array and initializes its fields.
nodes.length - 1 is the index in the array where the new node was added. This is considered the node’s ID.
Finally, the prev and next links in the neighboring nodes are updated to point to the new node.
isValidNode checks if the node specified by the id parameter is a valid node in the list:

function isValidNode(uint256 id) internal view returns (bool) {
    // 0 is a sentinel and therefore invalid.
    // A valid node is the head or has a previous node.
    return id != 0 && (id == nodes[0].next || nodes[id].prev != 0);
}
Given insertAfter, it’s trivial to implement insertBefore:

function insertBefore(uint256 id, bytes data) public returns (uint256 newID) {
    return insertAfter(nodes[id].prev, data);
}
Note that because this is a circular linked list, no special care needs to be taken with the head and tail of the list. To insert a node at the beginning of the list, call insertAfter(0, data). To insert a node at the end of the list, call insertBefore(0, data).

Removing a Node
Removing a node means updating its neighbors’ prev and next links and deleting the removed node to reclaim its storage:

function remove(uint256 id) public {
    require(isValidNode(id));

    Node storage node = nodes[id];

    nodes[node.next].prev = node.prev;
    nodes[node.prev].next = node.next;

    delete nodes[id];
}
Executing delete nodes[id] results in a gas refund for reclaiming storage space. Recall from our post “Understanding Ethereum Smart Contract Storage” that zeros are not actually stored, so deleting the node reclaims storage even though the underlying array length is not changed.

Summary
A doubly linked list is a useful data structure when arbitrary insertion or deletion is required and order is important.
Using a circular doubly linked list avoids edge cases when inserting or deleting nodes at the ends of the list.
Full Code
doublylinkedlist.sol
pragma solidity ^0.4.21;

contract DoublyLinkedList {
    struct Node {
        bytes data;
        uint256 prev;
        uint256 next;
    }

    // nodes[0].next is head, and nodes[0].prev is tail.
    Node[] public nodes;

    function DoublyLinkedList() public {
        // sentinel
        nodes.push(Node(new bytes(0), 0, 0));
    }

    function insertAfter(uint256 id, bytes data) public returns (uint256 newID) {
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

    function insertBefore(uint256 id, bytes data) public returns (uint256 newID) {
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
}
← Writing a Sealed-Bid Auction ContractWriting a Vickrey Auction Contract →
  