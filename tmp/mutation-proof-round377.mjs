#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **2026-09-27-i (377-es) körhöz**:
 *   * a Label-termékek **nyelvhelyes** szövege (kliens + Play-listázás),
 *   * a **görgetés megtartása** háttér-frissítéskor (a tulajdonos jelzése),
 *   * a **születésnapi köszöntés** (évente egyszer, időzóna-helyesen),
 *   * a **Play Console javaslatai** (teljes képernyős mód láthatósága, kép-memória).
 *
 * Minden mutációnál elvárjuk, hogy a kapuk **bukjanak**, majd bájtazonosan
 * visszaállítunk, és a helyreállított körnek **zöldnek** kell lennie.
 *
 * Használat: node tmp/mutation-proof-round377.mjs
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const SERVER_TESTS = [
  'functions/birthday-plan.test.cjs',
  'functions/play-product-plan.test.cjs',
];
const CLIENT_TESTS = [
  'test/services/content_refresh_keeps_scroll_test.dart',
  'test/services/label_product_text_test.dart',
  'test/services/image_asset_size_test.dart',
  'test/services/play_console_suggestions_test.dart',
];

const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const MUTATIONS = [
  {
    kind: 'server',
    name: 'a születésnapi kulcsból kimarad az ÉV (minden kör újra köszönt)',
    file: 'functions/birthday-plan.js',
    find: ['  return `${BIRTHDAY_TYPE}:${id}:${Number(year) || 0}`;'],
    replace: ['  return `${BIRTHDAY_TYPE}:${id}`;'],
  },
  {
    kind: 'server',
    name: 'a szökőnapi születésnap kezelése eltűnik (3 évente kimaradna)',
    file: 'functions/birthday-plan.js',
    find: [
      '  return parsed.month === 2 && parsed.day === 29 && today.month === 2 && today.day === 28 && !isLeapYear(today.year);',
    ],
    replace: ['  return false;'],
  },
  {
    kind: 'server',
    name: 'a köszöntő kör újraküld (nincs `created` kapu)',
    file: 'functions/index.js',
    find: ['    if (!created) continue;', '    summary.notified += 1;'],
    replace: ['    summary.notified += 1;'],
  },
  {
    kind: 'server',
    name: 'a katalógusból eltűnik a születésnapi köszöntés',
    file: 'functions/notification-texts.js',
    find: ['  birthday: {'],
    replace: ['  birthday_ELTÁVOLÍTVA: {'],
  },
  {
    kind: 'server',
    name: 'a Play-termék csak magyar listázást kap (angolul magyar szöveg)',
    file: 'functions/play-product-plan.js',
    find: [
      "    { languageCode: 'en-US', title: String(titleEn ?? ''), description: String(descriptionEn ?? '') },",
    ],
    replace: ['    { languageCode: \'hu-HU\', title: String(titleEn ?? \'\'), description: String(descriptionEn ?? \'\') },'],
  },
  {
    kind: 'server',
    name: 'a szinkron visszaesik a csak magyar listázásra',
    file: 'functions/index.js',
    find: ['    listings,', '    purchaseOptions: [purchaseOption],'],
    replace: ["    listings: [{ languageCode: 'hu-HU', title, description }],", '    purchaseOptions: [purchaseOption],'],
  },
  {
    kind: 'client',
    name: 'a Label fül újra töltő ikonra vált frissítéskor (görgetés-ugrás)',
    file: 'lib/screens/releases/releases_screen.dart',
    find: ['          skipLoadingOnReload: true,', '          skipLoadingOnRefresh: true,'],
    replace: ['          // (a védelem elvéve — a mutáció azt méri, hogy a kapu elkapja)'],
  },
  {
    kind: 'client',
    name: 'az eseménylista védelme eltűnik',
    file: 'lib/screens/events/events_screen.dart',
    find: ['              skipLoadingOnReload: true,'],
    replace: ['              // (a védelem elvéve)'],
  },
  {
    kind: 'client',
    name: 'a termék sora újra a Play (magyar) leírását írja ki',
    file: 'lib/screens/releases/release_detail_screen.dart',
    find: [
      "          trArgs(context, 'Hungarian Hardstyle {variant} letöltés: {title}', {",
      "            'variant': label,",
      "            'title': widget.release.title,",
      '          }),',
    ],
    replace: ['          product?.description ?? label,'],
  },
  {
    kind: 'client',
    name: 'a proguard-szabály eltűnik (a Play nem látja a teljes képernyős hívást)',
    file: 'android/app/proguard-rules.pro',
    find: ['-keep class androidx.activity.EdgeToEdge { *; }'],
    replace: ['# (a megtartó szabály elvéve)'],
  },
];

