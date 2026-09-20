#!/usr/bin/env node
/**
 * ÉLES (csak olvas): mit fog mutatni a „Saját zenéim" könyvtár?
 *
 * MIÉRT: a tulajdonos kérése, hogy *„az eddig megvásárolt, letöltött zenéket is
 * tegye be oda, ugye a régebbi verziókban volt aki vásárolt, vagy feloldott
 * zenét"*. A vásárlások a `label_entitlements`, a reklámmal feloldottak a
 * `label_ad_unlocks` gyűjteményben **évek óta** ott vannak — de soha nem
 * kérdezte le senki, ezért nem tudjuk, hogy a régi bejegyzések mind
 * **értelmezhetők-e**. Ez az eszköz ezt méri.
 *
 * A DÖNTÉS UGYANAZ, MINT AZ APPÉ: a `functions/label-library-plan.js` tiszta
 * modult használja, ezért az eszköz és az app **nem mondhat ellent** egymásnak.
 *
 * Titkot nem használ és nem ír: a Firebase CLI bejelentkezését használja, és
 * **UID-et nem ír ki** (rövidített lenyomatot mutat).
 *
 * Futtatás:
 *   node tools/check-label-library.mjs
 *   node tools/check-label-library.mjs --self-test
 * Kilépési kód: 0 = minden régi bejegyzés bekerül a könyvtárba, 1 = van olyan,
 * amelyik kimaradna (vagy önteszt-hiba).
 */
import {
  labelLibraryPayload,
  parseLabelProductId,
  adUnlockedVariants,
} from '../functions/label-library-plan.js';
import { firestoreList, shortHash, createChecker } from './lib/live-firebase.mjs';

/** Entitlement-rekordok osztályozása: mi kerül be és mi marad ki (tiszta). */
export function classifyEntitlements(rows) {
  const accepted = [];
  const dropped = [];
  for (const row of rows) {
    const parsed = parseLabelProductId(row?.productId);
    if (!parsed) {
      dropped.push({ id: shortHash(String(row?.id || row?.productId || '?')), reason: 'ismeretlen termék-azonosító', productId: String(row?.productId || '') });
      continue;
    }
    if (Number(row.releaseId) !== parsed.releaseId) {
      dropped.push({ id: shortHash(String(row?.id || '?')), reason: 'eltérő releaseId', productId: String(row?.productId || '') });
      continue;
    }
    accepted.push({ ...row, releaseId: parsed.releaseId, variant: parsed.variant });
  }
  return { accepted, dropped };
}

/** Reklám-feloldások: melyik dokumentum hoz egyáltalán lejátszható változatot. */
export function classifyUnlocks(rows) {
  const accepted = [];
  const empty = [];
  for (const row of rows) {
    const releaseId = Number(row?.releaseId);
    if (!Number.isInteger(releaseId) || releaseId < 1) {
      empty.push({ id: shortHash(String(row?.id || '?')), reason: 'nincs érvényes kiadvány' });
      continue;
    }
    const variants = adUnlockedVariants(row, releaseId);
    if (!variants.length) {
      empty.push({
        id: shortHash(String(row?.id || '?')),
        reason: 'nincs lejátszható változat (pl. csak free_link)',
      });
      continue;
    }
    // ⚠️ A rekordot **változatlanul** adjuk tovább: a `variants` mezőt NEM írjuk
    // felül a kiszámolt listával, mert a `labelLibraryPayload` ugyanebből a
    // mezőből dolgozik (egy `variants: [...]` tömb esetén nem találná a
    // `variants.<változat> === true` jelölést, és a tétel **némán eltűnne** —
    // élesben pontosan ez történt meg a csak-reklámos fiókoknál).
    accepted.push({ ...row, releaseId, unlockedVariants: variants });
  }
  return { accepted, empty };
}

/** Összegzés: ki mennyi zenét látna, és összesen hány kiadvány érintett. */
export function summarizeLibrary({ entitlements, unlocks }) {
  const byUid = new Map();
  for (const row of entitlements) {
    const uid = String(row.uid || '');
    if (!uid) continue;
    if (!byUid.has(uid)) byUid.set(uid, { entitlements: [], unlocks: [] });
    byUid.get(uid).entitlements.push(row);
  }
  for (const row of unlocks) {
    const uid = String(row.uid || '');
    if (!uid) continue;
    if (!byUid.has(uid)) byUid.set(uid, { entitlements: [], unlocks: [] });
    byUid.get(uid).unlocks.push(row);
  }
  const users = [];
  const releases = new Set();
  const variants = new Map();
  for (const [uid, data] of byUid) {
    const payload = labelLibraryPayload(data.entitlements, data.unlocks);
    if (!payload.count) continue;
    for (const item of payload.items) {
      releases.add(item.releaseId);
      for (const variant of item.variants) {
        variants.set(variant, (variants.get(variant) || 0) + 1);
      }
    }
    users.push({
      uid,
      releases: payload.count,
      items: payload.items.reduce((sum, item) => sum + item.variants.length, 0),
      purchasedOnly: payload.items.every((item) => item.purchased.length > 0),
    });
  }
  users.sort((a, b) => b.items - a.items);
  return {
    users: users.length,
    releases: releases.size,
    variants: [...variants.entries()].sort((a, b) => b[1] - a[1]),
    top: users.slice(0, 5).map((user) => ({ uid: shortHash(user.uid), releases: user.releases, items: user.items })),
  };
}

