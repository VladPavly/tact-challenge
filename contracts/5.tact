import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.
  Implement getter that will return NFT addresses held by the smart contract.
  Implement getter that will return the amount of admin`s profit collected.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchP
   rofit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  * profit
   - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  * nfts
   - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
  queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
  queryId: Int as uint64;
}

message AdminFetchProfit {
  queryId: Int as uint64;
}

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


contract Task5 with Deployable {
  nftCount: Int as uint16;
  seed: Int as uint128;
  owner: Address;
  nfts: map<Int as uint16, Address>;
  
  
  init(seed: Int, owner: Address) {
    self.owner = owner;
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address

    self.nftCount = 0;
  }

  receive(msg: OwnershipAssigned) {
    if (msg.prevOwner == self.owner) {
      self.nfts.set(self.nftCount, sender());
      self.nftCount = self.nftCount + 1;

      return;
    }

    if (context().value < ton("2.1")) {
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
            .endCell()
          )
        .endCell(), 66
      );

      return;
    }

    //let nft: Address = sender();

    let nftNumber: Int = nativeRandomInterval(self.nftCount - 1);

    //if (nftNumber != self.nftCount) {
      let nft: Address = self.nfts.get(nftNumber)!!;

      self.nfts.set(nftNumber, sender());
    //}

    nativeSendMessage(
      beginCell()
        .storeUint(16, 6)
        .storeAddress(nft) // to: 
        // .storeAddress(sender())
        .storeCoins(context().value - ton("2")) // value:
        .storeUint(1, 107)
        .storeRef(
          beginCell()
            .storeUint(0x5fcc3d14, 32)
            .storeUint(msg.queryId, 64)
            .storeAddress(msg.prevOwner)
            .storeAddress(msg.prevOwner)
            .storeUint(0, 5)
          .endCell()
        )
      .endCell(), 66
    );
  }

  receive(msg: AdminWithdrawalProfit) {
    nativeThrowUnless(1000, sender() == self.owner);

    nativeSendMessage(
      beginCell()
        .storeUint(16, 6)
        .storeAddress(sender()) // to: 
        .storeCoins(myBalance() - ton("0.1")) // value:
        .storeUint(1, 107)
        .storeRef(
          beginCell()
            .storeUint(0xfda48b79, 32)
            .storeUint(msg.queryId, 64)
          .endCell()
        )
      .endCell(), 0
    );
  }

  receive(msg: AdminWithdrawalAllNFTs) {
    nativeThrowUnless(1000, context().value >= (ton("1") + self.nftCount * ton("0.08")));
    nativeThrowUnless(1001, sender() == self.owner || sender() == myAddress());

    // require(context().value >= (ton("1") + self.nftCount * ton("0.08")), "if");
    // require(sender() == self.owner || sender() == myAddress(), "ip");

    let i: Int = self.nftCount - 1;

    repeat (min(140, self.nftCount)) {
      // self.nftCount = self.nftCount - 1;

      nativeSendMessage(
        beginCell()
          .storeUint(16, 6)
          .storeAddress(self.nfts.get(i)!!) // to: 
          .storeCoins(ton("0.08")) // value:
          .storeUint(1, 107)
          .storeRef(
            beginCell()
              .storeUint(0x5fcc3d14, 32)
              .storeUint(msg.queryId, 64)
              .storeAddress(self.owner)
              .storeAddress(self.owner)
              .storeUint(0, 5)
            .endCell()
          )
        .endCell(), 0
      );

      self.nfts.set(i, null);
      i = i - 1;
    }

    self.nftCount = max(self.nftCount - 140, 0);

    if (self.nftCount != 0) {
      nativeSendMessage(
        beginCell()
          .storeUint(16, 6)
          .storeAddress(myAddress()) // to: 
          .storeCoins(ton("1") + self.nftCount * ton("0.08")) // value:
          .storeUint(1, 107)
          .storeRef(
            beginCell()
              .storeUint(0x6339421f, 32)
              .storeUint(msg.queryId, 64)
            .endCell()
          )
        .endCell(), 1
      );
    }
  }

  get fun profit(): Int {
    return max(0, myBalance() - ton("0.1"));
  }
  
  get fun nfts(): map<Int as uint16, Address> {
    return self.nfts;
  }
}
