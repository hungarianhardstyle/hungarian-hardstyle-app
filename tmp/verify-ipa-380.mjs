// A 380-as iOS csomag (CI-artefakt) TARTALMI bizonyítéka — a reklám-identitáson túl.
//
// MIT MÉR:
//   1. a 380-as changelog MINDEN sora benne van a befordított Dart-részben
//      (a `lib/data/app_changelog.dart`-ból olvasva — nem kézzel beírva!),
//   2. a szótár egy ANGOL fordítása is benne van (vagyis nem csak magyarul szól),
//   3. az `Info.plist` a 380-as buildet és az 1.0.0 verziót viseli.
// Így a „benne van" állítás nem emlékezetből, hanem a forrásból származik.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const app = process.argv[2] ?? 'build/ios-ipa-380/extract/Payload/Runner.app';
const build = process.argv[3] ?? '380';

// 1) A changelog sorai a FORRÁSBÓL.
const changelog = fs.readFileSync('lib/data/app_changelog.dart', 'utf8');
const block = new RegExp(`build: ${build},[\\s\\S]*?changes: \\[([\\s\\S]*?)\\],\\r?\\n  \\)`).exec(changelog);
if (!block) throw new Error(`nincs changelog szakasz a ${build} buildhez`);
const lines = [...block[1].matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((m) => m[1].replace(/\\'/g, "'"));
console.log(`a ${build}-as changelog ${lines.length} sora (a forrásból):`);
for (const line of lines) console.log(`  - ${line.slice(0, 80)}${line.length > 80 ? '…' : ''}`);

// 2) Egy angol fordítás a szótárból — a bizonyíték arra, hogy a csomag kétnyelvű.
const en = JSON.parse(fs.readFileSync('assets/i18n/en.json', 'utf8'));
const digestKey = 'Heti összefoglaló';
const digestEn = en[digestKey];
if (!digestEn) throw new Error(`a szótárban nincs ilyen kulcs: ${digestKey}`);
console.log(`\nszótár-bizonyíték: «${digestKey}» -> «${digestEn}»`);

const contains = [...lines, digestKey, digestEn];
const args = [app, '--test-ads', ...contains.map((text) => `--contains=${text}`)];
let failed = 0;
try {
  const out = execFileSync(process.execPath, ['tools/verify-ios-ipa.mjs', ...args], {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  process.stdout.write(out);
  failed = /ELHASALT/.test(out) ? 1 : 0;
} catch (error) {
  process.stdout.write(error.stdout ?? '');
  process.stderr.write(error.stderr ?? String(error));
  failed = 1;
}

// 3) Az Info.plist buildje és verziója — IGAZI plist-olvasóval.
// ⚠️ MÉRT ESZKÖZ-HIBA (a sajátom, 2026-09-28): először a „kulcs közelében keresem
// az értéket" heurisztikát használtam, ami a **bináris plist** elrendezésében
// hamis „HIBA"-t adott (a kulcs és az érték objektuma külön táblában van). Ezért
// most a plistet valóban kiolvassuk, és a végén egy ismert kulccsal
// (`CFBundleIdentifier`) ellenőrizzük, hogy az olvasó JÓL működik.
function readBinaryPlist(buf) {
  if (buf.subarray(0, 8).toString('ascii') !== 'bplist00') {
    throw new Error('nem bináris plist (bplist00) — az olvasó erre az alakra készült');
  }
  const trailer = buf.subarray(buf.length - 32);
  const offsetIntSize = trailer[6];
  const objectRefSize = trailer[7];
  const numObjects = Number(trailer.readBigUInt64BE(8));
  const topObject = Number(trailer.readBigUInt64BE(16));
  const offsetTableOffset = Number(trailer.readBigUInt64BE(24));
  const readUInt = (at, size) => {
    let value = 0;
    for (let i = 0; i < size; i += 1) value = value * 256 + buf[at + i];
    return value;
  };
  const offsets = [];
  for (let i = 0; i < numObjects; i += 1) {
    offsets.push(readUInt(offsetTableOffset + i * offsetIntSize, offsetIntSize));
  }
  const utf16beToString = (bytes) => {
    const swapped = Buffer.from(bytes);
    for (let i = 0; i + 1 < swapped.length; i += 2) {
      const tmp = swapped[i];
      swapped[i] = swapped[i + 1];
      swapped[i + 1] = tmp;
    }
    return swapped.toString('utf16le');
  };
  const parseObject = (index, depth = 0) => {
    if (depth > 32) throw new Error('túl mély plist-szerkezet');
    const offset = offsets[index];
    const marker = buf[offset];
    const type = marker >> 4;
    let length = marker & 0x0f;
    let cursor = offset + 1;
    if (length === 0x0f && type !== 0x1 && type !== 0x2) {
      const sizeMarker = buf[cursor];
      const sizeBytes = 1 << (sizeMarker & 0x0f);
      length = readUInt(cursor + 1, sizeBytes);
      cursor += 1 + sizeBytes;
    }
    switch (type) {
      case 0x0:
        return marker === 0x09;
      case 0x1:
        return readUInt(cursor, 1 << length);
      case 0x2:
        return (1 << length) === 4 ? buf.readFloatBE(cursor) : buf.readDoubleBE(cursor);
      case 0x3:
        return buf.readDoubleBE(cursor);
      case 0x4:
        return buf.subarray(cursor, cursor + length);
      case 0x5:
        return buf.subarray(cursor, cursor + length).toString('latin1');
      case 0x6:
        return utf16beToString(buf.subarray(cursor, cursor + length * 2));
      case 0x8:
        return readUInt(cursor, length + 1);
      case 0xa:
      case 0xc: {
        const items = [];
        for (let i = 0; i < length; i += 1) {
          items.push(parseObject(readUInt(cursor + i * objectRefSize, objectRefSize), depth + 1));
        }
        return items;
      }
      case 0xd: {
        const dict = {};
        const valueBase = cursor + length * objectRefSize;
        for (let i = 0; i < length; i += 1) {
          const key = parseObject(readUInt(cursor + i * objectRefSize, objectRefSize), depth + 1);
          dict[key] = parseObject(readUInt(valueBase + i * objectRefSize, objectRefSize), depth + 1);
        }
        return dict;
      }
      default:
        throw new Error(`ismeretlen plist-típus: 0x${type.toString(16)}`);
    }
  };
  return parseObject(topObject);
}

const plistBytes = fs.readFileSync(path.join(app, 'Info.plist'));
const plist = readBinaryPlist(plistBytes);
const sanity = plist.CFBundleIdentifier === 'hu.hungarianhardstyle.app';
console.log(`  ${sanity ? 'OK  ' : 'HIBA'}  Info.plist olvasó önellenőrzése  CFBundleIdentifier = ${plist.CFBundleIdentifier ?? '(nincs)'}`);
if (!sanity) {
  console.log('        ⚠️ az olvasó hibásnak tűnik — a lenti sorok NEM a buildről szólnak, hanem az eszközről');
  failed += 1;
}
for (const [key, value] of [['CFBundleVersion', build], ['CFBundleShortVersionString', '1.0.0']]) {
  const actual = plist[key];
  const ok = String(actual) === value;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'OK  ' : 'HIBA'}  Info.plist ${key.padEnd(26)} = ${actual ?? '(nincs)'}${ok ? '' : `  (várt: ${value})`}`);
}

console.log(failed === 0 ? '\nMINDEN ELLENORZES RENDBEN' : `\n${failed} ELLENORZES ELHASALT`);
process.exitCode = failed ? 1 : 0;
