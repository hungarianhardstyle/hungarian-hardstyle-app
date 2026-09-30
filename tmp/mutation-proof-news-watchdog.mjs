// MUTÁCIÓS BIZONYÍTÉK a hír-push őréhez (plugin 2.14.12).
//
// MIÉRT: a zöld kapu önmagában nem bizonyíték — a mutáció azt méri, hogy a kapu
// TÉNYLEG elkapja-e a hibát. Minden mutáció a **másolatban** fut (a szállítandó
// forráshoz nem nyúlunk), és a végén a forrás bájtazonosságát is mérjük.
//
// A kör: minden mutációhoz külön könyvtár → a valódi PHP-teszt (Docker) futtatása
// a mutált forráson → a várt ellenőrzésnek EL KELL HASZNIA.
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const SOURCE = 'tmp/plugin-2152/huhs-mobile-api';
const WORK = 'tmp/mutation-news';
const TEST = '/work/tools/verify-push-news-watchdog.php';

const digest = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const before = digest(path.join(SOURCE, 'includes/push.php'));

/** A mutációk: [cím, mit cserélünk, mire, melyik ellenőrzésnek kell elhasalnia]. */
const mutations = [
  [
    'a FRISSESSÉGI KAPU elvétele (a 6 óránál régebbi cikk is kimegy)',
    '    $published = (int) get_post_time(\'U\', true, $post_id);\n    if ($published <= 0 || $published < $now - HUHS_PUSH_NEWS_FRESH_WINDOW) return false;\n',
    '    $published = (int) get_post_time(\'U\', true, $post_id);\n',
    'a 6 óránál régebbi cikkre NEM indul kör',
  ],
  [
    'a FÜGGŐ KÖR védelmének elvétele (dupla ütemezés)',
    '    $pending = (int) get_post_meta($post_id, \'_huhs_push_news_pending_at\', true);\n    if ($pending > 0 && $pending > $now - HOUR_IN_SECONDS) return false;\n',
    '',
    'lejárt hézag MELLETT is véd a függő kör',
  ],
  [
    'a JELÖLŐ ellenőrzésének elvétele (a már értesített cikk újra kimegy)',
    '    if ((string) get_post_meta($post_id, \'_huhs_push_news_sent\', true) !== \'\') return false;\n',
    '',
    'a már értesített cikkre akkor sem megy ki újra',
  ],
  [
    'a KERET és a HÉZAG elvétele (végtelen próbálkozás)',
    '    $tries = (int) get_post_meta($post_id, \'_huhs_push_news_watchdog_tries\', true);\n    if ($tries >= HUHS_PUSH_NEWS_WATCHDOG_MAX_TRIES) return false;\n    $last = (int) get_post_meta($post_id, \'_huhs_push_news_watchdog_at\', true);\n    if ($last > 0 && $last > $now - HUHS_PUSH_NEWS_WATCHDOG_GAP) return false;\n',
    '',
    'a keret elfogyása után nem próbálkozik tovább',
  ],
  [
    'az ÖT PERCES ütemezés elvétele (az ör nem fut rendszeresen)',
    "wp_schedule_event(time() + 180, 'huhs_five_minutes', 'huhs_push_news_scan')",
    "wp_schedule_event(time() + 180, 'hourly', 'huhs_push_news_scan')",
    'az ör az `init`-ben regisztrálódik az ötperces ütemezésre',
  ],
  [
    'a MENTÉS-HOOK elvétele (csak a törékeny közzététel-hook marad)',
    "add_action('save_post_post', function ($post_id, $post = null, $update = null) {",
    "add_action('save_post_nothing', function ($post_id, $post = null, $update = null) {",
    'a `save_post_post` hook be van kötve',
  ],
  [
    'a KÜLDÉS nem a bizonyított útra kerül (nincs függő jelölő)',
    '    $queued = huhs_schedule_news_push(get_post($post_id));',
    "    $queued = huhs_push_send('Új hír', (string) get_the_title($post_id), array('type' => 'news', 'id' => (string) $post_id)) >= 0;",
    'a küldés a bizonyított útra került',
  ],
];

fs.rmSync(WORK, { recursive: true, force: true });
fs.mkdirSync(WORK, { recursive: true });

let caught = 0;
const report = [];
const say = (line) => {
  console.log(line);
  report.push(line);
};
for (const [index, [title, from, to, expectedFailure]] of mutations.entries()) {
  const dir = path.join(WORK, `m${index + 1}`);
  fs.mkdirSync(dir, { recursive: true });
  const target = path.join(dir, 'huhs-mobile-api');
  fs.cpSync(SOURCE, target, { recursive: true });

  const file = path.join(target, 'includes', 'push.php');
  const source = fs.readFileSync(file, 'utf8');
  if (!source.includes(from)) {
    say(`ELTER  ${title} — a minta nem illik a forrásra (a bizonyíték érvénytelen)`);
    continue;
  }
  fs.writeFileSync(file, source.replace(from, to), 'utf8');

  let output = '';
  let failed = false;
  try {
    output = execFileSync(
      'docker',
      ['run', '--rm', '-v', `${process.cwd()}:/work`, '-w', '/work', 'php:8.2-cli', 'php', TEST, `/work/${target.replaceAll('\\', '/')}`],
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
    );
  } catch (error) {
    failed = true;
    output = `${error.stdout ?? ''}${error.stderr ?? ''}`;
  }

  const hit = failed || output.includes('HIBA');
  const named = output.includes(`HIBA ${expectedFailure}`) || output.includes(expectedFailure);
  if (hit && named) {
    caught += 1;
    say(`OK     ${title} → a kapu elcsípte («${expectedFailure}»)`);
  } else {
    say(`ELTER  ${title} → NEM bukott el a várt ellenőrzés («${expectedFailure}»), failed=${failed}`);
    for (const line of output.split(/\r?\n/).filter((entry) => entry.startsWith('HIBA')).slice(0, 5)) say(`       ${line}`);
  }
}

const after = digest(path.join(SOURCE, 'includes/push.php'));
say(`\n${caught}/${mutations.length} mutáció ELKAPVA`);
say(`a szállítandó forrás ${before === after ? 'BÁJTAZONOS (érintetlen)' : 'MEGVÁLTOZOTT — HIBA!'}`);
fs.writeFileSync('tmp/mutation-news-proof.txt', `${report.join('\n')}\n`, 'utf8');
fs.rmSync(WORK, { recursive: true, force: true });
process.exitCode = caught === mutations.length && before === after ? 0 : 1;
