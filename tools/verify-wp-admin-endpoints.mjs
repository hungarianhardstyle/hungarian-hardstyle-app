#!/usr/bin/env node
/**
 * ÉLES ellenőrzés: a WordPress-plugin admin-végpontjai mit adnak az appnak?
 *
 * MIÉRT: a 2026-09-19-i „nincs ott a kvíz/kérdőív/nyereményjáték menüpont” ügy
 * megmutatta, hogy a szerver és az app **két külön helyen** tud elcsúszni. Ez az
 * eszköz a szerver oldalát méri élesben:
 *   * a plugin verziója (`apiVersion`) legalább a várt-e;
 *   * a nyereményjáték- és kérdőív-végpontok **élnek** és valódi adatot adnak;
 *   * a válasz **nem** tartalmaz UID-t és hash-t (ez a `verify-prize-draw.mjs`
 *     forrás-lintje mellett a futásidejű bizonyíték);
 *   * a nyereményjátéknál a `players` és a résztvevő-lista hossza egyezik.
 *
 * A hitelesítés a WordPress alkalmazás-jelszóval történik, amit a Secret
 * Managerből kérdezünk le futásidőben (a repóban **nincs** titok).
 *
 * Futtatás (a repository gyökeréből):
 *   node tools/verify-wp-admin-endpoints.mjs
 *   node tools/verify-wp-admin-endpoints.mjs --self-test
 *
 * Kilépési kód: 0 = minden rendben, 1 = eltérés, 2 = nem futtatható (pl. nincs titok).
 */
import { createChecker, findForbiddenKeys, secret } from './lib/live-firebase.mjs';

const SITE = 'https://hungarianhardstyle.hu/wp-json';
// A 2.5.7 kell a natív létrehozáshoz (admin-create.php), ezért ez a küszöb.
const MIN_API_VERSION = '2.5.7';

/** „2.5.6” >= „2.5.6” — szám szerint, nem szövegként. */
export function apiVersionAtLeast(actual, expected) {
  const parse = (value) => String(value || '').split('.').map((part) => Number.parseInt(part, 10) || 0);
  const [aMajor, aMinor, aPatch] = parse(actual);
  const [eMajor, eMinor, ePatch] = parse(expected);
  if (aMajor !== eMajor) return aMajor > eMajor;
  if (aMinor !== eMinor) return aMinor > eMinor;
  return aPatch >= ePatch;
}

/** A nyereményjáték válasz belső konzisztenciája. */
export function prizeResultsConsistent(prize) {
  if (!prize || typeof prize !== 'object') return false;
  const players = Number(prize.players || 0);
  const participants = Array.isArray(prize.participants) ? prize.participants.length : -1;
  if (participants < 0) return false;
  if (players > 0 && players !== participants) return false;
  return true;
}

function selfTest() {
  const checker = createChecker();
  checker.check('a verzió-összehasonlítás szám szerint működik', apiVersionAtLeast('2.5.10', '2.5.6') && !apiVersionAtLeast('2.5.5', '2.5.6'));
  checker.check('az azonos verzió elfogadható', apiVersionAtLeast('2.5.6', '2.5.6'));

  const leaked = findForbiddenKeys({ prize: { participants: [{ name: 'X', uid: 'abc' }] } });
  checker.check('az UID-szivárgást megtalálja', leaked.length === 1 && leaked[0].endsWith('.uid'), leaked.join(', '));
  const hashed = findForbiddenKeys({ participants: [{ hash: 'deadbeef' }] });
  checker.check('a hash-szivárgást megtalálja', hashed.length === 1 && hashed[0].endsWith('.hash'));
  const clean = findForbiddenKeys({ prize: { participants: [{ name: 'X', answerIndex: 2, correct: true }] } });
  checker.check('a tiszta választ nem jelöli meg', clean.length === 0);

  constraintCheck: {
    checker.check('a konzisztens nyeremény választ elfogadja', prizeResultsConsistent({ players: 4, participants: [1, 2, 3, 4] }));
    checker.check('a hiányzó játékosokat kiszúrja', !prizeResultsConsistent({ players: 4, participants: [1, 2] }));
    checker.check('a résztvevő lista nélküli választ kiszúrja', !prizeResultsConsistent({ players: 4 }));
    checker.check('az üres (0 játékos) játékot elfogadja', prizeResultsConsistent({ players: 0, participants: [] }));
  }

  // Mutációs bizonyíték: egy „mindent elfogadó” detektor a hibás eseteket átengedné.
  const blindDetector = () => [];
  checker.check(
    'a „mindig tiszta” mutált szivárgás-detektor elbukna',
    blindDetector().length === 0 && leaked.length === 1,
  );

  const code = checker.report();
  console.log(code === 0 ? 'Önteszt: a detektorok működnek.' : 'Önteszt: HIBA!');
  return code;
}

