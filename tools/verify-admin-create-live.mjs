#!/usr/bin/env node
/**
 * ÉLES ellenőrzés: a plugin 2.5.7 létrehozó-útja működik-e?
 *
 * MIÉRT: az app 331-től a natív adminból **új** kérdőív / nyereményjáték / kvíz is
 * létrehozható. A forrás-lint és a PHP-harness a logikát méri, de a **valódi
 * WordPress** csak élőben bizonyítható: hogy a `resource&id=0` visszaadja a
 * mezőket, és hogy a `save_resource` `id=0`-ra tényleg létrehoz.
 *
 * Alapból **CSAK OLVAS**: mindhárom típusra lekéri a mezőlistát (`id=0`).
 * `--confirm`-mal egy **PISZKOZAT** kvízt hoz létre, visszaolvassa (ellenőrzi a
 * meta-körjárást), majd jelzi, hogy a WordPressben törölhető — a CPT-k
 * (`huhs_poll`/`huhs_prize`/`huhs_game`) ugyanis **nincsenek** `show_in_rest`
 * módban, ezért azok REST-ből nem törölhetők.
 *
 * Futtatás:
 *   node tools/verify-admin-create-live.mjs             # olvasás
 *   node tools/verify-admin-create-live.mjs --confirm    # + 1 piszkozat kvíz
 */
import { createChecker, secret } from './lib/live-firebase.mjs';

const SITE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/admin';
const TYPES = ['huhs_poll', 'huhs_prize', 'huhs_game'];

async function call(auth, { method = 'GET', query = '', body = null } = {}) {
  const response = await fetch(`${SITE}${query}`, {
    method,
    headers: {
      Authorization: `Basic ${auth}`,
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    /* nem JSON */
  }
  return { status: response.status, json, text: text.slice(0, 200) };
}

(async () => {
  const checker = createChecker();
  let auth;
  try {
    const user = secret('WORDPRESS_USERNAME');
    const password = secret('WORDPRESS_APPLICATION_PASSWORD');
    auth = Buffer.from(`${user}:${password}`).toString('base64');
  } catch (error) {
    console.error(`Nem futtatható: ${error.message}`);
    process.exitCode = 2;
    return;
  }

  const version = await call(auth, { query: '?action=dashboard' });
  const apiVersion = version.json?.apiVersion || '';
  console.log(`apiVersion=${apiVersion}`);
  checker.check('a plugin verziója legalább 2.5.7 (a létrehozó-végpontokkal)', apiVersion >= '2.5.7' || apiVersion === '2.5.7', `mért: ${apiVersion}`);

  for (const type of TYPES) {
    const result = await call(auth, { query: `?action=resource&type=${type}&id=0` });
    const fields = Array.isArray(result.json?.fields) ? result.json.fields : [];
    console.log(`  ${type}: status=${result.status} mezők=${fields.length}${fields.length ? ` (${fields.map((field) => field.key).join(', ')})` : ''}`);
    checker.check(`a(z) „${type}" űrlapja lekérhető létrehozáshoz (id=0)`, result.status === 200 && fields.length > 0);
    checker.check(
      `a(z) „${type}" mezői a valódi meta-kulcsok`,
      fields.length > 0 && fields.every((field) => String(field.key).startsWith('_huhs_')),
    );
  }

  if (!process.argv.includes('--confirm')) {
    console.log('');
    console.log('Olvasó ellenőrzés kész. Élő létrehozáshoz: --confirm (egy PISZKOZAT kvízt hoz létre).');
    process.exitCode = checker.report();
    return;
  }

  const stamp = new Date().toISOString().slice(0, 16);
  const body = {
    action: 'save_resource',
    id: 0,
    type: 'huhs_game',
    status: 'draft',
    title: `TESZT – törölhető (${stamp})`,
    meta: {
      _huhs_game_type: 'hardstyle_quiz',
      _huhs_game_summary: 'Automatikus éles ellenőrzés — nyugodtan törölhető.',
      _huhs_game_start: '',
      _huhs_game_end: '',
      _huhs_game_results_until: '',
      _huhs_game_reward_points: '5',
      _huhs_game_questions: [
        { prompt: 'Él ellenőrzés: 1 + 1 = ?', options: ['2', '3'], correct: 0 },
      ],
    },
  };
  const created = await call(auth, { method: 'POST', body });
  console.log(`létrehozás: status=${created.status} ${JSON.stringify(created.json).slice(0, 160)}`);
  const id = Number(created.json?.id || 0);
  checker.check('a szerver létrehozta a piszkozat kvízt', created.status === 200 && id > 0, `id=${id}`);

  if (id > 0) {
    const readBack = await call(auth, { query: `?action=resource&type=huhs_game&id=${id}` });
    const fields = Object.fromEntries(
      (readBack.json?.fields || []).map((field) => [field.key, field.value]),
    );
    console.log(`  visszaolvasva: status=${readBack.status} méret=${JSON.stringify(fields).length} byte`);
    checker.check('a mentett típus visszaolvasható', fields._huhs_game_type === 'hardstyle_quiz', String(fields._huhs_game_type));
    checker.check('a kérdések JSON-ként megmaradtak', String(fields._huhs_game_questions).includes('1 + 1'));
    checker.check('a jutalom pont megmaradt', String(fields._huhs_game_reward_points) === '5');
    console.log('');
    console.log(`FIGYELEM: a(z) ${id} azonosítójú PISZKOZAT kvízt a WordPress adminban lehet törölni`);
    console.log('(a huhs_game típus nincs REST-ben, ezért innen nem törölhető). Az appban nem látszik.');
  }

  process.exitCode = checker.report();
})();
