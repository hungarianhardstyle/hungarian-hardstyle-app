#!/usr/bin/env node
// Bitmap-alul-mintavételezés vizsgáló (CSAK OLVAS).
//
// A Play Console időnként ezt a javaslatot adja ki:
//   „Az alkalmazás teljesítményének javítása bittérkép alul-mintavételezésével —
//    Alkalmazásod a következő helyeken használja a(z) BitmapFactory paramétert
//    alul-mintavételezés nélkül: <osztaly>.<metodus>"
// A Play a fedett (obfuszkált) nevet írja, ezért ezzel az eszközzel az IDEKÜLDÖTT
// csomagból visszafejthető, hogy PONTOSAN melyik osztály az, kié (melyik SDK), és
// hogy a saját kódunk érintett-e egyáltalán.
//
// Módok:
//   1) csomag + mapping (ez válaszolja meg a Play jelzését):
//      node tools/check-bitmap-subsampling.mjs --aab build/HUHS-v1.0.0+353-release.aab
//      (a mapping alapból: build/app/outputs/mapping/release/mapping.txt)
//   2) SDK-verziók összevetése (javít-e egy library-emelés?):
//      node tools/check-bitmap-subsampling.mjs --aar play-services-ads-25.4.0.aar --aar play-services-ads-25.5.0.aar
//   3) önteszt: node tools/check-bitmap-subsampling.mjs --self-test
//
// ⚠️ ŐSZINTE KORLÁT: a DEX-mód a `dexdump`-ot használja (Android SDK build-tools),
// és a `--aar`/`--jar` mód a .class konstans-táblájában keres (ez erős, de nem
// teljes bytecode-elemzés): azt jelzi, hogy az osztály hívja-e a BitmapFactory
// paraméter NÉLKÜLI alakját, és hogy ő maga állít-e inSampleSize-t. Ha az
// `Options`-t egy MÁSIK osztály tölti fel inSampleSize-szel, az itt nem látszik —
// ezért a jelentés mindig kiírja ezt a korlátot.

import { readFileSync, writeFileSync, existsSync, readdirSync, createReadStream, unlinkSync } from 'node:fs';
import { inflateRawSync } from 'node:zlib';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import path from 'node:path';

const args = process.argv.slice(2);
const flagValues = (name) => args.flatMap((a, i) => (a === name && args[i + 1] ? [args[i + 1]] : []));
const flag = (name) => args.includes(name);
const asJson = flag('--json');

// ---------------------------------------------------------------- ZIP olvasó
export function zipEntries(buf) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= 0 && i > buf.length - 70000; i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('nem ZIP (nincs EOCD)');
  const count = buf.readUInt16LE(eocd + 10);
  let off = buf.readUInt32LE(eocd + 16);
  const out = [];
  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) throw new Error('rossz központi könyvtár-fejléc');
    const method = buf.readUInt16LE(off + 10);
    const compSize = buf.readUInt32LE(off + 20);
    const nameLen = buf.readUInt16LE(off + 28);
    const extraLen = buf.readUInt16LE(off + 30);
    const commentLen = buf.readUInt16LE(off + 32);
    const localOff = buf.readUInt32LE(off + 42);
    const name = buf.toString('utf8', off + 46, off + 46 + nameLen);
    out.push({ name, method, compSize, localOff });
    off += 46 + nameLen + extraLen + commentLen;
  }
  return out;
}

export function readZipEntry(buf, entry) {
  const nameLen = buf.readUInt16LE(entry.localOff + 26);
  const extraLen = buf.readUInt16LE(entry.localOff + 28);
  const start = entry.localOff + 30 + nameLen + extraLen;
  const raw = buf.subarray(start, start + entry.compSize);
  if (entry.method === 0) return raw;
  if (entry.method === 8) return inflateRawSync(raw);
  throw new Error('ismeretlen tömörítés: ' + entry.method);
}

// ------------------------------------------------- .class konstans-tábla elemzés
const PLAIN_STREAM = '(Ljava/io/InputStream;)Landroid/graphics/Bitmap;';
const PLAIN_BYTES = '([BII)Landroid/graphics/Bitmap;';
const PLAIN_FILE = '(Ljava/lang/String;)Landroid/graphics/Bitmap;';
const OPTIONS_TYPE = 'Landroid/graphics/BitmapFactory$Options;';

