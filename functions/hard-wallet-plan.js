'use strict';

// HARD token – tárca-azonosítás és egyenleg: TISZTA logika (nincs Firestore/RPC),
// hogy külön tesztelhető legyen. A callable-ök a `index.js` végén vannak.
//
// Függőség nélkül: az ed25519-ellenőrzés a beépített `node:crypto`-val megy, a
// base58 pedig itt van (a Solana-cím 32 bájt base58-ban).
const crypto = require('node:crypto');

const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
// A 32 bájtos nyers kulcs elé kerül az SPKI-fejléc, így a Node be tudja olvasni.
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

/** Egy kihívás ennyi ideig érvényes (rövid lejárat, egyszer használatos). */
const CHALLENGE_TTL_MS = 5 * 60 * 1000;
const CHALLENGE_DOMAIN = 'hungarianhardstyle.hu';
const NETWORK_RPC = Object.freeze({
  devnet: 'https://api.devnet.solana.com',
});

function base58Decode(text) {
  if (typeof text !== 'string' || text === '') return null;
  const bytes = [];
  for (const char of text) {
    const value = ALPHABET.indexOf(char);
    if (value < 0) return null;
    let carry = value;
    for (let i = 0; i < bytes.length; i++) {
      carry += bytes[i] * 58;
      bytes[i] = carry & 0xff;
      carry >>= 8;
    }
    while (carry > 0) {
      bytes.push(carry & 0xff);
      carry >>= 8;
    }
  }
  for (const char of text) {
    if (char !== '1') break;
    bytes.push(0);
  }
  return Buffer.from(bytes.reverse());
}

function base58Encode(buffer) {
  const digits = [0];
  for (const byte of buffer) {
    let carry = byte;
    for (let i = 0; i < digits.length; i++) {
      carry += digits[i] << 8;
      digits[i] = carry % 58;
      carry = (carry / 58) | 0;
    }
    while (carry > 0) {
      digits.push(carry % 58);
      carry = (carry / 58) | 0;
    }
  }
  let out = '';
  for (const byte of buffer) {
    if (byte !== 0) break;
    out += '1';
  }
  for (let i = digits.length - 1; i >= 0; i--) out += ALPHABET[digits[i]];
  return out;
}

/** Érvényes Solana-cím: pontosan 32 bájtra dekódolható base58. */
function parseSolanaAddress(value) {
  if (typeof value !== 'string' || value.length < 32 || value.length > 44) return null;
  const bytes = base58Decode(value);
  return bytes && bytes.length === 32 ? bytes : null;
}

/** A kihívás szövege: a tárca ezt írja alá. Fiókhoz, tárcához és időhöz kötött. */
function buildChallengeMessage({ uid, address, nonce, issuedAtMs, expiresAtMs }) {
  return [
    'Hungarian Hardstyle – HARD tárca igazolása',
    `Domain: ${CHALLENGE_DOMAIN}`,
    `Fiók: ${uid}`,
    `Tárca: ${address}`,
    `Nonce: ${nonce}`,
    `Kiadva: ${new Date(issuedAtMs).toISOString()}`,
    `Lejár: ${new Date(expiresAtMs).toISOString()}`,
    'Ez az aláírás nem tranzakció, nem költ és nem utal semmit.',
  ].join('\n');
}

function parseSignature(value) {
  if (typeof value !== 'string' || value === '') return null;
  const bytes = Buffer.from(value, 'base64');
  return bytes.length === 64 ? bytes : null;
}

/** ed25519-aláírás ellenőrzése a Solana-cím (nyers publikus kulcs) ellen. */
function verifyWalletSignature({ address, message, signature }) {
  const publicBytes = parseSolanaAddress(address);
  const signatureBytes = typeof signature === 'string' ? parseSignature(signature) : signature;
  if (!publicBytes || !signatureBytes || typeof message !== 'string') return false;
  try {
    const key = crypto.createPublicKey({
      key: Buffer.concat([ED25519_SPKI_PREFIX, publicBytes]),
      format: 'der',
      type: 'spki',
    });
    return crypto.verify(null, Buffer.from(message, 'utf8'), key, signatureBytes);
  } catch {
    return false;
  }
}

/** Mismatch esetén indok, különben null: a callable ezt fordítja HttpsError-ra. */
function challengeProblem(challenge, { uid, nowMs }) {
  if (!challenge) return 'missing';
  if (challenge.uid !== uid) return 'foreign';
  if (challenge.used === true) return 'used';
  if (!(challenge.expiresAtMs > nowMs)) return 'expired';
  return null;
}

/** RPC-ből jövő egész egyenleg (string) összegzése; lebegőpont soha. */
function sumRawAmounts(accounts) {
  let total = 0n;
  for (const account of accounts || []) {
    const raw = account?.account?.data?.parsed?.info?.tokenAmount?.amount;
    if (typeof raw === 'string' && /^\d+$/.test(raw)) total += BigInt(raw);
  }
  return total;
}

/** Egész legkisebb egységből tizedes szöveg (pl. 1500000, 6 → "1.5"). */
function formatRawAmount(raw, decimals) {
  const value = BigInt(raw);
  const base = 10n ** BigInt(decimals);
  const whole = value / base;
  const fraction = (value % base).toString().padStart(decimals, '0').replace(/0+$/, '');
  return fraction === '' ? whole.toString() : `${whole}.${fraction}`;
}

/** A `hard_config/current` dokumentum érvényes-e a használathoz. */
function readHardConfig(data) {
  if (!data || data.enabled !== true) return null;
  const mint = typeof data.mint === 'string' ? data.mint : '';
  const cluster = typeof data.cluster === 'string' ? data.cluster : '';
  if (!parseSolanaAddress(mint) || !NETWORK_RPC[cluster]) return null;
  return { mint, cluster, rpcUrl: NETWORK_RPC[cluster] };
}

module.exports = {
  CHALLENGE_TTL_MS,
  CHALLENGE_DOMAIN,
  NETWORK_RPC,
  base58Decode,
  base58Encode,
  parseSolanaAddress,
  buildChallengeMessage,
  parseSignature,
  verifyWalletSignature,
  challengeProblem,
  sumRawAmounts,
  formatRawAmount,
  readHardConfig,
};
