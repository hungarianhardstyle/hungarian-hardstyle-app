// MUTÁCIÓS BIZONYÍTÉK a kétoldali meghívó-jutalomhoz (2026-09-28).
//
// A kapuk (`functions/referral-reward-plan.test.cjs`,
// `functions/notification-texts.test.cjs`, `test/services/referral_reward_test.dart`)
// akkor érnek valamit, ha a VALÓDI hibát elkapják. Hét mutáció:
//   1. a meghívott jutalmának elvétele        -> visszaáll az EGYOLDALÚ jutalom;
//   2. az önmegírás-védelem elvétele          -> pontfarmolás a saját kóddal;
//   3. a „már beváltott" kapu elvétele        -> egy írás újabb kört indíthat;
//   4. a jelölő oldalankénti szétválasztásának elvétele -> az egyik oldal
//      jóváírása elviszi a másikét;
//   5. a jelölő írása a jóváírás ELŐTT      -> hiba esetén elveszne a pont;
//   6. a meghívott forráskulcsa a meghívóéval azonos -> a ledger összemosódik;
//   7. a kliens összege elcsúszik a szerverétől -> a felület mást ígér.
//
// A 7. mutáció a FLUTTER kaput méri (a felület és a szerver egyezését), a többi
// a tiszta node-tesztet. A szkript a valódi fájlokat a végén bájtazonosan
// visszaállítja (és ellenőrzi).
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const NODE_TESTS = ['functions/referral-reward-plan.test.cjs', 'functions/notification-texts.test.cjs'];
const FLUTTER_TEST = 'test/services/referral_reward_test.dart';
const FILES = [
  'functions/referral-reward-plan.js',
  'functions/index.js',
  'lib/services/referral_reward.dart',
];

const originals = new Map(FILES.map((file) => [file, fs.readFileSync(path.join(REPO, file))]));
const hashes = new Map(
  FILES.map((file) => [file, createHash('sha256').update(originals.get(file)).digest('hex')]),
);

