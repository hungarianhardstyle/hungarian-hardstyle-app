#!/usr/bin/env node
/**
 * A szállítandó plugin-CSOMAG ellenőrzése: a ZIP ugyanaz-e, mint a forrás, és
 * benne vannak-e a kiadás kritikus elemei.
 *
 * MIÉRT ESZKÖZ: a csomagot a `tools/build-plugin-zip.mjs` írja, a viselkedését a
 * `tools/run-php-plugin-tests.mjs` méri — de eddig **semmi** nem mérte azt, hogy
 * a ZIP **tartalma** (fájllista, bájtok) megegyezik-e a forráskönyvtárral, és
 * hogy a release kritikus sorai tényleg bekerültek-e a csomagba. Ez a hiányzó láncszem.
 *
 * Használat:
 *   node tools/verify-plugin-package.mjs                    # 2.13.0 (alap)
 *   node tools/verify-plugin-package.mjs --zip=build/x.zip --source=.tmp-api-260/huhs-mobile-api
 *   node tools/verify-plugin-package.mjs --self-test
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const DEFAULT_ZIP = 'build/huhs-mobile-api-2.14.4.zip';
export const DEFAULT_SOURCE = '.tmp-api-260/huhs-mobile-api';
export const EXPECTED_ROOT = 'huhs-mobile-api';

/** Rekurzív fájllista (relatív, `/` elválasztóval), rendezve. */
export function listFiles(dir) {
  const out = [];
  const walk = (current, prefix) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) walk(path.join(current, entry.name), relative);
      else if (entry.isFile()) out.push(relative);
    }
  };
  walk(dir, '');
  return out.sort();
}

/** Két fájllista összevetése (hiányzó / plusz). */
export function compareFileLists(zipFiles, sourceFiles) {
  const zipSet = new Set(zipFiles);
  const sourceSet = new Set(sourceFiles);
  return {
    missing: sourceFiles.filter((file) => !zipSet.has(file)),
    extra: zipFiles.filter((file) => !sourceSet.has(file)),
  };
}

/**
 * A PHP megjegyzések eltávolítása — a tiltó ellenőrzésekhez kell.
 *
 * ⚠️ MIÉRT (mért hiba): a pótló kör fejlécében **szövegként** szerepel, hogy
 * „nem `wp_update_post`-ot hívunk" — a nyers `includes()` keresés ezért
 * hamisan bukott. A tiltást a **kódra** kell mérni, nem a kommentre.
 */
export function stripPhpComments(source) {
  return String(source)
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .map((line) => line.replace(/\/\/.*$/, ''))
    .join('\n');
}

/**
 * A 2.13.0 kritikus tartalmi elemei — `read(relative)` adja a fájlok szövegét.
 *
 * Minden sor egy állítás; a `read` szándékosan injektálható, hogy önteszttel
 * mérhető legyen (nem csak a valódi ZIP-en).
 */
