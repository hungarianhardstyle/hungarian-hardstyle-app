// ÉLES, CSAK OLVAS mérés: megy-e ki a push az új hírekről?
//
// MIÉRT: a tulajdonos jelzése (2026-09-30): „az új hírekről nem megy ki push".
// A hír-push a **WordPress-pluginban** él (`huhs_push_on_publish` →
// `huhs_schedule_news_push` → `huhs_push_publish_news` → `huhs_push_send`),
// ezért a mérés a plugin állapotát kérdezi le:
//
//   1. a legfrissebb publikált hírek (mióta nem ment ki értesítés),
//   2. a **titkos diagnosztikai fejléc** (`?huhs_diag=huhs-boot-probe-2026`) —
//      ebben van `push_tokens=`, `push_last=<típus>/<ok> recipients=… sent=…`,
//      `cron_overdue=`, `push_job=`, `push_active=`; ez megmondja, hogy az
//      utolsó küldés mikor és mit tett, illetve hogy a WP-Cron viszi-e a kört.
//
// Ez a szkript NEM ír semmit: nincs POST, nincs beállítás-módosítás.
import { secretAsync, accessToken } from '../tools/lib/live-firebase.mjs';

const SITE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
const api = (path) => `${SITE}/wp-json/huhs/v1${path}`;

async function get(path, label) {
  const response = await fetch(api(path), {
    headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' },
  });
  const health = response.headers.get('x-huhs-health') || '';
  const cache = response.headers.get('x-huhs-cache') || '';
  const body = await response.json().catch(() => null);
  console.log(`\n=== ${label} -> HTTP ${response.status}${cache ? ` (cache: ${cache})` : ''}`);
  return { response, health, body };
}

/* --- 1. A legfrissebb hírek ------------------------------------------- */
const posts = await get(`/posts?per_page=6&_=${Date.now()}`, 'legfrissebb hírek');
const items = Array.isArray(posts.body?.items)
  ? posts.body.items
  : Array.isArray(posts.body)
    ? posts.body
    : [];
if (items.length === 0) {
  console.log('  (a válaszban nem találtam listát — nyers kulcsok:)', Object.keys(posts.body ?? {}));
} else {
  for (const item of items.slice(0, 6)) {
    const id = item.id ?? item.ID ?? '?';
    const date = item.date ?? item.date_gmt ?? item.publishedAt ?? '?';
    const title = String(item.title ?? '').slice(0, 70);
    console.log(`  #${id} ${date} — ${title}`);
  }
}

/* --- 2. A diagnosztikai fejléc (push + cron állapot) ------------------ */
const diag = await get(`/posts?per_page=1&huhs_diag=${MARKER}&probe=${Date.now()}`, 'diagnosztika');
console.log(`  X-HUHS-Health: ${diag.health || '(nincs fejléc)'}`);

/* --- 3. Értelmezés (csak a mért szövegből) ---------------------------- */
const health = diag.health;
if (!health) {
  console.log('\nNINCS diagnosztikai fejléc — a marker nem élt, vagy a szerver elrejti a fejléceket.');
} else {
  const pick = (key) => new RegExp(`${key}=([^\\s]+)`).exec(health)?.[1] ?? '(nincs)';
  console.log('\n--- a mért értékek ---');
  console.log(`  api verzió:        ${pick('api')}`);
  console.log(`  regisztrált token: ${pick('push_tokens')}`);
  console.log(`  utolsó küldés:     ${pick('push_last')}`);
  console.log(`  recipient/ment:    recipients=${pick('recipients')} sent=${pick('sent')} failed=${pick('failed')} dead=${pick('dead')} http=${pick('code')}`);
  console.log(`  aktív feladat:     ${pick('push_active')}`);
  console.log(`  cron:              overdue=${pick('cron_overdue')} job=${pick('push_job')} disabled=${pick('cron_disabled')}`);
}

/* --- 4. A szerveroldali (Cloud Function) oldal: jött-e bejövő értesítés? */
const token = await accessToken().catch(() => '');
if (!token) {
  console.log('\n(a Secret Manager nem olvasható — a WordPress-admin kör kimarad)');
} else {
  const username = await secretAsync('WORDPRESS_USERNAME', { token }).catch(() => '');
  const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token }).catch(() => '');
  if (!username || !password) {
    console.log('\n(a WordPress admin jelszó nem olvasható — az admin állapot kimarad)');
  } else {
    const credentials = Buffer.from(`${username}:${password}`).toString('base64');
    const admin = await fetch(`${SITE}/wp-json/huhs/v1/admin?action=push`, {
      headers: { Authorization: `Basic ${credentials}`, Accept: 'application/json' },
    });
    const body = await admin.json().catch(() => ({}));
    console.log(`\n=== admin action=push -> HTTP ${admin.status}`);
    console.log(`  regisztrált eszköz: ${body.registeredDevices ?? '?'}`);
    console.log(`  FCM fiók beállítva: ${body.configured === undefined ? '?' : body.configured}`);
    const targets = Array.isArray(body.targets) ? body.targets : [];
    console.log(`  a legutóbbi célpontok (${targets.length}):`);
    for (const target of targets.slice(0, 5)) {
      console.log(`    #${target.id} [${target.type}] ${String(target.title ?? '').slice(0, 60)}`);
    }
  }
}