const contains = (buf, s) => buf.indexOf(Buffer.from(s, 'utf8')) !== -1;

/** Egy .class bájtjai → null (nem érintett) vagy { plain, sample, options }. */
export function analyzeClassBytes(buf) {
  if (!contains(buf, 'BitmapFactory')) return null;
  const plain =
    (contains(buf, 'decodeStream') && contains(buf, PLAIN_STREAM)) ||
    (contains(buf, 'decodeByteArray') && contains(buf, PLAIN_BYTES)) ||
    (contains(buf, 'decodeFile') && contains(buf, PLAIN_FILE));
  if (!plain) return null;
  return { plain: true, sample: contains(buf, 'inSampleSize'), options: contains(buf, OPTIONS_TYPE) };
}

/** AAR/JAR → a BitmapFactory-t alul-mintavételezés nélkül hívó osztályok. */
export function scanClassContainer(buf, isAar) {
  let jar = buf;
  if (isAar) {
    const e = zipEntries(buf).find((x) => x.name === 'classes.jar');
    if (!e) throw new Error('az AAR-ban nincs classes.jar');
    jar = readZipEntry(buf, e);
  }
  const found = [];
  for (const e of zipEntries(jar)) {
    if (!e.name.endsWith('.class')) continue;
    const info = analyzeClassBytes(readZipEntry(jar, e));
    if (info) found.push({ name: e.name.replace(/\.class$/, '').replace(/\//g, '.'), ...info });
  }
  return found;
}

// ------------------------------------------------------------ dexdump szöveg
const INVOKE_RE = /BitmapFactory;\.(\w+):(\([^)]*\)[^\s]*)/;

/** Egy dexdump-sor BitmapFactory-hívása → { plain } vagy null. */
export function classifyDexInvoke(line) {
  const m = INVOKE_RE.exec(line);
  if (!m) return null;
  const [, method, desc] = m;
  const plain =
    (method === 'decodeStream' && desc === PLAIN_STREAM) ||
    (method === 'decodeByteArray' && desc === PLAIN_BYTES) ||
    (method === 'decodeFile' && desc === PLAIN_FILE);
  return { plain };
}

/** Állapotgép a dexdump kimenetéhez — soronként etethető, nem kell memóriába gyűjteni. */
export function createDexdumpParser() {
  const classes = new Map();
  let current = null;
  return {
    push(line) {
      const cls = /^\s*Class descriptor\s*:\s*'(.*)'/.exec(line);
      if (cls) {
        current = cls[1].replace(/^L/, '').replace(/;$/, '').replace(/\//g, '.');
        if (!classes.has(current)) classes.set(current, { plain: false, sample: false });
        return;
      }
      if (!current) return;
      const rec = classes.get(current);
      const inv = classifyDexInvoke(line);
      if (inv?.plain) rec.plain = true;
      if (line.includes('inSampleSize')) rec.sample = true;
    },
    result: () => classes,
  };
}

/** dexdump -d sorai → Map(obfuszkált osztály → { plain, sample }). */
export function parseDexdumpLines(lines) {
  const parser = createDexdumpParser();
  for (const line of lines) parser.push(line);
  return parser.result();
}

// ------------------------------------------- R8-mapping (obfuszkált ↔ eredeti)
export function resolveMappingLines(lines, wanted) {
  const byObfuscated = new Map();
  const byOriginal = new Map();
  const re = /^(\S+) -> ([^:\s]+):$/;
  for (const line of lines) {
    const m = re.exec(line);
    if (!m) continue;
    const [, original, obfuscated] = m;
    if (wanted.has(obfuscated)) byObfuscated.set(obfuscated, original);
    if (wanted.has(original)) byOriginal.set(original, obfuscated);
  }
  return { byObfuscated, byOriginal };
}

// ------------------------------------------------------------------ jelentés
const OWNER_RULES = [
  [/^com\.google\.android\.gms\.internal\.ads/, 'Google Mobile Ads SDK (play-services-ads)'],
  [/^com\.google\.android\.gms\.internal\.play_billing/, 'Google Play Billing'],
  [/^com\.google\.android\.gms/, 'Google Play services'],
  [/^com\.google\.firebase\.messaging/, 'Firebase Messaging'],
  [/^com\.google\.firebase/, 'Firebase'],
  [/^io\.flutter\.embedding/, 'Flutter engine'],
  [/^io\.flutter\.plugins\./, 'Flutter plugin'],
  [/^com\.ryanheise\.audioservice/, 'audio_service plugin'],
  [/^androidx\./, 'AndroidX'],
  [/^com\.google\.crypto\.tink/, 'Tink (Google crypto)'],
  [/^_COROUTINE/, 'R8 által összevont szintetikus osztály'],
  [/^hu\.hungarianhardstyle/, 'A MI APPUNK'],
  [/^hu\.hungarianhardstyle\.app\./, 'A MI APPUNK'],
];

export function ownerOf(name) {
  for (const [re, label] of OWNER_RULES) if (re.test(name)) return label;
  const parts = name.split('.');
  return parts.length >= 2 ? parts.slice(0, 2).join('.') : name;
}

export function isOurs(name) {
  return /^hu\.hungarianhardstyle/.test(name);
}

export function summarize(entries) {
  const withoutSample = entries.filter((e) => !e.sample);
  const groups = new Map();
  for (const e of withoutSample) {
    const owner = ownerOf(e.original ?? e.name);
    if (!groups.has(owner)) groups.set(owner, []);
    groups.get(owner).push(e);
  }
  return {
    total: entries.length,
    withoutSample: withoutSample.length,
    ours: withoutSample.filter((e) => isOurs(e.original ?? e.name)).length,
    groups: [...groups.entries()]
      .map(([owner, items]) => ({ owner, count: items.length, items }))
      .sort((a, b) => b.count - a.count),
  };
}

export function reportText(result, limitPerGroup = 4) {
  const out = [];
  out.push(`Bitmap-alul-mintavételezés vizsgálat (csak olvasás) — ${result.source}`);
  if (result.dexes) out.push(`  DEX: ${result.dexes.join(', ')}`);
  out.push(`  BitmapFactory-t hívó osztály: ${result.total}`);
  out.push(`  ebből alul-mintavételezés nélkül: ${result.withoutSample}`);
  out.push(result.ours === 0
    ? '  ✔ A MI KÓDUNKBAN ilyen hely NINCS — a saját képeinket ez nem érinti.'
    : `  ⚠️ A MI KÓDUNKBAN ${result.ours} ilyen hely van — ezt meg kell nézni.`);
  out.push('');
  out.push('Kitől jön (alul-mintavételezés nélkül):');
  for (const g of result.groups) {
    out.push(`  ${String(g.count).padStart(3)} osztály  ${g.owner}`);
    for (const it of g.items.slice(0, limitPerGroup)) {
      const play = it.obfuscated ? `  (a Playen: ${it.obfuscated}.X)` : '';
      out.push(`        - ${it.original ?? it.name}${play}`);
    }
    if (g.items.length > limitPerGroup) out.push(`        … +${g.items.length - limitPerGroup} további`);
  }
  out.push('');
  out.push('⚠️ Korlát: a vizsgálat azt nézi, hogy az adott osztály hívja-e a BitmapFactory');
  out.push('   paraméter nélküli alakját, és ő maga állít-e inSampleSize-t. Ha az Options-t');
  out.push('   egy másik osztály tölti fel, az itt nem látszik. Nem a mi kódunkat érintő');
  out.push('   találatot nem lehet „megjavítani" fork nélkül — ilyenkor a helyes válasz a');
  out.push('   mérés rögzítése, és újramérés a következő SDK-emelésnél.');
  out.push('⚠️ Az R8 a kódot összevonhatja és inline-olhatja, ezért a kiírt (eredeti) osztálynév');
  out.push('   lehet az, amelyik a kódot BEFOGADTA, nem az, amelyikben eredetileg megírták');
  out.push('   (pl. androidx/tink név alatt AdMob-kód is lehet). Az SDK-hovatartozás ezért');
  out.push('   tájékoztató; a biztos pont a Playen megjelenő fedett név, amit ez az eszköz kiír.');
  out.push('⚠️ A Play a saját elemzését adja: a listája lehet szűkebb, mint az itteni találatok.');
  return out.join('\n');
}

// ----------------------------------------------------------------------- IO
function findDexdump(explicit) {
  if (explicit) return existsSync(explicit) ? explicit : null;
  const roots = [process.env.ANDROID_HOME, process.env.ANDROID_SDK_ROOT,
    process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'Android', 'Sdk') : null,
    'C:/Android/Sdk'].filter(Boolean);
  const exe = process.platform === 'win32' ? 'dexdump.exe' : 'dexdump';
  for (const root of roots) {
    const bt = path.join(root, 'build-tools');
    if (!existsSync(bt)) continue;
    const versions = readdirSync(bt).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
    for (const v of versions.reverse()) {
      const p = path.join(bt, v, exe);
      if (existsSync(p)) return p;
    }
  }
  return null;
}

function dexdumpParse(dexdump, dexPath) {
  return new Promise((resolve, reject) => {
    const child = spawn(dexdump, ['-d', dexPath], { stdio: ['ignore', 'pipe', 'pipe'] });
    const parser = createDexdumpParser();
    const rl = createInterface({ input: child.stdout });
    rl.on('line', (l) => parser.push(l));
    let err = '';
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (d) => { err += d; });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code !== 0) reject(new Error(`dexdump exit ${code}: ${err.slice(0, 300)}`));
      else resolve(parser.result());
    });
  });
}

