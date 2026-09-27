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
check('a szótár legalább 1300 kulcsú', keyCount >= 1300, `${keyCount} kulcs`);
// ⚠️ 374: a tulajdonos KONKRÉT jelzése — a „Saját zenéim" fejlécében angol
// módban is magyarul maradt a letöltött zenék száma. A kulcsnak a **csomagolt**
// szótárban kell lennie (a megjelenítés ebből fordít).
check(
  'a „letöltött zene" kulcs a csomagolt szótárban angolul szól',
  `${dictionary['{n} letöltött zene'] ?? ''}`.toLowerCase().includes('downloaded'),
  `${dictionary['{n} letöltött zene'] ?? 'HIÁNYZIK'}`,
);
check(
  'a tárolt állapotüzenetek kulcsai is bent vannak',
  ['Mentés…', 'Küldés…', 'TÖRLÉS', 'Kötelező mező.'].every((key) =>
    Object.prototype.hasOwnProperty.call(dictionary, key),
  ),
);
// ⚠️ 375: az „ékezet nélkül is magyar" címke és a kivétel-üzenetek.
check(
  'a „WAV (ingyenes)" kulcs a csomagolt szótárban angolul szól',
  `${dictionary['WAV (ingyenes)'] ?? ''}`.toLowerCase().includes('free'),
  `${dictionary['WAV (ingyenes)'] ?? 'HIÁNYZIK'}`,
);
check(
  'a kivétel-üzenetek kulcsai is bent vannak (a `userFacingError` fordítja)',
  [
    'A beszélgetés törléséhez bejelentkezés szükséges.',
    'Az üzenet 1–2000 karakter lehet.',
    'A felhasználó nem található.',
    'Nem sikerült kapcsolódni. Ellenőrizd az internetkapcsolatot.',
  ].every((key) => Object.prototype.hasOwnProperty.call(dictionary, key)),
);

