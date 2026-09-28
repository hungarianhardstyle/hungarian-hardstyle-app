// ÉLES ellenőrzés: fent van-e a 2.14.9, és mit érne el a heti összefoglaló?
//
// ⚠️ SZÁRAZ KÖR: a végpontot `dry_run: true`-val hívjuk, ezért NEM küld senkinek.
// A híváshoz a WordPress admin alkalmazás-jelszót a Firebase Secret Managerből
// kérjük le (ugyanaz a titok, amit a Cloud Function használ).
import { accessToken, secretAsync } from '../tools/lib/live-firebase.mjs';

const PROJECT = 'hungarian-hardstyle';
const ENDPOINT = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/push/digest';

const token = await accessToken();

// 1) Élő plugin-verzió (a health fejlécből) — többször próbáljuk, mert az első
// kérésnél a gyorsítótár még üres lehet.
let health = '';
for (let attempt = 1; attempt <= 3 && !health; attempt += 1) {
  const response = await fetch(
    `https://hungarianhardstyle.hu/wp-json/huhs/v1/posts?per_page=1&probe=digest-live-${attempt}`,
    { headers: { Accept: 'application/json' } },
  );
  health = response.headers.get('x-huhs-health') || '';
  if (!health) await new Promise((resolve) => setTimeout(resolve, 1500));
}
console.log(`élő plugin (health): ${health || '(nincs fejléc)'}`);

// 2) Hitelesítés nélkül: létezik-e a végpont (404 = nincs, 401/403 = van, védett)?
const anonymous = await fetch(ENDPOINT, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ week: '2026-W40', texts: { hu: { title: 'x', body: 'y' } } }),
});
console.log(`hitelesítés nélkül: HTTP ${anonymous.status} (404 = még nincs fent, 401/403 = fent van és védett)`);

// 3) Admin alkalmazás-jelszóval, SZÁRAZ körben: mennyi eszközt érne el?
const username = await secretAsync('WORDPRESS_USERNAME', { token });
const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token });
if (!username || !password) {
  console.log('a WordPress-jelszó nem olvasható a Secret Managerből — a száraz kör kimarad');
  process.exit(0);
}
const credentials = Buffer.from(`${username}:${password}`).toString('base64');
const dry = await fetch(ENDPOINT, {
  method: 'POST',
  headers: { Authorization: `Basic ${credentials}`, 'Content-Type': 'application/json', Accept: 'application/json' },
  body: JSON.stringify({
    week: '2026-W40-dry-run',
    dry_run: true,
    texts: {
      hu: { title: 'Heti összefoglaló', body: '2 új hír · 1 közelgő esemény' },
      en: { title: 'Weekly recap', body: '2 new stories · 1 upcoming event' },
    },
  }),
});
const body = await dry.json().catch(() => ({}));
console.log(`száraz kör (admin): HTTP ${dry.status}`);
console.log(JSON.stringify(body, null, 2));
void PROJECT;
