// MIÉRT nem találja az IPA-merő a 380-as changelog ELSŐ két sorát?
// (A harmadik megvan — ezért nem tippelünk, hanem kódolásonként és darabonként mérünk.)
import fs from 'node:fs';

const app = process.argv[2] ?? 'build/ios-ipa-380/extract/Payload/Runner.app';
const file = `${app}/Frameworks/App.framework/App`;
const buffer = fs.readFileSync(file);

const needles = [
  'ÚJ: értesítést kapsz, ha a kedvelt DJ-d új kiadványt tesz közzé, vagy a kedvelt szerveződ új eseményt hirdet.',
  'ÚJ: értesítést kapsz, ha a kedvelt DJ-d',
  'értesítést kapsz, ha a kedvelt',
  'ÚJ: értesítést kapsz',
  'ÚJ: a DJ adatlapján is kedvencelheted',
  'ÚJ: a DJ adatlapján',
  'adatlapján is kedvencelheted (követheted) a DJ-t',
  'ÚJ: a Beállításokban külön ki-be kapcsolhatod',
  'kapcsolhatod a vasárnapi heti összefoglalót.',
];

// ⚠️ A Node NEM ismeri a `utf16be` kódolást (`ERR_UNKNOWN_ENCODING`) — a
// big-endian alakot a little-endian bájtjainak megfordításával állítjuk elő.
function utf16beOf(text) {
  const le = Buffer.from(text, 'utf16le');
  for (let i = 0; i + 1 < le.length; i += 2) {
    const tmp = le[i];
    le[i] = le[i + 1];
    le[i + 1] = tmp;
  }
  return le;
}

for (const needle of needles) {
  const utf8 = buffer.indexOf(Buffer.from(needle, 'utf8'));
  const utf16le = buffer.indexOf(Buffer.from(needle, 'utf16le'));
  const utf16be = buffer.indexOf(utf16beOf(needle));
  const latin1 = buffer.indexOf(Buffer.from(needle, 'latin1'));
  const found = utf8 >= 0 || utf16le >= 0 || utf16be >= 0 || latin1 >= 0;
  console.log(
    `${found ? 'MEGVAN' : 'nincs '}  utf8=${utf8} utf16le=${utf16le} utf16be=${utf16be} latin1=${latin1}  «${needle.slice(0, 60)}»`,
  );
}

// Az „ÚJ: " előtag és az em-dash külön ellenőrzése: hátha a bináris máshogy tárolja.
console.log('\n--- karakter-szintű próba (a 2. sor em-dash-e) ---');
for (const needle of ['—', 'DJ-t — eddig', 'DJ-t ', 'eddig csak a listában']) {
  const utf8 = buffer.indexOf(Buffer.from(needle, 'utf8'));
  const utf16le = buffer.indexOf(Buffer.from(needle, 'utf16le'));
  console.log(`${utf8 >= 0 || utf16le >= 0 ? 'MEGVAN' : 'nincs '}  «${needle}»  utf8=${utf8} utf16le=${utf16le}`);
}
