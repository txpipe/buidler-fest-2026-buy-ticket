use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/primitive/bytearray.{concat, from_string}
use aiken/primitive/string
use cardano/address.{Address}
use cardano/assets.{
  PolicyId, ada_asset_name, ada_policy_id, from_asset, quantity_of, tokens,
}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Spend, Transaction, find_input,
}
use ticketer/types.{
  AssetClass, BurnTicket, BuyTicket, MintTicket, TicketPolicyRedeemer,
  TicketerDatum, TicketerRedeemer,
}

validator ticketer(
  admin_token: AssetClass,
  ticket_price: Int,
  treasury: Address,
  max_tickets: Int,
) {
  spend(
    datum: Option<TicketerDatum>,
    redeemer: TicketerRedeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, outputs, mint, .. } = self
    expect Some(datum) = datum
    let TicketerDatum { ticket_counter, ticket_policy } = datum

    expect ticket_counter < max_tickets

    expect Some(ticketer_input) = find_input(inputs, utxo)

    let BuyTicket = redeemer

    // Find the ticketer output (the one that continues the state)
    expect [ticketer_output] =
      list.filter(
        outputs,
        fn(output) { output.address == ticketer_input.output.address },
      )
    expect Output {
      address: _,
      value: ticketer_value,
      datum: InlineDatum(ticketer_datum),
      reference_script: None,
    } = ticketer_output

    // Check datum update
    expect ticketer_datum: TicketerDatum = ticketer_datum
    let must_update_datum =
      ticketer_datum == TicketerDatum {
        ticket_counter: ticket_counter + 1,
        ticket_policy,
      }

    // Check value update (accumulate price)
    let must_hold_admin_token =
      quantity_of(ticketer_value, admin_token.policy, admin_token.name) > 0

    let must_maintain_value = ticketer_value == ticketer_input.output.value

    let must_pay_treasury =
      list.any(
        outputs,
        fn(output) {
          output.address == treasury && quantity_of(
            output.value,
            ada_policy_id,
            ada_asset_name,
          ) >= ticket_price
        },
      )

    let must_have_correct_value = and {
        must_hold_admin_token?,
        must_maintain_value?,
        must_pay_treasury?,
      }

    // Check minting
    let ticket_name =
      concat("TICKET", from_string(string.from_int(ticket_counter)))
    let expected_minted_value = from_asset(ticket_policy, ticket_name, 1)

    let must_mint_ticket = mint == expected_minted_value

    and {
      must_update_datum?,
      must_have_correct_value?,
      must_mint_ticket?,
    }
  }

  mint(redeemer: TicketPolicyRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction { inputs, mint, redeemers, .. } = self

    when redeemer is {
      MintTicket -> {
        // Check that the ticketer validator is running BuyTicket
        // We need to find the ticketer input. We can identify it by the admin token.

        expect [ticketer_input] =
          list.filter(
            inputs,
            fn(input) {
              quantity_of(
                input.output.value,
                admin_token.policy,
                admin_token.name,
              ) > 0
            },
          )

        // Check that the redeemer for this input is BuyTicket
        let ticketer_purpose = Spend(ticketer_input.output_reference)
        let ticketer_redeemer: Data = BuyTicket
        let must_run_ticketer =
          pairs.get_all(redeemers, ticketer_purpose) == [ticketer_redeemer]

        must_run_ticketer
      }

      BurnTicket -> {
        let minted_tokens =
          mint
            |> tokens(policy_id)
            |> dict.to_pairs()

        // Check that we are burning
        expect [Pair(_, -1)] = minted_tokens
        True
      }
    }
  }

  else(_) {
    fail
  }
}
