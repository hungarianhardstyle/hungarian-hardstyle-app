#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **valódi PHP-teszthez**: minden mutációt el kell kapnia.
 *
 * A mérés a kibontott ZIP-en fut (`tmp/php-plugin/huhs-mobile-api`), a
 * visszaállítás pedig a **ZIP-ből újrakibontással** történik, és a teljes
 * fájlfa lenyomatát összevetjük (bájtpontos ellenőrzés).
 *
 * ⚠️ 2.13.0: a lista bővült a pótló kör (sweep), a hely-névtár és az
 * ujjlenyomat-logika mutációival — a 2.12.0 öt mutációja is megmaradt, mert a
 * régi viselkedés sem törhet el.
 */
import { execFileSync, spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const ZIP = (process.argv.find((arg) => arg.startsWith('--zip=')) ?? '').slice(6)
  || 'build/huhs-mobile-api-2.14.5.zip';
const DIR = 'tmp/php-plugin';
const PLUGIN = `${DIR}/huhs-mobile-api`;

const treeHash = (dir) => {
  const hash = crypto.createHash('sha256');
  const walk = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) walk(full);
      else {
        hash.update(path.relative(dir, full).replaceAll('\\', '/'));
        hash.update(fs.readFileSync(full));
      }
    }
  };
  walk(dir);
  return hash.digest('hex').toUpperCase();
};

const extract = () => {
  fs.rmSync(DIR, { recursive: true, force: true });
  fs.mkdirSync(DIR, { recursive: true });
  execFileSync('tar', ['-xf', ZIP, '-C', DIR]);
};

