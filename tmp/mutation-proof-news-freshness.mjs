#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **hír-frissességre** (app-oldal).
 *
 * Két valódi visszaállítást mér:
 *  1. a főoldali provider **nem indítja** a csendes egyeztetést (`startNewsRevalidation` elvétele),
 *  2. a háttérben beérkező változás **nem kényszerített** úton olvasódik vissza (`forceRefresh: true` elvétele).
 *
 * Mindkettőnek **elbukó** tesztet kell okoznia (`test/services/news_freshness_test.dart`);
 * a végén a fájlok **bájtazonosak** (SHA-256-tal igazolva).
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TEST = 'test/services/news_freshness_test.dart';
const target = 'lib/providers/news_provider.dart';

/**
 * ⚠️ MÉRT ESZKÖZ-HIBA (2026-09-26): a `flutter` Windows-on egy `.bat`, ezért az
 * `execFileSync('flutter', …)` **ENOENT**-tel elhasal — és a „nem futott le"
 * eredményt a szkript **hamis „ELKAPVA"-ként** jelentette. Ezért a futtatás
 * **shell-en** át megy, és a hibaüzenetet is megkülönböztetjük.
 */
const runTest = () => {
  try {
    execSync(`flutter test ${TEST}`, { stdio: 'pipe' });
    return { passed: true, output: '' };
  } catch (error) {
    const output = `${error.stdout ?? ''}${error.stderr ?? ''}`.toString();
    return { passed: false, output };
  }
};

const spawnOk = (output) => !/ENOENT|not recognized|is not recognized/i.test(output);

const hash = (buffer) => crypto.createHash('sha256').update(buffer).digest('hex').toUpperCase();
const original = fs.readFileSync(target);
const originalHash = hash(original);

const mutations = [
  {
    name: 'a csendes egyeztetés indításának elvétele a főoldali providerből',
    from: '  startNewsRevalidation(ref, ref.watch(newsRevalidateProvider));\n',
    to: '',
  },
  {
    name: 'a kényszerített visszaolvasás elvétele a háttér-frissítésből',
    from: 'final cached = await _getPostsPage(page: 1, forceRefresh: true);',
    to: 'final cached = await _getPostsPage(page: 1);',
  },
];

let allCaught = true;
for (const mutation of mutations) {
  const source = original.toString('utf8');
  if (!source.includes(mutation.from)) {
    console.log(`HIBA  a mutáció nem talált: ${mutation.name}`);
    allCaught = false;
    continue;
  }
  try {
    fs.writeFileSync(target, source.replace(mutation.from, mutation.to), 'utf8');
    const result = runTest();
    if (result.passed) {
      console.log(`NEM KAPTA EL  ${mutation.name}`);
      allCaught = false;
    } else if (!spawnOk(result.output)) {
      console.log(`NEM FUTOTT LE (eszköz-hiba)  ${mutation.name} — ${result.output.slice(0, 120)}`);
      allCaught = false;
    } else {
      console.log(`ELKAPVA       ${mutation.name}`);
    }
  } finally {
    fs.writeFileSync(target, original);
  }
}

const restoredHash = hash(fs.readFileSync(target));
console.log(`\nvisszaállítás bájtazonos: ${restoredHash === originalHash} (${restoredHash.slice(0, 12)}…)`);
if (restoredHash !== originalHash) allCaught = false;

// A helyreállított állapotban a körnek újra zöldnek kell lennie.
const green = runTest();
const greenError = green.passed ? null : green.output;
console.log(`a helyreállított kör újra zöld: ${greenError === null}`);
if (greenError) {
  console.log(`  hiba: ${greenError.trim().split('\n').slice(-3).join(' | ').slice(0, 200)}`);
  allCaught = false;
}

console.log(allCaught ? '\nOK — a frissességi viselkedés mutációs bizonyítéka teljes' : '\nHIBA — hiányos bizonyíték');
process.exitCode = allCaught ? 0 : 1;
