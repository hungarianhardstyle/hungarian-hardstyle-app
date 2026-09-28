#!/usr/bin/env node
/**
 * ESEMÉNY-OLDALI QR — a beszkennelhető linkek előállítása és ELLENŐRZÉSE.
 *
 * MIÉRT (a cél 4. pontja): a helyszínen kifüggesztett QR akkor hoz telepítést,
 * ha **mindenkinél működik** — ezért a QR egy **webes** linkre mutat (nem
 * mélylinkre): aki még nem használja az appot, a Play-listára jut; aki már
 * használja, annak az Android a **manifestben bejelentett** útvonalon (381 óta)
 * az appot nyitja meg ugyanarra a tartalomra.
 *
 * ⚠️ A QR-kódot NEM ez a szkript rajzolja (nincs képkönyvtár-függőség): kiírja a
 * **pontos szövegeket**, amiket bármelyik QR-generátorba be kell másolni — és
 * **leellenőrzi**, hogy a címek élnek (HTTP-státusz), mert egy halott QR a
 * helyszínen derül ki.
 *
 * Használat:
 *   node tools/make-qr-links.mjs                 # az összes minta-link + ellenőrzés
 *   node tools/make-qr-links.mjs --event=12505   # egy konkrét esemény
 */
const PLAY =
  'https://play.google.com/store/apps/details?id=hu.hungarianhardstyle.app&referrer=qr';
const SITE = 'https://hungarianhardstyle.hu';

function argValue(name) {
  const arg = process.argv.find((value) => value.startsWith(`--${name}=`));
  return arg ? arg.split('=').slice(1).join('=') : '';
}

/** A QR-be kerülő szövegek — mind a **mért** link-alakokat használja. */
function qrTargets(eventId) {
  const targets = [
    {
      label: 'Telepítés (Play) — a helyszíni plakátra ez a legjobb',
      url: PLAY,
    },
    {
      label: 'A weboldal nyitólapja (tartalom app nélkül is)',
      url: `${SITE}/`,
    },
  ];
  if (eventId) {
    targets.push({
      label: `Konkrét esemény (#${eventId}) — az appban nyílik meg (381 óta)`,
      url: `${SITE}/?p=${eventId}`,
    });
  }
  return targets;
}

async function checkStatus(url) {
  try {
    const response = await fetch(url, { redirect: 'follow', headers: { Accept: 'text/html' } });
    return response.status;
  } catch (error) {
    return `hiba: ${error.message}`;
  }
}

const eventId = Number(argValue('event')) || 0;
const targets = qrTargets(eventId);

console.log('A QR-kódba másolandó szövegek (egyenként ellenőrizve):\n');
let failed = 0;
for (const target of targets) {
  const status = await checkStatus(target.url);
  const ok = status === 200;
  if (!ok) failed += 1;
  console.log(`${ok ? 'OK  ' : 'HIBA'}  ${target.label}`);
  console.log(`      ${target.url}`);
  console.log(`      HTTP ${status}`);
}
console.log(
  `\n${targets.length - failed}/${targets.length} cím él.` +
    (failed ? '  ⚠️ A halott cím a helyszínen derülne ki — javítsd, mielőtt kinyomtatod!' : ''),
);
console.log(
  '\nTipp: a plakátra kerüljön a Play-link (telepítés) ÉS a konkrét esemény linkje is,\n' +
    'mert aki már használja az appot, annak az eseményt nyissa meg — ne a boltot.',
);
process.exitCode = failed ? 1 : 0;