function writeTemp(buf, name) {
  const dir = path.join(process.cwd(), 'tmp');
  if (!existsSync(dir)) throw new Error('nincs tmp/ könyvtár');
  const p = path.join(dir, name);
  writeFileSync(p, buf);
  return p;
}

async function scanAab(aabPath, mappingPath, dexdump) {
  const buf = readFileSync(aabPath);
  const dexEntries = zipEntries(buf).filter((e) => e.name.endsWith('.dex'));
  if (!dexEntries.length) throw new Error('a csomagban nincs DEX');
  const merged = new Map();
  const dexNames = [];
  for (const e of dexEntries) {
    const dexBuf = readZipEntry(buf, e);
    const p = writeTemp(dexBuf, path.basename(e.name));
    dexNames.push(e.name);
    const parsed = await dexdumpParse(dexdump, p);
    try { unlinkSync(p); } catch { /* a takarítás nem kritikus */ }
    for (const [name, rec] of parsed) {
      const prev = merged.get(name) ?? { plain: false, sample: false };
      merged.set(name, { plain: prev.plain || rec.plain, sample: prev.sample || rec.sample });
    }
  }
  const wanted = new Set([...merged.entries()].filter(([, r]) => r.plain).map(([n]) => n));
  const entries = [...wanted].map((n) => ({ name: n, ...merged.get(n), original: null, obfuscated: null }));

  if (mappingPath && existsSync(mappingPath)) {
    const wantedForMapping = new Set();
    for (const n of wanted) wantedForMapping.add(n);
    const { byObfuscated, byOriginal } = await streamMapping(mappingPath, wantedForMapping);
    for (const e of entries) {
      e.original = byObfuscated.get(e.name) ?? null;
      e.obfuscated = e.name;
      if (!e.original) {
        const direct = byOriginal.get(e.name);
        if (direct) e.obfuscated = direct;
      }
    }
  }
  return { source: aabPath, dexes: dexNames, entries };
}

