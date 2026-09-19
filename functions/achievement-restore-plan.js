/**
 * Az ELVESZETT achievement-pontok visszaállítási TERVE — tiszta logika.
 *
 * MIÉRT külön fájl: ugyanezt a tervet két helyről kell kiszámolni, és nem
 * szabad, hogy kettő közül az egyik elavuljon:
 *  * a Cloud Function (`functions/index.js` → `runAchievementRestoreJob`)
 *    ebből dolgozik, amikor a karbantartó munkát jóváhagyják;
 *  * a karbantartó eszköz (`tools/restore-lost-achievement-points.mjs`)
 *    ebből készít **előnézetet**, mielőtt bármi történne.
 * Ez a fájl ezért **nulla függőségű** (se Firebase, se hálózat), így
 * önmagában, emulátor nélkül is tesztelhető.
 *
 * A HÁTTÉR: a 2026-09-19 előtti kód a hír-lájk visszavonásakor **levonta** a
 * pontot, a `grant`/`revoke` párosból álló ledger-kulcs miatt pedig az újralájk
 * már nem adott újat — a felhasználó így **véglegesen mínuszba** került
 * ugyanazzal a cikkel (élő mérés: 19 ilyen eset, 40 pont). A mechanizmus azóta
 * javított (a visszavonás nem vesz el pontot); a tulajdonos döntése szerint a
 * **már elveszett pontokat vissza kell állítani** — a szabályok megtartásával.
 *
 * A TERV SZABÁLYAI:
 *  1. `news-like:<postId>` — a naplóban szereplő **negatív sorok abszolút
 *     összegét** állítjuk vissza (jellemzően 2 pont). Pontosan annyit, amennyit
 *     elvettek: **sosem többet**, mert ami sosem járt, azt visszaadni sem szabad.
 *  2. `profile-complete` — a saját hibám (`796c0f52` előtt a ledger-kulcs
 *     átállása miatt az **egyszeri** jutalmat másodszor is kifizette). Egynél
 *     több jóváírás bizonyítottan hiba, ezért a felesleget külön
 *     `correction:` sorral vonjuk le — a jóváírás eredeti naplója megmarad.
 *  3. **Szándékosan kimarad** az esemény/meetup oda-vissza váltogatás: ott a
 *     grant/revoke **valódi életciklus** (jelentkezés → lemondás), tehát a
 *     negatív sor nem hiba, és nem állítjuk vissza.
 *
 * @param {Array<{uid?: string, sourceKey?: string, delta?: number, state?: string}>} ledgerRows
 *   A valódi `achievement_ledger` sorai (mindkét korszak: a régi `grant`/`revoke`
 *   páros és az új `state`-alapú sor is).
 * @returns {{restores: Array<{uid: string, sourceKey: string, delta: number}>,
 *            corrections: Array<{uid: string, sourceKey: string, delta: number}>}}
 */
function buildAchievementRestorePlan(ledgerRows) {
  const rows = (Array.isArray(ledgerRows) ? ledgerRows : []).filter(Boolean);
  // Ami MÁR vissza van állítva, azt nem tervezzük újra. Ez nem csak kényelmes:
  // így az ELŐNÉZET is igazat mond a végrehajtás után (üres terv), és a
  // függvény sem dolgozik feleslegesen. A védelem második rétege továbbra is a
  // ledger (`awardAchievementPoints` állapotváltás nélkül nem ad pontot).
  const alreadyRestored = new Set();
  const alreadyCorrected = new Set();
  for (const row of rows) {
    const sourceKey = String(row?.sourceKey || '').trim();
    const uid = String(row?.uid || '').trim();
    if (!uid) continue;
    if (sourceKey.startsWith('news-like-restore:')) {
      if ('state' in row && String(row.state) !== 'granted') continue;
      alreadyRestored.add(`${uid}\u0000${sourceKey.slice('news-like-restore:'.length)}`);
      continue;
    }
    // A korrekció EGYSZER futhat: ha már van levont korrekciós sor, kész.
    if (sourceKey === 'correction:profile-complete-duplicate') {
      const applied = 'state' in row ? String(row.state) === 'revoked' : Number(row?.delta || 0) < 0;
      if (applied) alreadyCorrected.add(uid);
    }
  }
  const groups = new Map();
  for (const row of rows) {
    const uid = String(row?.uid || '').trim();
    const sourceKey = String(row?.sourceKey || '').trim();
    if (!uid || !sourceKey) continue;
    // A `\u0000` nem fordulhat elő valódi forráskulcsban, ezért biztonságos
    // összetett kulcs (a `:` igen, hiszen a sourceKey maga is tartalmaz kettőst).
    const key = `${uid}\u0000${sourceKey}`;
    if (!groups.has(key)) groups.set(key, { uid, sourceKey, rows: [] });
    groups.get(key).rows.push(row);
  }
  const restores = [];
  const corrections = [];
  for (const { uid, sourceKey, rows: groupRows } of groups.values()) {
    if (sourceKey.startsWith('news-like:')) {
      const postId = sourceKey.slice('news-like:'.length);
      if (alreadyRestored.has(`${uid}\u0000${postId}`)) continue;
      const removed = groupRows
        .map((row) => Number(row?.delta || 0))
        .filter((delta) => delta < 0)
        .reduce((sum, delta) => sum + Math.abs(delta), 0);
      if (removed > 0) {
        restores.push({
          uid,
          // KÜLÖN forrás: így a ledger megmutatja, hogy ez visszaállítás, és a
          // napi plafon sem fogy tőle (`news-like-restore:` nem `news-like:`).
          sourceKey: `news-like-restore:${postId}`,
          delta: removed,
        });
      }
      continue;
    }
    if (sourceKey === 'profile-complete') {
      if (alreadyCorrected.has(uid)) continue;
      const granted = groupRows.filter((row) =>
        'state' in row ? String(row.state) === 'granted' : Number(row?.delta || 0) > 0,
      );
      if (granted.length > 1) {
        const unit = Math.abs(Number(granted[0]?.delta || 0));
        corrections.push({
          uid,
          sourceKey: 'correction:profile-complete-duplicate',
          delta: -((granted.length - 1) * unit),
        });
      }
    }
  }
  return { restores, corrections };
}

module.exports = { buildAchievementRestorePlan };