function runNode() {
  const result = spawnSync(process.execPath, ['--test', ...NODE_TESTS], {
    cwd: REPO,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  return { failed: result.status !== 0, output: `${result.stdout ?? ''}${result.stderr ?? ''}` };
}

function runFlutter() {
  const result = spawnSync('flutter', ['test', FLUTTER_TEST], {
    cwd: REPO,
    encoding: 'utf8',
    shell: true,
    maxBuffer: 64 * 1024 * 1024,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { failed: result.status !== 0 || /Some tests failed/.test(output), output };
}

const mutations = [
  {
    title: 'a meghívott jutalmának elvétele (visszaáll az egyoldalú jutalom)',
    file: 'functions/referral-reward-plan.js',
    runner: 'node',
    apply: (text) => text.replace('const INVITEE_REWARD_POINTS = 25;', 'const INVITEE_REWARD_POINTS = 0;'),
  },
  {
    title: 'az önmegírás-védelem elvétele (saját kóddal lehet pontot farmolni)',
    file: 'functions/referral-reward-plan.js',
    runner: 'node',
    apply: (text) => text.replace("  if (inviterId === inviteeId) return { ...empty, skipped: 'self-referral' };\n", ''),
  },
  {
    title: 'az öngyógyítás elvétele (a `before.referredBy` kapu visszatevése)',
    file: 'functions/referral-reward-plan.js',
    runner: 'node',
    apply: (text, eol) =>
      text.replace(
        [
          '  // ⚠️ SZÁNDÉKOSAN NINCS `before`-kapu: a döntés a profilban tárolt',
          '  // **jelölőkből** jön, ezért egy korábban elveszett jutalom **pótlódik** a',
          '  // következő írásnál, kétszer viszont nem adható (jelölő + ledger).',
        ].join(eol),
        "  if (cleanId((arguments[0] || {}).before?.referredBy)) return { ...empty, skipped: 'already-referred' };",
      ),
  },
  {
    title: 'a jelölő szétválasztásának elvétele (a meghívott jelölője a meghívóéval azonos)',
    file: 'functions/referral-reward-plan.js',
    runner: 'node',
    apply: (text) =>
      text.replace(
        "const INVITEE_FLAG = 'referralWelcomeGranted';",
        "const INVITEE_FLAG = 'referralRewardGranted';",
      ),
  },
  {
    title: 'a jelölő írása a jóváírás ELŐTT (hiba esetén elveszne a pont)',
    file: 'functions/index.js',
    runner: 'node',
    // ⚠️ EOL-TUDATOS horgony (a projekt visszatérő tanulsága): a fájl a gépen
    // CRLF-es lehet, ezért a mintát a fájl SAJÁT sorvégeiből építjük — a `\n`-es
    // minta különben „nem illett" volna (mért eset, 2026-09-28).
    apply: (text, eol) =>
      text.replace(
        [
          '        const result = await awardAchievementPoints(reward.userId, reward.points, reward.reason);',
          '        // A jelölő csak SIKERES jóváírás után íródik — így egy átmeneti hiba',
          '        // nem veszíti el a pontot, viszont egy ismételt futás sem dupláz.',
          '        await event.data.after.ref.update({',
          '          [reward.flag]: true,',
          '          [`${reward.flag}At`]: FieldValue.serverTimestamp(),',
          '        });',
        ].join(eol),
        [
          '        await event.data.after.ref.update({',
          '          [reward.flag]: true,',
          '          [`${reward.flag}At`]: FieldValue.serverTimestamp(),',
          '        });',
          '        const result = await awardAchievementPoints(reward.userId, reward.points, reward.reason);',
        ].join(eol),
      ),
  },
  {
    title: 'a meghívott forráskulcsa a meghívóéval azonos (a ledger összemosódik)',
    file: 'functions/referral-reward-plan.js',
    runner: 'node',
    apply: (text) => text.replace("const INVITEE_REASON_PREFIX = 'referral_welcome:';", "const INVITEE_REASON_PREFIX = 'referral:';"),
  },
  {
    title: 'a kliens összege elcsúszik a szerverétől (a felület mást ígér)',
    file: 'lib/services/referral_reward.dart',
    runner: 'flutter',
    apply: (text) => text.replace('const int referralInviteeRewardPoints = 25;', 'const int referralInviteeRewardPoints = 30;'),
  },
];

const baseline = { node: runNode(), flutter: runFlutter() };
console.log(`alapállapot: node ${baseline.node.failed ? 'BUKIK (hiba!)' : 'zöld'}, flutter ${baseline.flutter.failed ? 'BUKIK (hiba!)' : 'zöld'}`);
let bad = baseline.node.failed || baseline.flutter.failed ? 1 : 0;
let caught = 0;

try {
  for (const mutation of mutations) {
    const filePath = path.join(REPO, mutation.file);
    const original = originals.get(mutation.file).toString('utf8');
    const eol = original.includes('\r\n') ? '\r\n' : '\n';
    const mutated = mutation.apply(original, eol);
    if (mutated === original) {
      console.log(`ELTER  ${mutation.title} — a minta nem illett`);
      bad += 1;
      continue;
    }
    fs.writeFileSync(filePath, mutated, 'utf8');
    const result = mutation.runner === 'flutter' ? runFlutter() : runNode();
    if (result.failed) {
      caught += 1;
      const reason =
        result.output
          .split('\n')
          .find((line) => /✖|Expected|HIBA|AssertionError/.test(line))
          ?.trim()
          .slice(0, 110) ?? '';
      console.log(`OK     ${mutation.title} — ELKAPVA${reason ? ` (${reason})` : ''}`);
    } else {
      bad += 1;
      console.log(`ELTER  ${mutation.title} — NEM bukott meg`);
    }
    fs.writeFileSync(filePath, original, 'utf8');
  }
} finally {
  for (const file of FILES) fs.writeFileSync(path.join(REPO, file), originals.get(file));
}

const restored = FILES.every(
  (file) =>
    createHash('sha256').update(fs.readFileSync(path.join(REPO, file))).digest('hex') === hashes.get(file),
);
const after = { node: runNode(), flutter: runFlutter() };
console.log(`\nbájtazonos visszaállítás: ${restored ? 'IGEN' : 'NEM'}`);
console.log(`a helyreállított körök: node ${after.node.failed ? 'BUKIK' : 'zöld'}, flutter ${after.flutter.failed ? 'BUKIK' : 'zöld'}`);
if (!restored || after.node.failed || after.flutter.failed) bad += 1;
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 ? 0 : 1;
