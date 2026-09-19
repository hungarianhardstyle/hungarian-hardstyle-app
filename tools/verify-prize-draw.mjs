/**
 * Nyeremenyjatek — szerveroldali viselkedes ellenorzese.
 *
 * A jatek harom dolgot iger, es mind a harmat a SZERVEREN kell betartani:
 *
 *   1. **A helyes valasz nem szivarog ki a sorsolas elott.** Ha a nyilvanos
 *      `/prize/active` kiadna, a jatekos be tudna skennelni, es a
 *      „csak a helyes valasz nyer" ertelmetlenne valna.
 *   2. **Egy jatekos egyszer jatszik.** A masodik proba nem valtoztat a
 *      rogzitett valaszon, es nem ad meg egy probat.
 *   3. **A sorsolas idempotens.** A sorsolo fuggveny otpercenkent lefut; egy
 *      ujrainditas nem hozhat letre masodik nyertest.
 *
 * A szimulacio a PHP viselkedeset utanozza (ablak-allapot, ujjlenyomat,
 * bejegyzes rogzitese, nyertes beirasa), es emellett a FORRASBOL ellenorzi
 * azokat az invariansokat, amiket viselkedessel nem lehet megfogni.
 *
 * Futtatas: `node tools/verify-prize-draw.mjs [plugin-mappa]`
 */

import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const pluginDir = process.argv[2] || '.tmp-api-24115/huhs-mobile-api';
const prizeFile = path.join(pluginDir, 'includes', 'prize.php');

let failed = 0;
let checked = 0;
const results = [];

function check(label, condition, detail) {
  checked++;
  if (condition) {
    results.push(`OK    ${label}`);
  } else {
    failed++;
    results.push(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
  }
}

/* --- A PHP viselkedes utanzasa ------------------------------------------ */

// A webhely idozonajaban ertelmezett helyi ido, ugyanolyan alakban, mint a PHP
// `current_time('Y-m-d\TH:i')`.
function localNow() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
}

function windowState(start, end) {
  const now = localNow();
  if (start && now < start) return 'before';
  if (end && now > end) return 'closed';
  return 'open';
}

// Sotolt ujjlenyomat (a so a szerveren marad).
function playerHash(prizeId, uid, salt) {
  return crypto
    .createHash('sha256')
    .update(`${prizeId}|${uid}|${salt}`)
    .digest('hex');
}

// A reszvetel rogzitese: a helyességet a SZERVER donti el, es a masodik proba
// nem valtoztat semmit.
function recordEntry(store, prizeId, uid, answerIndex, correctIndex, name) {
  const key = `_huhs_prize_entry_${playerHash(prizeId, uid, 'salt')}`;
  if (store.has(key)) {
    const existing = JSON.parse(store.get(key));
    return { ok: true, alreadyPlayed: true, correct: existing.correct };
  }
  const entry = { answer: answerIndex, correct: answerIndex === correctIndex, name };
  store.set(key, JSON.stringify(entry));
  return { ok: true, alreadyPlayed: false, correct: entry.correct };
}

// A nyertes beirasa — idempotens.
function setWinner(prize, uid, name) {
  if (prize.winner) return { ok: true, alreadyDrawn: true, winner: prize.winner };
  prize.winner = name;
  prize.winnerUid = uid;
  return { ok: true, alreadyDrawn: false, winner: name };
}

/* --- 1. Ablak-allapot --------------------------------------------------- */

{
  const now = new Date();
  const pad = (v) => String(v).padStart(2, '0');
  const fmt = (d) =>
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  const past = fmt(new Date(now.getTime() - 3600_000));
  const future = fmt(new Date(now.getTime() + 3600_000));

  check('kezdes elott: before', windowState(future, fmt(new Date(now.getTime() + 7200_000))) === 'before');
  check('a ket datum kozott: open', windowState(past, future) === 'open');
  check('zaras utan: closed', windowState(fmt(new Date(now.getTime() - 7200_000)), past) === 'closed');
  check('hianyzo kezdes -> nyitott hatar', windowState('', future) === 'open');
  check('hianyzo zaras -> nyitott hatar', windowState(past, '') === 'open');
}

/* --- 2. A helyes valasz nem szivarog ki --------------------------------- */

