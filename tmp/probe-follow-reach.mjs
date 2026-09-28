// ÉLES, SZÁRAZ mérés: kiket érintene a „követés a kedvencek alapján" kör?
// (Nem ír semmit: csak olvassa a kedvenceket és a WordPress-listát.)
import { firestoreList, shortHash } from '../tools/lib/live-firebase.mjs';
import { followTargetsFor, followCatalogKindFor } from '../functions/favorite-follow-plan.js';

const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

const profiles = await firestoreList('community_profiles', { fields: [] });
const uids = profiles.map((doc) => doc.id ?? doc.name?.split('/').pop()).filter(Boolean);
console.log(`profilok: ${uids.length}`);

// Kedvencek profilonként (alkollekció) — típus szerint számolva.
const byTarget = new Map(); // 'artist:123' → Set(uid)
let total = 0;
for (const uid of uids) {
  let favorites = [];
  try {
    favorites = await firestoreList(`community_profiles/${uid}/favorites`);
  } catch (error) {
    console.log(`  (a kedvencek nem olvashatók: ${uid.slice(0, 6)}… — ${String(error.message).slice(0, 60)})`);
    continue;
  }
  for (const favorite of favorites) {
    const kind = String(favorite.kind ?? '').trim();
    const id = String(favorite.id ?? '').trim();
    if (!kind || !id) continue;
    total += 1;
    const key = `${kind}:${id}`;
    if (!byTarget.has(key)) byTarget.set(key, new Set());
    byTarget.get(key).add(uid);
  }
}
const artistKeys = [...byTarget.keys()].filter((key) => key.startsWith('artist:'));
const organizerKeys = [...byTarget.keys()].filter((key) => key.startsWith('organizer:'));
console.log(`kedvencek összesen: ${total} (DJ: ${artistKeys.length} célpont, szervező: ${organizerKeys.length} célpont)`);

// Élő tartalom: melyik új elem hány követőt érintene?
async function list(path) {
  const response = await fetch(`${BASE}${path}`, { headers: { Accept: 'application/json' } });
  const body = await response.json();
  return Array.isArray(body) ? body : Array.isArray(body?.items) ? body.items : [];
}

const releases = await list('/releases?per_page=5&lang=hu');
const events = await list('/events?lang=hu');
for (const [key, items] of [['release', releases], ['event', events]]) {
  console.log(`\n=== ${key} (${items.length} élő elem) ===`);
  for (const item of items.slice(0, 5)) {
    const targets = followTargetsFor(key, item);
    const recipients = new Set();
    for (const target of targets) {
      const followers = byTarget.get(`${target.kind}:${target.id}`);
      if (followers) for (const uid of followers) recipients.add(uid);
    }
    const title = String(item.title?.rendered || item.title || '').trim().slice(0, 44);
    console.log(
      `  #${item.id} ${title} → célpontok: ${targets.map((t) => `${t.kind}:${t.id}`).join(', ') || '(nincs)'}` +
        ` · érintett tag: ${recipients.size}` +
        (followCatalogKindFor(key) ? ` · katalógus: ${followCatalogKindFor(key)}` : ''),
    );
  }
}
console.log('\n(ez csak mérés: a kör a következő ÚJ tartalomnál küld bejövő értesítést)');
