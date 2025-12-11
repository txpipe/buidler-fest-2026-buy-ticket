# Buidler Fest 2026

## Reference Docs

- [Buidler Fest on-chain validators](./onchain)

## Using Tx3

This starter kit relies on the [Tx3 toolchain](https://docs.txpipe.io/tx3), a development toolkit for UTxO protocols. Make sure to visit the [Tx3 installation](https://docs.txpipe.io/tx3/installation) guide to setup your system before continuing.

The `main.tx3` file contains the interface definition for the Buidler Fest protocol. This file uses the Tx3 DSL to describe the different on-chain interactions.

We encourage you to explore the [Tx3 language](https://docs.txpipe.io/tx3), but the important thing to notice is that the `main.tx3` file contains definition for the transaction to buy a ticket.

```js
tx buy_ticket(
    ticket_name: Bytes, // TICKET + number
) {
    ...
}
```

The body of this _function_ contains the transaction building logic that you need for minting your ticket.

## Building your transaction

First you need to install the Node dependencies:

```bash
npm install
```

### Create a wallet

The following command uses cardano-cli to create a new private / public key for the buyer. This is the wallet that will pay for the ticket.

```bash
cardano-cli address key-gen --verification-key-file buyer.vk --signing-key-file buyer.sk
```

Run the following command to get the address of your new wallet:

```bash
cardano-cli address build --payment-verification-key-file buyer.vk --mainnet
```

Make sure to send some ADA to the address to use as "gas" for executing the required transactions and to pay for the ticket.

### Get your wallet private key

In order to get your wallet private key you can use [cbor.me](https://cbor.me/).

Paste your `cborHex` value from the `buyer.sk` file and you'll get your wallet private key.

### Buy Ticket Tx

This transaction mints a `Ticket` token and pays the `ticket_price` to the treasury. It also updates the `Ticketer` state to increment the ticket counter.

You need to implement a script that calls the `buyTicketTx` function from the generated SDK in `offchain/protocol.ts`.

Most of the protocol parameters (like policies and contract addresses) are provided in the `.env` file included by network. You mainly need to provide:

*   `ticketName`: The name of the ticket to mint. It must follow the format `TICKET<N>`, where `<N>` is the current ticket counter.
*   `buyer`: Your wallet address.

The other parameters (`adminTokenName`, `adminTokenPolicy`, `ticketPolicy`, `ticketer`, `treasury`) should be loaded from the environment variables.

**Tip:** Check the `offchain/protocol.ts` file to see the type definitions and the `main.tx3` file to understand the transaction structure.

**Note:** You need to know the correct `ticketNumber` (it must be sequential) based on the current state of the `Ticketer` UTxO. You can find this value in the on-chain state.