Program the Blockchain	Archive About Subscribe
Building Decentralized Apps With Ethereum and JavaScript
DECEMBER 13, 2017 BY STEVE MARX
For users to be able to interact with a smart contract, they need some sort of user interface. The standard means of providing this interface in Ethereum is called a “decentralized app.”

In this post, I’ll walk through the process of creating a simple decentralized app. Specifically, I’ll be building the Counter Example DApp. The code for the smart contract can be found in our post Writing a Very Simple Smart Contract. The decentralized app has two buttons, corresponding to the contract’s two functions: getCount and increment.

To follow along with this post, you’ll need to be familiar with the basics of smart contracts and building web apps with HTML and JavaScript.

What Is a Decentralized App?
In a traditional web application, a browser-based user interface talks to a server-side back end. This back end creates a point of centralization. The back end can only be trusted to the extent that its owner is trusted.

In Ethereum, a decentralized app (DApp or ÐApp) replaces that centralized back end with one or more smart contracts, which run in a distributed fashion on the blockchain. The browser-based user interface uses a JavaScript API called Web3 to interact with smart contracts.

Web3.js Installation
The web3.js documentation describes a few options for including the library in your project, depending on what tools you prefer. Feel free to use any of those mechanisms, but for the app we’re looking at in this post, I simply downloaded a copy of web3.min.js and included it via a script tag:

<script src="/path/to/web3.min.js"></script>
Connecting to a Node
To perform any actions that require the blockchain, a decentralized app needs to communicate with an Ethereum node. Web3 is the class the app will use to make API calls. To use it, the app needs to create an instance using a “provider.” An example of a provider is the HttpProvider, which lets the app connect directly to a node. You may run your own Ethereum node or use a public node like those provided by Infura, but the most common way users connect to an Ethereum node is via a browser extension called MetaMask.

MetaMask implements a Web3 provider that communicates with the browser extension, which in turn sends API calls to whatever node the user has chosen. (By default, this will be Infura.) It may seem counterintuitive to use an intermediary like MetaMask rather than communicating directly with a node, but MetaMask performs an important function: it keeps a user’s private key secure. Ethereum transactions need to be signed with an account’s private key, but allowing an app unfettered access to that private key would mean that a malicious app could drain a user’s account. Instead, MetaMask intercepts each operation that requires a signature, prompts the user to approve that operation, and then creates the signature using the user’s private key. This way, the user is in full control of how their private key is used.

MetaMask injects a global web3 variable, but newer versions of web3.js discourage use of this global variable directly because it makes it difficult to use more than one Web3 instance on the same page. Instead, the app can create a new Web3 instance itself using the global instance’s provider. The Counter Example DApp waits for jQuery’s ready event to make sure MetaMask has had a chance to inject web3:

$(function () {  // equivalent to $(document).ready(...)
  if (typeof(web3) === "undefined") {
    error("Unable to find web3. " +
          "Please run MetaMask (or something else that injects web3).");
  } else {
    log("Found injected web3.");
    web3 = new Web3(window.web3.currentProvider);
    ...
  }   
});
To use the Ropsten test network, you’ll need ether in an account there to pay for gas. Ether on a test network has no real monetary value because it’s extremely easy to mine. You can fund your Ropsten account for free via the MetaMask faucet.
After creating the Web3 instance, the app further tests to make sure the user is connected to the expected network. This is especially important for this app, because the backing smart contract is deployed on the Ropsten test network, not the main Ethereum network:

if (web3.version.network != 3) {
  error("Wrong network detected. Please switch to the Ropsten test network.");
} else {
  log("Connected to the Ropsten test network.");
}
Interacting With a Contract
To interact with a deployed smart contract, an app needs to have two things: the contract’s address and its interface (ABI). The address identifies where the contract can be found, and the ABI describes the available functions and events. We’ll explore the deployment process in a future post, but I’ve already deployed the Counter smart contract on the Ropsten test network and will simply use the address and ABI I obtained when I did that:

