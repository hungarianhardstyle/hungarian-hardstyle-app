// Az iOS csomag reklam-identitasanak ellenorzese — Xcode NELKUL, Windows-on.
//
// MIERT KELL: a rossz reklam-azonosito NEMAN jelentkezik. Az app elindul, minden
// kepernyo betolt, csak epp nem szolgal ki hirdetest (vagy a Google
// teszt-egységeit hasznalja). Ez pontosan az a hiba-osztaly, amit egy sikeres
// build es egy tiszta `flutter analyze` SEM jelez.
//
// Ezert a KIMZIPELT `.app` byte-jait olvassuk, es megkeressuk benne:
//   * az AdMob **app** ID-t  — az `Info.plist`-ben (ASCII vagy UTF-16BE),
//   * a ket egyseg-azonositot — a beforditott Dart-konstansokban (ASCII),
//   * es ELLENORIZZUK, hogy a Google **teszt** app ID-ja NE legyen benne.
//
// Hasznalat (a .ipa valojaban egy zip):
//   Copy-Item build/ios-ipa/Runner-unsigned.ipa build/ipa.zip
//   Expand-Archive build/ipa.zip -DestinationPath build/ipa -Force
//   node tools/verify-ios-ipa.mjs build/ipa/Payload/Runner.app
//
// Opciok:
//   --app-id=<id>       varhato AdMob app ID   (alap: a projekt ismert ID-ja)
//   --banner=<id>       varhato banner egyseg
//   --rewarded=<id>     varhato jutalmazott egyseg
//   --self-test         onteszt (nem kell hozza semmilyen csomag)
import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

// ⚠️ Ezek NYILVANOS azonosítók (a kesz binarisban ugyis benne vannak), nem titkok.
export const DEFAULT_APP_ID = 'ca-app-pub-7714662594685378~6550697484';
export const DEFAULT_BANNER = 'ca-app-pub-7714662594685378/5511193968';
export const DEFAULT_REWARDED = 'ca-app-pub-7714662594685378/7238016636';
// A Google teszt APP ID-ja — ez SOHA nem kerulhet egy kiadott csomagba.
export const FORBIDDEN_TEST_APP_ID = 'ca-app-pub-3940256099942544~1458002511';

/** ASCII és UTF-16BE alak (a binaris plist UTF-16BE-t is hasznal). */
export function needlesFor(text) {
  const ascii = Buffer.from(text, 'latin1');
  const utf16be = Buffer.alloc(text.length * 2);
  for (let i = 0; i < text.length; i += 1) {
    utf16be[i * 2] = 0;
    utf16be[i * 2 + 1] = text.charCodeAt(i) & 0xff;
  }
  return [
    { encoding: 'ascii', bytes: ascii },
    { encoding: 'utf16be', bytes: utf16be },
  ];
}

/** Melyik fajlok tartalmazzak a szoveget (ASCII vagy UTF-16BE alakban)? */
export function findInTree(root, text, { maxBytes = 400 * 1024 * 1024 } = {}) {
  const hits = [];
  const needles = needlesFor(text);
  let scanned = 0;
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.isFile()) continue;
      const size = statSync(full).size;
      if (size === 0 || size > maxBytes) continue;
      scanned += size;
      const buf = readFileSync(full);
      for (const n of needles) {
        if (buf.indexOf(n.bytes) !== -1) {
          hits.push({ file: full.slice(root.length + 1), encoding: n.encoding });
          break;
        }
      }
    }
  };
  walk(root);
  return { hits, scannedBytes: scanned };
}

function parseArgs(argv) {
  const args = { app: null, appId: DEFAULT_APP_ID, banner: DEFAULT_BANNER, rewarded: DEFAULT_REWARDED, selfTest: false };
  for (const a of argv) {
    if (a === '--self-test') args.selfTest = true;
    else if (a.startsWith('--app-id=')) args.appId = a.slice(9);
    else if (a.startsWith('--banner=')) args.banner = a.slice(9);
    else if (a.startsWith('--rewarded=')) args.rewarded = a.slice(11);
    else if (!a.startsWith('--')) args.app = a;
  }
  return args;
}

function checkApp(args) {
  const results = [];
  const expect = [
    { label: 'AdMob app ID', value: args.appId, must: true },
    { label: 'banner egyseg', value: args.banner, must: true },
    { label: 'jutalmazott egyseg', value: args.rewarded, must: true },
  ];
  for (const e of expect) {
    if (!e.value) continue;
    const { hits } = findInTree(args.app, e.value);
    results.push({ label: e.label, value: e.value, ok: hits.length > 0, files: hits.map((h) => h.file) });
  }
  const forbidden = findInTree(args.app, FORBIDDEN_TEST_APP_ID);
  results.push({
    label: 'Google TESZT app ID',
    value: FORBIDDEN_TEST_APP_ID,
    ok: forbidden.hits.length === 0,
    forbidden: true,
    files: forbidden.hits.map((h) => h.file),
  });
  return results;
}

