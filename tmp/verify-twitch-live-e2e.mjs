#!/usr/bin/env node
/**
 * **ÉLŐ ADÁS — végponttól végpontig mérés** (egy paranccsal).
 *
 * MIÉRT: a Twitch-integráció utolsó, géppel nem kiváltható lépése az, amikor
 * **tényleg megy az adás**: ilyenkor kell látni, hogy (1) a figyelő bejelenti
 * (`twitch_live_notice` a naplóban), (2) a jelölő bekerül a Firestore-ba
 * (`app_settings/twitch_live` → `announcedStreamId`), (3) a széles push
 * tényleg kimegy a WordPress-táron (~1027 eszköz), és (4) a főoldali kártya
 * megjelenik. Ez a szkript mind a négyet **egy menetben** méri.
 *
 * NEM KÜLD semmit: csak olvas (Twitch GraphQL, Firestore, a plugin
 * diagnosztikai fejléce), és a végén megmondja, melyik lépés hiányzik.
 *
 * Használat:
 *   node tmp/verify-twitch-live-e2e.mjs
 *   node tmp/verify-twitch-live-e2e.mjs --emulator   # a képernyőképeket is elkészíti
 */
import { execFileSync } from 'node:child_process';
import { accessToken, firestoreGet, secretAsync } from '../tools/lib/live-firebase.mjs';

const withEmulator = process.argv.includes('--emulator');
const adb = `${process.env.LOCALAPPDATA}\\Android\\Sdk\\platform-tools\\adb.exe`;

let problems = 0;
const check = (label, ok, detail = '') => {
  if (!ok) problems += 1;
  console.log(`${ok ? 'OK  ' : 'HIÁNY'} ${label}${detail ? ` — ${detail}` : ''}`);
};

/* --- 1) Él-e a csatorna? -------------------------------------------------- */
const live = await fetchLive();
console.log('=== 1) Twitch élő állapot ===');
console.log(
  live.isLive
    ? `  ÉLŐ: „${live.title}" — ${live.viewers} néző, adás id ${live.streamId}, indult: ${live.startedAt}`
    : '  nem él (a `stream` mező null)',
);

/* --- 2) A figyelő jelölője a Firestore-ban -------------------------------- */
console.log('\n=== 2) A szerveroldali figyelő jelölője (app_settings/twitch_live) ===');
const token = await accessToken();
const state = await firestoreGet('app_settings/twitch_live', { token }).catch(() => null);
console.log(`  ${JSON.stringify(state)}`);
if (live.isLive) {
  check(
    'a figyelő bejelentette EZT az adást (announcedStreamId egyezik)',
    String(state?.announcedStreamId ?? '') === live.streamId,
    `jelölő: ${state?.announcedStreamId ?? '(nincs)'} / adás: ${live.streamId}`,
  );
} else {
  check(
    'nincs bejelentett adás (az adás vége törli a jelölőt)',
    !state?.announcedStreamId,
    `jelölő: ${state?.announcedStreamId ?? '(nincs)'}`,
  );
}

/* --- 3) A széles push a WordPress-táron ---------------------------------- */
console.log('\n=== 3) A széles push (WordPress-plugin fejléc) ===');
const header = readHealthHeader();
const pushLast = /push_last=([^ ]+ recipients=\d+ processed=\d+ sent=\d+ failed=\d+ dead=\d+ http=\d+ at=[0-9:]+)/.exec(header)?.[1] ?? '';
console.log(`  api=${/api=([0-9.]+)/.exec(header)?.[1] ?? '?'}  ${/push_limits=[^ ]+/.exec(header)?.[0] ?? ''}`);
console.log(`  push_last=${pushLast || '(nincs)'}`);
console.log(`  ${/push_tokens=\d+/.exec(header)?.[0] ?? ''}  ${/news_scan=[^ ]*/.exec(header)?.[0] ?? ''}`);
check('van mérhető küldési sor a fejlécben', pushLast !== '', pushLast);
if (live.isLive) {
  const recipients = Number(/recipients=(\d+)/.exec(pushLast)?.[1] ?? 0);
  check('a legutóbbi küldés széles volt (500+ eszköz)', recipients >= 500, `recipients=${recipients}`);
}

/* --- 4) A széles push VEZETÉKE (negatív kontroll, NEM küld) --------------- */
console.log('\n=== 4) Az admin push-végpont vezetéke (a figyelő ezt hívja) ===');
const adminUrl = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/admin';
const adminCheck = await checkAdminPushWiring(token);
check('a végpont él és védett (401/403 hitelesítés nélkül)', adminCheck.anonymous401, `HTTP ${adminCheck.anonymous}`);
check(
  'a figyelő payload-alakját elfogadja (a szándékosan hibás célnál áll meg)',
  adminCheck.invalidTarget400,
  `HTTP ${adminCheck.authorized} ${adminCheck.code}`,
);