async function streamMapping(mappingPath, wanted) {
  const rl = createInterface({ input: createReadStream(mappingPath, 'utf8'), crlfDelay: Infinity });
  // A mappinget nem töltjük memóriába: soronként szűrünk, és csak a kért neveket tartjuk meg.
  const byObfuscated = new Map();
  const byOriginal = new Map();
  const re = /^(\S+) -> ([^:\s]+):$/;
  for await (const line of rl) {
    const m = re.exec(line);
    if (!m) continue;
    const [, original, obfuscated] = m;
    if (wanted.has(obfuscated)) byObfuscated.set(obfuscated, original);
    if (wanted.has(original)) byOriginal.set(original, obfuscated);
  }
  return { byObfuscated, byOriginal };
}

// ------------------------------------------------------------------ önteszt
export function selfTest() {
  const cls = (...parts) => Buffer.from(parts.join('\u0000'), 'utf8');
  const cases = [];

  cases.push(['plain decodeStream felismerve',
    analyzeClassBytes(cls('android/graphics/BitmapFactory', 'decodeStream', PLAIN_STREAM))?.sample === false]);
  cases.push(['inSampleSize-szel együtt → sample=true',
    analyzeClassBytes(cls('android/graphics/BitmapFactory', 'decodeStream', PLAIN_STREAM, 'inSampleSize'))?.sample === true]);
  cases.push(['csak Options-es overload → nem találat',
    analyzeClassBytes(cls('android/graphics/BitmapFactory', 'decodeStream',
      '(Ljava/io/InputStream;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;', 'inSampleSize')) === null]);
  cases.push(['BitmapFactory nélkül → nem találat',
    analyzeClassBytes(cls('java/lang/String', 'decodeStream', PLAIN_STREAM)) === null]);
  cases.push(['decodeByteArray plain felismerve',
    analyzeClassBytes(cls('BitmapFactory', 'decodeByteArray', PLAIN_BYTES))?.plain === true]);

  const dump = [
    "  Class descriptor  : 'Llb6;'",
    "      invoke-static {v9}, Landroid/graphics/BitmapFactory;.decodeStream:(Ljava/io/InputStream;)Landroid/graphics/Bitmap;",
    "  Class descriptor  : 'Lki1;'",
    "      invoke-static {v0, v1}, Landroid/graphics/BitmapFactory;.decodeFile:(Ljava/lang/String;Landroid/graphics/BitmapFactory$Options;)Landroid/graphics/Bitmap;",
    '      const/16 v2, 0x2 // inSampleSize',
  ];
  const parsed = parseDexdumpLines(dump);
  cases.push(['dexdump: a plain osztály felismerve', parsed.get('lb6')?.plain === true && parsed.get('lb6')?.sample === false]);
  cases.push(['dexdump: az Options-es osztály nem plain', parsed.get('ki1')?.plain === false && parsed.get('ki1')?.sample === true]);

  const mapping = resolveMappingLines([
    'com.google.android.gms.internal.ads.zzelp -> lb6:',
    'com.example.Other -> zz9:',
  ], new Set(['lb6']));
  cases.push(['mapping: az obfuszkált név visszafejtve',
    mapping.byObfuscated.get('lb6') === 'com.google.android.gms.internal.ads.zzelp']);
  cases.push(['mapping: a nem kért név kimarad', mapping.byObfuscated.size === 1]);

  const summary = summarize([
    { name: 'lb6', sample: false, original: 'com.google.android.gms.internal.ads.zzelp', obfuscated: 'lb6' },
    { name: 'k17', sample: false, original: 'com.google.android.gms.internal.ads.zzgtp', obfuscated: 'k17' },
    { name: 'fi1', sample: false, original: 'com.google.firebase.messaging.ImageDownload', obfuscated: 'fi1' },
    { name: 'ki1', sample: true, original: 'io.flutter.plugins.imagepicker.ImagePickerCache', obfuscated: 'ki1' },
    { name: 'zzz', sample: false, original: 'hu.hungarianhardstyle.app.Sajat', obfuscated: 'zzz' },
  ]);
  cases.push(['összegzés: csak az alul-mintavételezés nélkülieket számolja', summary.withoutSample === 4 && summary.total === 5]);
  cases.push(['összegzés: a saját kódot külön jelzi', summary.ours === 1]);
  cases.push(['összegzés: a csoportosítás SDK szerint megy',
    summary.groups.some((g) => g.owner.includes('Mobile Ads') && g.count === 2)]);
  cases.push(['a jelentés kiírja a saját kód figyelmeztetését',
    reportText({ source: 'x', total: 5, withoutSample: 4, ours: 1, groups: summary.groups }).includes('A MI KÓDUNKBAN 1')]);
  cases.push(['a jelentés jelzi, ha nincs saját érintettség',
    reportText({ source: 'x', total: 3, withoutSample: 2, ours: 0, groups: [] }).includes('NINCS')]);

  // ZIP-író az olvasó teszteléséhez (csak tárolt/tömörítetlen bejegyzés).
  const stored = makeStoredZip([{ name: 'a.txt', data: Buffer.from('hello', 'utf8') }]);
  cases.push(['ZIP-olvasó: a tárolt bejegyzés neve és tartalma jó',
    (() => { const e = zipEntries(stored)[0]; return e.name === 'a.txt' && readZipEntry(stored, e).toString('utf8') === 'hello'; })()]);

  let failed = 0;
  for (const [name, ok] of cases) {
    console.log(`  ${ok ? 'OK  ' : 'HIBA'} ${name}`);
    if (!ok) failed += 1;
  }
  console.log(failed === 0 ? `ÖNTESZT: ${cases.length}/${cases.length} OK` : `ÖNTESZT: ${failed} bukott`);
  return failed;
}

