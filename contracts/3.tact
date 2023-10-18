import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins;
    from: Address;
    forwardPayload: Slice as remaining;
}

// To simplify the testing process and the specificity of the messages being sent, we decided to add clear default values in this transaction
message(0xf8a7ea5) TokenTransfer {
     queryId: Int as uint64; // should be 0
     amount: Int as coins; // should be amount of jettons to send
     destination: Address; // should be user address / TokenNotification.from
     responseDestination: Address?; // should be myAddress()
     customPayload: Cell?; // should be null
     forwardTonAmount: Int as coins; // should be ton("0.01")
     forwardPayload: Slice as remaining; // should be emptySlice()
}

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int as uint128;
  bAmount: Int as uint128;
  jettonAddressA: Address;
  jettonAddressB: Address;

  init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
    self.owner = admin;
    self.jettonAddressA = newJettonAddressA;
    self.jettonAddressB = newJettonAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
  }

  receive(msg: TokenNotification) {
    if (msg.from == self.owner) {
      if (sender() == self.jettonAddressA) {
        self.aAmount = self.aAmount + msg.amount;
        return;
      }
      
      if (sender() == self.jettonAddressB) {
        self.bAmount = self.bAmount + msg.amount;
        return;
      }
      
      require(false, "Invalid jetton");
    }

    require(
      sender() == self.jettonAddressA || sender() == self.jettonAddressB, 
      "Invalid jetton"
    );

    let jetton_address: Address = self.jettonAddressA;

    let amount_of_token: Int = 0;

    if (sender() == self.jettonAddressB) {
      amount_of_token = (self.aAmount * 1000000000 / self.bAmount) * msg.amount / 1000000000;

      if (self.aAmount < amount_of_token) {
        amount_of_token = msg.amount;
        jetton_address = self.jettonAddressB;
      } else {
        self.bAmount = self.bAmount + msg.amount;
        self.aAmount = self.aAmount - amount_of_token;
      }
    } else {
      amount_of_token = (self.bAmount * 1000000000 / self.aAmount) * msg.amount / 1000000000;

      if (self.bAmount < amount_of_token) {
        amount_of_token = msg.amount;
      } else {
        self.aAmount = self.aAmount + msg.amount;
        self.bAmount = self.bAmount - amount_of_token;

        jetton_address = self.jettonAddressB;
      }
    }

    nativeSendMessage(
      beginCell()
        .storeInt(1, 2)
        .storeBool(false)
        .storeInt(0, 3)
        .storeAddress(jetton_address) // to: 
        .storeCoins(0) // value:
        .storeInt(0, 105)
        .storeBool(false)
        .storeBool(true)
        .storeRef(
          beginCell()
            .storeUint(0xf8a7ea5, 32)
            .storeUint(0, 64)
            .storeCoins(amount_of_token)
            .storeAddress(msg.from)
            .storeAddress(myAddress())
            .storeBool(false)
            .storeCoins(ton("0.01"))
            .storeSlice(emptySlice())
          .endCell()
        )
      .endCell(), 64
    );

    // send(SendParameters{
    //   to: jetton_address, 
    //   value: 0, 
    //   mode: 64, 
    //   bounce: false,
    //   body: beginCell()
    //           .storeUint(0xf8a7ea5, 32)
    //           .storeUint(0, 64)
    //           .storeCoins(amount_of_token)
    //           .storeAddress(msg.from)
    //           .storeAddress(myAddress())
    //           .storeBool(false)
    //           .storeCoins(ton("0.01"))
    //           .storeSlice(emptySlice())
    //         .endCell()
    // });
  }

  get fun price(jetton: Address): Int { 
    if (jetton == self.jettonAddressB) {
      return self.aAmount * 1000000000 / self.bAmount;
    }
    
    return self.bAmount * 1000000000 / self.aAmount;
  }
  
  get fun balance(jetton: Address): Int { 
    if (jetton == self.jettonAddressA) {
      return self.aAmount;
    }
    
    return self.bAmount;
  }
}
