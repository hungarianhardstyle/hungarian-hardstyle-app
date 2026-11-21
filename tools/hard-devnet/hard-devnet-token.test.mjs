import test from 'node:test';
import assert from 'node:assert/strict';
import {
  EXPECTED_RAW_SUPPLY,
  TOKEN_NAME,
  TOKEN_SYMBOL,
  verifyMetadataFacts,
  TOKEN_URI,
  verifyMintFacts,
} from './hard-devnet-token.mjs';

const good = { supply: EXPECTED_RAW_SUPPLY, decimals: 6, mintAuthority: null, freezeAuthority: null };

test('mint-garanciák: fix kínálat, mindkét jogosultság visszavonva', () => {
  assert.equal(verifyMintFacts(good).ok, true);
  assert.equal(verifyMintFacts({ ...good, mintAuthority: 'X' }).ok, false);
  assert.equal(verifyMintFacts({ ...good, freezeAuthority: 'X' }).ok, false);
  assert.equal(verifyMintFacts({ ...good, supply: EXPECTED_RAW_SUPPLY + 1n }).ok, false);
  assert.equal(verifyMintFacts({ ...good, decimals: 9 }).ok, false);
});

test('metaadat: a név és a szimbólum helyes, és nem módosítható', () => {
  assert.ok(TOKEN_NAME.length <= 32 && TOKEN_SYMBOL.length <= 10);
  const meta = { name: TOKEN_NAME, symbol: TOKEN_SYMBOL, isMutable: false };
  assert.equal(verifyMetadataFacts(meta).ok, true);
  assert.equal(verifyMetadataFacts({ ...meta, isMutable: true }).ok, false);
  assert.equal(verifyMetadataFacts({ ...meta, name: 'Más' }).ok, false);
  assert.equal(verifyMetadataFacts({ ...meta, symbol: 'X' }).ok, false);
  assert.equal(verifyMetadataFacts({ ...meta, uri: TOKEN_URI }).ok, true);
  assert.equal(verifyMetadataFacts({ ...meta, uri: '' }).ok, false);
});
