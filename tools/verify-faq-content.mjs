#!/usr/bin/env node
/**
 * A GYIK szovegek ellenorzese.
 *
 * A TULAJDONOS JELZESE: „nezzuk meg a GYIK menut is mert most eleg gagyi,
 * ertheto normalis funkcio ismerteto kell, nem pedig mindenfele Firebase meg
 * semmi ertelme duma, es csak az elerheto funkciokrol segitseg".
 *
 * MIERT KELL EZ A SZKRIPT: a regi GYIK-ben volt egy TARGYI HIBA — azt allitotta,
 * hogy cikkkommentert naponta OT alkalom jar pont, kozben a kodban a plafon
 * HAROM. Az ilyen hiba a legrosszabb fajta: a felhasznalo azt hiszi, elromlott
 * az app. Ezert itt a GYIK szoveget a VALOS KODHOZ kotjuk: ha valaki atirja a
 * napi plafont vagy egy pont-erteket, de a GYIK-et nem, az itt elhasal.
 *
 * Futtatas (a repository gyokerebol):
 *   node tools/verify-faq-content.mjs [plugin-mappa]
 */

import fs from 'node:fs';
import path from 'node:path';

const pluginDir = process.argv[2] || '.tmp-api-24115/huhs-mobile-api';
const faqFile = path.join(pluginDir, 'includes', 'faq-human.php');
const functionsFile = path.join('functions', 'index.js');

const results = [];
let checked = 0;
let failed = 0;

function check(label, ok, detail) {
  checked += 1;
  if (ok) results.push(`OK    ${label}`);
  else {
    failed += 1;
    results.push(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

if (!fs.existsSync(faqFile)) {
  console.error(`Nincs meg: ${faqFile}`);
  process.exit(2);
}

const source = fs.readFileSync(faqFile, 'utf8');
// A komment-sorokat kihagyjuk: a hibát leíró magyarázat különben maga buktatná
// el a lintet (pontosan ez történt a verify-poll-status.mjs-nél is).
const codeOnly = source
  .split('\n')
  .filter((line) => {
    const trimmed = line.trim();
    return !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*');
  })
  .join('\n');

/* --- 1. A temakorok --------------------------------------------------- */

const groupNames = [...codeOnly.matchAll(/'name'\s*=>\s*'([^']+)'/g)].map((m) => m[1]);
check('van legalabb 5 temakor', groupNames.length >= 5, `talalt: ${groupNames.length}`);
check(
  'minden temakornek van neve',
  groupNames.every((name) => name.trim().length > 2),
);

const groupSlugs = [...codeOnly.matchAll(/'(elso-lepesek|kozosseg|hirek-es-ertesitesek|zene-es-kiadvanyok|jatekok|szavazas-es-nyeremenyjatek|segitseg-es-adatvedelem)'\s*=>/g)]
  .map((m) => m[1]);
check('a temakor-slugok egyediek', new Set(groupSlugs).size === groupSlugs.length);

/* --- 2. A bejegyzesek ------------------------------------------------- */

/** A `huhs_faq_v4_items()` tomb elemei. */
const itemBlocks = codeOnly.split("array(\n            'slug'").slice(1);
const items = itemBlocks.map((block) => {
  const slug = /^\s*=>\s*'([^']+)'/.exec(block)?.[1] ?? '';
  const group = /'group'\s*=>\s*'([^']+)'/.exec(block)?.[1] ?? '';
  const order = Number(/'order'\s*=>\s*(\d+)/.exec(block)?.[1] ?? '0');
  const title = /'title'\s*=>\s*'((?:[^'\\]|\\.)*)'/.exec(block)?.[1] ?? '';
  const contentMatch = /'content'\s*=>\s*"((?:[^"\\]|\\.)*)"/.exec(block)
    || /'content'\s*=>\s*'((?:[^'\\]|\\.)*)'/.exec(block);
  const content = contentMatch?.[1] ?? '';
  return { slug, group, order, title, content };
});

check('van legalabb 20 GYIK bejegyzes', items.length >= 20, `talalt: ${items.length}`);
check(
  'minden bejegyzesnek van slugja, temakore, kerdese es valasza',
  items.every((item) => item.slug && item.group && item.title && item.content),
  items
    .filter((item) => !item.slug || !item.group || !item.title || !item.content)
    .map((item) => item.slug || '(nincs slug)')
    .join(', '),
);
check(
  'a slugok egyediek',
  new Set(items.map((item) => item.slug)).size === items.length,
);
check(
  'minden bejegyzes VALOS temakorhoz tartozik',
  items.every((item) => groupSlugs.includes(item.group)),
  items.filter((item) => !groupSlugs.includes(item.group)).map((item) => item.slug).join(', '),
);
check(
  'minden bejegyzesnek van temakoron beluli sorrendje',
  items.every((item) => item.order >= 1),
);

