#!/usr/bin/env node
/**
 * SZONDA: miért nem találja az IPA-merő a 370 első changelog-sorát?
 *
 * Nem tippelünk: a `Frameworks/App.framework/App` nyers bájtjaiban keressük a
 * sor **egyre rövidebb** részleteit, UTF-8 és UTF-16LE alakban is, és kiírjuk,
 * melyik találat hol van. Így kiderül, hogy a sor egyáltalán benne van-e, és ha
 * igen, melyik karakteren törik a keresés.
 */
import fs from 'node:fs';
import path from 'node:path';

const app = path.join(process.argv[2] ?? 'tmp/ipa-check-370', 'Payload', 'Runner.app');
const buffer = fs.readFileSync(path.join(app, 'Frameworks/App.framework/App'));

const needles = [
  'Javítva: az értesítésben a cikk (és a kiadás, esemény, DJ) címe is a választott nyelven jelenik meg.',
  'az értesítésben a cikk (és a kiadás, esemény, DJ) címe is a választott nyelven jelenik meg',
  'az értesítésben a cikk',
  '(és a kiadás, esemény, DJ) címe',
  'a kiadás, esemény, DJ',
  'esemény, DJ) címe',
  'címe is a választott nyelven jelenik meg',
  'A már meglévő értesítéseknél is átfordul a cím',
  'fordul a cím — nem kell megvárni az új értesítéseket.',
];

const found = (needle, encoding) => buffer.indexOf(Buffer.from(needle, encoding));

for (const needle of needles) {
  const utf8 = found(needle, 'utf8');
  const utf16 = found(needle, 'utf16le');
  // ⚠️ A Dart AOT-snapshot a **Latin-1** karakterekből álló szöveget EGY bájtos
  // alakban tárolja (nem UTF-8-ként), ezért a latin1 keresés is kell.
  const latin1 = found(needle, 'latin1');
  console.log(
    `${utf8 >= 0 || utf16 >= 0 || latin1 >= 0 ? 'MEGVAN' : 'nincs '}  utf8=${utf8} utf16le=${utf16} latin1=${latin1}  «${needle}»`,
  );
}

// A 370-es sor környéke: a „Javítva:" kezdetű sorokat keressük előfordulásonként.
const marker = Buffer.from('Javítva', 'utf8');
const markerWide = Buffer.from('Javítva', 'utf16le');
const dumpAround = (index, encoding) => {
  const step = encoding === 'utf16le' ? 2 : 1;
  const slice = buffer.subarray(index, index + 200 * step);
  const text = slice.toString(encoding).replace(/\u0000/g, '');
  console.log(`\n--- előfordulás @${index} (${encoding}):\n${text.slice(0, 200)}`);
};
let index = buffer.indexOf(marker);
if (index >= 0) dumpAround(index, 'utf8');
index = buffer.indexOf(markerWide);
if (index >= 0) dumpAround(index, 'utf16le');