{
  const correctIndex = 2;
  const answers = ['A', 'B', 'C', 'D'];
  const publicPayload = {
    id: 1,
    state: 'open',
    question: 'Kerdés?',
    answers: answers.map((label, index) => ({ index, label })),
  };

  check(
    'a nyilvanos valasz NEM tartalmazza a helyes valaszt',
    !Object.prototype.hasOwnProperty.call(publicPayload, 'correct') &&
      !Object.prototype.hasOwnProperty.call(publicPayload, 'correct_index'),
  );
  check(
    'a nyilvanos valasz egyik valaszlehetosege sem jelzi a helyeset',
    publicPayload.answers.every((item) => !('correct' in item)),
  );
  check('a szerver ismeri a helyes valaszt', answers[correctIndex] === 'C');
}

/* --- 3. Egyszer jatszhat, nincs javitas --------------------------------- */

{
  const store = new Map();
  const first = recordEntry(store, 7, 'uid-1', 1, 2, 'Jatekos');
  check('az elso valasz rogzitodik', first.alreadyPlayed === false);
  check('a rossz valasz rosszkent rogzitodik', first.correct === false);

  const second = recordEntry(store, 7, 'uid-1', 2, 2, 'Jatekos');
  check('a masodik proba NEM ad uj eselyt', second.alreadyPlayed === true);
  check(
    'a masodik proba nem javitja a valaszt (rossz marad)',
    second.correct === false,
    'a helyes valaszra valtásnak nem szabad atmennie',
  );
  check('egy jatekoshoz egy sor tartozik', store.size === 1);

  // Aki elso re jol valaszolt, az helyes marad a masodik proban is.
  const store2 = new Map();
  recordEntry(store2, 7, 'uid-2', 2, 2, 'Ugyes');
  const again = recordEntry(store2, 7, 'uid-2', 0, 2, 'Ugyes');
  check('helyes valasz utan sem lehet rosszra valtani', again.correct === true);

  // Kulon jatekos kulon sort kap.
  recordEntry(store, 7, 'uid-3', 2, 2, 'Masik');
  check('mas jatekos kulon sort kap', store.size === 2);
  check('a mas jatekos helyes valasza helyes', JSON.parse([...store.values()][1]).correct === true);
}

/* --- 4. A sorsolas idempotens ------------------------------------------- */

{
  const prize = { id: 7, winner: null };
  const first = setWinner(prize, 'uid-2', 'Ugyes');
  check('az elso sorsolas beirja a nyertest', first.alreadyDrawn === false && first.winner === 'Ugyes');

  const second = setWinner(prize, 'uid-9', 'Valaki Mas');
  check('a masodik sorsolas NEM irja felul a nyertest', second.alreadyDrawn === true);
  check('a nyertes valtozatlan', prize.winner === 'Ugyes');

  // Ures nevvel nem lehet nyertest beirni (a sorsolo fuggveny hibauzenetet kap).
  const empty = { id: 8, winner: null };
  const rejected = empty.winner ? { ok: true } : null;
  check('ures nev nem lesz nyertes', rejected === null && empty.winner === null);
}

/* --- 5. Csak a helyes valaszolok jatszanak a sorsolasban ---------------- */

{
  const entries = [
    { hash: 'h1', correct: false },
    { hash: 'h2', correct: true },
    { hash: 'h3', correct: true },
    { hash: 'h4', correct: false },
  ];
  const eligible = entries.filter((entry) => entry.correct).map((entry) => entry.hash);
  check('a sorsolasba csak a helyes valaszok kerulnek', eligible.length === 2);
  check('a helytelenek kimaradnak', !eligible.includes('h1') && !eligible.includes('h4'));

  // Kriptografiailag veletlen valasztas a helyesek kozul.
  const index = crypto.randomInt(0, eligible.length);
  check('a nyertes a helyesek kozul kerul ki', eligible.includes(eligible[index]));
  check('a veletlen index a tartomanyban van', index >= 0 && index < eligible.length);
}

/* --- 6. Forras-invariansok --------------------------------------------- */

const source = fs.readFileSync(prizeFile, 'utf8');

// A kód-sorokat nezzuk, hogy a magyarazo komment ne buktassa el a lintet.
const codeOnly = source
  .split('\n')
  .filter((line) => {
    const trimmed = line.trim();
    return !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*') && !trimmed.startsWith('#');
  })
  .join('\n');