/** Ket bejegyzes nem kaphatja ugyanazt a helyet egy temakoron belul. */
const positions = items.map((item) => `${item.group}#${item.order}`);
check(
  'egy temakoron belul nincs ket azonos sorrend',
  new Set(positions).size === positions.length,
);

/* --- 3. A szoveg a FELHASZNALONAK szol -------------------------------- */

/**
 * Belső technologia es fejlesztoi reszletek, amiknek NEM szabad a GYIK-ben
 * szerepelniuk. A tulajdonos kifejezett keresere kerult ide a lista.
 *
 * FIGYELEM: a „gyorsítótár" SZANDEKOSAN NINCS a tiltott szavak kozott — az a
 * fioktorlesnel a felhasznalonak fontos informacio (a helyi adatok es a mentett
 * ideiglenes fajlok is torlodnek). Az `cache` viszont tiltott: az a fejlesztoi
 * szakszó.
 */
const forbidden = [
  'Firebase', 'Firestore', 'Cloud Function', 'API', 'endpoint', 'JSON',
  'kbps', 'WAV', 'bitrata', 'cache', 'wp-admin', 'WordPress',
  'adatbázis', 'szerver', 'token', 'SDK', 'Flutter',
];
const textCorpus = items.map((item) => `${item.title} ${item.content}`).join(' ');
const foundForbidden = forbidden.filter((word) =>
  new RegExp(`\\b${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(textCorpus),
);
check(
  'nincs technikai/fejlesztoi szakkifejezes a szovegekben',
  foundForbidden.length === 0,
  foundForbidden.length ? `talalt: ${foundForbidden.join(', ')}` : undefined,
);

/**
 * A „terjengosseg" merese a FOLYÓ szovegre vonatkozik, nem a felsorolasra.
 *
 * A pontlista szandekosan lista: 8 sor, egyenkent 3-6 szo. Ha ezt egyetlen
 * bekezdeskent mernenk, a limit ertelmetlenul buntetne egy hasznos, attekintheto
 * felsorolast. Ezert a `•`-vel kezdodo sorokat kihagyjuk — a maradek szoveg a
 * bevezeto es a zaro magyarazat, es arra a 600 karakter boven eleg.
 *
 * FONTOS: a forrasban a sorvege `\n` KET karakterkent all, tehat a nyers
 * szoveget elobb valodi sorokra kell bontani, kulonben a meres 10-15 karakterrel
 * tobbet mutat a valosnal.
 */
function decodePhpString(text) {
  return text
    .replace(/\\n/g, '\n')
    .replace(/\\"/g, '"')
    .replace(/\\'/g, "'")
    .replace(/\\\\/g, '\\');
}

function proseOnly(text) {
  return decodePhpString(text)
    .split('\n')
    .filter((line) => !line.trim().startsWith('•'))
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

check(
  'nincs vontatott, terjengos valasz (a folyo szoveg 600 karakter alatt)',
  items.every((item) => proseOnly(item.content).length <= 600),
  items
    .filter((item) => proseOnly(item.content).length > 600)
    .map((item) => `${item.slug} (${proseOnly(item.content).length})`)
    .join(', '),
);

// A teljes valasz sem lehet korlatlan — egy GYIK-ben senki nem olvas el 1200
// karaktert.
check(
  'egyetlen valasz sem haladja meg az 1200 karaktert',
  items.every((item) => decodePhpString(item.content).length <= 1200),
  items
    .filter((item) => decodePhpString(item.content).length > 1200)
    .map((item) => `${item.slug} (${decodePhpString(item.content).length})`)
    .join(', '),
);
check(
  'minden valasz legalabb egy ertelmes mondat',
  items.every((item) => item.content.trim().length >= 40),
);

/* --- 4. A HIANYZO temak bent vannak ----------------------------------- */

const corpus = textCorpus.toLowerCase();
for (const [topic, needle] of [
  ['nyeremenyjatek', 'nyereményjáték'],
  ['kerdőív', 'kérdőív'],
  ['archivált ertesitesek', 'archivált'],
  ['achievment pontok', 'achievement'],
  ['chat', 'chat'],
  ['cikk-komment', 'hozzászólás'],
]) {
  check(`a GYIK kitér a kovetkezore: ${topic}`, corpus.includes(needle.toLowerCase()));
}

/* --- 5. A REGI bejegyzesek nyugdijazasa ------------------------------- */

const retireStart = codeOnly.indexOf('function huhs_faq_v4_retire_stale');
check('megvan a nyugdijazo fuggveny', retireStart > 0);
const retireBlock = retireStart > 0 ? codeOnly.slice(retireStart) : '';

check(
  'a nyugdijazas MINDEN bent maradt sort kezel, nem egy kezi listat',
  // A „bent marad" feltétel: ha a slug benne van az új listában, kihagyjuk —
  // minden más publikal bejegyzés vázlatba kerül.
  //
  // FIGYELEM a mintára: a `in_array(...)` első argumentuma maga is zárójelet
  // tartalmaz (`get_post_field(...)`), ezért a `[^)]*` NEM működik — a minta
  // az első zárójelnél elakadna. Ezért `[\s\S]`-t használunk lazán.
  /in_array\([\s\S]{0,160}?\$keep_slugs[\s\S]{0,160}?\)\s*\)\s*continue;/.test(retireBlock),
  'a „nincs benne az uj listaban" feltetel kell',
);
check(
  'a nyugdijazas VAZLATBA tesz, nem torol',
  retireBlock.includes("'post_status' => 'draft'") && !/wp_delete_post/.test(codeOnly),
);
check(
  'a nyugdijazas csak a PUBLIKALT sorokhoz nyul',
  /'post_status'\s*=>\s*'publish'/.test(retireBlock),
);
check(
  'a nyugdijazas hangosan naploz (nem tunik el csendben a tartalom)',
  retireBlock.includes('error_log'),
);
check(
  'a nyugdijazas MEGKIMELI a tulajdonos kezzel irt szoveget',
  // Aki kezzel írt/átírt egy GYIK-et, annak a szövegét nem dobjuk vázlatba:
  // a vizsgálat megköveteli a `continue;`-t is, különben a feltétel kiiktatása
  // (a bejegyzés átcsúszna a vázlatba tevő ágra) nem tűnne fel.
  // A VISELKEDÉST a `tools/verify-faq-retire.php` bizonyítja valódi PHP-val.
  /_huhs_faq_human_edited[\s\S]{0,240}?continue;/.test(retireBlock) &&
    /\$kept\[\]/.test(retireBlock),
  'a kezzel irt bejegyzes nem kerulhet vazlatba',
);
check(
  'a kezzel irt bejegyzesek megtartasa is naplozva van',
  /if \(\$result\['kept'\]\)\s*\{[\s\S]{0,240}?error_log/.test(codeOnly),
);

/* --- 5/b. A MIGRACIO VERZIOJA ELINDUL-E EGYALTALAN --------------------- */

// EZ A LENYEG: a migráció a `huhs_faq_human_version` opcióhoz hasonlít, és ha a
// konstans nem nagyobb a már alkalmazott értéknél, NÉMÁN visszatér.
// ÉLESBEN MÉRVE: a 2.5.3 is a 4-es jelzést használta, és az opció már 4-en állt
// (a 31 új bejegyzés bent volt, a hibás „naponta legfeljebb öt" szöveg már nem).
// Ezért a 4-es jelzéssel a szigorúbb nyugdíjazás SOHA nem futott volna le.
const contentVersion = Number(
  /define\(\s*'HUHS_FAQ_CONTENT_VERSION'\s*,\s*(\d+)\s*\)/.exec(codeOnly)?.[1] ?? '0',
);
check(
  'a GYIK-migracio verzioja ismert',
  contentVersion > 0,
);
check(
  'a GYIK-migracio verzioja nagyobb, mint a 2.5.3-ban mar alkalmazott 4',
  contentVersion >= 5,
  `a 2.5.3 mar 4-et alkalmazott elesben, ezert a konstans most ${contentVersion} — ` +
    '4-gyel a nyugdijazas neman elhalna',
);
check(
  'a migracio a sajat irasat NEM belyegzi kezi szerkesztesnek',
  // A `save_post_huhs_faq` marker a migráció közben nem jelölhet.
  /huhs_faq_v4_seeding/.test(codeOnly) &&
    /\$GLOBALS\['huhs_faq_v4_seeding'\]\s*=\s*true/.test(codeOnly) &&
    /unset\(\$GLOBALS\['huhs_faq_v4_seeding'\]\)/.test(codeOnly),
  'a migracio sajat irasa nem szamit emberi szerkesztesnek',
);
check(
  'a kezzel LETREHOZOTT GYIK is vedelmet kap (save_post, nem post_updated)',
  // A `post_updated` csak MÓDOSÍTÁSNÁL fut le, új bejegyzésnél nem — ezért a
  // `save_post_huhs_faq` hook kell.
  /add_action\('save_post_huhs_faq'/.test(codeOnly),
  'uj bejegyzesre a post_updated nem indul el',
);

/* --- 6. A SZOVEG A VALOS KODHOZ ILLESZKEDIK --------------------------- */

if (fs.existsSync(functionsFile)) {
  const functions = fs.readFileSync(functionsFile, 'utf8');

  const commentLimit = Number(
    /ARTICLE_COMMENT_DAILY_POINT_LIMIT\s*=\s*(\d+)/.exec(functions)?.[1] ?? '0',
  );
  const newsLimit = Number(
    /NEWS_LIKE_DAILY_POINT_LIMIT\s*=\s*(\d+)/.exec(functions)?.[1] ?? '0',
  );
  check(
    'a napi cikkkomment-plafon ismert a kodbol',
    commentLimit > 0,
    `ARTICLE_COMMENT_DAILY_POINT_LIMIT = ${commentLimit}`,
  );
  const limitMentions = [...corpus.matchAll(/naponta legfeljebb (\d+)/g)].map((m) => Number(m[1]));
  check(
    'a GYIK a VALOS napi plafont irja (nem 5-ot)',
    limitMentions.length > 0 && limitMentions.every((value) => value === commentLimit && value === newsLimit),
    limitMentions.length
      ? `a szovegben: ${limitMentions.join(', ')}; a kodban: ${commentLimit} (komment) / ${newsLimit} (hirek)`
      : 'a szovegben nincs napi plafon emlites',
  );

  /**
   * A pont-ertekek: minden `awardAchievementPoints(uid, N, '<forras>')` hivas.
   * A GYIK-ben emlitett osszegeknek szerepelniuk kell a kodban — kulonben a
   * szoveg olyat iger, ami nincs.
   */
  const pointCalls = [...functions.matchAll(/awardAchievementPoints\((?:uid|invitedBy),\s*(\d+),\s*[`'"]([a-z0-9:\-${}]+)/g)]
    .map((m) => ({ points: Number(m[1]), source: m[2] }));

  for (const [label, expected] of [
    ['profil teljes kitöltése', 30],
    ['éves szavazás', 10],
    ['esemény értékelése', 10],
    ['Meetup', 5],
    ['ajánlás', 50],
    ['cikk kedvelése', 2],
    ['hozzászólás', 1],
  ]) {
    const inCode = pointCalls.some((call) => call.points === expected);
    const inText = new RegExp(`${expected}\\s*pont`, 'i').test(textCorpus);
    check(
      `a GYIK pontszama valos: ${label} = ${expected}`,
      inCode && inText,
      inCode ? 'a szovegben nem szerepel' : 'a kodban nincs ilyen pont-ertek',
    );
  }
} else {
  check('a functions/index.js elerheto a pont-egyezteteshez', false, functionsFile);
}

/* --- 7. A migracio biztonsagos ---------------------------------------- */

check(
  'a migracio a SZOVEGET nem irja felul, ha a tulajdonos kezzel atirta',
  codeOnly.includes('_huhs_faq_human_edited') && codeOnly.includes('if (!$edited)'),
);
check(
  'a migracio verzióhoz kotott (nem fut le ketszer foloslegesen)',
  codeOnly.includes('huhs_faq_human_version') && codeOnly.includes('HUHS_FAQ_CONTENT_VERSION'),
);
check(
  'a nyugdijazas VAZLATBA tesz, nem torol',
  codeOnly.includes("'post_status' => 'draft'") && !/wp_delete_post/.test(codeOnly),
);
check(
  'a migracio csak adminnak fut',
  codeOnly.includes("current_user_can('manage_options')"),
);

console.log(results.join('\n'));
console.log(`\n${checked - failed}/${checked} ellenorzes rendben`);
process.exit(failed === 0 ? 0 : 1);
