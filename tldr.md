# Buy Ticket - Quick Version

If you're in a hurry and just want your ticket, these are the steps you need to follow:

## 1. Install the Tx3 toolchain

If you don't have the Tx3 toolchain already insalled, follow the [install instructions](https://docs.txpipe.io/tx3/installation) on the documentation site.


## 2. ensure you're up to date

You'll need the latest versions of the toolchain, run the toolchain manager to make sure: 

```
tx3up
```

## 3. clone this repo

```
git clone https://github.com/txpipe/buidler-fest-2026-buy-ticket
```

## 3. generate the unsigned tx cbor

```
trix invoke --profile mainnet --skip-submit
```

- Make sure to run the trix command from inside the root of the cloned project.
- When asked for the `buyer` address, enter your wallet address from where you'll be making the payment.
- Your address needs to hold at least 400 ADA required for the ticket.

## 4. copy the unsigned CBOR and submit it using your wallet

You'll get a JSON output that looks like the following:


```json
// redacted for simplificty, should be much longer
{
  "cbor": "84a900...00f5f6", 
  "hash": "270199...61ba43"
}
```

- copy the whole content of the `cbor` field, it represents the un-signed tx for purchaing your ticket.
- import it from a wallet that supports CBOR input
- use your wallet UI to validate the tx, make sure you're paying 400A and that you get a TICKET#` token back
- use your wallet to sign & submit the tx.
