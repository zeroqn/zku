import {
  Field,
  prop,
  PublicKey,
  CircuitValue,
  Signature,
  UInt64,
  UInt32,
  KeyedAccumulatorFactory,
  ProofWithInput,
  proofSystem,
  branch,
  MerkleStack,
  shutdown,
} from 'snarkyjs';

const AccountDbDepth: number = 32;
const AccountDb = KeyedAccumulatorFactory<PublicKey, RollupAccount>(
  AccountDbDepth
);
type AccountDb = InstanceType<typeof AccountDb>;

class RollupAccount extends CircuitValue {
  @prop balance: UInt64;
  @prop nonce: UInt32;
  @prop publicKey: PublicKey;

  constructor(balance: UInt64, nonce: UInt32, publicKey: PublicKey) {
    super();
    this.balance = balance;
    this.nonce = nonce;
    this.publicKey = publicKey;
  }
}

class RollupTransaction extends CircuitValue {
  @prop amount: UInt64;
  @prop nonce: UInt32;
  @prop sender: PublicKey;
  @prop receiver: PublicKey;

  constructor(
    amount: UInt64,
    nonce: UInt32,
    sender: PublicKey,
    receiver: PublicKey
  ) {
    super();
    this.amount = amount;
    this.nonce = nonce;
    this.sender = sender;
    this.receiver = receiver;
  }
}

class RollupDeposit extends CircuitValue {
  @prop publicKey: PublicKey;
  @prop amount: UInt64;
  constructor(publicKey: PublicKey, amount: UInt64) {
    super();
    this.publicKey = publicKey;
    this.amount = amount;
  }
}

class RollupState extends CircuitValue {
  @prop pendingDepositsCommitment: Field;
  @prop accountDbCommitment: Field;
  constructor(p: Field, c: Field) {
    super();
    this.pendingDepositsCommitment = p;
    this.accountDbCommitment = c;
  }
}

class RollupStateTransition extends CircuitValue {
  @prop source: RollupState;
  @prop target: RollupState;
  constructor(source: RollupState, target: RollupState) {
    super();
    this.source = source;
    this.target = target;
  }
}

// a recursive proof system is kind of like an "enum"
@proofSystem
class RollupProof extends ProofWithInput<RollupStateTransition> {
  // Generate state transition proof for a deposit
  @branch static processDeposit(
    pending: MerkleStack<RollupDeposit>, // Pending deposit in merkle tree
    accountDb: AccountDb
  ): RollupProof {
    // Old state
    let before = new RollupState(pending.commitment, accountDb.commitment());
    // Pop a depoist
    let deposit = pending.pop();
    // Check account is not exists, mem is accumulator membership proof
    let [{ isSome }, mem] = accountDb.get(deposit.publicKey);
    isSome.assertEquals(false);

    // Create new account circuit value
    let account = new RollupAccount(
      UInt64.zero,
      UInt32.zero,
      deposit.publicKey
    );
    accountDb.set(mem, account);

    // New state
    let after = new RollupState(pending.commitment, accountDb.commitment());

    // New state transition proof (old state -> new state) after a
    // deposit
    return new RollupProof(new RollupStateTransition(before, after));
  }

  // Generate state transition proof for a transfer transaction
  @branch static transaction(
    t: RollupTransaction, // Transfer tx
    s: Signature, // Tx signature
    pending: MerkleStack<RollupDeposit>, // Pending deposits
    accountDb: AccountDb
  ): RollupProof {
    // Verify transaction signature, message is circuit value
    s.verify(t.sender, t.toFields()).assertEquals(true);
    // Old state
    let stateBefore = new RollupState(
      pending.commitment,
      accountDb.commitment()
    );

    // Get sender from account tree
    let [senderAccount, senderPos] = accountDb.get(t.sender);
    // Assert sender exists
    senderAccount.isSome.assertEquals(true);
    // Check nonce is correct
    senderAccount.value.nonce.assertEquals(t.nonce);

    // Minus sender balance with amount in transaction
    senderAccount.value.balance = senderAccount.value.balance.sub(t.amount);
    // Update sender nonce
    senderAccount.value.nonce = senderAccount.value.nonce.add(1);

    // Update sender in account tree
    accountDb.set(senderPos, senderAccount.value);

    // Get receiver, we can transfer to non exists account
    let [receiverAccount, receiverPos] = accountDb.get(t.receiver);
    // Add receiver balance
    receiverAccount.value.balance = receiverAccount.value.balance.add(t.amount);
    // Save receiver to account tree
    accountDb.set(receiverPos, receiverAccount.value);

    // New state
    let stateAfter = new RollupState(
      pending.commitment,
      accountDb.commitment()
    );
    // Proof for state transition after transfer transaction
    return new RollupProof(new RollupStateTransition(stateBefore, stateAfter));
  }

  // Proof recursive here, we merge two proof into one
  @branch static merge(p1: RollupProof, p2: RollupProof): RollupProof {
    // P1 output state should be p2 input state (aka old -> p1 -> p2 -> new)
    p1.publicInput.target.assertEquals(p2.publicInput.source);
    // Create merged one (aka old -> new)
    return new RollupProof(
      new RollupStateTransition(p1.publicInput.source, p2.publicInput.target)
    );
  }
}

shutdown();

export {RollupAccount, RollupDeposit, RollupState, RollupStateTransition, RollupTransaction, RollupProof}
