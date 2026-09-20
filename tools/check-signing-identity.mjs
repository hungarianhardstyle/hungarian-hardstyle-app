#!/usr/bin/env node
/**
 * Az ALÁÍRÁSI IDENTITÁS ellenőrzése — a Play „csomagnév + aláírási kulcs" regisztrációhoz.
 *
 * MIÉRT: a Play Console 2026-07-15-i értesítése szerint **2026. szeptember 30-tól**
 * a nem regisztrált Play-alkalmazásokat globálisan letiltják, és a **Playen kívül**
 * terjesztett, Android-aláírási kulcsot használó buildek sem telepíthetők a
 * tanúsítvánnyal rendelkező Android-eszközökre bizonyos országokban. Ezért nem
 * elég, hogy „a Playen regisztrált az app": **minden** kulcsot regisztrálni kell,
 * amivel terjesztünk.
 *
 * Ez az eszköz megmutatja, hány KÜLÖNBÖZŐ aláírási identitásunk van, és kiírja a
 * tanúsítvány SHA-256 lenyomatát — pontosan azt a formát, amit a Play Console
 * „Aláírási kulcsok" nézetében össze lehet hasonlítani. Titkot nem kér és nem ír:
 * a kulcstárat nem nyitja meg, csak a **kész** AAB/APK aláírását olvassa
 * (`keytool -printcert -jarfile`, illetve `apksigner`).
 *
 * Futtatás:  node tools/check-signing-identity.mjs
 *            node tools/check-signing-identity.mjs --self-test
 * Kilépési kód: 0 = egy aláírási identitás (várt), 1 = több különböző (figyelmeztetés).
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

export const PACKAGE_NAME = 'hu.hungarianhardstyle.app';

/** A lenyomat egységes alakja (a Play és a keytool is így, nagybetűvel írja). */
export function normalizeFingerprint(value) {
  const hex = String(value || '')
    .replace(/[^0-9a-fA-F]/g, '')
    .toUpperCase();
  if (hex.length !== 64) return '';
  return (hex.match(/.{2}/g) || []).join(':');
}

/** A `keytool -printcert` kimenetéből az SHA-256 lenyomat. */
export function parseKeytoolSha256(output) {
  const match = String(output || '').match(/SHA256:\s*([0-9A-Fa-f:]{64,})/);
  return match ? normalizeFingerprint(match[1]) : '';
}

/** Az `apksigner verify --print-certs` kimenetéből az SHA-256 lenyomat. */
export function parseApksignerSha256(output) {
  const match = String(output || '').match(/certificate SHA-256 digest:\s*([0-9a-fA-F:]{64,})/);
  return match ? normalizeFingerprint(match[1]) : '';
}

/** Besorolja a talált aláírásokat identitás szerint. */
export function groupIdentities(entries) {
  const groups = new Map();
  for (const entry of entries) {
    const fingerprint = normalizeFingerprint(entry.fingerprint);
    if (!fingerprint) continue;
    const group = groups.get(fingerprint) || { fingerprint, files: [] };
    group.files.push(entry.file);
    groups.set(fingerprint, group);
  }
  return [...groups.values()];
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const sample = 'B4:FB:6D:AF:37:A7:0C:56:17:6F:8D:34:A5:BE:79:A1:7C:2E:5B:B5:59:1C:C4:F6:64:BF:29:47:F0:AB:0A:50';

  check('a lenyomatot egységesíti', normalizeFingerprint(sample.toLowerCase().replace(/:/g, '')) === sample);
  check(
    'a keytool kimenetét kiolvassa',
    parseKeytoolSha256(`\t SHA256: ${sample}\n`) === sample,
  );
  check(
    'az apksigner kimenetét kiolvassa',
    parseApksignerSha256(`V2 Signer: certificate SHA-256 digest: ${sample.toLowerCase()}\n`) === sample,
  );
  check('a csonka lenyomatot elutasítja', normalizeFingerprint('B4:FB:6D') === '');
  check('az üres kimenetből nem talál ki lenyomatot', parseKeytoolSha256('nincs itt semmi') === '');

  const groups = groupIdentities([
    { file: 'a.aab', fingerprint: sample },
    { file: 'b.apk', fingerprint: sample.toLowerCase() },
    { file: 'c.apk', fingerprint: 'AA'.repeat(32) },
    { file: 'd.apk', fingerprint: '' },
  ]);
  check('az azonos identitást összevonja', groups.length === 2);
  check('az azonos csoportban mindkét fájl ott van', groups[0].files.length === 2);
  check('a lenyomat nélküli fájlt kihagyja', groups.every((group) => !group.files.includes('d.apk')));

  return checks;
}

