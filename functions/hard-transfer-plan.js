'use strict';

// HARD-küldés felhasználók között: TISZTA logika (nincs Firestore/RPC), hogy külön
// tesztelhető legyen. A szerver CSAK összeállítja a tranzakciót (a feladó a díjfizető);
// az aláírást és a beküldést a feladó tárcája végzi, a szerver nem mozgat pénzt.

/** Legfeljebb ennyi egész HARD küldhető egyszerre (elírás ellen, nem kereskedelmi korlát). */
const MAX_WHOLE_AMOUNT = 1_000_000_000n;

/**
 * Tizedes szöveg → legkisebb egység (BigInt), vagy `null`, ha nem érvényes:
 * csak számjegy és legfeljebb egy pont/vessző, legfeljebb `decimals` tizedes,
 * pozitív, és az egész rész nem haladja meg a korlátot.
 */
function parseAmountRaw(text, decimals) {
  if (typeof text !== 'string') return null;
  const normalized = text.trim().replace(',', '.');
  const match = /^(\d{1,12})(?:\.(\d{1,18}))?$/.exec(normalized);
  if (!match) return null;
  const fraction = match[2] || '';
  if (fraction.length > decimals) return null;
  const whole = BigInt(match[1]);
  if (whole > MAX_WHOLE_AMOUNT) return null;
  const raw = whole * 10n ** BigInt(decimals) + BigInt(fraction.padEnd(decimals, '0') || '0');
  return raw > 0n ? raw : null;
}

/**
 * Aláíratlan tranzakció (base64): a címzett token-számlájának idempotens
 * létrehozása (a feladó fizeti) + `TransferChecked` a feladó számlájáról.
 * A web3.js csak itt töltődik be, hogy a többi függvény hidegindítását ne lassítsa.
 */
function buildTransferTransaction({ sender, recipient, mint, rawAmount, decimals, blockhash }) {
  const { PublicKey, Transaction } = require('@solana/web3.js');
  const {
    createAssociatedTokenAccountIdempotentInstruction,
    createTransferCheckedInstruction,
    getAssociatedTokenAddressSync,
  } = require('@solana/spl-token');
  const senderKey = new PublicKey(sender);
  const recipientKey = new PublicKey(recipient);
  const mintKey = new PublicKey(mint);
  const sourceAccount = getAssociatedTokenAddressSync(mintKey, senderKey);
  const destinationAccount = getAssociatedTokenAddressSync(mintKey, recipientKey);
  const transaction = new Transaction({ feePayer: senderKey, recentBlockhash: blockhash });
  transaction.add(
    createAssociatedTokenAccountIdempotentInstruction(senderKey, destinationAccount, recipientKey, mintKey),
    createTransferCheckedInstruction(sourceAccount, mintKey, destinationAccount, senderKey, rawAmount, decimals),
  );
  return {
    base64: transaction.serialize({ requireAllSignatures: false, verifySignatures: false }).toString('base64'),
    sourceAccount: sourceAccount.toBase58(),
    destinationAccount: destinationAccount.toBase58(),
  };
}

module.exports = { MAX_WHOLE_AMOUNT, parseAmountRaw, buildTransferTransaction };
