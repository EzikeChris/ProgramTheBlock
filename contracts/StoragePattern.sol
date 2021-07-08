Program the Blockchain
Archive About Subscribe
Storage Patterns: Set
JUNE 3, 2018 BY STEVE MARX
In this post, I’ll build a minimal enumerable set in Solidity. A set stores unordered values without repetition.

Set Functionality
The implementation in this post will support the following primitive set operations:

Add a value to the set.
Remove a value from the set.
Test whether the set contains a given value.
Enumerate all values in the set.
Many implementations additionally implement set-theoretical operations:

Find the union of two sets.
Find the intersection of two sets.
Find the difference between two sets.
I won’t write those higher level functions here, but note that they can be easily implemented using the primitive operations.

Combining Data Structures
A mapping from value types to booleans provides much of a set’s functionality. It efficiently supports adding and removing items as well as testing for membership. What it doesn’t support is enumeration.

An array works well for enumeration, but it doesn’t support efficiently finding an existing item.

To support all the primitive operations efficiently, I will combine the two data structures. In this example code, I’ve chosen bytes32 as the data type being stored in the set, but the pattern generalizes to any data type:

contract Set {
    bytes32[] public items;

    // 1-based indexing into the array. 0 represents non-existence.
    mapping(bytes32 => uint256) indexOf;
The items array is where the values are stored, in no particular order. This allows for efficient enumeration.

The indexOf mapping keeps track of which values are contained within the set and where they can be found in the items array.

In Solidity, mappings do not have a notion of existence. Every key maps to something, and the default value is 0. This is a bit of a problem, because 0 is also the first index into the items array. To resolve this ambiguity, indexOf will hold 1-based indexes:

If indexOf[value] == 0, then the value does not exist in the set.
If indexOf[value] == n, where n > 0, then items[n - 1] == value.
Adding Items
To add an item to the set, it must be appended to the items array, and it’s new (1-based) index must be stored in indexOf:

function add(bytes32 value) public {
    if (indexOf[value] == 0) {
        items.push(value);
        indexOf[value] = items.length;
    }
}
Recall that sets do not allow repeated elements. The if statement ensures that an item is not added multiple times.

Testing for Membership
The indexOf mapping makes it easy to efficiently test for set membership:

function contains(bytes32 value) public view returns (bool) {
    return indexOf[value] > 0;
}
Removing Items
Removing an item involves updating both the indexOf mapping and the items array. Updating the mapping is straightforward, but it’s less obvious how an item can be efficiently deleted from the middle of an array.

The key to implementing this operation efficiently is to recall that items in a set are unordered. Because we don’t need to preserve order, we can shuffle items around to make our lives easier. To remove the item from the array, we first swap it to the end of the array and then shrink the array:

function remove(bytes32 value) public {
    uint256 index = indexOf[value];

    require(index > 0);

    // move the last item into the index being vacated
    bytes32 lastValue = items[items.length - 1];
    items[index - 1] = lastValue;  // adjust for 1-based indexing
    indexOf[lastValue] = index;

    items.length -= 1;
    indexOf[value] = 0;
}
Enumeration
Because it’s a public state variable, the Solidity compiler generates a getter for the items array. A client can call items(n) to retrieve the nth item from the array.

To enumerate the entire list, the client also needs to know how many items there are. The count() function provides this:

function count() public view returns (uint256) {
    return items.length;
}
Summary
A set stores values, unordered and without repetition.
An enumerable set can be efficiently implemented with a mapping and an array.
Full Source Code
set.sol
pragma solidity ^0.4.24;

contract Set {
    bytes32[] public items;

    // 1-based indexing into the array. 0 represents non-existence.
    mapping(bytes32 => uint256) indexOf;

    function add(bytes32 value) public {
        if (indexOf[value] == 0) {
            items.push(value);
            indexOf[value] = items.length;
        }
    }

    function remove(bytes32 value) public {
        uint256 index = indexOf[value];

        require(index > 0);

        // move the last item into the index being vacated
        bytes32 lastValue = items[items.length - 1];
        items[index - 1] = lastValue;  // adjust for 1-based indexing
        indexOf[lastValue] = index;

        items.length -= 1;
        indexOf[value] = 0;
    }

    function contains(bytes32 value) public view returns (bool) {
        return indexOf[value] > 0;
    }

    function count() public view returns (uint256) {
        return items.length;
    }
}
← Escrowing ERC20 TokensSupporting Off-Chain Token Trading →
  