const runPhpTest = () => {
  const result = spawnSync(
    'docker',
    ['run', '--rm', '-v', `${process.cwd()}:/work`, '-w', '/work', 'php:8.2-cli',
      'php', '/work/tools/php/plugin-translation-test.php', `/work/${PLUGIN}`],
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const summary = /(\d+) ellenőrzés, (\d+) hiba/.exec(output);
  return {
    output,
    status: result.status,
    checks: Number(summary?.[1] ?? -1),
    failures: Number(summary?.[2] ?? -1),
  };
};

const mutations = [
  {
    name: 'a fallback-kapu gyengítése (csak cím vizsgálata)',
    file: 'includes/post-translation-meta.php',
    edits: [{ from: "if ($title_en === '' || $content_en === '') {", to: "if ($title_en === '') {" }],
  },
  {
    // ⚠️ MÉRT TANULSÁG: a kulcs-kapuból **kettő** van (a cron külső kapuja és a
    // kérés belső ellenőrzése), és bármelyik önmagában **maszkolt** — ezért a
    // viselkedést csak a kettő együttes kivétele változtatja meg. Ez a mutáció
    // pontosan ezt méri (a redundancy szándékos: védelem a felesleges hívás ellen).
    name: 'MINDKÉT kulcs-kapu kivétele (kulcs nélkül is hívna)',
    file: 'includes/translation-cron.php',
    edits: [
      {
        // ⚠️ ANKER KELL: a fájlban **két** ugyanilyen kapu van (a `save_post`
        // ágban és a `huhs_run_translation`-ban), és a naiv `replace` az ELSŐT
        // módosította — így a mutáció a rossz helyre került, és a teszt „nem
        // kapta el" eredményt adott (hamis negatív). Ezért a függvény-fejléccel
        // együtt cserélünk.
        from: "function huhs_run_translation($post_id, $force = false)\n{\n    if (!huhs_translation_enabled()) {\n        return 'disabled';\n    }",
        to: "function huhs_run_translation($post_id, $force = false)\n{\n    if (false) {\n        return 'disabled';\n    }",
      },
      {
        from: "    if ($key === '' || empty($provider['url'])) {",
        to: "    if (empty($provider['url'])) {",
      },
    ],
  },
  {
    name: 'az örökölt kulcs felismerésének elvétele',
    file: 'includes/translation-cron.php',
    edits: [
      {
        from: '    return huhs_translation_api_key() !== "";',
        to: '    return false;',
        alternateFrom: "    return huhs_translation_api_key() !== '';",
      },
    ],
  },
  {
    name: 'a meta-írás elhagyása (nincs angol a payloadban)',
    file: 'includes/translation-cron.php',
    edits: [
      {
        from: "        update_post_meta($post_id, '_huhs_content_en', wp_slash($response['content']));",
        to: '        // meta-írás elvéve',
      },
    ],
  },
  {
    // ⚠️ Ez a 2026-09-25-i ÉLES hiba mutációja: e nélkül a REST-en küldött angol
    // meta csendben elveszik a nem-`post` típusoknál.
    name: 'a custom-fields támogatás elvétele (REST-meta írás előfeltétele)',
    file: 'includes/post-translation-meta.php',
    edits: [
      {
        from: "            add_post_type_support($post_type, 'custom-fields');",
        to: '            // support elvéve',
      },
    ],
  },
  {
    // ⚠️ EZ A 2.13.0 SAJÁT MÉRT HIBÁJA: ha a „kész" jelzés a MEGLEVŐ metát nézi,
    // egy megváltozott magyar szövegnél a régi angol fordítás miatt a fél válasz
    // is késznek látszik.
    name: 'a „kész" jelzés a meglevő metára épül (a saját mért hiba)',
    file: 'includes/translation-cron.php',
    edits: [
      {
        from: "    $done = $response['title'] !== '' && $response['content'] !== '';",
        to: '    $done = true;',
      },
    ],
  },
  {
    name: 'az ujjlenyomat-ellenőrzés elvétele (minden mentés újrafordítana)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "function huhs_translation_is_current($post_id, $hash)\n{\n    if ($hash === ''",
        to: "function huhs_translation_is_current($post_id, $hash)\n{\n    return false;\n    if ($hash === ''",
      },
    ],
  },
  {
    name: 'a tartós hiba késleltetésének elvétele (minden körben újrapróbálná)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "function huhs_translation_failed_recently($post_id, $hash)\n{\n    if ($hash === ''",
        to: "function huhs_translation_failed_recently($post_id, $hash)\n{\n    return false;\n    if ($hash === ''",
      },
    ],
  },
  {
    // ⚠️ 2.14.0: a szűrés átkerült a `huhs_translation_post_needs_work()`-ba
    // (a várólista pontos döntése), ezért az anker is ott van.
    name: 'az üres magyar törzs kiszűrésének elvétele (üres elemeket is fordítana)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "        if ($title !== '' && $content !== '') {",
        to: '        if (true) {',
      },
    ],
  },
  {
    // ⚠️ MÉRT TANULSÁG (mint a kulcs-kapunál): a költségvetést **két** kapu
    // védi (a típus-ciklus elején és az elem-ciklusban), és bármelyik önmagában
    // **maszkolt** — csak a kettő együttes kivétele változtat viselkedést. Ez a
    // mutáció ezt méri; a redundancia szándékos (egy lassú hívás ne vigye el a
    // teljes kérést).
    name: 'MINDKÉT költségvetés-kapu kivétele (egy kérésben végezne mindent)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "        if (time() >= $deadline) {\n            $result['by_type'][$post_type] = $type_stats;\n            continue;\n        }",
        to: "        if (false) {\n            $result['by_type'][$post_type] = $type_stats;\n            continue;\n        }",
      },
      {
        from: '            if (time() >= $deadline) {\n                break;\n            }',
        to: '            if (false) {\n                break;\n            }',
      },
    ],
  },
  {
    name: 'az órás ütemezés elvétele (nem pótolná magától a hiányzó angolt)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "wp_schedule_event(time() + 5 * MINUTE_IN_SECONDS, 'hourly', 'huhs_translation_sweep_event');",
        to: "wp_schedule_event(time() + 5 * MINUTE_IN_SECONDS, 'daily', 'huhs_translation_sweep_event');",
      },
    ],
  },
  {
    name: 'a pótlás végpontjának jogosultsági kapuja (`manage_options` elvétele)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "        'callback' => 'huhs_translation_sweep_endpoint',\n        'permission_callback' => function () {\n            return current_user_can('manage_options');\n        },",
        to: "        'callback' => 'huhs_translation_sweep_endpoint',\n        'permission_callback' => function () {\n            return current_user_can('read');\n        },",
      },
    ],
  },
  {
    name: 'a magyar ág megőrzésének elvétele a hely-névtárban (a hu kérés is fordítana)',
    file: 'includes/translation-places.php',
    edits: [
      {
        from: "    if ($lang !== 'en') {\n        return $value;\n    }\n\n    $key = huhs_translation_place_key($value);\n    if ($key === '') {\n        return $value;\n    }\n\n    $names = huhs_translation_country_names();",
        to: "    if (false) {\n        return $value;\n    }\n\n    $key = huhs_translation_place_key($value);\n    if ($key === '') {\n        return $value;\n    }\n\n    $names = huhs_translation_country_names();",
      },
    ],
  },
  {
    name: 'az ország-névtár használatának elvétele (magyar országnév maradna)',
    file: 'includes/translation-places.php',
    edits: [
      {
        from: "    $names = huhs_translation_country_names();\n\n    return isset($names[$key]) ? $names[$key] : $value;",
        to: "    $names = huhs_translation_country_names();\n    unset($names);\n\n    return $value;",
      },
    ],
  },
  {
    // 2.14.0: a meta-szöveges típusok (kérdőív, nyereményjáték) fordításának elvétele.
    name: 'a mező-fordítás kérésének elvétele (a kérdőív/nyeremény magyar maradna)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: "    $translated = huhs_translation_request_fields($source);\n    if ($translated === null || !$translated) {",
        to: "    $translated = null;\n    if ($translated === null || !$translated) {",
      },
    ],
  },
  {
    name: 'a lista HOSSZ-ellenőrzésének elvétele (félkész válaszlista is beíródna)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: '            if (count($translated) === count($source)) {',
        to: '            if (true) {',
      },
    ],
  },
  {
    name: 'a GYÍK kategória-névtár elvétele (magyar kategórianév maradna)',
    file: 'includes/faq.php',
    edits: [
      {
        from: "    return isset($map[$key]) ? $map[$key] : $name;",
        to: '    return $name;',
      },
    ],
  },
  {
    name: 'a meta-szöveges típusok elvétele a MINDEN típus listájából',
    file: 'includes/post-translation-meta.php',
    edits: [
      {
        from: "    if (function_exists('huhs_translation_field_post_types')) {\n        $types = array_merge($types, huhs_translation_field_post_types());\n    }",
        to: '    // a meta-szöveges típusok elvéve',
      },
    ],
  },
  {
    // ⚠️ 2.14.0: a nyilvános nyeremény-végpont magyar tartaléka. Ha ez üres
    // lenne, a játékos nem látná, miért játszik (ez volt a 2026-09-24-i élő hiba).
    name: 'a nyitott nyeremény-ág üres tartalékot küld (a nyeremény elveszne)',
    file: 'includes/prize.php',
    edits: [
      {
        from: "            'prize_type' => huhs_translation_text(\n                $prize_id,\n                $lang,\n                '_huhs_prize_type',\n                (string) get_post_meta($prize_id, '_huhs_prize_type', true)\n            ),",
        to: "            'prize_type' => '',",
      },
    ],
  },
  {
    // ⚠️ A `lang` elvétele: a végpont mindig magyart adna — pontosan az a hiba,
    // amit a tulajdonos jelzett („a nyereményjáték tartalma magyar maradt").
    name: 'a nyeremény-végpont nyelvének beégetése (mindig magyar)',
    file: 'includes/prize.php',
    edits: [
      {
        from: "    $lang = $request instanceof WP_REST_Request ? huhs_request_lang($request) : 'hu';\n    $prize_id = huhs_prize_active_id();",
        to: "    $lang = 'hu';\n    $prize_id = huhs_prize_active_id();",
      },
    ],
  },
  {
    // ⚠️ 2.14.1: a játék-végpont nyelve. Az éles mérés mutatta meg, hogy a
    // `title`/`type_label` a magyar `HUHS_GAME_TYPES`-ból ment ki angol kérésre.
    name: 'a játéktípus-névtár elvétele (magyar címke maradna angol módban)',
    file: 'includes/games.php',
    edits: [
      {
        from: "    $names = huhs_game_type_labels_en();\n\n    return isset($names[$type]) ? $names[$type] : $fallback;",
        to: "    $names = huhs_game_type_labels_en();\n    unset($names);\n\n    return $fallback;",
      },
    ],
  },
  {
    // ⚠️ A játék összefoglalója: a nyers meta olvasása (a 2.14.0 mért hibája).
    name: 'a játék-összefoglaló nyelvi olvasójának elvétele (magyar maradna)',
    file: 'includes/games.php',
    edits: [
      {
        from: "'summary' => huhs_translation_text($post->ID, $lang, '_huhs_game_summary', $summary_hu),",
        to: "'summary' => $summary_hu,",
      },
    ],
  },
  {
    // ⚠️ 2.14.2: a kvíz kérdéseinek laposítását kivéve nem lenne mit fordítani.
    name: 'a kvíz laposításának elvétele (a kérdések magyarul maradnának)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: "    $out = array();\n    foreach (array_values(huhs_game_questions_json($post_id)) as $index => $question) {",
        to: "    $out = array();\n    if (true) { return $out; }\n    foreach (array_values(huhs_game_questions_json($post_id)) as $index => $question) {",
      },
    ],
  },
  {
    // ⚠️ A nyilvános payload a nyers kérdés-olvasót használná (nincs fordítás).
    name: 'a kvíz-kiolvasó elvétele a nyilvános payloadból',
    file: 'includes/games.php',
    edits: [
      {
        from: '    }, huhs_translation_game_questions($post->ID, $lang));',
        to: '    }, huhs_game_questions_json($post->ID));',
      },
    ],
  },
  {
    // ⚠️ A helyes válasz kiszivárogtatása: a játék skennelhető lenne.
    name: 'a `correct` index kiszivárogtatása a nyilvános payloadba',
    file: 'includes/games.php',
    edits: [
      {
        from: "        return array('prompt' => $question['prompt'] ?? '', 'options' => array_values($question['options'] ?? array()));",
        to: "        return array('prompt' => $question['prompt'] ?? '', 'options' => array_values($question['options'] ?? array()), 'correct' => $question['correct'] ?? -1);",
      },
    ],
  },
  {
    // ⚠️ 2.14.3: a mért ÉLES hiba — a `wp_slash()` nélkül az `update_metadata()`
    // unslash-e szétroncsolja a JSON-escape-eket (`\r\n` → `rn`, `\u00e9` → `u00e9`).
    name: 'a `wp_slash()` elvétele a mező-írásból (a leírás „rnrn" lesz)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: 'update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_META, wp_slash(wp_json_encode($stored)));',
        to: 'update_post_meta($post_id, HUHS_TRANSLATION_FIELDS_META, wp_json_encode($stored));',
      },
    ],
  },
  {
    // ⚠️ A séma-verzió kapuja nélkül a RÉGI, hibás escape-ekkel mentett
    // fordítások „naprakésznek" látszanának, és a `rn` / `u00e9` szemét bennük
    // maradna (a forrás-ujjlenyomat ugyanis nem változott).
    name: 'a séma-verzió kapujának elvétele (a hibás fordítás nem generálódna újra)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: "    if ((int) get_post_meta($post_id, HUHS_TRANSLATION_FIELDS_VERSION_META, true)\n        !== HUHS_TRANSLATION_FIELDS_VERSION) {\n        return false;\n    }",
        to: '    // verzió-kapu elvéve',
      },
    ],
  },
  {
    name: 'a `wp_slash()` elvétele a törzs írásából (a backslash elveszne)',
    file: 'includes/translation-cron.php',
    edits: [
      {
        from: "        update_post_meta($post_id, '_huhs_content_en', wp_slash($response['content']));",
        to: "        update_post_meta($post_id, '_huhs_content_en', $response['content']);",
      },
    ],
  },
  {
    // ⚠️ 2.14.4: a MÉRT ÉLES HIBA — a verzió-kapu a várólista előszűrőjében
    // hiányzott, ezért a pótló kör 0 elemet vizsgált, és a roncsolt (`rnrn`)
    // nyeremény-leírás örökre benne maradt.
    name: 'a séma-verzió ágának elvétele a várólista előszűrőjéből (a kapu elérhetetlen)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "        $meta_query[] = array(\n            'key' => HUHS_TRANSLATION_FIELDS_VERSION_META,\n            'compare' => 'NOT EXISTS',\n        );\n        $meta_query[] = array(\n            'key' => HUHS_TRANSLATION_FIELDS_VERSION_META,\n            'value' => (string) HUHS_TRANSLATION_FIELDS_VERSION,\n            'compare' => '<',\n            'type' => 'NUMERIC',\n        );",
        to: '        // verzió-ág elvéve',
      },
    ],
  },
  {
    name: 'a verzió-összehasonlítás `=`-re cserélése (a korábbi verzió kimaradna)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: "            'value' => (string) HUHS_TRANSLATION_FIELDS_VERSION,\n            'compare' => '<',",
        to: "            'value' => (string) HUHS_TRANSLATION_FIELDS_VERSION,\n            'compare' => '=',",
      },
    ],
  },
  {
    name: 'a `force` átadásának elvétele a pótló körből (a javító út nem működne)',
    file: 'includes/translation-sweep.php',
    edits: [
      {
        from: 'huhs_run_translation($post->ID, $force)',
        to: 'huhs_run_translation($post->ID)',
      },
    ],
  },
  {
    name: 'a `force` kihagyása a cím/törzs ágon (a sérült fordítás nem cserélődne le)',
    file: 'includes/translation-cron.php',
    edits: [
      {
        from: '    if (!$force && huhs_translation_is_current($post_id, $hash)) {',
        to: '    if (huhs_translation_is_current($post_id, $hash)) {',
      },
    ],
  },
  {
    name: 'a `force` kihagyása a mező-ágon (a roncsolt leírás bennmaradna)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: '    if (!$force && huhs_translation_fields_current($post_id)) {',
        to: '    if (huhs_translation_fields_current($post_id)) {',
      },
    ],
  },
  {
    // ⚠️ 2.14.5 — a tulajdonos kérése: a KÉZI angol szöveg elsőbbsége.
    name: 'a kézi angol szöveg elsőbbségének elvétele (a gép írná felül)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: "    $manual = huhs_translation_manual_text($post_id, $meta_key);\n    if ($manual !== '') {\n        return $manual;\n    }\n",
        to: '',
      },
    ],
  },
  {
    name: 'a kézi angol lista kivétele a listáknál (a kézzel írt válasz elveszne)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: '        foreach (array($manual, $machine) as $source) {',
        to: '        foreach (array($machine) as $source) {',
      },
      {
        from: '    $manual = huhs_translation_manual_list($post_id, $meta_key);',
        to: '    $manual = array();',
      },
    ],
  },
  {
    name: 'a `has_en` visszaállítása a gépi fordításra (a kézi angol nem számítana)',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: '    return huhs_translation_fields_current($post_id);',
        to: '    return huhs_translation_fields_current($post_id) && false;',
      },
    ],
  },
  {
    name: 'a kézi angol kvízkérdés figyelmen kívül hagyása',
    file: 'includes/translation-fields.php',
    edits: [
      {
        from: '    $manual = huhs_translation_manual_questions($post_id);',
        to: '    $manual = array();',
      },
    ],
  },
];

