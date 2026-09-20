#!/usr/bin/env node
/**
 * ÉLES (csak olvas): mi van az app értesítés-listájában?
 *
 * MIÉRT: a chat-értesítések (lájk, válasz) és az ikonjelvény működését akkor
 * lehet igazolni, ha látszik, hogy a szerver **tényleg** ír-e bejegyzést. Ez az
 * eszköz típusonként összegzi a `notifications` gyűjteményt, megmutatja az
 * olvasatlanok számát (ezt tükrözi az app-ikon jelvénye), és külön kiemeli a
 * chat-típusokat.
 *
 * Titkot nem használ és nem ír: a Firebase CLI bejelentkezését használja, és
 * **UID-et nem ír ki** (rövidített lenyomatot mutat).
 *
 * Futtatás:
 *   node tools/check-notifications.mjs
 *   node tools/check-notifications.mjs --self-test
 * Kilépési kód: 0 = sikerült kiolvasni, 1 = nem (vagy önteszt-hiba).
 */
import { accessToken, firestoreList, shortHash } from './lib/live-firebase.mjs';

/** A chat-értesítések, amelyeket a tulajdonos kérése hozott létre. */
export const CHAT_TYPES = ['chat_reaction', 'chat_reply', 'article_comment_reply'];

/** Típusonkénti összegzés + az olvasatlanok száma (tiszta függvény). */
export function summarize(rows) {
  const byType = new Map();
  let unread = 0;
  for (const row of rows) {
    const type = String(row.type || '(nincs típus)');
    const record = byType.get(type) || { type, total: 0, unread: 0 };
    record.total += 1;
    if (!row.readAt) {
      record.unread += 1;
      unread += 1;
    }
    byType.set(type, record);
  }
  return {
    total: rows.length,
    unread,
    types: [...byType.values()].sort((a, b) => b.total - a.total),
  };
}

/** A legfrissebb bejegyzések (idő szerint csökkenő), UID nélkül. */
export function newest(rows, limit = 5) {
  const timeOf = (row) => {
    const raw = row.createdAt;
    if (!raw) return 0;
    if (typeof raw === 'string') return Date.parse(raw) || 0;
    if (typeof raw === 'object' && raw.seconds) return raw.seconds * 1000;
    return 0;
  };
  return [...rows]
    .sort((a, b) => timeOf(b) - timeOf(a))
    .slice(0, limit)
    .map((row) => ({
      type: String(row.type || '?'),
      title: String(row.title || '').slice(0, 80),
      body: String(row.body || '').slice(0, 100),
      targetType: String(row.targetType || ''),
      read: row.readAt != null,
      recipient: shortHash(String(row.recipientUid || '')),
    }));
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });

  const rows = [
    { type: 'new_news', recipientUid: 'u1' },
    { type: 'new_news', recipientUid: 'u2', readAt: 'x' },
    { type: 'chat_reaction', recipientUid: 'u3' },
    { type: 'chat_reply', recipientUid: 'u4', readAt: 'x' },
  ];
  const summary = summarize(rows);
  check('összesen ennyi bejegyzés', summary.total === 4);
  check('az olvasatlanokat számolja', summary.unread === 2);
  check(
    'típusonként bontja (a legtöbb elöl)',
    summary.types[0].type === 'new_news' && summary.types[0].total === 2,
  );
  check('típuson belül is számol olvasatlant', summary.types[0].unread === 1);

  const list = newest(rows, 2);
  check('a legfrissebbeket adja vissza', list.length === 2);
  check(
    'nem ír ki teljes UID-et',
    list.every((item) => !('recipientUid' in item) && item.recipient.length <= 16),
  );

  check('üres bemenet nem törik el', summarize([]).total === 0 && newest([]).length === 0);
  return checks;
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checks = selfTest();
    for (const check of checks) console.log(`${check.ok ? 'OK  ' : 'HIBA'} ${check.label}`);
    const failed = checks.filter((check) => !check.ok).length;
    console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
    return failed ? 1 : 0;
  }

  const token = await accessToken();
  const rows = await firestoreList('notifications', { token, max: 3000 });
  const summary = summarize(rows);
  console.log(`értesítések: ${summary.total}, ebből olvasatlan: ${summary.unread}`);
  console.log('\ntípusonként (összes / olvasatlan):');
  for (const item of summary.types) {
    console.log(`  ${item.type}: ${item.total} / ${item.unread}`);
  }

  const chat = summary.types.filter((item) => CHAT_TYPES.includes(item.type));
  console.log('\na chat-értesítések (a tulajdonos kérése):');
  if (!chat.length) {
    console.log('  még nincs egy sem — amint valaki lájkol/válaszol, itt megjelenik');
  }
  for (const type of CHAT_TYPES) {
    const item = chat.find((entry) => entry.type === type);
    console.log(`  ${type}: ${item ? item.total : 0}`);
  }

  console.log('\na legfrissebb 5:');
  for (const item of newest(rows, 5)) {
    console.log(
      `  [${item.read ? 'olvasott' : 'OLVASATLAN'}] ${item.type} — ${item.title} — ${item.body}`,
    );
  }
  return 0;
}

main()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