async function call(action, auth) {
  const response = await fetch(`${SITE}/huhs/v1/admin?action=${action}`, {
    headers: { Authorization: `Basic ${auth}`, Accept: 'application/json' },
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    /* nem JSON */
  }
  return { status: response.status, json, text };
}

async function liveCheck() {
  const checker = createChecker();
  let auth;
  try {
    const user = secret('WORDPRESS_USERNAME');
    const password = secret('WORDPRESS_APPLICATION_PASSWORD');
    auth = Buffer.from(`${user}:${password}`).toString('base64');
  } catch (error) {
    console.error(`Nem futtatható: ${error.message}`);
    process.exit(2);
  }

  const dashboard = await call('dashboard', auth);
  const apiVersion = dashboard.json?.apiVersion || '';
  console.log(`apiVersion=${apiVersion || 'ismeretlen'} (status=${dashboard.status})`);
  checker.check('az admin-végpont válaszol (dashboard)', dashboard.status === 200, `status=${dashboard.status}`);
  checker.check(`a plugin verziója legalább ${MIN_API_VERSION}`, apiVersionAtLeast(apiVersion, MIN_API_VERSION), `mért: ${apiVersion}`);

  const payloads = {};
  for (const action of ['prize_games', 'prize_results', 'poll_results', 'polls']) {
    const result = await call(action, auth);
    payloads[action] = result;
    checker.check(`a(z) „${action}” végpont válaszol`, result.status === 200, `status=${result.status}`);
    const leaks = result.json ? findForbiddenKeys(result.json) : [];
    checker.check(`a(z) „${action}” válasz nem ad ki UID-t/hash-t`, leaks.length === 0, leaks.join(', '));
  }

  const prize = payloads.prize_results?.json?.prize;
  if (prize) {
    const participants = Array.isArray(prize.participants) ? prize.participants.length : 0;
    console.log(
      `nyereményjáték: id=${prize.id} players=${prize.players} correct=${prize.correct} ` +
        `correctIndex=${prize.correctIndex} participants=${participants}`,
    );
    checker.check('a nyereményjáték válasz konzisztens (players = résztvevők)', prizeResultsConsistent(prize));
    checker.check(
      'a helyes válasz indexe kiadható az adminnak (0..válaszok-1)',
      Number.isInteger(Number(prize.correctIndex)) &&
        Number(prize.correctIndex) >= 0 &&
        Number(prize.correctIndex) < (Array.isArray(prize.answers) ? prize.answers.length : 99),
      `correctIndex=${prize.correctIndex}, válaszok=${Array.isArray(prize.answers) ? prize.answers.length : 0}`,
    );
  } else {
    checker.check('van legalább egy nyereményjáték a szerveren', false, 'a prize_results nem adott játékot');
  }

  const poll = payloads.poll_results?.json?.poll;
  checker.check('a kérdőív-végpont kérdőívet ad', Boolean(poll && Array.isArray(poll.options)));
  if (poll) {
    console.log(`kérdőív: id=${poll.id} állapot=${poll.state} szavazatok=${poll.total} válaszok=${poll.options.length}`);
    checker.check(
      'a kérdőív válaszaihoz tartozik szám és százalék',
      poll.options.every((option) => Number.isInteger(Number(option.count)) && Number.isInteger(Number(option.percent))),
    );
  }
  checker.check('a kérdőív-lista nem üres', Array.isArray(payloads.polls?.json?.polls) && payloads.polls.json.polls.length > 0);

  return checker.report();
}

// FIGYELEM: `process.exitCode`, nem `process.exit()` — a nyitott hálózati
// kapcsolatok mellett a Windows-os Node kilépéskor elhasalna.
if (process.argv.includes('--self-test')) {
  process.exitCode = selfTest();
} else {
  liveCheck()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`HIBA: ${error.message}`);
      process.exitCode = 2;
    });
}
