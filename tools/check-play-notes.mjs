#!/usr/bin/env node
/*
 * A Play Console kiadasi jegyzet (changelog) ellenorzese.
 *
 * MIERT KELL: a Play Console a kiadasi megjegyzeseket nyelvenkent legfeljebb
 * 500 karakterben fogadja el, es a changelog csak akkor hasznal, ha PONTOSAN
 * azt mondja, amit a felhasznalo megkap. Ket tipikus, CSENDBEN marado hiba:
 *
 *   1. a szoveg tullepi a karakterlimitet -> a Play elutasítja a feltoltesnel
 *      (vagy a tulajdonos a helyszinen kezdi el vagdosni a szoveget);
 *   2. a changelog KIHAGY egy buildet -> ha 322 ota 328-ig minden egy csomagban
 *      megy ki, akkor a kimaradt pontok sose jutnak el a felhasznalohoz.
 *
 * Amit ez a kapu ellenoriz:
 *   - minden ```play-notes blokk <= 500 karakter (es nem ures);
 *   - a dokumentum fejlecében megadott build/verzio egyezik a pubspec.yaml-lel;
 *   - MINDEN buildhez van teteles bejegyzes a (lastPublishedBuild, currentBuild]
 *     tartomanyban;
 *   - az AAB letezik, es a dokumentumban szereplo SHA-256 TÉNYLEG az;
 *   - nincs benne TODO/XXX helykitolto.
 *
 * Futtatas: node tools/check-play-notes.mjs [dokumentum-utvonal]
 */

import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';

const PLAY_LIMIT = 500;
const SAFETY_LIMIT = 480;
const docPath = process.argv[2] ?? 'docs/PLAY-KIADASI-JEGYZET.md';

let failures = 0;
const check = (label, ok, detail = '') => {
  if (ok) {
    console.log(`OK    ${label}${detail ? ` — ${detail}` : ''}`);
    return;
  }
  failures++;
  console.log(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
};

if (!fs.existsSync(docPath)) {
  console.error(`HIBA  nincs ilyen dokumentum: ${docPath}`);
  process.exit(2);
}
const doc = fs.readFileSync(docPath, 'utf8');

/* --- 1. A fejlec (meta) ------------------------------------------------ */

const meta = {};
const metaMatch = /<!--\s*play-notes-meta([\s\S]*?)-->/.exec(doc);
if (metaMatch) {
  for (const line of metaMatch[1].split('\n')) {
    const m = /^\s*([A-Za-z0-9_]+)\s*:\s*(.+?)\s*$/.exec(line);
    if (m) meta[m[1]] = m[2];
  }
}
check('megvan a play-notes-meta fejlec', Boolean(metaMatch));
const currentBuild = Number(meta.currentBuild ?? '0');
const lastPublished = Number(meta.lastPublishedBuild ?? '0');
check('a fejlec tartalmazza a currentBuild/lastPublishedBuild erteket', currentBuild > 0 && lastPublished > 0);

/* --- 2. Egyezik-e a pubspec.yaml-lel ---------------------------------- */

const pubspec = fs.existsSync('pubspec.yaml') ? fs.readFileSync('pubspec.yaml', 'utf8') : '';
const pubVersion = /^version:\s*(\S+)/m.exec(pubspec)?.[1] ?? '';
const [pubName, pubBuildRaw] = pubVersion.split('+');
const pubBuild = Number(pubBuildRaw ?? '0');
check(
  'a dokumentum buildje egyezik a pubspec.yaml-lel',
  currentBuild === pubBuild && (meta.currentVersion ?? '') === pubName,
  `dokumentum: ${meta.currentVersion}+${currentBuild}, pubspec: ${pubVersion}`,
);

/* --- 3. A Play-blokkok hossza ----------------------------------------- */

const blocks = [];
const fenceRe = /```play-notes\r?\n([\s\S]*?)```/g;
let match;
while ((match = fenceRe.exec(doc)) !== null) blocks.push(match[1].replace(/\r?\n$/, ''));

check('van legalabb egy play-notes blokk', blocks.length > 0, `${blocks.length} blokk`);
blocks.forEach((block, index) => {
  const length = [...block].length; // kodpontonkent szamolunk, mint a Play
  check(
    `a(z) ${index + 1}. Play-blokk a limiten belul van`,
    length > 0 && length <= PLAY_LIMIT,
    `${length}/${PLAY_LIMIT} karakter`,
  );
  // Biztonsagi margo: a 497-500 karakteres szoveg MAR a hataron ul, es egy
  // kesobbi szovegmodositas csendben atbillentené a feltoltest. Ezert a
  // kapu 480 felett jelez, hogy legyen hely a javitasra.
  check(
    `a(z) ${index + 1}. Play-blokk megtartja a biztonsagi margot`,
    length <= SAFETY_LIMIT,
    `${length}/${SAFETY_LIMIT} karakter`,
  );
});

/* --- 4. Minden build le van fedve ------------------------------------- */

const covered = new Set();
for (const m of doc.matchAll(/^###\s+(\d{3})\b/gm)) covered.add(Number(m[1]));
const missing = [];
for (let build = lastPublished + 1; build <= currentBuild; build++) {
  if (!covered.has(build)) missing.push(build);
}
check(
  'minden kihagyott buildhez van teteles bejegyzes',
  missing.length === 0,
  missing.length ? `hianyzik: ${missing.join(', ')}` : `${covered.size} build bejegyzes`,
);
check(
  'a jelenlegi buildhez is van bejegyzes',
  covered.has(currentBuild),
  `currentBuild=${currentBuild}`,
);

/* --- 5. Az AAB es a hash ---------------------------------------------- */

if (meta.aab) {
  check('az AAB letezik', fs.existsSync(meta.aab), meta.aab);
  if (fs.existsSync(meta.aab)) {
    const actual = crypto.createHash('sha256').update(fs.readFileSync(meta.aab)).digest('hex').toUpperCase();
    const declared = String(meta.sha256 ?? '').toUpperCase();
    check(
      'a dokumentumban szereplo AAB SHA-256 valos',
      declared !== '' && declared === actual,
      declared === actual ? actual : `dokumentum: ${declared}, valos: ${actual}`,
    );
    check(
      'a dokumentum megnevezi a verzokodot',
      doc.includes(`**${currentBuild}**`) || doc.includes(`| **${currentBuild}** |`),
    );
  }
}

/* --- 6. Helykitoltok -------------------------------------------------- */

const placeholders = ['TODO', 'XXX', 'FIXME'].filter((word) => doc.includes(word));
check('nincs helykitolto a szovegben', placeholders.length === 0, placeholders.join(', '));

/* --- Osszegzes -------------------------------------------------------- */

console.log(`\n${failures === 0 ? 'MINDEN ELLENORZES RENDBEN' : `${failures} HIBA`}`);
process.exit(failures === 0 ? 0 : 1);