var address = "0xf15090c01bec877a122b567e5552504e5fd22b79";
var abi = [{"constant":true,"inputs":[],"name":"getCount", ...;

counter = web3.eth.contract(abi).at(address);
The return value of web3.eth.contract(...).at(...) is an object that has members corresponding to each of the functions in the provided ABI. How the app invokes those functions depends on whether or not they are view functions.

Calling View Functions
View functions (also known as constant functions) in a smart contract do not mutate state. Because of this, the result of calling a view function can be computed by any node and does not require sending a transaction to the blockchain. This makes view function calls fast and free (requiring no gas).

In our Counter contract, the getCount function retrieves the current count without mutating any state. It’s a view function, so the app can call it without performing a blockchain transaction using the .call function:

counter.getCount.call(function (err, result) {
  if (err) {
    return error(err);
  } else {
    log("getCount call executed successfully.");
  }

  // Use the function's return value
});
If you try the Counter Example DApp, you’ll note that clicking the “Get current count” button does not require further user interaction, because there’s no transaction for the user to approve.

Sending Transactions
As opposed to view functions, functions which mutate state require sending a transaction to the blockchain and waiting for confirmation. In the Counter contract, the increment function, as the name suggests, mutates the contract’s state by incrementing the count. Because it is not a view function, calling it requires sending a transaction to the blockchain and attaching gas via the .sendTransaction function. MetaMask will prompt the user to approve the transaction, including the attached gas and suggested gas price.

counter.increment.sendTransaction(function (err, hash) {
  if (err) {
    return error(err);
  }

  waitForReceipt(hash, function () {
    log("Transaction succeeded.");
  });
});
The callback receives a “transaction hash,” which can be used to wait for the transaction to be confirmed by the blockchain. This is accomplished via the following waitForReceipt function:

function waitForReceipt(hash, cb) {
  web3.eth.getTransactionReceipt(hash, function (err, receipt) {
    if (err) {
      error(err);
    }

    if (receipt !== null) {
      // Transaction went through
      if (cb) {
        cb(receipt);
      }
    } else {
      // Try again in 1 second
      window.setTimeout(function () {
        waitForReceipt(hash, cb);
      }, 1000);
    }
  });
}
Because it requires a transaction, you’ll notice that if you click the “Increment count” button in the Counter Example DApp, MetaMask prompts the user to first approve the transaction.

Full DApp
You can try the Counter Example DApp here. You’ll need an account on the Ropsten test network, which you can fund via the MetaMask faucet.

Below is the full source code for the DApp:

counter.html
<script src="/js/web3.min.js"></script>
<script src="https://code.jquery.com/jquery-3.2.1.min.js"></script>

<p>Current count: <span id="count">??</span></p>
<button id="getcount">Get current count</button>
<button id="increment">Increment count</button>
<div id="log"></div>

<script>
  function log(message) {
    $('#log').append($('<p>').text(message));
    $('#log').scrollTop($('#log').prop('scrollHeight'));
  }

  function error(message) {
    $('#log').append($('<p>').addClass('dark-red').text(message));
    $('#log').scrollTop($('#log').prop('scrollHeight'));
  }

  function waitForReceipt(hash, cb) {
    web3.eth.getTransactionReceipt(hash, function (err, receipt) {
      if (err) {
        error(err);
      }

      if (receipt !== null) {
        // Transaction went through
        if (cb) {
          cb(receipt);
        }
      } else {
        // Try again in 1 second
        window.setTimeout(function () {
          waitForReceipt(hash, cb);
        }, 1000);
      }
    });
  }

  var address = "0xf15090c01bec877a122b567e5552504e5fd22b79";
  var abi = [{"constant":true,"inputs":[],"name":"getCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"increment","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"inputs":[{"name":"_count","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"}];

  $(function () {
    var counter;

    $('#getcount').click(function (e) {
      e.preventDefault();

      log("Calling getCount...");

      counter.getCount.call(function (err, result) {
        if (err) {
          return error(err);
        } else {
          log("getCount call executed successfully.");
        }

        // The return value is a BigNumber object
        $('#count').text(result.toString());
      });
    });

    $('#increment').click(function (e) {
      e.preventDefault();

      if(web3.eth.defaultAccount === undefined) {
        return error("No accounts found. If you're using MetaMask, " +
                     "please unlock it first and reload the page.");
      }

      log("Calling increment...");

      counter.increment.sendTransaction(function (err, hash) {
        if (err) {
          return error(err);
        }

        waitForReceipt(hash, function () {
          log("Transaction succeeded. " +
              "Call getCount again to see the latest count.");
        });
      });
    });

    if (typeof(web3) === "undefined") {
      error("Unable to find web3. " +
            "Please run MetaMask (or something else that injects web3).");
    } else {
      log("Found injected web3.");
      web3 = new Web3(web3.currentProvider);
      if (web3.version.network != 3) {
        error("Wrong network detected. Please switch to the Ropsten test network.");
      } else {
        log("Connected to the Ropsten test network.");
        counter = web3.eth.contract(abi).at(address);
        $('#getcount').click();
      }
    }
  });
</script>
Summary
Ethereum decentralized apps (DApps) connect smart contract back ends with JavaScript front ends.
JavaScript interfaces with Ethereum via the web3.js library.
MetaMask is a popular browser extension that provides an implementation of the web3.js API.
View functions can be called without creating a transaction.
To call a function that mutates state, a transaction is sent to the blockchain.
← Writing a Very Simple Smart ContractWriting a Contract That Handles Ether →
  