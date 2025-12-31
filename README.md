# Buidler Fest 2026 tickets using Tx3

This is an example of how to buy your Buidler Fest 2026 ticket using Tx3.

## TL;DR

If you want to learn about Tx3, we recommend you to follow the tutorial below, it's worthwhile.

If you're in a hurry and just want your ticket, follow the [I don't have time for this shit](tldr.md) version.

## Introduction

You've heard about Tx3 but never had enough time to check it out? Well, this is your chance.

Tx3 is a toolkit for authoring and interacting with UTxO procotols. Think of "UTxO Protocol" as the API to your dApp. The best analogy we have is to think of Tx3 as the "Open API" for blockchain.

In this case, the protocol we want to interact with is the "Buidler Fest Ticketing System". It's a great example for learning Tx3 since it has a little bit of everything, without getting too complex.

## Pre-requirements

The first step is to install the toolchain. If you don't have the Tx3 toolchain already insalled, follow the [install instructions](https://docs.txpipe.io/tx3/installation) on the documentation site.

Once you're done, you should have a new binary installed called `tx3up`. `tx3up` is our toolchain manager, it takes care of installs and versions of the different components of the Tx3 toolkit.

To make sure you're in the latest version of everything, run:

```bash
tx3up
```

## Clone the repo

This repo contains an implementation of the Ticketing System protocol already finished. You should clone this repo locally to be able to follow the rest of the tutorial.

```
git clone https://github.com/txpipe/buidler-fest-2026-buy-ticket
```

## The `main.tx3` file

Tx3, among other things, comes with a DSL for describing an UTxO protocol. It allows protocol authors to describe the interface of their system in terms of parties involved, policies and transactions that can be invoked.

To get an overall sense of the idea, this is Buidler Fest Ticketing protocol described using Tx3 DSL:

```tx3
party Buyer;

party Issuer;

party Treasury;

env {
    issuer_beacon_policy: Bytes,
    issuer_beacon_name: Bytes,
    ticket_policy: Bytes,
    issuer_script_ref: UtxoRef,
    ticket_price: Int,
}

type IssuerState {
    ticket_counter: Int,
}

tx buy_ticket() {
    locals {
        issuer_beacon: AnyAsset(issuer_beacon_policy, issuer_beacon_name, 1),
        ticket_name: concat("TICKET", current_state.ticket_counter),
        ticket_token: AnyAsset(ticket_policy, ticket_name, 1),
    }

    validity {
        until_slot: tip_slot() + 600,
    }

    reference issuer_script {
        ref: issuer_script_ref,
    }

    input* funds {
        from: Buyer,
        min_amount: fees + Ada(ticket_price) + min_utxo(ticket),
    }

    input current_state {
        from: Issuer,
        min_amount: issuer_beacon,
        datum_is: IssuerState,
        redeemer: (),
    }

    
    mint {
        amount: ticket_token,
        redeemer: (),
    }

    output ticket {
        to: Buyer,
        amount: funds - fees - Ada(ticket_price) + ticket_token,
    }

    output new_state {
        to: Issuer,
        amount: current_state,
        datum: IssuerState {
            ticket_counter: current_state.ticket_counter + 1,
        },
    }

    output payment {
        to: Treasury,
        amount: Ada(ticket_price),
    }

    collateral {
        from: Buyer,
        min_amount: fees,
    }
}
```

(TODO: more to come, this is just the begining, come back in a few hours)