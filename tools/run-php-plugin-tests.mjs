#!/usr/bin/env node
/**
 * A plugin PHP-jának **valódi futtatása** (szintaxis + viselkedés) konténerben.
 *
 * MIÉRT ESZKÖZ: a 2.12.0 két kritikus PHP-logikája (a fallback-kapu és a WP-cron
 * fordítási ága) eddig **csak forrás-lintekkel** volt ellenőrizve, mert ezen a
 * gépen nem volt PHP. A Docker + `php:8.2-cli` viszont valódi PHP-t ad, ezért a
 * szállítandó csomag tényleg **lefut** — a WordPress-függvények stubjaival.
 *
 * ⚠️ A MÉRÉS TÁRGYA A **ZIP**: az eszköz kibontja a `build/huhs-mobile-api-<verzió>.zip`
 * csomagot a `tmp/php-plugin/` alá, és azt futtatja — így nem a forráskönyvtárat,
 * hanem a **kiadott** fájlokat méri.
 *
 * ⚠️ DOCKER NÉLKÜL NEM HAZUDIK: ha a Docker démon nem érhető el, az eszköz
 * „KIHAGYVA" üzenettel és indoklással tér vissza (a `--strict` viszont hibázik),
 * hogy a „zöld" jelentése ne csússzon el (lásd a projekt skip-burkoló mintáját).
 *
 * Használat:
 *   node tools/run-php-plugin-tests.mjs              # futtat (Docker kell)
 *   node tools/run-php-plugin-tests.mjs --strict     # Docker nélkül HIBA
 *   node tools/run-php-plugin-tests.mjs --zip=build/huhs-mobile-api-2.12.0.zip
 *   node tools/run-php-plugin-tests.mjs --self-test
 */
import { spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const DEFAULT_ZIP = 'build/huhs-mobile-api-2.14.5.zip';
export const WORK_DIR = 'tmp/php-plugin';
export const CONTAINER_IMAGE = 'php:8.2-cli';

/**
 * A repó gyökere — **a szkript helyéből**, nem a `cwd`-ből.
 *
 * ⚠️ MIÉRT: a Docker mount és a ZIP útvonala a repóhoz képest értendő, ezért a
 * más könyvtárból indított futtatás különben „nincs ilyen csomag" hibát adna.
 */
export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

/** A kimenetből kiolvasott, kötelező jelzők. */
export const REQUIRED_MARKERS = ['PHP LINT OK', 'VISELKEDES OK', 'KONSTANS-AG OK', 'PUSH-DEDUPE OK'];

/** A kimenet összegzése (tesztelhető, hálózat nélkül). */
export function summarize(output) {
  const linted = Number(/lintelt PHP fajl: (\d+)/.exec(output)?.[1] ?? -1);
  const behaviorChecks = [...output.matchAll(/(\d+) ellenőrzés, (\d+) hiba/g)]
    .map((match) => ({ checks: Number(match[1]), failures: Number(match[2]) }));
  return {
    linted,
    behaviorChecks,
    missingMarkers: REQUIRED_MARKERS.filter((marker) => !output.includes(marker)),
    failed: /HIBA/.test(output) || behaviorChecks.some((entry) => entry.failures > 0),
  };
}

/** A ZIP kibontása a munkakönyvtárba (a korábbi tartalom törlésével). */
export function extractZip(zipPath = DEFAULT_ZIP, workDir = WORK_DIR) {
  const zip = path.isAbsolute(zipPath) ? zipPath : path.join(REPO_ROOT, zipPath);
  const target = path.isAbsolute(workDir) ? workDir : path.join(REPO_ROOT, workDir);
  if (!fs.existsSync(zip)) throw new Error(`nincs ilyen csomag: ${zip}`);
  fs.rmSync(target, { recursive: true, force: true });
  fs.mkdirSync(target, { recursive: true });
  const result = spawnSync('tar', ['-xf', zip, '-C', target], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`a kibontás hibázott: ${result.stderr || result.status}`);
  const entries = fs.readdirSync(target);
  if (!entries.length) throw new Error('a kibontott csomag üres');
  return path.join(target, entries[0]);
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const good = [
    'lintelt PHP fajl: 46',
    'PHP LINT OK',
    '19 ellenőrzés, 0 hiba',
    'VISELKEDES OK',
    '19 ellenőrzés, 0 hiba',
    'KONSTANS-AG OK',
    '12/12 ellenorzes rendben',
    'PUSH-DEDUPE OK',
  ].join('\n');
  const goodSummary = summarize(good);
  check('a jó kimenet nem jelez hibát', goodSummary.failed === false);
  check('a lintelt fájlok száma kiolvasható', goodSummary.linted === 46);
  check('a két viselkedés-kör kiolvasható', goodSummary.behaviorChecks.length === 2);
  check('minden kötelező jelző megvan', goodSummary.missingMarkers.length === 0);
  check(
    'a hiányzó push-lánc jelzőt is észreveszi',
    summarize(good.replace('PUSH-DEDUPE OK', '')).missingMarkers.includes('PUSH-DEDUPE OK'),
  );

  const bad = good.replace('VISELKEDES OK', 'VISELKEDES HIBA');
  check('a bukó futást észreveszi', summarize(bad).failed === true);
  check(
    'a hiányzó jelzőt észreveszi',
    summarize(good.replace('KONSTANS-AG OK', '')).missingMarkers.includes('KONSTANS-AG OK'),
  );
  check(
    'a hibás ellenőrzés-számot észreveszi',
    summarize(good.replace('19 ellenőrzés, 0 hiba', '19 ellenőrzés, 1 hiba')).failed === true,
  );
  check(
    'az üres kimenetben MINDEN jelző hiányzik (nem hamis zöld)',
    summarize('').failed === false && summarize('').missingMarkers.length === REQUIRED_MARKERS.length,
  );
  return checks;
}

function dockerAvailable() {
  const result = spawnSync('docker', ['version', '--format', '{{.Server.Version}}'], {
    encoding: 'utf8',
    shell: true,
  });
  return result.status === 0 && String(result.stdout || '').trim() !== '';
}

function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const zipArg = process.argv.find((arg) => arg.startsWith('--zip='));
  const zipPath = zipArg ? zipArg.slice('--zip='.length) : DEFAULT_ZIP;
  const strict = process.argv.includes('--strict');

  if (!dockerAvailable()) {
    const reason = `a Docker démon nem érhető el — indítsd el a Docker Desktopot (a PHP ${CONTAINER_IMAGE} képen fut)`;
    if (strict) {
      console.log(`HIBA  ${reason}`);
      return 1;
    }
    console.log(`KIHAGYVA  ${reason}`);
    console.log('  (a `--strict` kapcsolóval ez hiba lenne; a forrás-lintek ettől függetlenül futnak)');
    return 0;
  }

  const pluginDir = extractZip(zipPath);
  console.log(`csomag: ${zipPath} → ${path.relative(REPO_ROOT, pluginDir).replaceAll('\\', '/')}`);
  const result = spawnSync(
    'docker',
    [
      'run', '--rm',
      '-v', `${REPO_ROOT}:/work`,
      '-w', '/work',
      CONTAINER_IMAGE,
      'sh', '/work/tools/php/run-plugin-tests.sh',
    ],
    { encoding: 'utf8', shell: false, maxBuffer: 64 * 1024 * 1024 },
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  console.log(output.trimEnd());

  const summary = summarize(output);
  const ok = summary.failed === false && summary.missingMarkers.length === 0 && result.status === 0;
  const pushDedupe = /(\d+)\/(\d+) ellenorzes rendben/.exec(output);
  console.log(
    `\n${ok ? 'MINDEN ELLENŐRZÉS RENDBEN' : 'HIBA'} — lintelt fájl: ${summary.linted}, `
    + `viselkedés-körök: ${summary.behaviorChecks.map((entry) => `${entry.checks - entry.failures}/${entry.checks}`).join(', ')}`
    + (pushDedupe ? `, push-lánc: ${pushDedupe[1]}/${pushDedupe[2]}` : '')
    + (summary.missingMarkers.length ? `, hiányzó jelző: ${summary.missingMarkers.join(', ')}` : ''),
  );
  return ok ? 0 : 1;
}

if (process.argv[1] && process.argv[1].endsWith('run-php-plugin-tests.mjs')) {
  process.exitCode = main();
}

/** A ZIP lenyomata (a dokumentumokhoz; a hívó írja ki). */
export function zipDigest(zipPath = DEFAULT_ZIP) {
  const bytes = fs.readFileSync(zipPath);
  return {
    bytes: bytes.length,
    sha256: crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase(),
  };
}
