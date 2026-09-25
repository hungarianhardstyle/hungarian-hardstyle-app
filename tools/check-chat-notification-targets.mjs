#!/usr/bin/env node
/**
 * ÉLES (csak olvas) szonda: a `chat_reaction` / `chat_reply` értesítésekben
 * **benne van-e a célpont** (`targetType` + `targetId`)?
 *
 * MIÉRT: a tulajdonos jelzése szerint a chat-lájk értesítésre koppintva
 * *„néha a megfelelő helyre dob, néha nem"*. Az egyik lehetséges ok, hogy a
 * RÉGEBBI bejegyzésekben nincs célpont (azt csak később kezdte írni a szerver)
 * — ezt innen meg lehet mérni. UID-et nem ír ki, csak rövidített lenyomatot.
 *
 * Futtatás: node tools/check-chat-notification-targets.mjs
 */
import { accessToken, firestoreList, shortHash } from './lib/live-firebase.mjs';

export function summarizeTargets(rows) {
  const types = ['chat_reaction', 'chat_reply', 'chat_mention'];
  const result = [];
  for (const type of types) {
    const items = rows.filter((row) => String(row.type || '') === type);
    const withTargetType = items.filter((row) => String(row.targetType || '') === 'chat');
    const withTargetId = items.filter((row) => String(row.targetId || '').trim() !== '');
    const timeOf = (row) => {
      const raw = row.createdAt;
      if (!raw) return 0;
      if (typeof raw === 'string') return Date.parse(raw) || 0;
      if (typeof raw === 'object' && raw.seconds) return raw.seconds * 1000;
      return 0;
    };
    const sorted = [...items].sort((a, b) => timeOf(a) - timeOf(b));
    result.push({
      type,
      total: items.length,
      withTargetType: withTargetType.length,
      withTargetId: withTargetId.length,
      oldest: sorted.length ? new Date(timeOf(sorted[0])).toISOString() : '',
      newest: sorted.length ? new Date(timeOf(sorted[sorted.length - 1])).toISOString() : '',
      missing: sorted
        .filter((row) => String(row.targetId || '').trim() === '')
        .map((row) => ({
          at: new Date(timeOf(row)).toISOString(),
          recipient: shortHash(String(row.recipientUid || '')),
        })),
    });
  }
  return result;
}

export function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok });
  const rows = [
    { type: 'chat_reaction', targetType: 'chat', targetId: 'a', createdAt: { seconds: 100 } },
    { type: 'chat_reaction', targetType: '', targetId: '', createdAt: { seconds: 200 } },
    { type: 'chat_reply', targetType: 'chat', targetId: 'b', createdAt: { seconds: 300 } },
    { type: 'new_news', targetType: '', targetId: 'x', createdAt: { seconds: 400 } },
  ];
  const summary = summarizeTargets(rows);
  const reaction = summary.find((item) => item.type === 'chat_reaction');
  check('a lájk-értesítéseket megszámolja', reaction.total === 2);
  check('a célpont nélkülit kiszűri', reaction.withTargetId === 1 && reaction.missing.length === 1);
  check('az időrendet felismeri', reaction.oldest < reaction.newest);
  const reply = summary.find((item) => item.type === 'chat_reply');
  check('a válasz-típust is nézi', reply.total === 1 && reply.withTargetId === 1);
  const mention = summary.find((item) => item.type === 'chat_mention');
  check('a hiányzó típus nulla', mention.total === 0 && mention.missing.length === 0);
  check('üres bemenet nem törik el', summarizeTargets([]).every((item) => item.total === 0));
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
  const summary = summarizeTargets(rows);
  console.log(`chat-értesítések célpont-vizsgálata (összes bejegyzés: ${rows.length})\n`);
  for (const item of summary) {
    console.log(`${item.type}: ${item.total} db`);
    console.log(`  targetType=chat: ${item.withTargetType} / ${item.total}`);
    console.log(`  targetId megvan: ${item.withTargetId} / ${item.total}`);
    if (item.total) console.log(`  idő: ${item.oldest} .. ${item.newest}`);
    for (const missing of item.missing) {
      console.log(`  ⚠️ célpont nélkül: ${missing.at} (címzett: ${missing.recipient})`);
    }
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
