'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {
  base58Decode,
  base58Encode,
  parseSolanaAddress,
  buildChallengeMessage,
  verifyWalletSignature,
  challengeProblem,
  sumRawAmounts,
  formatRawAmount,
  readHardConfig,
} = require('./hard-wallet-plan');

function newWallet() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const raw = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
  return { address: base58Encode(raw), privateKey };
}
const sign = (wallet, message) =>
  crypto.sign(null, Buffer.from(message, 'utf8'), wallet.privateKey).toString('base64');

test('base58: a rendszercím 32 nulla bájt, és oda-vissza egyezik', () => {
  assert.equal(base58Decode('11111111111111111111111111111111').length, 32);
  const wallet = newWallet();
  assert.equal(base58Encode(base58Decode(wallet.address)), wallet.address);
});

test('címellenőrzés: rossz karakter, rossz hossz, nem 32 bájt = érvénytelen', () => {
  const wallet = newWallet();
  assert.ok(parseSolanaAddress(wallet.address));
  assert.equal(parseSolanaAddress('0OIl' + wallet.address.slice(4)), null); // tiltott karakterek
  assert.equal(parseSolanaAddress(wallet.address.slice(0, 20)), null);
  assert.equal(parseSolanaAddress(''), null);
  assert.equal(parseSolanaAddress(null), null);
});

test('az aláírás érvényes a saját tárcával, és csak azzal', () => {
  const wallet = newWallet();
  const other = newWallet();
  const message = buildChallengeMessage({
    uid: 'u1',
    address: wallet.address,
    nonce: 'abc',
    issuedAtMs: 1_000,
    expiresAtMs: 2_000,
  });
  const signature = sign(wallet, message);
  assert.equal(verifyWalletSignature({ address: wallet.address, message, signature }), true);
  // Másik tárca címe ellen: hamis.
  assert.equal(verifyWalletSignature({ address: other.address, message, signature }), false);
  // Módosított üzenet: hamis.
  assert.equal(verifyWalletSignature({ address: wallet.address, message: message + 'x', signature }), false);
  // Rossz hosszú / üres / nem base64 aláírás: hamis, nem dob.
  for (const bad of ['', 'AAAA', null, undefined, 123]) {
    assert.equal(verifyWalletSignature({ address: wallet.address, message, signature: bad }), false);
  }
});

test('a kihívás szövege a fiókhoz, tárcához és időhöz kötött', () => {
  const base = { uid: 'u1', address: 'ADDR', nonce: 'n', issuedAtMs: 0, expiresAtMs: 60_000 };
  const text = buildChallengeMessage(base);
  assert.match(text, /Fiók: u1/);
  assert.match(text, /Tárca: ADDR/);
  assert.match(text, /Nonce: n/);
  assert.match(text, /nem tranzakció/);
  assert.notEqual(text, buildChallengeMessage({ ...base, uid: 'u2' }));
});

test('a kihívás lejárt, idegen vagy már felhasznált: elutasítva', () => {
  const ok = { uid: 'u1', expiresAtMs: 10_000 };
  assert.equal(challengeProblem(ok, { uid: 'u1', nowMs: 9_000 }), null);
  assert.equal(challengeProblem(null, { uid: 'u1', nowMs: 0 }), 'missing');
  assert.equal(challengeProblem(ok, { uid: 'u2', nowMs: 9_000 }), 'foreign');
  assert.equal(challengeProblem({ ...ok, used: true }, { uid: 'u1', nowMs: 9_000 }), 'used');
  assert.equal(challengeProblem(ok, { uid: 'u1', nowMs: 10_000 }), 'expired');
});

test('egyenleg: egész számok összege, lebegőpont nélkül; hibás sor kimarad', () => {
  const account = (amount) => ({ account: { data: { parsed: { info: { tokenAmount: { amount } } } } } });
  assert.equal(sumRawAmounts([account('1500000'), account('500000')]), 2_000_000n);
  assert.equal(sumRawAmounts([account('12.5'), account('-1'), account(7), {}, null]), 0n);
  assert.equal(sumRawAmounts(undefined), 0n);
  // 100 millió HARD 6 tizedessel nem csúszik el (a Number pontossága itt kevés lenne).
  assert.equal(sumRawAmounts([account('100000000000000')]), 100_000_000_000_000n);
});

test('formázás: kerekítés nélkül, a felesleges nullák levágva', () => {
  assert.equal(formatRawAmount('1500000', 6), '1.5');
  assert.equal(formatRawAmount('2000000', 6), '2');
  assert.equal(formatRawAmount('1', 6), '0.000001');
  assert.equal(formatRawAmount('0', 6), '0');
  assert.equal(formatRawAmount('100000000000000', 6), '100000000');
});

test('hard_config: csak bekapcsolva, érvényes mint-címmel és ismert hálózattal él', () => {
  const mint = newWallet().address; // bármely érvényes 32 bájtos cím
  assert.deepEqual(readHardConfig({ enabled: true, mint, cluster: 'devnet' }), {
    mint,
    cluster: 'devnet',
    rpcUrl: 'https://api.devnet.solana.com',
  });
  assert.equal(readHardConfig({ enabled: false, mint, cluster: 'devnet' }), null);
  assert.equal(readHardConfig({ enabled: true, mint: 'nem-cim', cluster: 'devnet' }), null);
  // Mainnet SZÁNDÉKOSAN nincs engedélyezve (külön döntés).
  assert.equal(readHardConfig({ enabled: true, mint, cluster: 'mainnet-beta' }), null);
  assert.equal(readHardConfig(undefined), null);
});

test('FORRÁS-LINT: minden HARD-callable regisztrált felhasználót kér, és nem nyúl a pontokhoz', () => {
  const fs = require('node:fs');
  const path = require('node:path');
  const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
  const block = source.slice(source.indexOf('HARD token (devnet)'));
  for (const name of ['hardWalletChallenge', 'hardWalletVerify', 'hardWalletDisconnect', 'hardGetBalance']) {
    const start = block.indexOf(`exports.${name} =`);
    assert.ok(start > 0, `${name} hiányzik`);
    const next = block.indexOf('\nexports.', start + 10);
    const body = block.slice(start, next === -1 ? undefined : next);
    assert.match(body, /requireRegisteredViewer\(context\)/, `${name}: nincs regisztráció-ellenőrzés`);
    assert.match(body, /allowCall\(uid/, `${name}: nincs rate limit`);
  }
  // A tárcát érintő három hívás nagykorúságot is kér (a szerver dönt, nem a kliens).
  for (const name of ['hardWalletChallenge', 'hardWalletVerify', 'hardGetBalance']) {
    const start = block.indexOf(`exports.${name} =`);
    const next = block.indexOf('\nexports.', start + 10);
    assert.match(block.slice(start, next === -1 ? undefined : next), /requireHardAdult\(uid\)/, `${name}: nincs kor-kapu`);
  }
  // A felhasznált kihívás törlődik, nem marad `used: true` sorként.
  assert.doesNotMatch(block, /used: true/);
  // A HARD és a pontok külön rendszer: ez a blokk nem írhat pontot.
  assert.doesNotMatch(block, /awardAchievementPoints|achievement_ledger/);
});