/** Minimál ZIP-író az önteszthez (tárolt, tömörítetlen bejegyzések). */
function makeStoredZip(files) {
  const chunks = [];
  const central = [];
  let offset = 0;
  for (const f of files) {
    const name = Buffer.from(f.name, 'utf8');
    const crc = crc32(f.data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0, 6);
    local.writeUInt16LE(0, 8); // tárolt
    local.writeUInt32LE(0, 10);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(f.data.length, 18);
    local.writeUInt32LE(f.data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    chunks.push(local, name, f.data);
    const cd = Buffer.alloc(46);
    cd.writeUInt32LE(0x02014b50, 0);
    cd.writeUInt16LE(20, 4);
    cd.writeUInt16LE(20, 6);
    cd.writeUInt16LE(0, 8);
    cd.writeUInt16LE(0, 10);
    cd.writeUInt32LE(0, 12);
    cd.writeUInt32LE(crc, 16);
    cd.writeUInt32LE(f.data.length, 20);
    cd.writeUInt32LE(f.data.length, 24);
    cd.writeUInt16LE(name.length, 28);
    cd.writeUInt32LE(offset, 42);
    central.push(Buffer.concat([cd, name]));
    offset += local.length + name.length + f.data.length;
  }
  const centralBuf = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(centralBuf.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...chunks, centralBuf, end]);
}

