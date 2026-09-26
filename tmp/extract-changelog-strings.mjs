// A `lib/data/app_changelog.dart` változás-sorainak kinyerése (kulcs = a magyar szöveg).
//
// MIÉRT: a changelog a Névjegyben angol felületen is magyarul jelent meg, mert a
// kiírás nyers (`Text(change)`), és a szövegek nincsenek a szótárban. A javításhoz
// a szótárba kell tenni a magyar sorokat — ehhez kellenek pontosan a forrásban
// szereplő literálok (escape-feloldással, hogy a kulcs a futásidejű szöveg legyen).
import fs from 'node:fs';

const source = fs.readFileSync('lib/data/app_changelog.dart', 'utf8');

/** Egy Dart egyszeres idézőjeles literál beolvasása a `start` pozíciótól. */
function readLiteral(text, start) {
  let index = start + 1;
  let out = '';
  while (index < text.length) {
    const char = text[index];
    if (char === '\\') {
      const next = text[index + 1];
      const escapes = { n: '\n', r: '\r', t: '\t', "'": "'", '"': '"', '\\': '\\', $: '$' };
      out += Object.prototype.hasOwnProperty.call(escapes, next) ? escapes[next] : next;
      index += 2;
      continue;
    }
    if (char === "'") return { value: out, end: index + 1 };
    out += char;
    index += 1;
  }
  throw new Error('lezárás nélküli literál');
}

const entries = [];
const entryRegex = /AppReleaseNotes\(\s*version:\s*'([^']*)',\s*build:\s*(\d+),\s*changes:\s*\[/g;
let match;
while ((match = entryRegex.exec(source)) !== null) {
  const build = Number(match[2]);
  let index = match.index + match[0].length;
  const changes = [];
  // A `changes` lista végéig: literálok, vesszők, majd `]`.
  while (index < source.length) {
    while (index < source.length && /[\s,]/.test(source[index])) index += 1;
    if (source[index] === ']') break;
    if (source[index] !== "'") {
      throw new Error(`váratlan karakter a(z) ${build} listájában: ${JSON.stringify(source.slice(index, index + 40))}`);
    }
    const literal = readLiteral(source, index);
    changes.push(literal.value);
    index = literal.end;
  }
  entries.push({ build, changes });
}

const all = entries.flatMap((entry) => entry.changes);
const unique = [...new Set(all)];
const charCount = unique.reduce((sum, text) => sum + text.length, 0);

console.log(`bejegyzések: ${entries.length}`);
console.log(`változás-sorok: ${all.length}, egyedi: ${unique.length}`);
console.log(`összes karakter (egyedi): ${charCount}`);
console.log(`leghosszabb: ${Math.max(...unique.map((text) => text.length))} karakter`);
const duplicates = unique.filter((text) => all.filter((item) => item === text).length > 1);
console.log(`többször szereplő sor: ${duplicates.length}${duplicates.length ? ` — pl. ${JSON.stringify(duplicates[0].slice(0, 60))}` : ''}`);

fs.writeFileSync('tmp/changelog-hu.json', `${JSON.stringify(unique, null, 2)}\n`, 'utf8');
console.log('kiírva: tmp/changelog-hu.json');
