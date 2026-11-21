import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { isValidMint } from './set-hard-config.mjs';

const MINT = '8yi3SaRjcftYWqyJY7JdoBKa4DuBDzjgpyjnAhFEvH7k';

test('mint-cím: csak a pontosan 32 bájtos base58 elfogadott', () => {
  assert.equal(isValidMint(MINT), true);
  assert.equal(isValidMint(MINT.slice(0, 30)), false); // jó karakterek, rossz hossz
  assert.equal(isValidMint('0' + MINT.slice(1)), false); // tiltott karakter
  assert.equal(isValidMint(undefined), false);
});

test('--confirm nélkül szárazon fut: kiírja, de nem ér az éles adatbázishoz', () => {
  const out = execFileSync(process.execPath, [new URL('./set-hard-config.mjs', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'), MINT], {
    encoding: 'utf8',
  });
  assert.match(out, /SZÁRAZ FUTÁS/);
  assert.match(out, /--confirm/);
  assert.doesNotMatch(out, /"id": "current"/); // nem olvasta vissza az éles dokumentumot
});
