use cardano/assets.{AssetName, PolicyId}

pub type AssetClass {
  policy: PolicyId,
  name: AssetName,
}

pub type TicketerDatum {
  ticket_counter: Int,
}

pub type TicketerRedeemer {
  BuyTicket
}

pub type TicketPolicyRedeemer {
  MintTicket
  BurnTicket
}
