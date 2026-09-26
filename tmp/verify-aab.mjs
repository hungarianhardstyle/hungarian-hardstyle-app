import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

/**
 * A feltöltendő AAB mérése (verziótól független).
 *
 * Használat: node tmp/verify-aab.mjs [aab] [build]
 * A mérés a **csomag tartalmát** ellenőrzi: verziókód, termelési AdMob ID,
 * aláírás, a szótár kulcsai (a kiadás új kulcsaival) és a changelog-sorok
 * mindhárom ABI-ban.
 */
const AAB = process.argv[2] ?? 'build/HUHS-v1.0.0+365-release.aab';
const BUILD = Number.parseInt(process.argv[3] ?? '365', 10);
const OUT = `tmp/aabcheck-${BUILD}`;

let failures = 0;
const check = (label, ok, detail = '') => {
  if (!ok) failures += 1;
  console.log(`  ${ok ? 'OK  ' : 'HIBA'} ${label}${detail ? ` — ${detail}` : ''}`);
};

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });

const bytes = fs.readFileSync(AAB);
const sha = crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
console.log(`csomag: ${AAB}`);
console.log(`méret: ${bytes.length} bájt (${(bytes.length / 1024 / 1024).toFixed(2)} MB)`);
console.log(`SHA-256: ${sha}\n`);

const manifest = fs.readFileSync(
  'build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml',
  'utf8',
);
check(
  `verziókód = ${BUILD}`,
  /android:versionCode="(\d+)"/.exec(manifest)?.[1] === String(BUILD),
  /android:versionCode="(\d+)"/.exec(manifest)?.[1],
);
check('versionName = 1.0.0', /android:versionName="1.0.0"/.test(manifest));
check('termelési AdMob App ID bent van', manifest.includes('ca-app-pub-7714662594685378~1123886696'));
check('teszt AdMob App ID NINCS bent', !manifest.includes('ca-app-pub-3940256099942544'));

const entries = execFileSync('tar', ['-tf', AAB], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 })
  .split('\n')
  .map((line) => line.trim())
  .filter(Boolean);
check('aláírás bent van', entries.some((entry) => entry.startsWith('META-INF/HUHS-UPL')));

const dictionaryEntry = entries.find((entry) => entry.endsWith('assets/i18n/en.json'));
execFileSync('tar', ['-xf', AAB, '-C', OUT, dictionaryEntry], { maxBuffer: 64 * 1024 * 1024 });
const dictionary = JSON.parse(fs.readFileSync(`${OUT}/${dictionaryEntry}`, 'utf8'));
const keyCount = Object.keys(dictionary).length;
check('a szótár legalább 1128 kulcsú', keyCount >= 1128, `${keyCount} kulcs`);

// ⚠️ 369: az ÉRTESÍTÉS-katalógus is az appban van (a megjelenítéskori fordításhoz).
const catalogEntry = entries.find((entry) => entry.endsWith('assets/i18n/notification_texts.json'));
check('az értesítés-katalógus be van csomagolva', Boolean(catalogEntry), String(catalogEntry));
if (catalogEntry) {
  execFileSync('tar', ['-xf', AAB, '-C', OUT, catalogEntry], { maxBuffer: 64 * 1024 * 1024 });
  const catalog = JSON.parse(fs.readFileSync(`${OUT}/${catalogEntry}`, 'utf8'));
  const kinds = Object.keys(catalog.kinds ?? {});
  check('az értesítés-katalógusban legalább 36 típus van', kinds.length >= 36, `${kinds.length} típus`);
  check(
    'a privát üzenet típusa is benne van (angolul is)',
    catalog.kinds?.private_message?.en?.title === '{name} sent you a message',
    JSON.stringify(catalog.kinds?.private_message?.en?.title),
  );
}

