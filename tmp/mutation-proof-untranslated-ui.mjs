#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **fordítatlan felirat** kapuhoz
 * (`test/services/i18n_untranslated_ui_test.dart`).
 *
 * A KÉRDÉS, amire válaszol: a kapu **valóban elkapja-e** azt a hibaosztályt,
 * amit a tulajdonos jelzett („itt maradt egy magyar szó"), vagy csak zöld?
 * Ezért minden mutációnál **visszaállítjuk a hibát**, lefuttatjuk a tesztet, és
 * elvárjuk, hogy **bukjon** — majd bájtazonosan visszaállítunk, és a
 * helyreállított körnek **újra zöldnek** kell lennie.
 *
 * ⚠️ A horgonyok a fájl **saját** sorvégével épülnek (`eolOf`), különben a
 * CRLF-es fájlokban „nem találom" lenne — ez a hiba már egyszer hamis képet
 * adott (lásd AGENTS.md).
 *
 * Használat: node tmp/mutation-proof-untranslated-ui.mjs
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const TEST = 'test/services/i18n_untranslated_ui_test.dart';
const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const MUTATIONS = [
  {
    name: 'a tulajdonos jelzése visszakerül: nyers „letöltött zene" a lejátszóban',
    file: 'lib/screens/more/my_music_screen.dart',
    find: [
      "                            : trArgs(context, '{n} letöltött zene', {",
      "                                'n': '${_downloaded.length}',",
      '                              }),',
    ],
    replace: ["                            : '${_downloaded.length} letöltött zene',"],
  },
  {
    name: 'nyers magyar felirat egy megjelenítési helyen (tárhely-összegzés)',
    file: 'lib/screens/more/my_music_screen.dart',
    find: [
      "                    ? trArgs(context, '{releases} kiadvány · {tracks} tétel · {size} a készüléken', {",
    ],
    replace: [
      "                    ? '${visible.length} kiadvány · ${_queue.length} tétel · ${_formatBytes(_storageBytes)} a készüléken',",
    ],
  },
  {
    name: 'új, szótárban nem szereplő tárolt üzenet',
    file: 'lib/screens/more/my_music_screen.dart',
    find: ["        setState(() => _message = 'Ez a tétel most nincs a lejátszási listán.');"],
    replace: ["        setState(() => _message = 'Ez a tétel most nincs a listán, bocs.');"],
  },
  {
    name: 'a gombfelirat visszaáll nyersre (Küldés…)',
    file: 'lib/screens/poll/poll_screen.dart',
    find: ["            child: Text(_submitting ? tr(context, 'Küldés…') : tr(context, 'Szavazok')),"],
    replace: ["            child: Text(_submitting ? 'Küldés…' : tr(context, 'Szavazok')),"],
  },
  {
    name: 'a szótárból eltűnik egy megjelenítéskor fordított kulcs',
    file: 'assets/i18n/en.json',
    find: ['  "{n} letöltött zene": "{n} downloaded tracks",'],
    replace: ['  "{n} letöltött zene — ELTÁVOLÍTVA": "{n} downloaded tracks",'],
  },
];

/** A teszt eredménye (true = zöld). */
const testPasses = () => {
  try {
    execFileSync('flutter', ['test', TEST], { stdio: 'pipe', shell: true });
    return true;
  } catch {
    return false;
  }
};

const results = [];
console.log('--- kiinduló állapot ---');
const baseline = testPasses();
console.log(`a kapu a kiinduló állapotban: ${baseline ? 'ZÖLD' : 'BUKIK'}`);

for (const mutation of MUTATIONS) {
  const source = fs.readFileSync(mutation.file, 'utf8');
  const eol = eolOf(source);
  const find = mutation.find.join(eol);
  const hits = source.split(find).length - 1;
  if (hits !== 1) {
    results.push({ name: mutation.name, verdict: `NEM MÉRHETŐ (a minta ${hits}× szerepel)` });
    console.log(`\n${mutation.name}\n  NEM MÉRHETŐ — a minta ${hits}× szerepel (1 kell)`);
    continue;
  }
  fs.writeFileSync(mutation.file, source.replace(find, mutation.replace.join(eol)), 'utf8');
  const caught = !testPasses();
  fs.writeFileSync(mutation.file, source, 'utf8'); // bájtazonos visszaállítás
  const restored = fs.readFileSync(mutation.file, 'utf8') === source;
  results.push({ name: mutation.name, verdict: caught ? 'ELKAPVA' : 'NEM KAPTA EL' });
  console.log(`\n${mutation.name}\n  ${caught ? 'ELKAPVA' : 'NEM KAPTA EL'}${restored ? '' : ' — ⚠️ a visszaállítás nem bájtazonos!'}`);
}

console.log('\n--- helyreállított állapot ---');
const after = testPasses();
console.log(`a kapu a helyreállítás után: ${after ? 'ZÖLD' : 'BUKIK'}`);

const caught = results.filter((r) => r.verdict === 'ELKAPVA').length;
console.log(`\n${caught}/${MUTATIONS.length} mutáció elkapva`);
process.exitCode = caught === MUTATIONS.length && baseline && after ? 0 : 1;