function run(command, args) {
  try {
    // Windows-on az `apksigner` egy `.bat`, amit csak shell-lel lehet futtatni.
    return execFileSync(command, args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      shell: process.platform === 'win32' && command.toLowerCase().endsWith('.bat'),
    });
  } catch (error) {
    return `${error?.stdout || ''}${error?.stderr || ''}`;
  }
}

function findFiles(root, extensions, { skip = ['node_modules', '.git', '.tmp-', 'intermediates'] } = {}) {
  const found = [];
  const walk = (dir, depth) => {
    if (depth > 6) return;
    let entries = [];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch (_) {
      return;
    }
    for (const entry of entries) {
      if (skip.some((part) => entry.name.includes(part))) continue;
      const absolute = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(absolute, depth + 1);
      else if (extensions.some((extension) => entry.name.endsWith(extension))) found.push(absolute);
    }
  };
  walk(root, 0);
  return found;
}

function findApksigner() {
  const sdk = process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME ||
    path.join(process.env.LOCALAPPDATA || '', 'Android', 'sdk');
  const tools = path.join(sdk, 'build-tools');
  if (!fs.existsSync(tools)) return '';
  const versions = fs.readdirSync(tools).sort().reverse();
  for (const version of versions) {
    const candidate = path.join(tools, version, process.platform === 'win32' ? 'apksigner.bat' : 'apksigner');
    if (fs.existsSync(candidate)) return candidate;
  }
  return '';
}

function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const root = process.cwd();
  const bundles = findFiles(path.join(root, 'build'), ['.aab']);
  const apks = findFiles(path.join(root, 'build'), ['.apk']).filter((file) => !file.includes('debug'));
  const keystores = findFiles(path.join(root, 'android'), ['.jks', '.keystore']);
  const apksigner = findApksigner();

  const entries = [];
  for (const file of bundles) {
    const fingerprint = parseKeytoolSha256(run('keytool', ['-printcert', '-jarfile', file]));
    entries.push({ file: path.relative(root, file), fingerprint });
  }
  for (const file of apks) {
    const output = apksigner ? run(apksigner, ['verify', '--print-certs', file]) : '';
    entries.push({ file: path.relative(root, file), fingerprint: parseApksignerSha256(output) });
  }

  console.log(`csomagnév: ${PACKAGE_NAME}`);
  console.log(`vizsgált kész csomag: AAB ${bundles.length}, release APK ${apks.length}\n`);
  const unreadable = entries.filter((entry) => !entry.fingerprint);
  for (const entry of unreadable) {
    console.log(`  (aláírás nem olvasható)  ${entry.file}`);
  }

  const groups = groupIdentities(entries);
  if (!groups.length) {
    console.log('\nNem találtam olvasható aláírást (nincs kész AAB/APK a build/ alatt).');
    return 0;
  }
  console.log(`${groups.length} különböző aláírási identitás:\n`);
  for (const group of groups) {
    console.log(`  SHA-256 ${group.fingerprint}`);
    console.log(`      ${group.files.length} csomag, pl.:`);
    for (const file of group.files.slice(0, 3)) console.log(`        ${file}`);
    if (group.files.length > 3) console.log(`        … és további ${group.files.length - 3}`);
  }
  if (groups.length > 1) {
    console.log(
      '\nFIGYELEM: egynél több aláírási identitás van a buildek között. A Play regisztráció\n' +
        'MINDEN olyan kulcsot megkövetel, amellyel terjesztesz — ha ezek közül valamelyik\n' +
        'nincs a Play Console „Aláírási kulcsok" listáján, azt pótolni kell 2026-09-30 előtt.',
    );
    return 1;
  }
  console.log(
    '\nEgyetlen aláírási identitás. Ellenőrizd a Play Console-ban (Play Console-feltételek →\n' +
      'alkalmazásregisztráció), hogy ez a lenyomat szerepel-e a regisztrált kulcsok között.',
  );
  return 0;
}

process.exitCode = main();
