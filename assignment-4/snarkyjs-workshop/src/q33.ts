import { strict as assert} from 'assert';
import {
  Field,
  PrivateKey,
  PublicKey,
  SmartContract,
  state,
  State,
  method,
  UInt64,
  Mina,
  Party,
  isReady,
  shutdown,
} from 'snarkyjs';

class Q33 extends SmartContract {
  @state(Field) x: State<Field>;
  @state(Field) y: State<Field>;
  @state(Field) z: State<Field>;

  constructor(initialBalance: UInt64, address: PublicKey, x: Field, y: Field, z: Field) {
    super(address);
    this.balance.addInPlace(initialBalance);
    this.x = State.init(x);
    this.y = State.init(y);
    this.z = State.init(z);
  }

  @method async update(x: Field, y: Field, z: Field) {
    this.x.set(x);
    this.y.set(y);
    this.z.set(z);
  }
}

export async function run() {
  await isReady;

  const Local = Mina.LocalBlockchain();
  Mina.setActiveInstance(Local);
  const account1 = Local.testAccounts[0].privateKey;
  const account2 = Local.testAccounts[1].privateKey;

  const snappPrivkey = PrivateKey.random();
  const snappPubkey = snappPrivkey.toPublicKey();

  let snappInstance: Q33;
  const initSnappStateX = new Field(1);
  const initSnappStateY = new Field(2);
  const initSnappStateZ = new Field(3);

  // Deploys the snapp
  await Mina.transaction(account1, async () => {
    // account2 sends 1000000000 to the new snapp account
    const amount = UInt64.fromNumber(1000000000);
    const p = await Party.createSigned(account2);
    p.balance.subInPlace(amount);

    snappInstance = new Q33(amount, snappPubkey, initSnappStateX, initSnappStateY, initSnappStateZ);
  })
    .send()
    .wait();

  // Update the snapp
  await Mina.transaction(account1, async () => {
    await snappInstance.update(new Field(4), new Field(5), new Field(6));
  })
    .send()
    .wait();

  const a = await Mina.getAccount(snappPubkey);

  const finalStateX = a.snapp.appState[0].toString();
  assert.strictEqual(finalStateX, '4');
  const finalStateY = a.snapp.appState[1].toString();
  assert.strictEqual(finalStateY, '5');
  const finalStateZ = a.snapp.appState[2].toString();
  assert.strictEqual(finalStateZ, '6');

  console.log('Q33');
  console.log(`final state value x ${finalStateX}`);
  console.log(`final state value y ${finalStateY}`);
  console.log(`final state value z ${finalStateZ}`);
}

run();
shutdown();
