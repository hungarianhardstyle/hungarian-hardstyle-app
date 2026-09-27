#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **2026-09-27-i gyermekbiztonsági körhöz**:
 *   * a jelzőrendszer döntése (`functions/child-safety-plan.js`),
 *   * a jelzés kiírása és a **rendszer**-ágú értesítés (`functions/index.js`),
 *   * a születési dátum emlékeztető **kapcsolója** és idempotenciája
 *     (`functions/birth-date-notice-plan.js` + `index.js`),
 *   * a kliens célpont-útja (`content_target.dart`) és a beállító képernyő.
 *
 * Minden mutációnál elvárjuk, hogy a kapuk **bukjanak**, majd bájtazonosan
 * visszaállítunk, és a helyreállított körnek **zöldnek** kell lennie.
 *
 * Használat: node tmp/mutation-proof-child-safety-birthday.mjs
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const SERVER_TESTS = [
  'functions/child-safety-plan.test.cjs',
  'functions/birth-date-notice-plan.test.cjs',
];
const CLIENT_TESTS = [
  'test/services/notification_language_test.dart',
  'test/services/birth_date_notice_link_test.dart',
];

const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const MUTATIONS = [
  {
    kind: 'server',
    name: 'a jelzési küszöb eltűnik (minden életkorra-kérdezés jelez)',
    file: 'functions/child-safety-plan.js',
    find: ['const MINIMUM_SCORE = 3;'],
    replace: ['const MINIMUM_SCORE = 0;'],
  },
  {
    kind: 'server',
    name: 'az ANGOL titoktartás-minta eltűnik (csak magyarul jelez)',
    file: 'functions/child-safety-plan.js',
    find: ["      'dont tell anyone',", ''],
    replace: [''],
  },
  {
    kind: 'server',
    name: 'a kiskorú + magas kockázatú jel fokozás eltűnik',
    file: 'functions/child-safety-plan.js',
    find: [
      '  if (',
      '    severity &&',
      '    minorInvolved &&',
      '    textSignals.some((code) => HIGH_RISK_CODES.includes(code))',
      '  ) {',
      '    severity = \'high\';',
      '  }',
    ],
    replace: ['  // (a fokozás elvéve — a mutáció azt méri, hogy a kapu elkapja)'],
  },
  {
    kind: 'server',
    name: 'a korkülönbség súlya eltűnik (a nagy korkülönbség önmagában nem jelez)',
    file: 'functions/child-safety-plan.js',
    find: ['  if (ageGap >= AGE_GAP_THRESHOLD) return 2;'],
    replace: ['  if (ageGap >= AGE_GAP_THRESHOLD) return 0;'],
  },
  {
    kind: 'server',
    name: 'a rendszer-jelzés újra a „felhasználó jelentett" szöveget kapja',
    file: 'functions/index.js',
    find: ['  const systemFlag = report.systemFlag === true;'],
    replace: ['  const systemFlag = false;'],
  },
  {
    kind: 'server',
    name: 'a jelző újrakézbesítésnél is ír/naplóz (nincs `created` kapu)',
    file: 'functions/index.js',
    find: [
      '  const created = await writeFlag(flagId, flag);',
      '  // Újrakézbesítés: a jelzés már megvan, nincs második dokumentum és értesítés.',
      '  if (!created) return null;',
    ],
    replace: ['  await writeFlag(flagId, flag);'],
  },
  {
    kind: 'server',
    name: 'a születési dátum kiküldést már semmi nem zárja (a kapcsoló eltűnik)',
    file: 'functions/index.js',
    find: ['    if (settings.enabled !== true) {'],
    replace: ['    if (false) {'],
  },
  {
    kind: 'server',
    name: 'az e-mail ténye nem kerül a profilba (minden kör újraküldi)',
    file: 'functions/index.js',
    find: [
      '              [BIRTH_DATE_NOTICE_FIELD]: FieldValue.serverTimestamp(),',
      '              [BIRTH_DATE_NOTICE_EMAIL_FIELD]: FieldValue.serverTimestamp(),',
    ],
    replace: ['              [BIRTH_DATE_NOTICE_FIELD]: FieldValue.serverTimestamp(),'],
  },
  {
    kind: 'client',
    name: 'az angol katalógusból eltűnik a születési dátum emlékeztető',
    file: 'assets/i18n/notification_texts.json',
    find: ['        "title": "Please add your date of birth",'],
    replace: ['        "title": "Kérjük, add meg a születési dátumod",'],
  },
  {
    kind: 'client',
    name: 'a `birth_date` célpont kikerül a közös feloldóból',
    file: 'lib/core/navigation/content_target.dart',
    find: ["      case 'birth_date':"],
    replace: ["      case 'birth_date_x':"],
  },
  {
    kind: 'client',
    name: 'a beállító képernyő dátum nélkül is menthetővé válik',
    file: 'lib/screens/community/birth_date_setup_screen.dart',
    find: ['            onPressed: _value == null || _saving ? null : _save,'],
    replace: ['            onPressed: _save,'],
  },
];

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

console.log('\n--- helyreállított állapot ---');
let after = true;
for (const kind of ['server', 'client']) {
  const green = passes(kind);
  after = after && green;
  console.log(`  ${kind}: ${green ? 'ZÖLD' : 'BUKIK'}`);
}

const caught = results.filter((value) => value === 'ELKAPVA').length;
console.log(`\n${caught}/${MUTATIONS.length} mutáció elkapva`);
process.exitCode = caught === MUTATIONS.length && after ? 0 : 1;