export function packageChecks(read) {
  const main = read('huhs-mobile-api.php');
  const sweep = read('includes/translation-sweep.php');
  const sweepCode = stripPhpComments(sweep);
  const places = read('includes/translation-places.php');
  const fields = read('includes/translation-fields.php');
  const cron = read('includes/translation-cron.php');
  const events = read('includes/api-events.php');
  const artists = read('includes/api-artists.php');
  const organizers = read('includes/api-organizers.php');
  const releases = read('includes/api-releases.php');
  const faq = read('includes/faq.php');
  const poll = read('includes/poll.php');
  const prize = read('includes/prize.php');
  const games = read('includes/games.php');
  const gamesCode = stripPhpComments(games);
  const fieldsCode = stripPhpComments(fields);

  return [
    ['a fejléc és a konstans is 2.14.4', /Version:\s*2\.14\.4/.test(main) && main.includes("HUHS_API_VERSION', '2.14.4'")],
    ['a fő fájl behúzza a hely-névtárat, a pótló kört és a mező-fordítást',
      main.includes('includes/translation-places.php') && main.includes('includes/translation-sweep.php')
        && main.includes('includes/translation-fields.php')],
    ['a mező-fordítás ismeri a kérdőív és a nyereményjáték meta-kulcsait',
      fields.includes("'_huhs_poll_question'") && fields.includes("'_huhs_prize_answers'")
        && fields.includes("'_huhs_prize_description'")],
    ['a mező-fordítás a lista HOSSZÁT is ellenőrzi (nincs félkész fordítás)',
      fields.includes('count($translated) === count($source)')],
    ['a mező-fordításnak SAJÁT hiba-jelölője van (nem blokkolja a cím/törzs ágat)',
      fields.includes('HUHS_TRANSLATION_FIELDS_FAILED_META')],
    ['a MINDEN típus listája a meta-szöveges típusokat is tartalmazza',
      read('includes/post-translation-meta.php').includes('huhs_translation_field_post_types()')],
    ['a GYÍK a közös kaput használja (kérdés = cím, válasz = törzs)',
      faq.includes('huhs_translation_meta_values(') && faq.includes('huhs_request_lang($request)')
        && faq.includes("'has_en'")],
    ['a GYÍK kategória-neveit névtárból fordítja',
      faq.includes('huhs_translation_faq_category_names()') && faq.includes("'első lépések' => 'Getting Started'")],
    ['a kérdőív a mező-fordítást olvassa (kérdés + válaszlehetőségek)',
      poll.includes('huhs_translation_text(') && poll.includes('huhs_translation_list(')],
    ['a nyereményjáték a mező-fordítást olvassa (kérdés, válaszok, nyeremény)',
      prize.includes("'_huhs_prize_question'") && prize.includes("'_huhs_prize_answers'")
        && prize.includes("'_huhs_prize_description'")],
    ['a pótlás a HIÁNYZÓ angolt keresi (NOT EXISTS)', sweep.includes("'compare' => 'NOT EXISTS'")],
    ['a pótlás a közös fordítást hívja (nincs saját másolat)',
      sweep.includes('huhs_run_translation($post->ID, $force)')],
    ['a pótlás óránként ütemeződik', sweep.includes("'hourly'") && sweep.includes("'huhs_translation_sweep_event'")],
    ['a pótlás korlátozza a költséget (limit + budget)', sweep.includes("'limit'") && sweep.includes("'budget'")],
    ['a pótlás NEM hoz létre felhasználói értesítést (nincs wp_update_post / ütemezés a kódban)',
      !/wp_update_post\s*\(/.test(sweepCode) && !/wp_schedule_single_event\s*\(/.test(sweepCode)],
    ['a tartós hiba késleltetve próbálkozik újra', sweep.includes('huhs_translation_retry_delay')],
    ['a pótlás admin végpontjai bent vannak (status + sweep)',
      sweep.includes("'/translations/status'") && sweep.includes("'/translations/sweep'")],
    ['az ország-névtárban benne van a Magyarország → Hungary', places.includes("'magyarország' => 'Hungary'")],
    ['a "Velence" csapda dokumentálva van (nem fordítjuk félre)', places.includes('Velence') && !places.includes("'velence' =>")],
    ['a hely-névtár csak angol kérésre nyúl az értékhez', places.includes("if ($lang !== 'en')")],
    ['a cron ujjlenyomatot ír a kész fordításról', cron.includes('HUHS_TRANSLATION_HASH_META')],
    ['a cron nem fordít kétszer ugyanarra a szövegre', cron.includes('huhs_translation_is_current')],
    ['a cron a meta-szöveges típusokat is fordítja', cron.includes('huhs_run_field_translation(')],
    ['a cron státuszt ad vissza (a pótlás ebből számol)', cron.includes("return 'translated';")],
    ['a kulcs továbbra sincs a kódban', !/sk-[A-Za-z0-9]{16,}/.test(cron + sweep + places + fields)],
    ['az esemény a névtáron át adja az országot', events.includes('huhs_translation_country_value(')],
    ['a DJ a névtáron át adja az országot', artists.includes('huhs_translation_country_value(')],
    ['a szervező a névtáron át adja az országot', organizers.includes('huhs_translation_country_value(')],
    ['a szervező átadja a nyelvet a közelgő eseményeknek', organizers.includes('use ($lang)')],
    ['a kiadvány végpont továbbra sem hív fordítást', !releases.includes('huhs_translation_meta_values(')],
    // ---- 2.14.1: a JÁTÉK végpontjai (mért éles hiba javítása) -------------
    ['a játék összefoglalója a nyelvi olvasón át megy ki (nem nyers meta)',
      gamesCode.includes("huhs_translation_text($post->ID, $lang, '_huhs_game_summary'")],
    ['a játéktípus neve névtárból fordul (nem a magyar HUHS_GAME_TYPES megy ki)',
      gamesCode.includes('huhs_game_type_label($type, $lang)') && gamesCode.includes('huhs_game_type_labels_en()')],
    ['a játék névtár minden típust lefed',
      ["'daily_challenge'", "'hardstyle_quiz'", "'festival_quiz'", "'hungarian_hardstyle_quiz'",
        "'guess_track'", "'guess_artist'", "'timeline'", "'who_is_dj'", "'cover_recognition'"]
        .every((key) => gamesCode.includes(key))],
    ['a játék nyilvános végpontjai átadják a kért nyelvet',
      (gamesCode.match(/huhs_request_lang\(\$request\)/g) || []).length >= 4],
    ['a játék a magyar ágat nem rontja el (nem-angol kérésre a magyar címke)',
      gamesCode.includes("if ($lang !== 'en')")],
    ['a játék kérdései és válaszai is fordulnak (2.14.2, lapos kulcsokkal)',
      gamesCode.includes('huhs_translation_game_questions(')
        && fieldsCode.includes("'_huhs_game_questions' => 'questions'")
        && fieldsCode.includes('huhs_translation_game_question_texts(')],
    ['a helyes válasz indexe (`correct`) nem kerül a fordítási kérésbe',
      !/correct/i.test(/function huhs_translation_game_question_texts\(\$post_id\)[\s\S]*?\n\}/.exec(fieldsCode)?.[0] ?? 'HIBA')],
    ['a nyilvános játék-payload nem adja ki a `correct` indexet',
      // ⚠️ Csak a NYILVÁNOS payloadra mérünk: a `correct` a privát (proxy)
      // útvonalon és a validációban **legitim** módon szerepel.
      !/'correct'/.test(
        /function huhs_game_public_payload[\s\S]*?\nfunction huhs_game_create_clip_token/.exec(gamesCode)?.[0] ?? 'HIBA',
      )],
    // ---- 2.14.3: a meta-írás escape-jei (mért éles hiba) --------------------
    ['a mező-fordítás írása `wp_slash()`-ol (a WordPress unslash-e nem roncsolhatja a JSON-escape-eket)',
      fieldsCode.includes('wp_slash(wp_json_encode($stored))')],
    ['a séma-verzió jelölő megvan (a régi, hibás escape-ekkel mentett fordítások újragenerálódnak)',
      fieldsCode.includes('HUHS_TRANSLATION_FIELDS_VERSION = 2')
        && fieldsCode.includes('HUHS_TRANSLATION_FIELDS_VERSION_META')],
    ['a naprakészség a séma-verziót is megköveteli',
      /function huhs_translation_fields_current\(\$post_id\)[\s\S]*?HUHS_TRANSLATION_FIELDS_VERSION\b/.test(fieldsCode)],
    ['a cím/törzs fordítás írása is `wp_slash()`-ol',
      cron.includes("wp_slash($response['")],
    // ---- 2.14.4: a séma-verzió kapuja ELÉRHETŐ + kényszerített javítás -----
    // ⚠️ MÉRT ÉLES HIBA: a 2.14.3 verzió-kapuja **elérhetetlen** volt, mert a
    // pótló kör SQL-előszűrője csak a HIÁNYZÓ/üres fordításra szűrt — a
    // nyeremény leírásában élesben ott maradt az `rnrn`.
    ['a várólista előszűrője a séma-verziót is figyeli (a kapu elérhető)',
      sweep.includes('HUHS_TRANSLATION_FIELDS_VERSION_META')
        && sweep.includes("'compare' => 'NOT EXISTS'")
        && /HUHS_TRANSLATION_FIELDS_VERSION_META[\s\S]{0,200}'compare' => '<'/.test(sweep)],
    ['a verzió-összehasonlítás numerikus (nem join-függő `!=`)',
      /'compare' => '<',\s*'type' => 'NUMERIC'/.test(sweep)],
    ['a kényszerített javítás (`force`) végig van kötve',
      sweep.includes('function huhs_translation_pending_posts($post_type, $limit = 5, $force = false)')
        && sweep.includes('huhs_run_translation($post->ID, $force)')
        && sweep.includes("'force' => $request->get_param('force')")
        && cron.includes('function huhs_run_translation($post_id, $force = false)')],
    ['a kényszerített út a cím/törzs és a mező-ágat is átviszi',
      cron.includes('huhs_run_content_translation($post, $title, $content, $force)')
        && cron.includes('huhs_run_field_translation($post_id, $force)')
        && fieldsCode.includes('function huhs_run_field_translation($post_id, $force = false)')],
    ['a kényszerített út csak fordítható forrást választ ki',
      sweep.includes('function huhs_translation_post_has_source($post)')
        && sweep.includes('huhs_translation_post_has_source($post)')],
  ];
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  check(
    'a fájllista-összevetés azonos listára nem jelez semmit',
    JSON.stringify(compareFileLists(['a.php', 'b/c.php'], ['a.php', 'b/c.php'])) === '{"missing":[],"extra":[]}',
  );
  check(
    'a hiányzó és a plusz fájlt is jelzi',
    JSON.stringify(compareFileLists(['a.php'], ['a.php', 'b.php'])) === '{"missing":["b.php"],"extra":[]}'
      && JSON.stringify(compareFileLists(['a.php', 'x.php'], ['a.php'])).includes('x.php'),
  );

  const star = 'x';
  const full = {
    'huhs-mobile-api.php': 'Version: 2.14.4 HUHS_API_VERSION\', \'2.14.4\' includes/translation-places.php includes/translation-sweep.php includes/translation-fields.php',
    'includes/translation-sweep.php': "'compare' => 'NOT EXISTS' huhs_run_translation($post->ID, $force) 'hourly' 'huhs_translation_sweep_event' 'limit' 'budget' huhs_translation_retry_delay '/translations/status' '/translations/sweep' HUHS_TRANSLATION_FIELDS_VERSION_META HUHS_TRANSLATION_FIELDS_VERSION_META x 'compare' => '<' \"'compare' => '<',\\n            'type' => 'NUMERIC'\" function huhs_translation_pending_posts($post_type, $limit = 5, $force = false) 'force' => $request->get_param('force') function huhs_translation_post_has_source($post) huhs_translation_post_has_source($post)",
    'includes/translation-fields.php': "'_huhs_poll_question' '_huhs_prize_answers' '_huhs_prize_description' '_huhs_game_summary' \"'_huhs_game_questions' => 'questions'\" huhs_translation_game_question_texts($post_id) { return array(); } count($translated) === count($source) HUHS_TRANSLATION_FIELDS_FAILED_META wp_slash(wp_json_encode($stored)) HUHS_TRANSLATION_FIELDS_VERSION = 2 HUHS_TRANSLATION_FIELDS_VERSION_META function huhs_translation_fields_current($post_id) { HUHS_TRANSLATION_FIELDS_VERSION function huhs_run_field_translation($post_id, $force = false)",
    'includes/translation-places.php': "'magyarország' => 'Hungary' Velence if ($lang !== 'en')",
    'includes/translation-cron.php': "HUHS_TRANSLATION_HASH_META huhs_translation_is_current huhs_run_field_translation( return 'translated'; wp_slash($response['title']) function huhs_run_translation($post_id, $force = false) huhs_run_content_translation($post, $title, $content, $force) huhs_run_field_translation($post_id, $force)",
    'includes/post-translation-meta.php': 'huhs_translation_field_post_types()',
    'includes/faq.php': "huhs_translation_meta_values( huhs_request_lang($request) 'has_en' huhs_translation_faq_category_names() 'első lépések' => 'Getting Started'",
    'includes/poll.php': 'huhs_translation_text( huhs_translation_list(',
    'includes/prize.php': "'_huhs_prize_question' '_huhs_prize_answers' '_huhs_prize_description'",
    'includes/api-events.php': 'huhs_translation_country_value(',
    'includes/api-artists.php': 'huhs_translation_country_value(',
    'includes/api-organizers.php': 'huhs_translation_country_value( use ($lang)',
    'includes/api-releases.php': star,
    // A 2.14.1/2.14.2 szintetikus játék-fájlja: minden új ellenőrzés mintája benne van.
    'includes/games.php': "huhs_translation_text($post->ID, $lang, '_huhs_game_summary' huhs_game_type_label($type, $lang) huhs_game_type_labels_en() huhs_translation_game_questions( "
      + "'daily_challenge' 'hardstyle_quiz' 'festival_quiz' 'hungarian_hardstyle_quiz' 'guess_track' 'guess_artist' 'timeline' 'who_is_dj' 'cover_recognition' "
      + "huhs_request_lang($request) huhs_request_lang($request) huhs_request_lang($request) huhs_request_lang($request) if ($lang !== 'en') questions",
  };
  const readFull = (relative) => full[relative] ?? '';
  const okChecks = packageChecks(readFull);
  check('a teljes (szintetikus) csomagon minden tartalmi ellenőrzés zöld', okChecks.every(([, ok]) => ok));

  const missingSweep = packageChecks((relative) => (relative === 'includes/translation-sweep.php' ? '' : readFull(relative)));
  check(
    'a hiányzó pótló kört észreveszi (nem hamis zöld)',
    missingSweep.some(([, ok]) => !ok),
  );
  const leakedKey = packageChecks((relative) => (relative === 'includes/translation-cron.php' ? 'sk-abcdefghijklmnop1234' : readFull(relative)));
  check(
    'a kódba került kulcsot észreveszi',
    leakedKey.some(([label, ok]) => label.includes('kulcs') && !ok),
  );
  const notifyCheck = (sweepSource) =>
    packageChecks((relative) => (relative === 'includes/translation-sweep.php' ? sweepSource : readFull(relative)))
      .find(([label]) => label.includes('felhasználói értesítést'))[1];

  check(
    'a megjegyzésben szereplő tiltott hívás nem buktat (a tiltás a KÓDRA szól)',
    notifyCheck(`${full['includes/translation-sweep.php']}\n// nem wp_update_post-ot hívunk, hanem meta-írást`) === true,
  );
  check(
    'a valódi wp_update_post hívást viszont elkapja',
    notifyCheck(`${full['includes/translation-sweep.php']}\nwp_update_post(array('ID' => 1));`) === false,
  );
  return checks;
}

function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const arg = (name, fallback) => {
    const found = process.argv.find((value) => value.startsWith(`--${name}=`));
    return found ? found.slice(name.length + 3) : fallback;
  };
  const zipPath = path.resolve(REPO_ROOT, arg('zip', DEFAULT_ZIP));
  const sourcePath = path.resolve(REPO_ROOT, arg('source', DEFAULT_SOURCE));

  if (!fs.existsSync(zipPath)) {
    console.log(`HIBA  nincs ilyen csomag: ${zipPath}`);
    return 1;
  }

  const extractDir = path.join(REPO_ROOT, 'tmp', 'zipcheck');
  fs.rmSync(extractDir, { recursive: true, force: true });
  fs.mkdirSync(extractDir, { recursive: true });
  const extracted = spawnSync('tar', ['-xf', zipPath, '-C', extractDir], { encoding: 'utf8' });
  if (extracted.status !== 0) {
    console.log(`HIBA  a kibontás hibázott: ${extracted.stderr}`);
    return 1;
  }

  const roots = fs.readdirSync(extractDir);
  let failed = 0;
  const report = (label, ok, detail = '') => {
    if (!ok) failed += 1;
    console.log(`${ok ? 'OK  ' : 'HIBA'} ${label}${detail && !ok ? ` — ${detail}` : ''}`);
  };

  report(`a csomag gyökérkönyvtára \`${EXPECTED_ROOT}/\``, roots.length === 1 && roots[0] === EXPECTED_ROOT, roots.join(', '));

  const pluginRoot = path.join(extractDir, EXPECTED_ROOT);
  const zipFiles = listFiles(pluginRoot);
  const sourceFiles = listFiles(sourcePath);
  const { missing, extra } = compareFileLists(zipFiles, sourceFiles);
  report(
    `a fájllista egyezik a forrással (${sourceFiles.length} fájl)`,
    missing.length === 0 && extra.length === 0,
    `hiányzik: ${missing.join(', ')} | plusz: ${extra.join(', ')}`,
  );

  const different = [];
  for (const file of sourceFiles) {
    if (missing.includes(file)) continue;
    const a = fs.readFileSync(path.join(pluginRoot, file));
    const b = fs.readFileSync(path.join(sourcePath, file));
    if (!a.equals(b)) different.push(file);
  }
  report('a fájlok bájtazonosak', different.length === 0, different.join(', '));

  const read = (relative) => {
    const full = path.join(pluginRoot, relative);
    return fs.existsSync(full) ? fs.readFileSync(full, 'utf8') : '';
  };
  for (const [label, ok] of packageChecks(read)) report(label, ok);

  console.log(failed ? `\nHIBA — ${failed} ellenőrzés bukott` : '\nMINDEN ELLENŐRZÉS RENDBEN');
  return failed ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith('verify-plugin-package.mjs')) {
  process.exitCode = main();
}
