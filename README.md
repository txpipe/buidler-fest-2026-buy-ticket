# Buidler Fest 2026 tickets using Tx3

This is an example of how to buy your Buidler Fest 2026 ticket using Tx3.

## TL;DR

If you want to learn about Tx3, we recommend you to follow the tutorial below, it's worthwhile.

If you're in a hurry and just want your ticket, follow the [I don't have time for this shit](tldr.md) version.

## Introduction

You've heard about Tx3 but never had enough time to check it out? Well, this is your chance.

Tx3 is a toolkit for authoring and interacting with UTxO procotols. Think of "UTxO Protocol" as the API to your dApp. The best analogy we have is to think of Tx3 as the "Open API" for blockchain.

In this case, the protocol we want to interact with is the "Buidler Fest Ticketing System". It's a great example for learning Tx3 since it has a little bit of everything, without getting too complex.

---

## 0. What we're doing here (spoilers welcome)

We're going to:

1. Install and update the Tx3 toolchain.
2. Peek at the protocol definition in `main.tx3` so we know what magic is happening.
3. Use `trix` (Tx3's CLI sidekick) to build an unsigned transaction for buying a ticket.
4. Paste that unsigned CBOR blob into a wallet, sign, and submit it.

If you only want the quick version, jump to the [TL;DR](tldr.md). If you want to actually learn how Tx3 thinks about protocols, stick around.

---

## 1. Install and update the Tx3 toolchain

The first step is to install the toolchain. If you don't have the Tx3 toolchain already insalled, follow the [install instructions](https://docs.txpipe.io/tx3/installation) on the documentation site.

Once you're done, you should have a new binary installed called `tx3up`. `tx3up` is our toolchain manager, it takes care of installs and versions of the different components of the Tx3 toolkit.

To make sure you're in the latest version of everything, run:

```bash
tx3up
```

Behind the scenes `tx3up` will refresh the Tx3 compiler, the `trix` CLI, and any dependencies that the DSL needs for codegen. Think of it as `rustup`, but for Tx3 land.

---

## 2. Clone this repo (your playground)

This repo contains an implementation of the Ticketing System protocol already finished. You should clone this repo locally to be able to follow the rest of the tutorial.

```bash
git clone https://github.com/txpipe/buidler-fest-2026-buy-ticket
cd buidler-fest-2026-buy-ticket
```

> Tip: all commands below assume you're in the repo root.

---

## 3. Meet the protocol: `main.tx3`

Tx3, among other things, comes with a DSL for describing an UTxO protocol. It allows protocol authors to describe the interface of their system in terms of parties involved, policies and transactions that can be invoked.

Here's the Buidler Fest Ticketing protocol described using the Tx3 DSL:

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

Key ideas worth noticing:

- **Parties**: `Buyer`, `Issuer`, and `Treasury` describe who interacts with the UTxOs. Tx3 keeps them explicit so scripts and clients know the expected roles.
- **Environment**: everything under `env { ... }` are parameters the protocol expects at runtime. For example, `ticket_price` is pulled in when building the transaction, not hardcoded.
- **State**: `IssuerState` keeps a counter so each ticket name is unique. Tx3 uses typed datums so you don't get lost in opaque blobs.
- **Transaction shape**: `tx buy_ticket()` declares inputs, outputs, minting, and validity window. The DSL is strongly typed and keeps the flow readable (no more scrolling through JSON by hand).
- **Locals**: `locals` is a handy scratchpad for derived values—here we derive the ticket token name and asset IDs.

All of the above is what `trix` consumes to build transactions. Next, let's actually do that.

---

## 4. Generate the unsigned transaction with `trix`

We're going to ask `trix` to build the ticket purchase transaction for mainnet, but **not** submit it yet. That way you can sign it in your wallet of choice.

From the repo root, run:

```bash
trix invoke --profile mainnet --skip-submit
```

What happens next:

1. `trix` compiles `main.tx3`, loads the `mainnet` profile from `trix.toml`, and asks for any runtime params (like your buyer address).
2. You'll be prompted for `buyer`. Paste the address of the wallet you want to use to pay. Make sure it holds **at least 400 ADA** for the ticket plus fees.
3. `trix` assembles the transaction using the protocol definition, including the minting of your unique `TICKET#` asset and the payment to the treasury.
4. Because we passed `--skip-submit`, the tool spits out a JSON payload with the unsigned CBOR and its hash, something like:

   ```json
   {
     "cbor": "84a900...00f5f6",
     "hash": "270199...61ba43"
   }
   ```

The `cbor` field is the raw unsigned transaction. Copy it all—no whitespace trimming, no extra quotes.

> Want to see more flags or profiles? Check the [Tx3 CLI docs](https://docs.txpipe.io/tx3/reference/cli) for all the knobs.

---

## 5. Sign and submit from your wallet

Tx3 intentionally stops short of signing for you—that part is on your wallet so you keep control of keys. Use any wallet that supports CBOR import (Lace, Eternl, Nami with advanced flow, etc.). The flow is usually:

1. Open the wallet's "Import unsigned transaction" or "Submit CBOR" option.
2. Paste the `cbor` value you just copied.
3. Review the transaction details: you should see ~400 ADA leaving and a fresh `TICKET#` native asset coming back to you.
4. Approve, sign, and submit.

If everything goes well, the wallet will show the transaction hash and your fresh ticket asset. The `hash` printed by `trix` is your pre-sign hash—handy for double-checking you're signing what you built.

---

## 6. Why this showcases Tx3 (aka what you just learned)

- **Declarative protocols**: The entire ticketing logic is expressed in one readable DSL file. No hunting for off-chain helpers scattered across scripts.
- **Typed datums and redeemers**: `IssuerState` isn't just a comment—`trix` enforces the shape, so you don't accidentally feed wrong data to validators.
- **Profiles and environments**: The values in `trix.toml` let you target different networks or price points without rewriting the protocol.
- **Client ergonomics**: `trix invoke` hides the ledger plumbing (UTxO selection, change, collateral, minting policies) while still being auditable because it's derived from `main.tx3`.
- **Offline friendliness**: Generating unsigned CBOR means you can keep keys in cold storage and still use the protocol.

Want to go deeper? The [official Tx3 docs](https://docs.txpipe.io/tx3) cover the DSL, standard library, and more involved protocol patterns. Once you've bagged your ticket, try tweaking `main.tx3` and see how `trix` reacts—it's a great way to learn.

---

## 7. FAQ and troubleshooting

- **I see `not enough funds`**: Make sure the buyer address has >400 ADA plus room for fees.
- **My wallet rejects the CBOR**: Confirm you copied the entire `cbor` string from the JSON output—no trailing commas or quotes.
- **Different network?**: Update the profile in `trix.toml` or add a new one, then run `trix invoke --profile <name> --skip-submit`.
- **Want to inspect the transaction**: Use `cardano-cli transaction view --tx-file <file>` after saving the CBOR to disk, or use any CBOR explorer.

Happy minting and see you at Buidler Fest!
