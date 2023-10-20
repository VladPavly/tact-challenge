import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining; 
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal {
  queryId: Int as uint64;
  nftAddress: Address;
}

contract Task4 with Deployable {
  seed: Int as uint128;
  nft: Int? as uint256;
  owner: Int? as uint256;
  unlock_at: Int as uint32;
  
  init(seed: Int) {
    self.seed = seed;
    self.unlock_at = 0;
  }

  receive(msg: OwnershipAssigned) {
    if (self.nft == null) {
      let slice: Slice = sender().asSlice();
      slice.skipBits(11);
      self.nft = slice.loadUint(256);

      slice = msg.prevOwner.asSlice();
      slice.skipBits(11);
      self.owner = slice.loadUint(256);
      self.unlock_at = now() + msg.forwardPayload.loadUint(32);
      return;
    }

    nativeSendMessage(
      beginCell()
        .storeUint(16, 6)
        .storeAddress(sender()) // to: 
        // .storeCoins(0) // value:
        .storeUint(1, 111)
        .storeRef(
          beginCell()
            .storeUint(0x5fcc3d14, 32)
            .storeUint(msg.queryId, 64)
            .storeAddress(msg.prevOwner)
            .storeAddress(msg.prevOwner)
            .storeUint(0, 5)
            // .storeBool(false)
            // .storeCoins(0)
          .endCell()
        )
      .endCell(), 64
    );
  }

  receive(msg: NftWithdrawal) {
    let sender_slice: Slice = sender().asSlice();
    sender_slice.skipBits(11);
    let sender_hash: Int = sender_slice.loadUint(256);

    nativeThrowUnless(1000, sender_hash == self.owner);

    if (now() < self.unlock_at) {
      nativeSendMessage(
        beginCell()
          .storeUint(33792, 17)
          .storeUint(sender_hash, 256) // to: 
          // .storeCoins(0) // value:
          .storeUint(1, 111)
          // .storeBool(false)
          // .storeBool(true)
          .storeRef(
            "NFT is still locked".asComment()
          )
        .endCell(), 66
      );

      return;
    }

    nativeSendMessage(
      beginCell()
        .storeUint(33792, 17)
        .storeUint(self.nft!!, 256) // to: 
        // .storeCoins(0) // value:
        .storeUint(1, 111)
        .storeRef(
          beginCell()
            .storeUint(0x5fcc3d14, 32)
            .storeUint(msg.queryId, 64)
            .storeAddress(sender())
            .storeAddress(sender())
            .storeUint(0, 5)
          .endCell()
        )
      .endCell(), 64
    );

    self.nft = null;
    self.owner = null;
  }

  get fun time(): Int {
    return max(0, self.unlock_at - now());
  }

  get fun nft(): Cell? {
    if (self.nft == null) {
      return null;
    }

    return beginCell().storeUint(1024, 11).storeUint(self.nft!!, 256).endCell();
  }

  get fun owner(): Cell? {
    if (self.owner == null) {
      return null;
    }

    return beginCell().storeUint(1024, 11).storeUint(self.owner!!, 256).endCell();
  }
}
