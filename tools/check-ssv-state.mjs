// AdMob SSV (jutalmazott reklám) jovairas ellenorzese — ELO adat, csak olvas.
//
// MIERT KELL: a jutalmazott feloldas KIZAROLAG a szerveroldali visszaigazolasbol
// szarmazik (`admob_reward_transactions` + `label_ad_unlocks`). Ha a felhasznalo
// azt latja, hogy "a reklam lefutott, de a feloldas nem erkezett meg", akkor
// PONTOSAN ez a ket gyujtemeny mondja meg, hogy
//   (a) meg sem erkezett a visszahivas  -> az AdMob-oldali SSV beallitas a hibas,
//   (b) megérkezett, de keson            -> a kliens 20 masodperces varakozasa
//                                           keves (versenyhelyzet),
//   (c) megérkezett és jóváírt           -> a hiba a kliens oldalan van.
//
// Hasznalat:
//   node tools/check-ssv-state.mjs                 # az utolso 10 tranzakcio
//   node tools/check-ssv-state.mjs --hours 6       # csak az elmult 6 ora
//   node tools/check-ssv-state.mjs --release 12405
//   node tools/check-ssv-state.mjs --self-test     # halozat nelkul
import { accessToken, firestoreList } from './lib/live-firebase.mjs';

/** Barmilyen idobelyeg-alak szovegesitese (Firestore Timestamp vagy string). */
export function asText(value) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (value instanceof Date) return value.toISOString();
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (typeof value.seconds === 'number') return new Date(value.seconds * 1000).toISOString();
  return String(value);
}

/** A rekord idobelyege (tobbfele mezonev, mert a ket gyujtemeny mas). */
export function stampOf(doc) {
  return asText(doc?.createdAt || doc?.unlockedAt || doc?.updatedAt || '');
}

/**
 * Idobelyeg szerint csokkeno sorrend + szures.
 * @param {object[]} docs
 * @param {{hours?: number, releaseId?: number, now?: number, limit?: number}} opts
 */
export function recentRecords(docs, { hours = 0, releaseId = 0, now = Date.now(), limit = 10 } = {}) {
  let list = [...docs];
  if (releaseId) list = list.filter((d) => Number(d.releaseId) === Number(releaseId));
  if (hours > 0) {
    const cutoff = now - hours * 3600 * 1000;
    list = list.filter((d) => {
      const t = Date.parse(stampOf(d));
      return Number.isFinite(t) && t >= cutoff;
    });
  }
  list.sort((a, b) => String(stampOf(b)).localeCompare(String(stampOf(a))));
  return list.slice(0, limit);
}

function line(doc, extra = {}) {
  const uid = String(doc.uid || '');
  return [
    stampOf(doc).replace('T', ' ').slice(0, 19),
    (doc.id || doc._id || '').toString().slice(0, 34).padEnd(34),
    `uid=${uid.slice(0, 8)}…`,
    `release=${doc.releaseId ?? '-'}`,
    ...Object.entries(extra).map(([k, v]) => `${k}=${v}`),
  ].join('  ');
}

function selfTest() {
  const docs = [
    { id: 'a', releaseId: 1, uid: 'u1', createdAt: '2026-09-21T22:00:00Z' },
    { id: 'b', releaseId: 2, uid: 'u2', unlockedAt: { seconds: 1789000000 } },
    { id: 'c', releaseId: 1, uid: 'u3', createdAt: '2026-01-01T00:00:00Z' },
    { id: 'd', releaseId: 3, uid: 'u4' },
  ];
  const byRelease = recentRecords(docs, { releaseId: 1, limit: 10 });
  console.log('  onteszt 1 (release szures):', byRelease.length === 2 ? 'OK' : `HIBA (${byRelease.length})`);
  if (byRelease.length !== 2) throw new Error('a release-szures rossz');

  const sorted = recentRecords(docs, { limit: 10 });
  console.log('  onteszt 2 (csokkeno sorrend):', sorted[0].id === 'a' ? 'OK' : `HIBA (${sorted[0].id})`);
  if (sorted[0].id !== 'a') throw new Error('a sorrend rossz');

  // ⚠️ Az idobelyeg nelkuli rekord NEM kerulhet a "friss" listaba.
  const recent = recentRecords(docs, { hours: 24, now: Date.parse('2026-09-22T00:00:00Z'), limit: 10 });
  const ids = recent.map((d) => d.id);
  console.log('  onteszt 3 (nincs idobelyeg kimarad):', !ids.includes('d') ? 'OK' : 'HIBA');
  if (ids.includes('d')) throw new Error('az idobelyeg nelkuli rekord bekerult');

  const limit = recentRecords(docs, { limit: 2 });
  console.log('  onteszt 4 (darabszam korlat):', limit.length === 2 ? 'OK' : `HIBA (${limit.length})`);
  if (limit.length !== 2) throw new Error('a limit rossz');

  console.log('  ONTESZT: 4/4 OK');
}

function parseArgs(argv) {
  const args = { hours: 0, releaseId: 0, limit: 10, selfTest: false, require: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--self-test') args.selfTest = true;
    else if (a === '--require') args.require = true;
    else if (a === '--hours') args.hours = Number(argv[++i] || 0);
    else if (a === '--release') args.releaseId = Number(argv[++i] || 0);
    else if (a === '--limit') args.limit = Number(argv[++i] || 10);
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.selfTest) return selfTest();

  const token = await accessToken();
  const [tx, unlocks] = await Promise.all([
    firestoreList('admob_reward_transactions', { token, max: 2000 }),
    firestoreList('label_ad_unlocks', { token, max: 2000 }),
  ]);

  const txRecent = recentRecords(tx, args);
  const unRecent = recentRecords(unlocks, args);

  console.log(`AdMob SSV állapot${args.hours ? ` (utolsó ${args.hours} óra)` : ''}${args.releaseId ? ` · release ${args.releaseId}` : ''}`);
  console.log(`  admob_reward_transactions: ${tx.length} összesen, ebből a szűrésre ${txRecent.length}`);
  for (const d of txRecent) console.log('   ', line(d));
  console.log(`  label_ad_unlocks: ${unlocks.length} összesen, ebből a szűrésre ${unRecent.length}`);
  for (const d of unRecent) {
    console.log('   ', line(d, { variants: JSON.stringify(d.variants || {}) }));
  }

  // A lényeg egy mondatban: érkezett-e MOSTANÁBAN visszahívás?
  // ⚠️ Az alap kilépési kód 0 (a LEKÉRDEZÉS sikerült) — a „nincs visszahívás"
  // nem hiba. Aki hibaként akarja kezelni, adja meg a `--require`-ot.
  const hasRecent = txRecent.length > 0;
  console.log(
    hasRecent
      ? '  => ÉRKEZETT visszahívás a szűrt időszakban.'
      : '  => NINCS visszahívás a szűrt időszakban: az AdMob nem hívta a végpontot.',
  );
  if (!hasRecent && args.require) {
    console.log('  (--require: ez most hibás kilépési kódot ad)');
    return 1;
  }
  return 0;
}

const isMain = process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('tools/check-ssv-state.mjs');
if (isMain) {
  // ⚠️ NEM `process.exit()`: a hálózati lezárás közbeni kilépés a Node/libuv
  // „Assertion failed: !(handle->flags & UV_HANDLE_CLOSING)" hibáját váltja ki.
  main()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error('  HIBA:', error.message);
      process.exitCode = 2;
    });
}