extract();
const baselineHash = treeHash(PLUGIN);
console.log(`kiinduló fájlfa lenyomat: ${baselineHash}`);

const results = [];
for (const mutation of mutations) {
  const full = path.join(PLUGIN, mutation.file);
  let source = fs.readFileSync(full, 'utf8');
  let applied = 0;
  for (const edit of mutation.edits) {
    const from = source.includes(edit.from) ? edit.from : edit.alternateFrom;
    if (!from || !source.includes(from)) continue;
    source = source.replace(from, edit.to);
    applied += 1;
  }
  if (applied !== mutation.edits.length) {
    console.log(`  HIBA  a mutáció nem talált: ${mutation.name} (${applied}/${mutation.edits.length})`);
    results.push({ name: mutation.name, caught: false });
    extract();
    continue;
  }
  fs.writeFileSync(full, source, 'utf8');
  const during = runPhpTest();
  // Visszaállítás a ZIP-ből (bájtpontos), majd a teljes fa ellenőrzése.
  extract();
  const restoredHash = treeHash(PLUGIN);
  if (restoredHash !== baselineHash) throw new Error(`nem bájtpontos a visszaállítás (${mutation.name})`);
  results.push({ name: mutation.name, caught: during.failures > 0, during });
  console.log(
    `  ${mutation.name}: ${during.checks} ellenőrzés, ${during.failures} hiba `
    + `→ ${during.failures > 0 ? 'ELKAPVA' : 'NEM KAPTA EL'}`,
  );
}

const after = runPhpTest();
const ok = results.every((entry) => entry.caught) && after.failures === 0;
console.log(`  a visszaállítás bájtpontos és a teljes kör újra zöld: ${after.failures === 0} (${after.checks} ellenőrzés)`);
console.log(`\n${ok ? 'OK' : 'HIBA'} — a PHP-viselkedésteszt mutációs bizonyítéka (${results.length} mutáció)`);
process.exitCode = ok ? 0 : 1;
