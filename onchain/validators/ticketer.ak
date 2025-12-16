use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use aiken/primitive/bytearray.{concat, from_string}
use aiken/primitive/string
use cardano/address.{Address, Credential}
use cardano/assets.{
  PolicyId, ada_asset_name, ada_policy_id, from_asset, quantity_of, tokens,
}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Transaction, find_input,
}
use ticketer/types.{
  AssetClass, BurnTicket, BuyTicket, MintTicket, TicketPolicyRedeemer,
  TicketerDatum, TicketerRedeemer,
}

validator ticketer(
  admin_token: AssetClass,
  blind_price: Int,
  normal_price: Int,
  switch_slot: Int,
  treasury: Address,
  max_tickets: Int,
) {
  spend(
    datum: Option<TicketerDatum>,
    redeemer: TicketerRedeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, outputs, mint, validity_range, .. } = self
    trace @"expecting datum"
    expect Some(datum) = datum
    let TicketerDatum { ticket_counter } = datum

    trace @"checking ticket counter range"
    expect ticket_counter >= 0
    expect ticket_counter < max_tickets

    trace @"finding ticketer input"
    expect Some(ticketer_input) = find_input(inputs, utxo)

    let BuyTicket = redeemer

    // Find the ticketer output (the one that continues the state)
    trace @"finding ticketer output"
    expect [ticketer_output] =
      list.filter(
        outputs,
        fn(output) { output.address == ticketer_input.output.address },
      )
    trace @"validating ticketer output structure"
    expect Output {
      address: ticketer_address,
      value: ticketer_value,
      datum: InlineDatum(ticketer_datum),
      reference_script: None,
    } = ticketer_output

    trace @"validating ticketer address credential"
    expect Credential.Script(ticket_policy) =
      ticketer_address.payment_credential

    // Check datum update
    trace @"casting ticketer datum"
    expect ticketer_datum: TicketerDatum = ticketer_datum
    let must_update_datum =
      ticketer_datum == TicketerDatum { ticket_counter: ticket_counter + 1 }
    trace @"must_update_datum": must_update_datum

    // Check value update (accumulate price)
    let must_hold_admin_token =
      quantity_of(ticketer_value, admin_token.policy, admin_token.name) > 0
    trace @"must_hold_admin_token": must_hold_admin_token

    let input_value: Data = ticketer_input.output.value
    let must_maintain_value =
      assets.match(ticketer_value, input_value, fn(_new, _old) { True })
    trace @"must_maintain_value": must_maintain_value

    let current_price =
      if interval.is_entirely_before(validity_range, switch_slot) {
        blind_price
      } else {
        normal_price
      }

    trace @"current_price": current_price
    trace @"validity_range": validity_range
    trace @"switch_slot": switch_slot

    let must_pay_treasury =
      list.any(
        outputs,
        fn(output) {
          output.address == treasury && quantity_of(
            output.value,
            ada_policy_id,
            ada_asset_name,
          ) == current_price
        },
      )
    trace @"must_pay_treasury": must_pay_treasury

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
    trace @"must_mint_ticket": must_mint_ticket

    and {
      must_update_datum?,
      must_have_correct_value?,
      must_mint_ticket?,
    }
  }

  mint(redeemer: TicketPolicyRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction { inputs, mint, .. } = self

    when redeemer is {
      MintTicket -> {
        // We need to find the ticketer input. We identify it by the address (policy_id).

        trace @"finding script input for minting"
        expect Some(_) =
          list.find(
            inputs,
            fn(input) {
              input.output.address.payment_credential == Credential.Script(
                policy_id,
              )
            },
          )

        True
      }

      BurnTicket -> {
        let minted_tokens =
          mint
            |> tokens(policy_id)
            |> dict.to_pairs()

        // Check that we are burning
        list.all(minted_tokens, fn(pair) { pair.2nd < 0 })
      }
    }
  }

  else(_) {
    fail
  }
}
