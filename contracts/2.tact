import "@stdlib/deploy";

/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  User address will be provided in Refund message body as "sender".
  In refund transaction, it is important to have a check that the refund message came from the admin address
*/

message(0x44) Refund {
  queryId: Int as uint64;
  sender: Address;
}

contract Task2 with Deployable {
  admin: Int as uint256;

  init(admin: Address) {
    let admin_slice: Slice = admin.asSlice();
    admin_slice.skipBits(11);

    self.admin = admin_slice.loadUint(256);
  }
  
  receive(msg: Refund) {
    let sender_slice: Slice = sender().asSlice();
    sender_slice.skipBits(11);

    nativeThrowUnless(1000, sender_slice.loadUint(256) == self.admin);

    nativeSendMessage(
      beginCell()
        .storeUint(16, 6)
        .storeAddress(msg.sender) // to: 
        // .storeCoins(0) // value:
        .storeUint(0, 111)
      .endCell(), 64
    );
  }

  receive(msg: Slice) {
    nativeSendMessage(
      beginCell()
        .storeUint(33792, 17)
        .storeUint(self.admin, 256)
        // .storeSlice(self.admin) // to: 
        // .storeCoins(0) // value:
        .storeUint(1, 111)
        .storeRef(
          beginCell()
            .storeAddress(sender())
            .storeRef(msg.asCell())
          .endCell()
        )
      .endCell(), 64
    );
  }
}
