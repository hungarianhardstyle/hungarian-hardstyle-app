#!/usr/bin/env node
/**
 * HASZNÁLAT-MÉRŐ — mennyien használják ténylegesen az appot? (2026-09-29)
 *
 * MIÉRT: a döntéseink eddig a **push-eszközök számából** indultak (1022), de az
 * nem használat. Ez az eszköz a **Firestore-ban MÁR meglevő jeleket** olvassa —
 * vagyis azt, amit az app maga ír: profilok, kedvelések, jelenlét, értesítések.
 *
 * ⚠️ MÉRT KORLÁT (nem tipp): a **GA4 (analitika) API** a meglévő CLI-tokennel
 * **HTTP 403 — insufficient authentication scopes**. Az analitika kiolvasásához
 * külön szolgáltatói fiók kell `analytics.readonly` joggal (a tulajdonos oldala).
 * Addig ez az eszköz a Firestore-jelekre támaszkodik — azok viszont valódi,
 * felhasználói cselekvésekből származnak.
 *
 * Futtatás:
 *   node tools/check-usage.mjs               # összegzés
 *   node tools/check-usage.mjs --self-test   # önteszt (hálózat nélkül)
 */
import { accessToken, DATABASE, PROJECT } from './lib/live-firebase.mjs';

const ARG = process.argv.slice(2);

/** A „hány százaléka ez a másiknak" — 0-val osztás nélkül. */
export function share(part, whole) {
  if (!Number.isFinite(part) || !Number.isFinite(whole) || whole <= 0) return 0;
  return Math.round((part / whole) * 1000) / 10;
}

/** A `runQuery` sorai → dokumentumok. */
export function documentsOf(rows) {
  if (!Array.isArray(rows)) return [];
  // ⚠️ A `runQuery` adhat `readTime`-os vagy üres sort is — a hiányzó dokumentum
  // nem hiba. (Ezt az önteszt fogta meg: a `null` sor elszállította a láncot.)
  return rows.map((row) => row?.document).filter(Boolean);
}

/** Érték kiolvasása egy Firestore-mezőből (mindegy, milyen típus). */
export function valueOf(field) {
  if (!field || typeof field !== 'object') return null;
  return (
    field.stringValue ??
    field.integerValue ??
    field.booleanValue ??
    field.timestampValue ??
    field.doubleValue ??
    null
  );
}

/** Összegzés szövege — a lényeg egy képernyőn. */
export function summaryLines({ devices, profiles, favorites, notices, unread }) {
  // ⚠️ Ha az eszközszám nem ismert, a százalék **kimarad** — nem írunk 0%-ot,
  // mert az félrevezetne (az önteszt méri mindkét ágat).
  const profilesLine =
    devices > 0
      ? `közösségi profil:          ${profiles}  (${share(profiles, devices)}% az eszközöknek)`
      : `közösségi profil:          ${profiles}`;
  return [
    `push-eszköz (plugin):      ${devices}`,
    profilesLine,
    `kedvelés (DJ/szervező):    ${favorites}`,
    `értesítés összesen:        ${notices}  (olvasatlan: ${unread})`,
  ];
}

async function count(path, token) {
  let total = 0;
  let pageToken = '';
  do {
    const url =
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents/${path}` +
      `?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    const body = await response.json();
    if (!response.ok) throw new Error(`${response.status} — ${body?.error?.message || ''}`);
    total += (body.documents || []).length;
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return total;
}

async function query(collectionId, allDescendants, token) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId, ...(allDescendants ? { allDescendants: true } : {}) }],
          limit: 1000,
        },
      }),
    },
  );
  const rows = await response.json();
  if (!Array.isArray(rows)) throw new Error(rows?.error?.message || 'ismeretlen válasz');
  return documentsOf(rows);
}

function selfTest() {
  const checks = [];
  const check = (label, ok) => checks.push({ label, ok: Boolean(ok) });
  check('a százalék kerekítve', share(46, 1022) === 4.5);
  check('nullával osztás nem dob', share(5, 0) === 0);
  check('a dokumentumok kiszűrése', documentsOf([{ document: { name: 'a' } }, {}, null]).length === 1);
  check('a mező-érték minden típust kezel', valueOf({ integerValue: '12' }) === '12' && valueOf({}) === null);
  const lines = summaryLines({ devices: 1022, profiles: 46, favorites: 89, notices: 1000, unread: 531 });
  check('az összegzés a lényeget mondja', lines.length === 4 && lines[1].includes('4.5%'));
  const noDevices = summaryLines({ devices: 0, profiles: 46, favorites: 89, notices: 10, unread: 3 });
  check('ismeretlen eszközszámnál nincs félrevezető százalék', !noDevices[1].includes('%'));
  for (const item of checks) console.log(`${item.ok ? 'OK  ' : 'HIBA'} ${item.label}`);
  const failed = checks.filter((item) => !item.ok).length;
  console.log(`\n${checks.length - failed}/${checks.length} önteszt rendben`);
  return failed ? 1 : 0;
}

if (ARG.includes('--self-test')) {
  process.exitCode = selfTest();
} else {
  const token = await accessToken();
  const profiles = await count('community_profiles', token);
  const favorites = (await query('favorites', true, token)).length;
  const notices = await query('notifications', false, token);
  const unread = notices.filter((doc) => !valueOf(doc.fields?.readAt)).length;

  // Az eszközszám a pluginból jön (ott él a token-tár) — a health fejlécből.
  // ⚠️ A fejléc néha nem jön le az első kérésre (mért viselkedés), ezért próbáljuk
  // többször; ha így sem, akkor **kimarad** a sor, nem írunk félrevezető 0%-ot.
  let devices = 0;
  for (let attempt = 1; attempt <= 3 && devices === 0; attempt += 1) {
    try {
      const response = await fetch(
        `https://hungarianhardstyle.hu/wp-json/huhs/v1/posts?per_page=1&probe=usage-${attempt}`,
        { headers: { Accept: 'application/json' } },
      );
      const header = response.headers.get('x-huhs-health') || '';
      devices = Number(/push_tokens=(\d+)/.exec(header)?.[1] ?? 0);
    } catch (_) {
      devices = 0;
    }
    if (devices === 0) await new Promise((resolve) => setTimeout(resolve, 1200));
  }

  console.log('HASZNÁLAT (Firestore-jelek, mért)\n');
  const lines = summaryLines({
    devices,
    profiles,
    favorites,
    notices: notices.length,
    unread,
  });
  console.log(devices > 0 ? lines.join('\n') : lines.slice(1).join('\n'));
  if (devices === 0) {
    console.log('  (a plugin health fejléc most nem jött le — az eszközszám kimarad)');
  }

  const byType = new Map();
  for (const doc of notices) {
    const type = String(valueOf(doc.fields?.type) ?? '(nincs)');
    byType.set(type, (byType.get(type) ?? 0) + 1);
  }
  console.log('\nértesítések típus szerint:');
  for (const [type, count2] of [...byType].sort((a, b) => b[1] - a[1]).slice(0, 10)) {
    console.log(`  ${type}: ${count2}`);
  }
  console.log(
    '\n⚠️ Az analitika (GA4) kiolvasása külön jogosultságot kér (most 403) — addig ez a\n' +
      '   Firestore-alapú mérés a valódi használat képe: a profil, a kedvelés és az\n' +
      '   értesítés-olvasás mind a felhasználó cselekvése.',
  );
}