function printResults(results) {
  let failed = 0;
  for (const r of results) {
    const mark = r.ok ? 'OK  ' : 'HIBA';
    if (!r.ok) failed += 1;
    const where = r.files.length ? `  <- ${r.files.slice(0, 3).join(', ')}` : '';
    console.log(`  ${mark}  ${r.label.padEnd(22)} ${r.value}${where}`);
  }
  console.log(failed === 0 ? '\n  MINDEN ELLENORZES RENDBEN' : `\n  ${failed} ELLENORZES ELHASALT`);
  return failed;
}

function selfTest() {
  const dir = join(tmpdir(), `huhs-ipa-selftest-${Date.now()}`);
  mkdirSync(dir, { recursive: true });
  try {
    // Az app ID-t szandekosan UTF-16BE-kent irjuk (igy tarolja a binaris plist),
    // az egysegeket ASCII-kent (igy kerulnek a beforditott Dart-konstansokba).
    const utf16be = Buffer.alloc(DEFAULT_APP_ID.length * 2);
    for (let i = 0; i < DEFAULT_APP_ID.length; i += 1) {
      utf16be[i * 2] = 0;
      utf16be[i * 2 + 1] = DEFAULT_APP_ID.charCodeAt(i) & 0xff;
    }
    writeFileSync(join(dir, 'Info.plist'), Buffer.concat([Buffer.from('bplist00'), utf16be]));
    writeFileSync(join(dir, 'App'), Buffer.from(`...${DEFAULT_BANNER}...${DEFAULT_REWARDED}...`));
    mkdirSync(join(dir, 'Frameworks'), { recursive: true });
    writeFileSync(join(dir, 'Frameworks', 'empty.bin'), Buffer.alloc(0));

    const clean = checkApp({ app: dir, appId: DEFAULT_APP_ID, banner: DEFAULT_BANNER, rewarded: DEFAULT_REWARDED });
    const cleanFailed = clean.filter((r) => !r.ok);
    console.log('  onteszt 1 (helyes csomag):', cleanFailed.length === 0 ? 'OK' : `HIBA (${cleanFailed.length})`);
    if (cleanFailed.length !== 0) throw new Error('a helyes csomagot hibasnak jelolte');
    if (!clean[0].files.includes('Info.plist')) throw new Error('az app ID-t nem az Info.plist-ben talalta');

    // Most tegyuk bele a TILTOTT teszt app ID-t -> el kell hasalnia.
    writeFileSync(join(dir, 'Info.plist'), Buffer.concat([Buffer.from('bplist00'), utf16be, Buffer.from(FORBIDDEN_TEST_APP_ID)]));
    const dirty = checkApp({ app: dir, appId: DEFAULT_APP_ID, banner: DEFAULT_BANNER, rewarded: DEFAULT_REWARDED });
    const forbidden = dirty.find((r) => r.forbidden);
    console.log('  onteszt 2 (teszt app ID bent van):', forbidden.ok ? 'HIBA (nem vette eszre)' : 'OK (eszrevette)');
    if (forbidden.ok) throw new Error('a tiltott teszt app ID-t nem vette eszre');

    // Es ha HIANYZIK az egyseg -> azt is jelezni kell.
    writeFileSync(join(dir, 'App'), Buffer.from('...semmi...'));
    const missing = checkApp({ app: dir, appId: DEFAULT_APP_ID, banner: DEFAULT_BANNER, rewarded: DEFAULT_REWARDED });
    const missingBad = missing.filter((r) => !r.forbidden && !r.ok);
    console.log('  onteszt 3 (hianyzo egyseg):', missingBad.length === 2 ? 'OK (eszrevette)' : `HIBA (${missingBad.length})`);
    if (missingBad.length !== 2) throw new Error('a hianyzo egysegeket nem vette eszre');

    console.log('  ONTESZT: 3/3 OK');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const args = parseArgs(process.argv.slice(2));
if (args.selfTest) {
  selfTest();
} else if (!args.app) {
  console.error('  Hasznalat: node tools/verify-ios-ipa.mjs <kimzipelt Runner.app> [--self-test]');
  process.exit(2);
} else {
  if (!statSync(args.app).isDirectory()) {
    console.error(`  HIBA: nem konyvtar: ${args.app}  (a .ipa-t elobb ki kell csomagolni)`);
    process.exit(2);
  }
  const results = checkApp(args);
  process.exit(printResults(results) === 0 ? 0 : 1);
}