export function selfTest() {
  const checker = createChecker();
  const legacyEntitlement = {
    uid: 'u1',
    releaseId: 12699,
    productId: 'huhs_release_12699_radio_wav',
  };
  const brokenEntitlement = { uid: 'u1', releaseId: 12699, productId: 'huhs_release_12699' };
  const { accepted, dropped } = classifyEntitlements([legacyEntitlement, brokenEntitlement]);
  checker.check('a jó termék-azonosítójú vásárlás bekerül', accepted.length === 1);
  checker.check('a hibás azonosítójú kimarad (és számoljuk)', dropped.length === 1 && dropped[0].reason.includes('termék'));

  const legacyUnlock = { uid: 'u1', releaseId: 12699 };
  const { accepted: unlocksOk, empty } = classifyUnlocks([
    legacyUnlock,
    { uid: 'u1', releaseId: 0 },
    { uid: 'u1', releaseId: 12699, variants: { free_link: true } },
  ]);
  checker.check('a régi (változat nélküli) feloldás mp3_128-ként bekerül', unlocksOk.length === 1 && unlocksOk[0].unlockedVariants[0] === 'mp3_128');
  checker.check('a kiadvány nélküli feloldás kimarad', empty.some((row) => row.reason.includes('kiadvány')));
  checker.check('a csak free_link feloldás nem hoz lejátszható tételt', empty.some((row) => row.reason.includes('free_link')));

  const summary = summarizeLibrary({
    entitlements: [
      { uid: 'u1', releaseId: 100, productId: 'huhs_release_100_wav' },
      { uid: 'u2', releaseId: 200, productId: 'huhs_release_200_radio_wav' },
    ],
    unlocks: [{ uid: 'u1', releaseId: 100 }],
  });
  checker.check('két felhasználónak lesz könyvtára', summary.users === 2);
  checker.check('a kiadványok száma helyes', summary.releases === 2);
  checker.check('a változatok összesítve vannak', summary.variants.some(([variant, count]) => variant === 'wav' && count === 1));

  // ⚠️ CSAPDA, amit éles mérés fogott meg: a csak-reklámos fiók kimaradt, mert a
  // feldolgozás felülírta a `variants` mezőt, és a payload már nem találta a
  // `variants.<változat> === true` jelölést. Ez a teszt ezt őrzi.
  const unlockOnly = summarizeLibrary({
    entitlements: [],
    unlocks: classifyUnlocks([
      { uid: 'u9', releaseId: 12699, variants: { mp3_96: true } },
      { uid: 'u9', releaseId: 12699, variants: { mp3_128: true } },
    ]).accepted,
  });
  checker.check(
    'a CSAK reklámmal feloldott fióknak is lesz könyvtára',
    unlockOnly.users === 1 && unlockOnly.releases === 1,
    `users=${unlockOnly.users}, releases=${unlockOnly.releases}`,
  );
  checker.check(
    'a csak-reklámos fiók mindkét feloldott változatát látja',
    unlockOnly.variants.some(([variant, count]) => variant === 'mp3_96' && count === 1) &&
      unlockOnly.variants.some(([variant, count]) => variant === 'mp3_128' && count === 1),
    JSON.stringify(unlockOnly.variants),
  );
  checker.check('az u1-nek vásárlása is van (nem csak reklám)', summary.top.every((user) => user.items >= 1));
  return checker;
}

async function main() {
  if (process.argv.includes('--self-test')) {
    const checker = selfTest();
    return checker.report();
  }
  const checker = createChecker();
  const token = undefined;
  const [rawEntitlements, rawUnlocks] = await Promise.all([
    firestoreList('label_entitlements', { token, max: 5000 }),
    firestoreList('label_ad_unlocks', { token, max: 5000 }),
  ]);

  const entitlements = classifyEntitlements(rawEntitlements);
  const unlocks = classifyUnlocks(rawUnlocks);
  const summary = summarizeLibrary({
    entitlements: entitlements.accepted,
    unlocks: unlocks.accepted,
  });

  console.log(`Megvásárolt tételek (label_entitlements): ${rawEntitlements.length}`);
  console.log(`  értelmezhető:            ${entitlements.accepted.length}`);
  console.log(`  KIMARADNA a könyvtárból: ${entitlements.dropped.length}`);
  for (const row of entitlements.dropped.slice(0, 10)) {
    console.log(`    - ${row.id} (${row.reason}): ${row.productId}`);
  }
  console.log(`Reklámmal feloldott (label_ad_unlocks): ${rawUnlocks.length}`);
  console.log(`  lejátszható változatot ad: ${unlocks.accepted.length}`);
  console.log(`  nem ad lejátszható tételt: ${unlocks.empty.length}`);
  console.log('');
  console.log(`A könyvtár így nézne ki: ${summary.users} fióknak van zenéje, ${summary.releases} kiadvány érintett.`);
  console.log(`Változatok összesen: ${summary.variants.map(([v, c]) => `${v} ${c}`).join(', ') || '(nincs)'}`);
  console.log('A legnagyobb könyvtárak (UID-lenyomat):');
  for (const user of summary.top) {
    console.log(`  ${user.uid}: ${user.releases} kiadvány, ${user.items} tétel`);
  }

  checker.check(
    'MINDEN megvásárolt tétel bekerül a könyvtárba (nincs kimaradó régi bejegyzés)',
    entitlements.dropped.length === 0,
    entitlements.dropped.length ? `${entitlements.dropped.length} kimaradna` : '',
  );
  return checker.report();
}

const invokedDirectly = process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('tools/check-label-library.mjs');
if (invokedDirectly) {
  main()
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error(`HIBA  ${error?.message || error}`);
      process.exit(1);
    });
}