// ⚠️ 369: az ÉRTESÍTÉS-katalógus is az appban van (a megjelenítéskori fordításhoz).
const catalogEntry = entries.find((entry) => entry.endsWith('assets/i18n/notification_texts.json'));
check('az értesítés-katalógus be van csomagolva', Boolean(catalogEntry), String(catalogEntry));
if (catalogEntry) {
  execFileSync('tar', ['-xf', AAB, '-C', OUT, catalogEntry], { maxBuffer: 64 * 1024 * 1024 });
  const catalog = JSON.parse(fs.readFileSync(`${OUT}/${catalogEntry}`, 'utf8'));
  const kinds = Object.keys(catalog.kinds ?? {});
  check('az értesítés-katalógusban legalább 42 típus van', kinds.length >= 42, `${kinds.length} típus`);
  check(
    'a születésnapi köszöntés is bent van (angolul is)',
    catalog.kinds?.birthday?.en?.title === 'Happy birthday! 🎂' &&
      String(catalog.kinds?.birthday?.en?.body || '').includes('{greeting}'),
    JSON.stringify(catalog.kinds?.birthday?.en?.title),
  );
  check(
    'a privát üzenet típusa is benne van (angolul is)',
    catalog.kinds?.private_message?.en?.title === '{name} sent you a message',
    JSON.stringify(catalog.kinds?.private_message?.en?.title),
  );
  // ⚠️ 376: a gyermekbiztonsági jelzés (rendszer) és a születési dátum kérése —
  // mindkettő a beépített katalógusból fordul a megjelenítéskor.
  check(
    'a gyermekbiztonsági jelzés típusai bent vannak (súlyosságonként, angolul is)',
    catalog.kinds?.child_safety_flag_high?.en?.title === 'Child safety alert (high)' &&
      catalog.kinds?.child_safety_flag_medium?.en?.title === 'Child safety alert (medium)' &&
      catalog.kinds?.child_safety_flag_low?.en?.title === 'Child safety alert (low)' &&
      catalog.kinds?.child_safety_flag?.en?.title === 'Child safety alert',
    JSON.stringify(catalog.kinds?.child_safety_flag_high?.en?.title),
  );
  check(
    'a születési dátum kérése is bent van (angolul is)',
    catalog.kinds?.birth_date_required?.en?.title === 'Please add your date of birth',
    JSON.stringify(catalog.kinds?.birth_date_required?.en?.title),
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
  // 376: a gyermekbiztonsági kör szövegei (a rendszer jelzése és a dátum kérése).
  ['Gyermekbiztonsági jelzés', 'Child safety alert'],
  [
    'Add meg a születési dátumodat. A közösségi funkciók 16 éves kortól használhatók, és a dátum a kiskorúak védelmét szolgálja.',
    'Add your date of birth. The community features are available from the age of 16, and the date helps us protect minors.',
  ],
  [
    'A születési dátum elmentve.',
    'Your date of birth has been saved.',
  ],
  [
    'Figyelem: a beszélgetőpartnered nagykorú. Ha kellemetlenül érzed magad, jelentsd a felhasználót és blokkold.',
    'Warning: your chat partner is an adult. If you feel uncomfortable, report the user and block them.',
  ],
  // A 376 changelog-sorai is (a felhasználó a Névjegyben látja).
  [
    'ÚJ: a regisztrációhoz mostantól kötelező a születési dátum, és 16 éves kortól lehet regisztrálni.',
    'NEW: a date of birth is now required for registration, and you can register from the age of 16.',
  ],
  [
    'ÚJ: a privát beszélgetésben is bejelentheted a másik felet (a blokkolás és a törlés mellett).',
    'NEW: you can now report the other person in a private conversation (next to blocking and deleting).',
  ],
  // 377: a Label-termékek szövege (a tulajdonos jelzése) és a születésnapi köszöntés.
  [
    'Hungarian Hardstyle {variant} letöltés: {title}',
    'Hungarian Hardstyle {variant} download: {title}',
  ],
  [
    'Javítva: angol felületen a Label-termékek leírása is angolul szól (eddig magyarul maradt).',
    'Fixed: the Label product descriptions are now in English on the English interface (they used to stay Hungarian).',
  ],
  [
    'Javítva: a Label fül és a többi lista görgetése nem ugrik vissza a tetejére háttér-frissítéskor.',
    'Fixed: scrolling on the Label tab and other lists no longer jumps back to the top during a background refresh.',
  ],
  [
    'ÚJ: akinek születésnapja van, az aznap köszöntő értesítést kap.',
    'NEW: members get a birthday greeting notification on their birthday.',
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
  // 371: a @mindenki push + a küldő visszajelzése + a hírlista nyelvváltása.
  'a Chat @mindenki értesítéséhez mostantól push (banner) is jön',
  'A @mindenki küldője visszajelzést kap',
  'nyelvváltáskor a hírek listája is azonnal átáll',
  // 372: a megnyitott adatlapok is átállnak nyelvváltáskor.
  'nyelvváltáskor a már megnyitott cikk-, esemény- és kiadvány-adatlap',
  // 373: a &amp; kódolási hiba, az angol feliratok és a pont-sablon.
  'nem látszik többé a „&amp;" kódolási hiba',
  'az éves név-/e-mail-módosítás jelzése',
  'eltűnt a szóismétlés',
  // 374: a „Saját zenéim" fejléce (a tulajdonos jelzése), a lejátszó gombjai,
  // a törlés-megerősítés szava és az e-mail-űrlapok tárgya.
  'a „Saját zenéim" fejlécében angol felületen is angolul szól',
  'a lejátszó két gombja (szünet, keverés)',
  'a feliraton látható szót kéri (DELETE)',
  'a booking- és hibajelentő e-mail tárgya',
  // 375: a WAV (ingyenes), a @mindenki keveredése és a hibaüzenetek nyelve.
  'a „WAV (ingyenes)" felirat is angolul szól',
  'a @mindenki értesítés szövege nem keveredik',
  'a régi (a szóismétlés javítása előtt kelt) pont-értesítések',
  'angol felületen a hibaüzenetek is angolul szólnak',
  // 376: a születési dátum, a 16+ korhatár, a privát jelentés és a figyelmeztető sáv.
  'kötelező a születési dátum',
  'a privát beszélgetésben is bejelentheted a másik felet',
  'ha a partnered nagykorú',
  // 377: a Label-termékek szövege, a görgetés megtartása, a születésnapi köszöntés.
  'a Label-termékek leírása is angolul szól',
  'nem ugrik vissza a tetejére háttér-frissítéskor',
  'az aznap köszöntő értesítést kap',
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
