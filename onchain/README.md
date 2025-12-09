# Buidler Fest Ticketing

This project contains the on-chain logic for the Buidler Fest ticketing system, built with [Aiken](https://aiken-lang.org).

## Contracts

### Ticketer (`validators/ticketer.ak`)

This is the main contract that manages the lifecycle of tickets. It consists of two parts:

1.  **Validator (Spend):**
    -   Manages the state of the ticket sales (ticket counter).
    -   Validates `BuyTicket` actions.
    -   Ensures the correct ticket price is paid to the contract.
    -   Ensures the datum is updated correctly (incrementing the ticket counter).
    -   Ensures a new ticket is minted.

2.  **Minting Policy (Mint):**
    -   **MintTicket:** Validates that a ticket is being minted in the context of a valid `BuyTicket` transaction in the validator.
    -   **BurnTicket:** Allows burning of tickets.

## Building

```sh
aiken build
```

## Testing

Run the test suite:

```sh
aiken check
```

## Project Structure

-   `validators/`: Contains the Aiken source code for validators and minting policies.
-   `lib/`: Shared code and types.