for (const [key, expected] of [
  ['Bulizó', 'Partyface'],
  ['Kezdő ütem', 'First Beat'],
  ['{n} pont', '{n} points'],
  ['Közösség', 'Community'],
  ['Partyajánló', 'Party Guide'],
  ['Zene', 'Music'],
  ['DJ-k', 'DJs'],
  ['Nyeremény', 'Prize'],
  ['Élő adás', 'Live broadcast'],
  // 367: a játék-eredmény címkéi és a válasz-előnézet (a mért magyar maradványok).
  ['Játék eredményei', 'Game results'],
  ['JÁTÉK EREDMÉNYEI', 'GAME RESULTS'],
  [' (eddig: {d})', ' (until {d})'],
  ['Válasz {name} üzenetére: {text}', "Reply to {name}'s message: {text}"],
  // 368: a kiadási jegyzet fordításai (a teljes előzmény angolul).
  ['Ehhez a verzióhoz ({n}) még nincs kiadási jegyzet.', 'There are no release notes for version {n} yet.'],
  [
    'Javítva: angol felületen a kiadási jegyzet (Névjegy → Újdonságok) is angolul jelenik meg — a teljes előzmény, a legkorábbi kiadásokig visszamenőleg.',
    'Fixed: on the English interface the release notes (About → What is new) appear in English as well — the full history, back to the earliest releases.',
  ],
]) {
  check(`szótár: ${JSON.stringify(key)} → ${JSON.stringify(expected)}`, dictionary[key] === expected, String(dictionary[key]));
}

const contains = (buffer, text) =>
  ['utf8', 'latin1', 'utf16le'].filter((encoding) => buffer.includes(Buffer.from(text, encoding))).join('|') ||
  'NINCS';

const changelog = [
  'a kiadványok dátum-címkéje',
  'nyelvváltáskor a betöltött tartalom',
  'A GYÍK neve angolul',
  'a főoldal és a Hírek fül listája magától frissül',
  'a válasz idézetére koppintva az app ODAUGRLIK az eredeti üzenetre',
  'a „Bulizó" szerepkör felirata mostantól „Partyface"',
  // 367: a játék-eredmény fejléc, a válasz-előnézet és a szótár-elérhetőség.
  'a játék eredményei képernyő fejléce',
  'a válasz-előnézet is angolul szól',
  'az adatvédelmi tájékoztató és a Saját zenék súgóinak mondatai',
  // 368: a kiadási jegyzet angolul. ⚠️ A MAGYAR sor a Dart-literál (ezért van a
  // snapshotban); az ANGOL fordítás az `assets/i18n/en.json`-ban él, ezért azt a
  // fenti szótár-ellenőrzés méri (a snapshotban nem is lehetne megtalálni).
  'a kiadási jegyzet (Névjegy → Újdonságok) is angolul jelenik meg',
  // 369: az értesítések nyelve (a megjelenítéskori fordítás).
  'angol felületen az értesítések szövege azonnal a választott nyelven jelenik meg',
  // 370: az értesítésben a cikk címe is a választott nyelven.
  'az értesítésben a cikk (és a kiadás, esemény, DJ) címe is a választott nyelven',
];
for (const entry of entries.filter((item) => /^base\/lib\/.*\/libapp\.so$/.test(item))) {
  execFileSync('tar', ['-xf', AAB, '-C', OUT, entry], { maxBuffer: 64 * 1024 * 1024 });
  const buffer = fs.readFileSync(`${OUT}/${entry}`);
  const abi = entry.split('/')[2];
  for (const text of changelog) {
    check(`${abi}: changelog-sor bent van (${text.slice(0, 34)}…)`, contains(buffer, text) !== 'NINCS');
  }
  for (const symbol of ['newsRevalidateInterval', 'revalidatePosts', 'homeHeaderLabelWidth']) {
    console.log(`  info ${abi}: ${symbol}=${contains(buffer, symbol)}`);
  }
}

console.log(`\n${failures === 0 ? 'MINDEN ELLENŐRZÉS RENDBEN' : `HIBA — ${failures} ellenőrzés bukott`}`);
process.exitCode = failures === 0 ? 0 : 1;
