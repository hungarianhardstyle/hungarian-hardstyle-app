// A MAI (2026-09-30) KÉT ELMARADT HÍR-PUSH KIADÁSA — a tulajdonos kérése:
// „a mai két cikkről is menjen ki az elmaradt push".
//
// MIÉRT EZ AZ ÚT: a hír-push a pluginban automatikusan a közzétételkor megy ki
// (`huhs_push_on_publish` → `huhs_schedule_news_push` → `huhs_push_publish_news`).
// A mérés szerint ezekre a cikkekre **nem indult** kör (nincs mai `push_last`
// rekord és nincs függő cron-esemény), ezért a meglévő, bizonyított
// **admin-custom-push** utat használjuk ugyanazzal az adatcsomaggal
// (`type = news`, `id = <cikk>`), amit a normál hír-push is küld — így a
// koppintás ugyanúgy a cikket nyitja meg.
//
// Ez a szkript ÍR (valódi push megy ki ~1000 eszközre) — a tulajdonos kérésére.
import fs from 'node:fs';
import { secretAsync, accessToken } from '../tools/lib/live-firebase.mjs';

const SITE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
// A MAI két cikk (a `/posts` listából mérve) — a régebbit küldjük előbb, hogy a
// legfrissebb látszódjon felül az értesítési listán.
const ARTICLES = [12884, 12893];

const token = await accessToken();
const username = await secretAsync('WORDPRESS_USERNAME', { token });
const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token });
const credentials = Buffer.from(`${username}:${password}`).toString('base64');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function articleTitle(id) {
  const response = await fetch(`${SITE}/wp-json/huhs/v1/posts/${id}?_=${Date.now()}`, {
    headers: { Accept: 'application/json' },
  });
  const body = await response.json().catch(() => ({}));
  return { status: response.status, title: String(body.title ?? '').trim(), date: body.date ?? '' };
}

async function diagnostics() {
  const response = await fetch(`${SITE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=${Date.now()}`, {
    headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' },
  });
  const health = response.headers.get('x-huhs-health') || '';
  const pick = (key) => new RegExp(`${key}=([^\\s]+)`).exec(health)?.[1] ?? '';
  return {
    at: new Date().toISOString(),
    pushLast: pick('push_last'),
    recipients: pick('recipients'),
    processed: pick('processed'),
    sent: pick('sent'),
    failed: pick('failed'),
    pushJob: pick('push_job'),
    pushActive: pick('push_active'),
    cronOverdue: pick('cron_overdue'),
  };
}

const evidence = { startedAt: new Date().toISOString(), articles: [], sends: [], polls: [] };

// 0) Kiinduló állapot — bizonyíték arra, hogy a mai cikkekre nem volt kör.
const before = await diagnostics();
console.log(`KIINDULÁS  push_last=${before.pushLast} recipients=${before.recipients} processed=${before.processed} sent=${before.sent}`);
console.log(`           push_job=${before.pushJob} push_active=${before.pushActive} cron_overdue=${before.cronOverdue}`);
evidence.before = before;

for (const id of ARTICLES) {
  const article = await articleTitle(id);
  console.log(`\ncikk #${id} (${article.date}): ${article.title.slice(0, 80)}`);
  evidence.articles.push({ id, ...article });
  if (article.status !== 200 || article.title === '') {
    console.log('  KIHAGYVA: a cikk nem olvasható a nyilvános végponton');
    continue;
  }

  const response = await fetch(`${SITE}/wp-json/huhs/v1/admin`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      action: 'send_push',
      title: 'Új hír',
      body: article.title,
      targetType: 'news',
      targetId: id,
    }),
  });
  const body = await response.json().catch(() => ({}));
  console.log(`  send_push -> HTTP ${response.status}: ${JSON.stringify(body)}`);
  evidence.sends.push({ id, status: response.status, body });

  // Megvárjuk, amíg a küldési lánc befejezi ezt a kört (nincs feladat, nincs aktív munka).
  for (let round = 1; round <= 24; round += 1) {
    await sleep(20000);
    const state = await diagnostics();
    evidence.polls.push({ id, round, ...state });
    console.log(
      `  [${round}] push_last=${state.pushLast} rec=${state.recipients} proc=${state.processed} sent=${state.sent} failed=${state.failed} job=${state.pushJob} active=${state.pushActive}`,
    );
    if (state.pushJob === 'none' && state.pushActive === 'none' && round >= 2) break;
  }
}

fs.writeFileSync('tmp/news-push-replay-2026-09-30.json', `${JSON.stringify(evidence, null, 2)}\n`, 'utf8');
console.log('\nbizonyíték: tmp/news-push-replay-2026-09-30.json');