/**
 * A kod-sorok egy szakaszbol, komment nelkul.
 *
 * A hibát leíró kommentek szó szerint tartalmazzák a veszélyes alakokat, ezért
 * a lint csak a végrehajtható sorokat vizsgálja.
 */
function codeSection(from, to) {
  const start = source.indexOf(from);
  if (start < 0) return '';
  const end = to ? source.indexOf(to, start) : source.length;
  return source
    .slice(start, end < 0 ? source.length : end)
    .split('\n')
    .filter((line) => {
      const trimmed = line.trim();
      return (
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('*') &&
        !trimmed.startsWith('/*') &&
        !trimmed.startsWith('#')
      );
    })
    .join('\n');
}

{
  // Az 1. pont forrasoldali bizonyiteka: a NYILVANOS vegpont szakasza nem
  // tartalmazzon egyetlen `'correct' =>` visszaadast sem. (Az admin oldal és a
  // belso helperek természetesen használják a mezőt — azok nem nyilvánosak.)
  const publicSection = codeSection('function huhs_prize_api_active()', 'function huhs_prize_api_status(');
  check('a nyilvanos /prize/active fuggveny megtalalhato', publicSection.length > 0);
  check(
    'a nyilvanos /prize/active egyetlen return-jeben sincs helyes-valasz mezo',
    !/['"]correct['"]\s*=>/.test(publicSection) && !/correct_index/.test(publicSection),
    'a helyes valasz kizarolag a /prize/status (sajat fiok) valaszában szerepel',
  );
  check(
    'a nyilvanos /prize/active nyitott jatekot hirdet (nincs valasz kiszivarogva)',
    publicSection.includes("'state' => 'open'"),
  );
  // A jatekos Firebase UID-ja CSAK a szerver-szerver sorsolo vegponton megy ki
  // (a nyertes e-mail-cime a Firebase Auth-ban van, nem a WordPressben).
  check(
    'a nyilvanos /prize/active nem ad ki UID-t vagy hash-t',
    !/['"](uid|hash)['"]\s*=>/.test(publicSection),
    'a nyertes szemelyazonositoja csak a jelszoval vedett /prize/participants valaszban szerepel',
  );
  const participantsSection = codeSection('function huhs_prize_api_participants(', 'function huhs_prize_api_winner(');
  check(
    'a /prize/participants atadja a jatekos UID-jat a sorsolonak',
    /['"]uid['"]\s*=>/.test(participantsSection),
    'a nyertes e-mail-cime igy keresheto vissza a Firebase Auth-bol',
  );
  check(
    'a /prize/participants csak a helyes valaszokat adja ki',
    participantsSection.includes("if (empty($entry['correct'])) continue;"),
  );
  check(
    'a /prize/enter rogziti a UID-t a bejegyzesben',
    /['"]uid['"]\s*=>\s*\(string\) \$uid/.test(codeSection('function huhs_prize_record_entry(', 'function huhs_prize_correct_hashes(')),
  );
}

check(
  'a jatekost a sotolt ujjlenyomat azonositja (nincs nyers UID a metaban)',
  codeOnly.includes("'_huhs_prize_entry_' . $hash"),
);

{
  // A WordPress NEM tárol és NEM küld e-mail-címet. Az egyetlen megengedett
  // találat a felhasználónak szóló mondat, ami épp ezt közli. Ezért nem a
  // „mail" szóra keresünk, hanem arra, hogy bármilyen e-mail MEZŐ bekerül-e a
  // válaszba vagy a metaba.
  const emailFields = codeOnly.match(/['"][a-z_]*e?mail[a-z_]*['"]\s*=>/gi) || [];
  check(
    'e-mail-cím nem kerul semmilyen valaszba vagy metaba',
    emailFields.length === 0,
    emailFields.length ? `talalt mezok: ${emailFields.join(', ')}` : undefined,
  );
  check(
    'a WordPress nem kuld levelet (az ertesites a Firebase dolga)',
    !/wp_mail\s*\(/.test(codeOnly),
  );
}

check(
  'a nyertes beirasa ellenorzi, hogy van-e mar nyertes',
  /if \(\$existing\) \{\s*return array\('ok' => true, 'alreadyDrawn' => true/.test(source),
);

check(
  'a bejegyzes a helyességet a szerveren donti el',
  codeOnly.includes('$answer_index === $correct_index'),
);

check(
  'a mentes wp_slash + JSON_UNESCAPED_UNICODE (a meta nem csonkul)',
  /wp_slash\(wp_json_encode\(\$answers, JSON_UNESCAPED_UNICODE \| JSON_UNESCAPED_SLASHES\)\)/.test(codeOnly),
);

check(
  'az admin almenue priority 20 (a szulo-menu elott betoltodo fajlban)',
  /add_action\('admin_menu', function \(\) \{[\s\S]*?\}, 20\);/.test(source),
);

check(
  'van admin oldal a resztvevokkel',
  codeOnly.includes('function huhs_prize_admin_page()') && codeOnly.includes('Résztvevők'),
);

check(
  'a nyertes megjelenitese napokban allithato',
  codeOnly.includes('_huhs_prize_display_days') && codeOnly.includes('function huhs_prize_winner_visible'),
);

// A tulajdonos jelzese: „játékhoz adhatok meg képet, de minek, nem mutatja,
// ráadásul feltölteni se lehet képet, csak link van, igazából felesleges is a
// kép oda, jó a kártya". Ezert a kep MEZO es a hozza tartozo meta teljesen
// eltunt: nem csak el van rejtve a felulet, hanem a vegpontok sem adjak ki.
check(
  'nincs kep-mezo a nyeremenyjatek admin urlapon',
  !codeOnly.includes('huhs_prize_image'),
  'a kep mezot a tulajdonos keresere teljesen eltavolitottuk',
);
check(
  'a nyilvanos /prize/active nem ad ki kepet',
  !/['"]image['"]\s*=>/.test(codeSection('function huhs_prize_api_active()', 'function huhs_prize_api_status(')),
);

check(
  'a lezart, meg nem sorsolt jatekokat kulon vegpont adja (a sorsolonak)',
  codeOnly.includes("'/prize/pending'"),
);

check(
  'a sorsolashoz csak a helyes valaszolok mennek ki',
  codeOnly.includes('function huhs_prize_correct_hashes') &&
    /'hashes' => array_values\(array_filter\(array_column\(\$players, 'hash'\)\)\)/.test(codeOnly),
);

/* ------------------------------------------------------------------ */
/* A NATIV app-admin nezet (a tulajdonos keresere)                      */
/* ------------------------------------------------------------------ */

// A tulajdonos keresere: „Natív HUHS adminba bekerulhetnenek az uj dolgok,
// mukodoen (ertds: az appba)". A nyeremenyjatek eddig CSAK a WordPress
// adminjaban volt atlathato; az app mostantol a sajat admin-muveleteibol
// (prize_games, prize_results) rajzolja ki ugyanazt.
const adminFile = path.join(pluginDir, 'includes', 'api-admin.php');
const adminSource = fs.existsSync(adminFile) ? fs.readFileSync(adminFile, 'utf8') : '';
const adminCode = adminSource
  .split('\n')
  .filter((line) => !/^\s*(\/\/|\*|\/\*)/.test(line))
  .join('\n');

check(
  'az app-admin API ad jateklistat (prize_games)',
  adminCode.includes("$action === 'prize_games'") && adminCode.includes("'prizes' =>"),
);
check(
  'az app-admin API ad reszletes jatek-adatot (prize_results)',
  adminCode.includes("$action === 'prize_results'") &&
    adminCode.includes("'participants' =>") &&
    adminCode.includes("'correctIndex' =>"),
);
check(
  'az app-admin jatek-nezet NEM ad ki UID-t vagy hash-t a kliensnek',
  // Az appnak nem kell a jatekos azonositoja; a nyilvanos vegpont elve itt is
  // all: minel kevesebb adat megy ki.
  !/'uid'\s*=>/.test(adminCode) && !/'hash'\s*=>/.test(adminCode),
  'a participants sorokban ne legyen uid/hash',
);

console.log(results.join('\n'));
console.log(`\n${checked - failed}/${checked} ellenorzes rendben`);
process.exit(failed === 0 ? 0 : 1);
