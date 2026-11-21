'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { parseAmountRaw, buildTransferTransaction } = require('./hard-transfer-plan');

test('összeg: érvényes értékek legkisebb egységre váltva', () => {
  assert.equal(parseAmountRaw('1', 6), 1_000_000n);
  assert.equal(parseAmountRaw('1.5', 6), 1_500_000n);
  assert.equal(parseAmountRaw('0,000001', 6), 1n);
  assert.equal(parseAmountRaw(' 25 ', 6), 25_000_000n);
});

test('összeg: érvénytelen értékek null-t adnak', () => {
  for (const bad of ['', '0', '0.0', '-1', '1e3', '1.1234567', 'abc', '1..2', '1,2,3', null, 5, '99999999999999']) {
    assert.equal(parseAmountRaw(bad, 6), null, String(bad));
  }
});

test('tranzakció: két utasítás, a feladó a díjfizető, a mennyiség és a tizedesek benne vannak', () => {
  const { Keypair, Transaction } = require('@solana/web3.js');
  const sender = Keypair.generate().publicKey;
  const recipient = Keypair.generate().publicKey;
  const mint = Keypair.generate().publicKey;
  const blockhash = Keypair.generate().publicKey.toBase58();
  const built = buildTransferTransaction({
    sender: sender.toBase58(),
    recipient: recipient.toBase58(),
    mint: mint.toBase58(),
    rawAmount: 2_500_000n,
    decimals: 6,
    blockhash,
  });
  const tx = Transaction.from(Buffer.from(built.base64, 'base64'));
  assert.equal(tx.feePayer.toBase58(), sender.toBase58());
  assert.equal(tx.instructions.length, 2);
  const transfer = tx.instructions[1];
  // TransferChecked: [12, amount u64 LE, decimals]
  assert.equal(transfer.data[0], 12);
  assert.equal(transfer.data.readBigUInt64LE(1), 2_500_000n);
  assert.equal(transfer.data[9], 6);
  assert.equal(transfer.keys[3].pubkey.toBase58(), sender.toBase58());
  assert.equal(transfer.keys[3].isSigner, true);
  assert.equal(transfer.keys[2].pubkey.toBase58(), built.destinationAccount);
});
