#!/usr/bin/env node
/**
 * Az **utolsó @mindenki chat-üzenet** kiadása push-ban — MINDEN eszközre
 * (a nem regisztráltakra is). A tulajdonos kérése (2026-10-04):
 * *„ki tudod küldeni az utolsó @mindenki tages chat üzit pushban? nem csak a
 * regelteknek”*.
 *
 * MIÉRT ÍGY: a normál `@mindenki` push az **új** üzenetnél automatikus
 * (`publishChatPost` → széles WordPress-push). Egy **már meglévő** üzenethez
 * viszont kézzel kell kiadni — ugyanazon a bizonyított úton: a WordPress admin
 * `send_push` végpontja, `type = chat_everyone`, `postId = <üzenet>`, nyelvenkénti
 * szöveggel (2.14.19). A koppintás így a Chat üzenetére visz.
 *
 * Ez a szkript **ÍR** (valódi push megy ki ~1070 eszközre) — csak a tulajdonos
 * kérésére futtasd.
 *
 * Használat:
 *   node tmp/send-chat-everyone-push.mjs            # az utolsó @mindenki üzenet
 *   node tmp/send-chat-everyone-push.mjs --dry-run   # csak mérés, nem küld
 *   node tmp/send-chat-everyone-push.mjs --id=<postId>
 */
import { accessToken, firestoreGet, firestoreList, secretAsync } from '../tools/lib/live-firebase.mjs';

const SITE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const explicitId = (args.find((a) => a.startsWith('--id=')) || '').split('=')[1] || '';

const token = await accessToken();

/* --- 1) A plugin élő verziója (a 2.14.19 kell a széles chat-pushhoz) ------ */
async function health() {
  const response = await fetch(
    `${SITE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=${Date.now()}`,
    { headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' } },
  );
  const header = response.headers.get('x-huhs-health') || '';
  const pick = (key) => new RegExp(`${key}=([^\\s]+)`).exec(header)?.[1] ?? '';
  return { api: pick('api'), tokens: pick('push_tokens'), last: pick('push_last'), sent: pick('sent') };
}

const before = await health();
console.log(`PLUGIN: api=${before.api} push_tokens=${before.tokens} push_last=${before.last} sent=${before.sent}`);
const pluginReady = Boolean(before.api && before.api.startsWith('2.14.19'));
if (!pluginReady && !dryRun) {
  console.log(`\n⚠️ A plugin élő verziója ${before.api || '(ismeretlen)'} — a széles chat-pushhoz 2.14.19 kell.`);
  console.log('   E nélkül a push elmenne (magyar szöveggel), de a koppintás NEM a chat üzenetére vinne.');
  if (!args.includes('--force')) {
    console.log('\nMegállítva. Előbb töltsd fel a build/huhs-mobile-api-2.14.19.zip csomagot.');
    process.exit(2);
  }
  console.log('   (--force megadva: megy tovább)');
}

/* --- 2) Az utolsó @mindenki üzenet a Chatben ----------------------------- */
/** Időbélyeg → ms. ⚠️ MÉRT HIBA: ebben a kollekcióban a `createdAt` **ISO
 * szöveg** (nem Firestore-timestamp), ezért a `seconds` olvasása 0-t adott, a
 * rendezés elbukott, és a „legfrissebb” helyett a lista első találata ment ki. */
function millis(value) {
  if (value == null) return 0;
  if (typeof value === 'number') return value > 1e12 ? value : value * 1000;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  if (typeof value === 'object') {
    const seconds = value.seconds ?? value._seconds ?? value.secondsValue;
    if (typeof seconds === 'number') return seconds * 1000;
  }
  return 0;
}

let postId = explicitId;
let post = null;
if (!postId) {
  // A chat a `live_feed_posts` kollekcióban él; a `@mindenki` üzenet `mentions`
  // tömbjében `{type: 'everyone'}` van. A legfrissebbet az IDŐBÉLYEG dönti el.
  const posts = await firestoreList('live_feed_posts', {
    fields: ['authorId', 'authorName', 'text', 'createdAt', 'mentions'],
    token,
    max: 400,
  });
  const isEveryone = (entry) =>
    Array.isArray(entry.mentions) && entry.mentions.some((mention) => mention && mention.type === 'everyone');
  const sorted = [...posts].sort(
    (a, b) => millis(b.createdAt ?? b.createdAtMs) - millis(a.createdAt ?? a.createdAtMs),
  );
  post = sorted.find(isEveryone) || null;
  if (!post) {
    console.log('\n⚠️ Nincs @mindenki üzenet a Chatben (a vizsgált 400 legfrissebb bejegyzésben).');
    process.exit(3);
  }
  postId = post.id;
} else {
  post = await firestoreGet(`live_feed_posts/${postId}`, { token });
}

const authorName = String(post?.authorName || post?.author || 'Egy tag').trim();
// ⚠️ A chat-üzenetben lehet sortörés (mért példa: „Mai timetable\n\n@mindenki") —
// az értesítés törzsében egysoros, olvasható kivonat kell.
const text = String(post?.text || '').replace(/\s+/g, ' ').trim();
const stampMs = millis(post?.createdAt ?? post?.createdAtMs);
const stamp = stampMs ? new Date(stampMs).toISOString() : '(nincs idő)';
console.log(`\nÜZENET: id=${postId} szerző=${authorName} idő=${stamp}`);
console.log(`  szöveg: ${text.slice(0, 160)}${text.length > 160 ? '…' : ''}`);

/* --- 3) A push szövegei (a notification katalógusból, ugyanaz mint élesben) */
const notificationModule = await import('../functions/notification-texts.js');
const texts = notificationModule.TEXTS ?? (notificationModule.default ?? notificationModule).TEXTS;
const template = texts.chat_everyone;
const fill = (value) => String(value).replaceAll('{name}', authorName).replaceAll('{snippet}', text.slice(0, 120));
const payloadTexts = {
  hu: { title: fill(template.hu.title), body: fill(template.hu.body) },
  en: { title: fill(template.en.title), body: fill(template.en.body) },
};
console.log('\nPUSH (hu):', payloadTexts.hu.title, '|', payloadTexts.hu.body);
console.log('PUSH (en):', payloadTexts.en.title, '|', payloadTexts.en.body);

if (dryRun) {
  console.log('\n--dry-run: nem küldtem semmit.');
  process.exit(0);
}

/* --- 4) Küldés a WordPress admin végpontján (a széles út) ----------------- */
const username = await secretAsync('WORDPRESS_USERNAME', { token });
const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD', { token });
const credentials = Buffer.from(`${username}:${password}`).toString('base64');
const response = await fetch(`${SITE}/wp-json/huhs/v1/admin`, {
  method: 'POST',
  headers: {
    Authorization: `Basic ${credentials}`,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
  body: JSON.stringify({
    action: 'send_push',
    title: payloadTexts.hu.title,
    body: payloadTexts.hu.body,
    texts: payloadTexts,
    type: 'chat_everyone',
    postId: String(postId),
  }),
});
const body = await response.json().catch(() => ({}));
console.log(`\nKÜLDÉS: HTTP ${response.status} ${JSON.stringify(body)}`);

/* --- 5) Utómérés: elindult-e a kör, hány címzett -------------------------- */
for (let attempt = 0; attempt < 12; attempt += 1) {
  await new Promise((resolve) => setTimeout(resolve, 5000));
  const state = await health();
  console.log(`  [${attempt + 1}] push_last=${state.last} sent=${state.sent}`);
  if (state.last && state.last !== before.last && !state.last.includes('running')) break;
}
