use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/address.{Address, Script}
use cardano/assets.{
  AssetName, ada_asset_name, ada_policy_id, add, from_asset, from_lovelace,
}
use cardano/transaction.{
  InlineDatum, Input, Mint, Output, OutputReference, Spend, Transaction,
}
use ticketer
use ticketer/test_mock as mock
use ticketer/types.{AssetClass, BuyTicket, MintTicket, TicketerDatum}

// ==============================================================================================
// BuyTicket Tests
// ==============================================================================================

type BuyTestOptions {
  pay_price: Bool,
  include_admin_token: Bool,
  update_counter: Bool,
  preserve_policy: Bool,
  preserve_price: Bool,
  ticket_counter: Int,
  ticket_price: Int,
  ticket_minted_amount: Int,
  ticket_token_name: AssetName,
  spend_redeemer_present: Bool,
}

fn default_buy_options() {
  BuyTestOptions {
    pay_price: True,
    include_admin_token: True,
    update_counter: True,
    preserve_policy: True,
    preserve_price: True,
    ticket_counter: 7,
    ticket_price: 2_000_000,
    ticket_minted_amount: 1,
    ticket_token_name: "TICKET7",
    spend_redeemer_present: True,
  }
}

fn construct_tx(
  options: BuyTestOptions,
) -> (Transaction, TicketerDatum, AssetClass, Int) {
  let ticket_policy = mock.ticketer_policy
  // Reusing a mock policy
  let admin_token =
    AssetClass { policy: mock.admin_policy, name: mock.admin_token_name }
  let redeemer = BuyTicket
  let ticketer_address =
    Address {
      payment_credential: Script(mock.ticketer_credential),
      // Reusing a mock credential
      stake_credential: None,
    }
  let ticketer_value =
    if options.include_admin_token {
      from_lovelace(10_000_000)
        |> add(mock.admin_policy, mock.admin_token_name, 1)
    } else {
      from_lovelace(10_000_000)
    }
  let ticketer_datum =
    TicketerDatum { ticket_counter: options.ticket_counter, ticket_policy }
  let ticketer_in = {
    let output =
      Output {
        address: ticketer_address,
        value: ticketer_value,
        datum: InlineDatum(ticketer_datum),
        reference_script: None,
      }
    let output_reference =
      OutputReference { transaction_id: mock.transaction_id_1, output_index: 0 }
    Input { output_reference, output }
  }
  let ticketer_out =
    Output {
      address: ticketer_address,
      value: if options.pay_price {
        ticketer_in.output.value
          |> add(
              ada_policy_id,
              ada_asset_name,
              if options.preserve_price {
                options.ticket_price
              } else {
                options.ticket_price + 1
              },
            )
      } else {
        ticketer_in.output.value
      },
      datum: InlineDatum(
        TicketerDatum {
          ticket_counter: if options.update_counter {
            options.ticket_counter + 1
          } else {
            options.ticket_counter
          },
          ticket_policy: if options.preserve_policy {
            ticket_policy
          } else {
            "ffff"
          },
        },
      ),
      reference_script: None,
    }

  let tx =
    Transaction {
      inputs: [ticketer_in],
      reference_inputs: [],
      outputs: [ticketer_out],
      fee: 5_000,
      mint: from_asset(
        ticket_policy,
        options.ticket_token_name,
        options.ticket_minted_amount,
      ),
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound { bound_type: Finite(1), is_inclusive: True },
        upper_bound: IntervalBound {
          bound_type: Finite(10_000),
          is_inclusive: True,
        },
      },
      extra_signatories: [],
      redeemers: if options.spend_redeemer_present {
        [
          Pair(
            Spend(
              OutputReference {
                transaction_id: mock.transaction_id_1,
                output_index: 0,
              },
            ),
            {
              let redeemer_data: Data = redeemer
              redeemer_data
            },
          ),
          Pair(
            Mint(ticket_policy),
            {
              let redeemer_data: Data = MintTicket
              redeemer_data
            },
          ),
        ]
      } else {
        [
          Pair(
            Mint(ticket_policy),
            {
              let redeemer_data: Data = MintTicket
              redeemer_data
            },
          ),
        ]
      },
      datums: dict.empty
        |> dict.insert(
            mock.transaction_id_1,
            {
              let datum_data: Data = InlineDatum(ticketer_datum)
              datum_data
            },
          ),
      id: mock.transaction_id_3,
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  (tx, ticketer_datum, admin_token, options.ticket_price)
}

fn buy_ticket(options: BuyTestOptions) -> Bool {
  let (tx, ticketer_datum, admin_token, ticket_price) = construct_tx(options)
  let redeemer = BuyTicket

  let result =
    ticketer.ticketer.spend(
      admin_token,
      ticket_price,
      Some(ticketer_datum),
      redeemer,
      OutputReference { transaction_id: mock.transaction_id_1, output_index: 0 },
      tx,
    )
  result
}

fn mint_ticket(options: BuyTestOptions) -> Bool {
  let (tx, _ticketer_datum, admin_token, ticket_price) = construct_tx(options)
  let ticket_policy = mock.ticketer_policy
  ticketer.ticketer.mint(
    admin_token,
    ticket_price,
    MintTicket,
    ticket_policy,
    tx,
  )
}

test buy_ok() {
  buy_ticket(default_buy_options())
}

test mint_ok() {
  mint_ticket(default_buy_options())
}

test mint_fail_no_spend() fail {
  mint_ticket(
    BuyTestOptions { ..default_buy_options(), spend_redeemer_present: False },
  )
}

test no_price_paid() fail {
  buy_ticket(BuyTestOptions { ..default_buy_options(), pay_price: False })
}

test no_admin_token() fail {
  buy_ticket(
    BuyTestOptions { ..default_buy_options(), include_admin_token: False },
  )
}

test counter_not_updated() fail {
  buy_ticket(BuyTestOptions { ..default_buy_options(), update_counter: False })
}

test policy_not_preserved() fail {
  buy_ticket(BuyTestOptions { ..default_buy_options(), preserve_policy: False })
}

test price_not_preserved() fail {
  buy_ticket(BuyTestOptions { ..default_buy_options(), preserve_price: False })
}

test ticket_not_minted() fail {
  buy_ticket(
    BuyTestOptions { ..default_buy_options(), ticket_minted_amount: 0 },
  )
}

test ticket_wrong_amount() fail {
  buy_ticket(
    BuyTestOptions { ..default_buy_options(), ticket_minted_amount: 2 },
  )
}

test wrong_ticket_name() fail {
  buy_ticket(
    BuyTestOptions { ..default_buy_options(), ticket_token_name: "TICKET8" },
  )
}
