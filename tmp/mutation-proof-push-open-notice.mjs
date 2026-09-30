// MUTÁCIÓS BIZONYÍTÉK a szavazás/játék push kapujához (plugin 2.14.11).
//
// A kapu (`tools/verify-push-open-notice.php`) akkor ér valamit, ha a VALÓDI
// hibát elkapja. Hat mutáció a **kibontott, szállítandó csomagon**:
//   1. a frissességi kapu elvétele  -> a 2.14.11 feltöltésekor egy fél éve lezárt
//      kérdőív is kimenne (ez a legnagyobb kockázat, ezért ez az első);
//   2. a jelölő-ellenőrzés elvétele -> ugyanarra az időablakra kétszer menne ki;
//   3. az angol cím magyarra állítása -> a nyelvi szétválasztás elveszne;
//   4. a szezon kapcsolójának elvétele -> egy KIKAPCSOLT szavazás is hirdetne;
//   5. a jövőbeli nyitás azonnalira állítása -> a hirdetés a nyitás előtt menne ki;
//   6. a `polls` beállítás-kapu elvétele -> a kikapcsolt eszköz is kapna.
//
// A mérés a ZIP-ből kibontott példányt mutálja, ezért a kiadott csomag
// érintetlen marad; a végén a kibontott fát a ZIP-ből bájtazonosan visszaállítja.
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ZIP = 'build/huhs-mobile-api-2.14.11.zip';
const WORK = 'tmp/mutation-2151';
const EXTRACT = path.join(WORK, 'extract');
const PLUGIN_DIR = path.join(EXTRACT, 'huhs-mobile-api');
const TARGET = path.join(PLUGIN_DIR, 'includes', 'push.php');

/** A kibontott munkapéldány (a ZIP-ből) — a forrás nem változik. */
function extract() {
  fs.rmSync(path.join(REPO, WORK), { recursive: true, force: true });
  fs.mkdirSync(path.join(REPO, EXTRACT), { recursive: true });
  const result = spawnSync('tar', ['-xf', path.join(REPO, ZIP), '-C', path.join(REPO, EXTRACT)], {
    encoding: 'utf8',
  });
  if (result.status !== 0) throw new Error(`kibontás hiba: ${result.stderr || result.status}`);
}

/** A kapu futtatása a konténerben a kibontott (esetleg mutált) csomagon. */
function runGate() {
  const result = spawnSync(
    'docker',
    [
      'run', '--rm',
      '-v', `${REPO}:/work`,
      '-w', '/work',
      'php:8.2-cli',
      'php', '/work/tools/verify-push-open-notice.php', `/work/${WORK.replaceAll('\\', '/')}/extract/huhs-mobile-api`,
    ],
    { encoding: 'utf8', shell: false, maxBuffer: 32 * 1024 * 1024 },
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { failed: result.status !== 0, output };
}

const mutations = [
  {
    title: 'a frissességi kapu elvétele (régi tartalom is hirdethető lenne)',
    apply: (text) =>
      text.replace(
        "    if ($now - $moment > HUHS_PUSH_OPEN_FRESH_WINDOW) return;\n",
        '',
      ),
  },
  {
    title: 'a jelölő-ellenőrzés elvétele (ugyanarra az ablakra kétszer menne ki)',
    apply: (text) =>
      text.replace(
        "    if (get_post_meta($post->ID, '_huhs_push_open_sent', true) === $fingerprint) return;\n",
        '',
      ),
  },
  {
    title: 'az angol cím magyarra állítása (a nyelvi szétválasztás elveszne)',
    apply: (text) => text.replace("'en' => 'The new poll is open'", "'en' => 'Elindult a kérdőív'"),
  },
  {
    title: 'a szezon kapcsolójának elvétele (kikapcsolt szavazás is hirdetne)',
    apply: (text) =>
      text.replace(
        "    $key = (string) ($config['enabled'] ?? '');\n    if ($key === '') return true;\n",
        "    $key = (string) ($config['enabled'] ?? '');\n    if ($key === '' || $key !== '') return true;\n",
      ),
  },
  {
    title: 'a jövőbeli nyitás azonnalira állítása (a nyitás ELŐTT menne ki)',
    apply: (text) => text.replace('$when = max(time() + 1, $moment);', '$when = time() + 1;'),
  },
  {
    title: 'a `polls` beállítás-kapu elvétele (a kikapcsolt eszköz is kapna)',
    apply: (text) =>
      text.replace(
        "        if ($type === 'poll' && array_key_exists('polls', $record) && !$record['polls']) continue;\n",
        '',
      ),
  },
];

extract();
const original = fs.readFileSync(path.join(REPO, TARGET));
const originalHash = createHash('sha256').update(original).digest('hex');

const baseline = runGate();
console.log(`alapállapot (a ZIP-ből kibontva): ${baseline.failed ? 'BUKIK (hiba!)' : 'zöld'}`);
if (baseline.failed) console.log(baseline.output.split('\n').filter((line) => line.startsWith('HIBA')).join('\n'));
let bad = baseline.failed ? 1 : 0;
let caught = 0;

try {
  for (const mutation of mutations) {
    const text = fs.readFileSync(path.join(REPO, TARGET), 'utf8');
    const mutated = mutation.apply(text);
    if (mutated === text) {
      console.log(`ELTER  ${mutation.title} — a minta nem illett`);
      bad += 1;
      continue;
    }
    fs.writeFileSync(path.join(REPO, TARGET), mutated, 'utf8');
    const result = runGate();
    if (result.failed) {
      caught += 1;
      const reason = result.output.split('\n').find((line) => line.startsWith('HIBA ')) ?? '';
      console.log(`OK     ${mutation.title} — ELKAPVA${reason ? ` (${reason.trim().slice(0, 110)})` : ''}`);
    } else {
      bad += 1;
      console.log(`ELTER  ${mutation.title} — NEM bukott meg`);
    }
    fs.writeFileSync(path.join(REPO, TARGET), original);
  }
} finally {
  fs.writeFileSync(path.join(REPO, TARGET), original);
}

const restored = createHash('sha256').update(fs.readFileSync(path.join(REPO, TARGET))).digest('hex') === originalHash;
const after = runGate();
console.log(`\nbájtazonos visszaállítás: ${restored ? 'IGEN' : 'NEM'}`);
console.log(`a helyreállított kör: ${after.failed ? 'BUKIK' : 'zöld'}`);
if (!restored || after.failed) bad += 1;
console.log(`${caught}/${mutations.length} mutáció elkapva${bad ? `, ${bad} hiba` : ''}`);
process.exitCode = bad === 0 ? 0 : 1;
