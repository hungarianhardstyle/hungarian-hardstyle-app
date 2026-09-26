#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **nyelvi körre** (2026-09-26).
 *
 * Négy visszaállítást mér, mindegyiknek **elbukó** tesztet kell okoznia:
 *  1. a kiadvány-dátum címkéje újra nyers (`Megjelenés: ${…}`),
 *  2. a DJ-adatlap „Megjelenései" címe újra nyers,
 *  3. a GYÍK-válasz tisztítása elvéve (a `<p>` bekerül a szótárba? nem: a parse-ból),
 *  4. a nyelvváltásnál elvész a feldolgozott listák eldobása.
 *
 * ⚠️ A futtatás **shell-en** át megy: a `flutter` Windows-on `.bat`, ezért az
 * `execFileSync('flutter', …)` ENOENT-tel elhasalna, és a „nem futott le"
 * eredményt korábban **hamis „ELKAPVA"**-ként jelentette a szkript (mért hiba).
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const TESTS =
  'test/services/i18n_language_switch_test.dart test/models/faq_plain_text_test.dart';

const runTests = () => {
  try {
    execSync(`flutter test ${TESTS}`, { stdio: 'pipe' });
    return { passed: true, output: '' };
  } catch (error) {
    return {
      passed: false,
      output: `${error.stdout ?? ''}${error.stderr ?? ''}`.toString(),
    };
  }
};

const mutations = [
  {
    name: 'a kiadvány-dátum címkéje újra nyers (nem fordít)',
    file: 'lib/widgets/release_card.dart',
    from: "                            : trArgs(context, 'Megjelenés: {d}', {\n                                'd': release.releaseDate,\n                              }),",
    to: "                            : 'Megjelenés: ${release.releaseDate}',",
  },
  {
    name: 'a DJ-adatlap „Megjelenései" címe újra nyers',
    file: 'lib/widgets/artist_releases_section.dart',
    from: 'tr(context, artistReleasesLabel(all.length)),',
    to: 'artistReleasesLabel(all.length),',
  },
  {
    name: 'a GYÍK-válasz tisztítása elvéve (a <p> bekerül a felületre)',
    file: 'lib/models/faq.dart',
    from: "      answer: faqPlainText((json['answer'] ?? json['content'] ?? '').toString()),",
    to: "      answer: (json['answer'] ?? json['content'] ?? '').toString(),",
  },
  {
    name: 'a feldolgozott listák eldobása elvéve a nyelvváltásból',
    file: 'lib/providers/content_language_provider.dart',
    from: '    WordpressService().onContentLanguageChanged();\n',
    to: '',
  },
];

let ok = true;
const originals = new Map();
for (const file of new Set(mutations.map((m) => m.file))) {
  originals.set(file, fs.readFileSync(file));
}

try {
  for (const mutation of mutations) {
    const original = originals.get(mutation.file);
    const source = original.toString('utf8');
    if (!source.includes(mutation.from)) {
      console.log(`HIBA  a mutáció nem talált: ${mutation.name}`);
      ok = false;
      continue;
    }
    try {
      fs.writeFileSync(
        mutation.file,
        source.replace(mutation.from, mutation.to),
        'utf8',
      );
      const result = runTests();
      if (result.passed) {
        console.log(`NEM KAPTA EL  ${mutation.name}`);
        ok = false;
      } else if (/ENOENT|not recognized/i.test(result.output)) {
        console.log(`ESZKÖZ-HIBA  ${mutation.name} — ${result.output.slice(0, 100)}`);
        ok = false;
      } else {
        console.log(`ELKAPVA       ${mutation.name}`);
      }
    } finally {
      fs.writeFileSync(mutation.file, original);
    }
  }
} finally {
  for (const [file, original] of originals) {
    const restored = fs.readFileSync(file);
    const same =
      crypto.createHash('sha256').update(restored).digest('hex') ===
      crypto.createHash('sha256').update(original).digest('hex');
    console.log(`visszaállítás bájtazonos: ${same} (${file})`);
    if (!same) ok = false;
  }
}

const green = runTests();
console.log(`a helyreállított kör újra zöld: ${green.passed}`);
if (!green.passed) ok = false;

console.log(ok ? '\nOK — a nyelvi kör mutációs bizonyítéka teljes' : '\nHIBA — hiányos bizonyíték');
process.exitCode = ok ? 0 : 1;
