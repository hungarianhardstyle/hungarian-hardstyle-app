#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **nyelvváltás a megnyitott adatlapokon** javításra
 * (a tulajdonos kérése, 2026-09-26: *„csináld"*).
 *
 * Minden mutáció a javítás egy darabját veszi el, és mindegyiknek BUKNIA kell a
 * teszten. A visszaállítás **bájtazonos** (SHA-256-tal igazolva), és a végén a
 * helyreállított kör **újra zöld**.
 *
 * ⚠️ A „nem futott le" nem bizonyíték: a spawn-hibát megkülönböztetjük a valódi
 * tesztbukástól, a többsoros horgonyokat pedig a fájl **saját sorvégéhez**
 * igazítjuk (a fájlok CRLF-esek).
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const MIXIN = 'lib/core/i18n/content_language_reload.dart';
const NEWS = 'lib/screens/news/news_detail_screen.dart';
const EVENT = 'lib/screens/events/event_detail_screen.dart';
const RELOAD_TEST = 'test/services/content_language_reload_test.dart';

const sha = (text) => crypto.createHash('sha256').update(text, 'utf8').digest('hex');

function run(command) {
  try {
    execSync(command, { stdio: 'pipe', encoding: 'utf8' });
    return { ok: true, output: '' };
  } catch (error) {
    if (error.status === undefined || error.status === null) {
      throw new Error(`a parancs nem futott le (spawn-hiba): ${error.message}`);
    }
    return { ok: false, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

const runTest = () => run(`flutter test ${RELOAD_TEST}`);

const mutations = [
  {
    label: 'a mixin nem figyeli a jelzést (nyelvváltáskor sem tölt újra)',
    file: MIXIN,
    transform: (source) =>
      source.replace(
        '    WordpressService.publicContentRefreshGeneration.addListener(_onSignal);\n',
        '',
      ),
  },
  {
    label: 'a mixin minden jelzésre újratölt (nyelv-összehasonlítás elvéve)',
    file: MIXIN,
    transform: (source) =>
      source.replace('    if (current == _contentLanguage) return;\n', ''),
  },
  {
    label: 'a cikk-adatlap nem kapja meg a mixint',
    file: NEWS,
    transform: (source) =>
      source.replace('with ContentLanguageReload<NewsDetailScreen>', ''),
  },
  {
    label: 'az esemény-adatlap nyelvváltás-útja kiürítve',
    file: EVENT,
    transform: (source) =>
      source.replace(
        '  Future<void> reloadForLanguage() => _loadFullEvent();',
        '  Future<void> reloadForLanguage() async {}',
      ),
  },
];

let caught = 0;
const results = [];

for (const mutation of mutations) {
  const original = fs.readFileSync(mutation.file, 'utf8');
  const originalHash = sha(original);
  const mutated = mutation.transform(original);
  if (mutated === original) {
    results.push(`HIBA  ${mutation.label} — a mutáció nem változtatott semmit (a horgony elavult?)`);
    continue;
  }

  fs.writeFileSync(mutation.file, mutated, 'utf8');
  const outcome = runTest();
  fs.writeFileSync(mutation.file, original, 'utf8');
  const restored = sha(fs.readFileSync(mutation.file, 'utf8')) === originalHash;

  if (!restored) {
    results.push(`HIBA  ${mutation.label} — a visszaállítás NEM bájtazonos`);
    continue;
  }
  if (outcome.ok) {
    results.push(`NEM KAPTA EL  ${mutation.label}`);
  } else {
    caught += 1;
    results.push(`ELKAPVA  ${mutation.label}`);
  }
}

console.log(results.join('\n'));
console.log(`\n${caught}/${mutations.length} mutáció elkapva`);

const final = runTest();
console.log(final.ok ? 'a helyreállított kör ÚJRA ZÖLD' : `HIBA: a helyreállított kör sem zöld:\n${final.output.slice(-500)}`);
process.exitCode = caught === mutations.length && final.ok ? 0 : 1;