function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1));
  }
  return ~c >>> 0;
}

// -------------------------------------------------------------------- futás
if (args.includes('--self-test')) {
  process.exit(selfTest() === 0 ? 0 : 1);
}

const aabPaths = flagValues('--aab');
const aarPaths = flagValues('--aar');
const mappingPath = flagValues('--mapping')[0] ?? 'build/app/outputs/mapping/release/mapping.txt';

if (!aabPaths.length && !aarPaths.length) {
  console.log('Használat:');
  console.log('  node tools/check-bitmap-subsampling.mjs --aab build/HUHS-v1.0.0+<build>-release.aab [--mapping <mapping.txt>]');
  console.log('  node tools/check-bitmap-subsampling.mjs --aar <play-services-ads-X.aar> [--aar <...>]');
  console.log('  node tools/check-bitmap-subsampling.mjs --self-test');
  process.exit(2);
}

if (aabPaths.length) {
  const dexdump = findDexdump(flagValues('--dexdump')[0]);
  if (!dexdump) {
    console.log('HIBA: a DEX-módhoz `dexdump` kell (Android SDK build-tools).');
    console.log('      Add meg kézzel: --dexdump "C:\\...\\build-tools\\36.1.0\\dexdump.exe"');
    console.log('      Vagy használd a --aar módot egy konkrét SDK-verzió vizsgálatához.');
    process.exit(3);
  }
  for (const aab of aabPaths) {
    if (!existsSync(aab)) { console.log('nincs ilyen csomag:', aab); process.exit(4); }
    const { source, dexes, entries } = await scanAab(aab, mappingPath, dexdump);
    const summary = summarize(entries);
    const result = { source, dexes, ...summary };
    if (asJson) {
      console.log(JSON.stringify({ ...result, entries }, null, 2));
    } else {
      console.log(reportText(result));
      if (!existsSync(mappingPath)) {
        console.log(`\n⚠️ Nem találtam a mappinget (${mappingPath}) — az osztálynevek fedettek maradnak.`);
      }
    }
  }
}

for (const aar of aarPaths) {
  if (!existsSync(aar)) { console.log('nincs ilyen fájl:', aar); process.exit(4); }
  const found = scanClassContainer(readFileSync(aar), aar.toLowerCase().endsWith('.aar'));
  const entries = found.map((f) => ({ ...f, original: f.name, obfuscated: null }));
  const summary = summarize(entries);
  if (asJson) {
    console.log(JSON.stringify({ source: aar, ...summary, entries }, null, 2));
  } else {
    const without = found.filter((f) => !f.sample);
    console.log(`\n=== ${aar}`);
    console.log(`  BitmapFactory-t hívó osztály: ${found.length}, ebből alul-mintavételezés nélkül: ${without.length}`);
    for (const f of found) {
      console.log(`    ${f.sample ? '[van inSampleSize] ' : '[NINCS inSampleSize]'} ${f.name}`);
    }
  }
}
