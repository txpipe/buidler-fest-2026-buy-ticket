use cardano/address.{Address, Script, VerificationKey}

pub fn is_script_address(address: Address) -> Bool {
  when address.payment_credential is {
    VerificationKey(_) -> False
    Script(_) -> True
  }
}