/* --- 5) A főoldali kártya (opcionális, emulátoron) ----------------------- */
console.log('\n=== 5) A főoldali kártya és a kis képernyő (emulátor) ===');
if (!withEmulator) {
  console.log('  (kihagyva — add meg a --emulator kapcsolót a képernyőképekhez)');
} else {
  const shot = (name) => {
    execFileSync(adb, ['shell', 'screencap', '-p', `/sdcard/${name}.png`]);
    execFileSync(adb, ['pull', `/sdcard/${name}.png`, `tmp/${name}.png`], { stdio: 'ignore' });
    console.log(`  kép: tmp/${name}.png`);
  };
  const version = execFileSync(adb, ['shell', 'dumpsys', 'package', 'hu.hungarianhardstyle.app'], { encoding: 'utf8' });
  console.log(`  telepített: ${/versionCode=(\d+)/.exec(version)?.[1] ?? '?'}`);
  shot('twitch-live-home');
  console.log('  ⚠️ A kártyára koppintáshoz és a kis képernyőhöz kézi lépés kell:');
  console.log('     1) a kártyára koppintás (a Twitch-oldal megnyílik),');
  console.log('     2) HOME (a stream kicsiben megy tovább),');
  console.log('     3) ellenőrzés: adb shell dumpsys activity activities | findstr /i "pinned pip"');
}

/* --- Összegzés ------------------------------------------------------------ */
console.log(
  problems === 0
    ? '\nMINDEN MÉRHETŐ LÉPÉS RENDBEN'
    : `\n${problems} lépés még nem mérhető (lásd a HIÁNY sorokat)`,
);
process.exitCode = problems === 0 ? 0 : 1;

/* --- Segédek -------------------------------------------------------------- */
async function fetchLive() {
  const body = JSON.stringify({
    query:
      'query{user(login:"hungarianhardstyle"){id displayName stream{id title viewersCount createdAt type previewImageURL(width:640,height:360)}}}',
  });
  const response = await fetch('https://gql.twitch.tv/gql', {
    method: 'POST',
    headers: {
      'Client-ID': 'kimne78kx3ncx6brgo4mv6wki5h1ko',
      'Content-Type': 'application/json',
    },
    body,
  });
  if (!response.ok) return { isLive: false };
  const parsed = await response.json();
  const stream = parsed?.data?.user?.stream;
  if (!stream) return { isLive: false };
  return {
    isLive: true,
    title: stream.title,
    viewers: stream.viewersCount,
    streamId: stream.id,
    startedAt: stream.createdAt,
  };
}

function readHealthHeader() {
  const out = execFileSync(process.execPath, ['tmp/probe-news-push-live.mjs'], {
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
  });
  return /X-HUHS-Health: (.*)/.exec(out)?.[1] ?? '';
}

/**
 * Az admin push-végpont **vezetékének** mérése — SZÁNDÉKOSAN nem küld senkinek.
 *
 * MIÉRT: a figyelő akkor tud push-t küldeni, ha (1) a végpont él és védett,
 * (2) a hitelesítés jó, (3) a payload-alak (title/body/targetType/url) átmegy a
 * validáción. Ezt úgy mérjük, hogy a **szándékosan érvénytelen** célt küldjük:
 * a kérés a tartalom-ellenőrzésen már átjutott, és a cél-feloldásnál áll meg —
 * küldés nélkül.
 */
async function checkAdminPushWiring(token) {
  const anonymous = await fetch(adminUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ action: 'send_push', title: 'x', body: 'y', targetType: 'custom' }),
  }).catch(() => ({ status: 0 }));

  const username = await secretAsync('WORDPRESS_USERNAME', { token });
  const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token });
  if (!username || !password) {
    return { anonymous: anonymous.status, anonymous401: false, authorized: 0, code: '(nincs jelszó)', invalidTarget400: false };
  }
  const credentials = Buffer.from(`${username}:${password}`).toString('base64');
  const response = await fetch(adminUrl, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      action: 'send_push',
      // ⚠️ A tartalom VALÓS alakú (különben a validáció a tartalomnál állna meg,
      // és nem jutnánk el a cél-feloldásig)…
      title: 'Élőben vagyunk Twitchen',
      body: 'A csatorna most élőben sugároz — nézd meg az appban.',
      // …a cél viszont SZÁNDÉKOSAN érvénytelen: így nem megy ki semmi.
      targetType: 'release',
      targetId: 999999,
      url: '',
    }),
  }).catch(() => ({ status: 0, json: async () => ({}) }));
  const body = await response.json().catch(() => ({}));
  return {
    anonymous: anonymous.status,
    anonymous401: anonymous.status === 401 || anonymous.status === 403,
    authorized: response.status,
    code: body?.code ?? '',
    invalidTarget400: response.status === 400 && String(body?.code ?? '').includes('invalid_push_target'),
  };
}
