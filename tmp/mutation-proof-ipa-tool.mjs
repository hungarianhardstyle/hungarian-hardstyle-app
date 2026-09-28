// MUTÁCIÓS BIZONYÍTÉK az IPA-mérő eszköz 2026-09-28-i javításához.
//
// A MÉRT HIBA: a `needlesFor()` csak `latin1` és `utf16be` alakot készített, ezért
// a **nem Latin-1** szövegeket (pl. `szerveződ`, `—`) nem találta meg a csomagban,
// holott azok benne voltak UTF-16LE-ként → hamis „nincs a buildben" jelzés.
//
// Ez a szkript a JAVÍTOTT eszköz EGY MÁSOLATÁT rontja el, és megköveteli, hogy az
// önteszt (7. eset) elkapja. A valódi fájlhoz NEM nyúlunk — a végén a lenyomatát
// ellenőrizzük, hogy ez így is maradt.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';

const source = 'tools/verify-ios-ipa.mjs';
const original = fs.readFileSync(source, 'utf8');
const originalHash = createHash('sha256').update(original).digest('hex');
const eol = original.includes('\r\n') ? '\r\n' : '\n';
const withEol = (text) => (eol === '\n' ? text : text.split('\n').join(eol));
const copy = 'tmp/.ipa-tool-mutant.mjs';

const mutations = [
  {
    title: 'a régi, két-kódolású needlesFor (UTF-16LE hiányzik)',
    apply: (text) =>
      text.replace(
        / {2}return \[\r?\n {4}\.\.\.\(oneByteSafe[\s\S]*?\r?\n {2}\];/,
        withEol(
          '  return [\n'
          + "    { encoding: 'onebyte', bytes: Buffer.from(text, 'latin1') },\n"
          + "    { encoding: 'utf16be', bytes: utf16be },\n"
          + '  ];',
        ),
      ),
  },
  {
    title: 'a Latin-1 védőkapu elvétele (némán levágott karakter)',
    apply: (text) =>
      text.replace(
        /const oneByteSafe = \[\.\.\.text\]\.every\(\(ch\) => ch\.charCodeAt\(0\) <= 0xff\);/,
        'const oneByteSafe = true;',
      ),
  },
];

let caught = 0;
let bad = 0;
for (const mutation of mutations) {
  const mutated = mutation.apply(original);
  if (mutated === original) {
    bad += 1;
    console.log(`ELTER  ${mutation.title} — a minta NEM illett (nulla változás)`);
    continue;
  }
  fs.writeFileSync(copy, mutated, 'utf8');
  let failed = false;
  let output = '';
  try {
    output = execFileSync(process.execPath, [copy, '--self-test'], {
      encoding: 'utf8',
      maxBuffer: 32 * 1024 * 1024,
      // ⚠️ A Node alapból a SZÜLŐ stderr-jére írja a gyerek stderr-jét, így a
      // szándékos mutáns-hiba kifolyna, és a hívó (PowerShell) hibának hinné.
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    failed = true;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  }
  const caughtBySeven = /onteszt 7[^\n]*HIBA/.test(output);
  if (failed && caughtBySeven) {
    caught += 1;
    console.log(`OK     ${mutation.title} — ELKAPVA (onteszt 7)`);
  } else {
    bad += 1;
    console.log(`ELTER  ${mutation.title} — NEM bukott meg (exit=${failed}, onteszt7=${caughtBySeven})`);
    console.log(output.split('\n').slice(0, 12).map((l) => `         ${l}`).join('\n'));
  }
}

if (fs.existsSync(copy)) fs.rmSync(copy, { force: true });
const nowHash = createHash('sha256').update(fs.readFileSync(source)).digest('hex');
const untouched = nowHash === originalHash;
console.log(`\na valódi fájl érintetlen: ${untouched ? 'IGEN' : 'NEM'} (${nowHash.slice(0, 16)}…)`);
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 && untouched ? 0 : 1;
