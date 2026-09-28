// ÉLES mérés (nem küld): mit tartalmazna a VASÁRNAPI heti összefoglaló?
import { notificationText } from '../functions/notification-texts.js';
import {
  digestParamsByLanguage,
  digestPlan,
  isoWeekKey,
} from '../functions/weekly-digest-plan.js';

const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

async function list(path, lang) {
  const response = await fetch(`${BASE}${path}?lang=${lang}`, { headers: { Accept: 'application/json' } });
  if (!response.ok) return [];
  const body = await response.json();
  return Array.isArray(body) ? body : Array.isArray(body?.items) ? body.items : [];
}

const [news, newsEn, events, eventsEn] = await Promise.all([
  list('/posts', 'hu'),
  list('/posts', 'en'),
  list('/events', 'hu'),
  list('/events', 'en'),
]);

const now = Date.now();
const plan = digestPlan({ news, newsEn, events, eventsEn }, now);
const params = digestParamsByLanguage(plan);
const week = isoWeekKey('Europe/Budapest', new Date(now));

console.log(`hét kulcsa: ${week}`);
console.log(`bemenet: hír ${news.length} (en ${newsEn.length}) · esemény ${events.length} (en ${eventsEn.length})`);
console.log(`\nAZ ÖSSZEFOGLALÓ TARTALMA (${plan.news.length} hír, ${plan.events.length} esemény):`);
for (const item of plan.news) {
  console.log(`  HÍR  #${item.id}  ${typeof item.title === 'string' ? item.title : item.title.hu}`);
}
for (const item of plan.events) {
  console.log(`  ESEMÉNY  #${item.id}  ${typeof item.title === 'string' ? item.title : item.title.hu}  ${item.where}`);
}
const hu = notificationText('weekly_digest', 'hu', params);
const en = notificationText('weekly_digest', 'en', params);
console.log(`\nPUSH MAGYARUL: ${hu.title} — ${hu.body}`);
console.log(`PUSH ANGOLUL: ${en.title} — ${en.body}`);
if (!plan.news.length && !plan.events.length) console.log('\n(üres hét: a kör nem küldene semmit)');