const GENERATED_IMAGE = 'assets/images/nav_home.png';

const runTests = (kind) => {
  const command =
    kind === 'server'
      ? ['node', ['--test', ...SERVER_TESTS]]
      : ['flutter', ['test', ...CLIENT_TESTS]];
  try {
    execFileSync(command[0], command[1], { stdio: 'pipe', shell: true });
    return true;
  } catch {
    return false;
  }
};

const state = { server: null, client: null };
const passes = (kind) => {
  if (state[kind] === null) state[kind] = runTests(kind);
  return state[kind];
};

console.log('--- kiinduló állapot ---');
for (const kind of ['server', 'client']) {
  console.log(`  ${kind}: ${passes(kind) ? 'ZÖLD' : 'BUKIK'}`);
}

const results = [];
for (const mutation of MUTATIONS) {
  const source = fs.readFileSync(mutation.file, 'utf8');
  const eol = eolOf(source);
  const find = mutation.find.join(eol);
  const hits = source.split(find).length - 1;
  if (hits !== 1) {
    results.push('NEM MÉRHETŐ');
    console.log(`\n${mutation.name}\n  NEM MÉRHETŐ — a minta ${hits}× szerepel (1 kell)`);
    continue;
  }
  fs.writeFileSync(mutation.file, source.replace(find, mutation.replace.join(eol)), 'utf8');
  state[mutation.kind] = null;
  const caught = !runTests(mutation.kind);
  fs.writeFileSync(mutation.file, source, 'utf8');
  state[mutation.kind] = null;
  const restored = fs.readFileSync(mutation.file, 'utf8') === source;
  results.push(caught ? 'ELKAPVA' : 'NEM KAPTA EL');
  console.log(
    `\n${mutation.name}\n  ${caught ? 'ELKAPVA' : 'NEM KAPTA EL'}${restored ? '' : ' — ⚠️ a visszaállítás nem bájtazonos!'}`,
  );
}

/* --- A kép-memória kapuja: nagy kép visszatevése ---------------------- */

console.log('\n--- a kép-memória kapuja (nagy ikon visszatevése) ---');
const originalImage = fs.readFileSync(GENERATED_IMAGE);
try {
  execFileSync(
    'ffmpeg',
    ['-y', '-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c=red:s=1000x1000', '-frames:v', '1', GENERATED_IMAGE],
    { stdio: 'pipe' },
  );
  state.client = null;
  const caught = !runTests('client');
  results.push(caught ? 'ELKAPVA' : 'NEM KAPTA EL');
  console.log(`  ${caught ? 'ELKAPVA' : 'NEM KAPTA EL'} — 1000×1000 kép a navigációs ikon helyén`);
} catch (error) {
  results.push('NEM MÉRHETŐ');
  console.log(`  NEM MÉRHETŐ — ${error?.message || error}`);
} finally {
  fs.writeFileSync(GENERATED_IMAGE, originalImage);
  state.client = null;
}
const imageRestored = fs.readFileSync(GENERATED_IMAGE).equals(originalImage);
console.log(`  a kép visszaállítása: ${imageRestored ? 'bájtazonos' : '⚠️ NEM azonos'}`);

console.log('\n--- helyreállított állapot ---');
let after = true;
for (const kind of ['server', 'client']) {
  const green = passes(kind);
  after = after && green;
  console.log(`  ${kind}: ${green ? 'ZÖLD' : 'BUKIK'}`);
}

const caught = results.filter((value) => value === 'ELKAPVA').length;
console.log(`\n${caught}/${results.length} mutáció elkapva`);
process.exitCode = caught === results.length && after && imageRestored ? 0 : 1;
