#!/usr/bin/env node
/**
 * DJ-adatlap **claim-ek** áttekintése — és a hibás claim levétele.
 *
 * MIÉRT KELL: a tulajdonos jelezte (2026-09-21), hogy *„egy dj beküldött egy
 * dj-t… valamiért tudtam ÉN mint admin claimelni - ami hiba"*, és hogy *„most a
 * Denoiser accomon a Sunshite State dj van claimelve - ami hiba - lekéne szedni
 * rólam"*. A claim-ek a Firestore `artist_claims` gyűjteményében vannak
 * (`doc id = artistId`), és eddig **semmilyen** eszköz nem mutatta meg őket.
 *
 * A JOGOSULTSÁGOT a `functions/artist-claim-plan.js` tiszta szabálya dönti el
 * (booking **vagy** privát e-mail egyezés, **admin-kivétel nélkül**), ezért ez az
 * eszköz ugyanazt a döntést használja — nem tud ellent mondani az appnak.
 *
 * Futtatás (a Firebase CLI bejelentkezését használja, titkot nem tárol):
 *   node tools/check-artist-claims.mjs                 # lista (csak olvas)
 *   node tools/check-artist-claims.mjs --release 12345 --confirm   # claim törlése
 *   node tools/check-artist-claims.mjs --self-test     # tiszta logika önellenőrzése
 *
 * Kilépési kód: 0 = rendben, 1 = hiba (pl. jogosulatlan claim maradt, vagy
 * önteszt-hiba).
 */
import { claimEmailsFor, isHouseEmail } from '../functions/artist-claim-plan.js';
import {
  accessToken,
  firestoreDelete,
  firestoreList,
  secret,
  shortHash,
} from './lib/live-firebase.mjs';

const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

/** Egy e-mail cím **maszkolása** (a teljes cím soha nem kerül a kimenetre). */
export function maskEmail(value) {
  const email = String(value ?? '').trim().toLowerCase();
  if (!email) return '(nincs)';
  const at = email.indexOf('@');
  if (at <= 0) return '***';
  const local = email.slice(0, at);
  const domain = email.slice(at);
  const head = local.slice(0, 1);
  return `${head}***${domain}`;
}

/**
 * Jogosult-e a claim? Ugyanaz a szabály, mint a szerveren.
 *
 * ⚠️ Itt **nem** a `artistClaimState`-et használjuk: az a „claimelhetem-e MOST"
 * kérdésre válaszol (és a saját claimet `mine`-nak jelöli, ami nem
 * jogosultság-vizsgálat). A vizsgálat tárgya a **claimben tárolt e-mail** és az
 * adatlap címkéi.
 *
 * Visszaadás: `justified` (egyezik valamelyik cím), `unjustified` (egyik sem),
 * `unknown` (az adatlap címei nem kérdezhetők le — pl. régi plugin).
 */
export function claimVerdict({ claimEmail, artist }) {
  const normalized = String(claimEmail ?? '').trim().toLowerCase();
  const emails = claimEmailsFor(artist);
  if (!normalized) return 'unknown';
  // ⚠️ A **ház domainje** (`hungarianhardstyle.hu`) nem claimelhető, de egy MÁS
  // domainen lévő `info@` a DJ privát címe lehet — ezért domainre szűrünk.
  if (isHouseEmail(normalized)) return 'unjustified';
  if (!emails.length) return 'unknown';
  return emails.includes(normalized) ? 'justified' : 'unjustified';
}

/**
 * A privát végpont válasza **státusszal együtt** (a `--ping` ehhez kérdez rá,
 * hogy kiderüljön: a végpont létezik-e egyáltalán).
 */
async function fetchClaimEmailsWithStatus(artistId, authorization) {
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/artists/${artistId}/claim-emails`, {
      headers: authorization ? { Authorization: authorization } : {},
    });
    if (!response.ok) return { ok: false, status: response.status, value: null };
    const payload = await response.json().catch(() => ({}));
    return {
      ok: true,
      status: response.status,
      value: {
        booking_email: String(payload?.booking_email || ''),
        contact_email: String(payload?.contact_email || ''),
      },
    };
  } catch (error) {
    return { ok: false, status: 0, value: null, message: String(error?.message || error) };
  }
}

/** A privát végpont válasza (plugin 2.6.0+) vagy `null`, ha még nincs fent. */
async function fetchClaimEmails(artistId, authorization) {
  const result = await fetchClaimEmailsWithStatus(artistId, authorization);
  return result.ok ? result.value : null;
}

/** Az adatlap címe a nyilvános végpontról (csak megjelenítéshez). */
async function fetchArtistTitle(artistId) {
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/artists/${artistId}`);
    if (!response.ok) return '';
    const payload = await response.json().catch(() => ({}));
    return String(payload?.title || '');
  } catch {
    return '';
  }
}

function basicAuthorization(username, password) {
  return `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
}

/** Az összes **publikált** DJ-adatlap azonosítója (a nyilvános listából, lapozva). */
async function fetchPublishedArtistIds() {
  const ids = [];
  for (let page = 1; page <= 20; page += 1) {
    const response = await fetch(`${WORDPRESS_BASE_URL}/artists?per_page=50&page=${page}`);
    if (!response.ok) break;
    const payload = await response.json().catch(() => ({}));
    const items = Array.isArray(payload?.items) ? payload.items : [];
    if (!items.length) break;
    for (const item of items) {
      const id = Number(item?.id);
      if (Number.isInteger(id) && id > 0) ids.push(id);
    }
    if (items.length < 50) break;
  }
  return ids;
}

/** Egyszerű párhuzamosság-korlátozó (a WordPress lassú, de ne terheljük túl). */
async function forEachLimited(items, limit, worker) {
  let cursor = 0;
  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      await worker(items[index]);
    }
  });
  await Promise.all(runners);
}

async function main() {
  const args = process.argv.slice(2);
  const releaseIndex = args.indexOf('--release');
  const shouldRelease = releaseIndex >= 0;
  const confirm = args.includes('--confirm');

  if (args.includes('--self-test')) {
    return selfTest();
  }

  let authorization = '';
  try {
    authorization = basicAuthorization(
      secret('WORDPRESS_USERNAME'),
      secret('WORDPRESS_APPLICATION_PASSWORD'),
    );
  } catch {
    authorization = '';
  }

  // ⚠️ A PRIVÁT VÉGPONTOK VÉDELMÉNEK ÉLŐ ellenőrzése (plugin 2.7.0).
  //
  // MIÉRT: a 2.6.0-ban a nyilvános válasz-gyorsítótár engedélylistája **előtagra**
  // illeszkedett, ezért a `/artists/<id>/claim-emails` — amely a DJ **privát**
  // e-mail címét adja vissza — cache-elhető volt, a gyorsítótár pedig a
  // hitelesítés ELŐTT is kiszolgál. Ez a mód ezt méri élőben, írás nélkül:
  //
  //   1. hitelesítés NÉLKÜL a privát végpont **nem** adhat adatot (401/403),
  //   2. az új `dj-profile` írás-végpont létezik és védett (401/403, nem 404),
  //   3. hitelesítéssel a privát végpont adata **jön** (a végpont működik),
  //   4. hitelesítéssel egy ÜRES kéréssel a `dj-profile` **elutasít** (400) —
  //      üres kérés nem ír semmit, ezért ez az adatokat nem érinti.
  if (args.includes('--probe')) {
    const artistId = Number(args[args.indexOf('--probe') + 1]) || 12812;
    const checks = [];

    const unauth = await fetch(
      `${WORDPRESS_BASE_URL}/artists/${artistId}/claim-emails`,
    ).catch(() => null);
    checks.push({
      name: 'privát claim-emails hitelesítés nélkül',
      ok: unauth !== null && (unauth.status === 401 || unauth.status === 403),
      detail: unauth === null ? 'hálózati hiba' : `status=${unauth.status}`,
      hint: 'ha 200: a privát cím kiszolgálható — a gyorsítótár-javítás nem él',
    });

    const edit = await fetch(`${WORDPRESS_BASE_URL}/dj-profile/${artistId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}',
    }).catch(() => null);
    checks.push({
      name: 'új dj-profile végpont hitelesítés nélkül',
      ok: edit !== null && (edit.status === 401 || edit.status === 403),
      detail: edit === null ? 'hálózati hiba' : `status=${edit.status}`,
      hint: '404 = a végpont nincs fent (plugin 2.7.0 hiányzik)',
    });

    if (authorization) {
      const authed = await fetchClaimEmailsWithStatus(artistId, authorization);
      checks.push({
        name: 'privát claim-emails hitelesítéssel',
        ok: authed.ok,
        detail: `status=${authed.status}`,
        hint: 'a végpontnak a szerver (admin-alkalmazásjelszó) hívására adnia kell adatot',
      });
      const emptyEdit = await fetch(
        `${WORDPRESS_BASE_URL}/dj-profile/${artistId}`,
        {
          method: 'POST',
          headers: {
            Authorization: authorization,
            'Content-Type': 'application/json',
          },
          body: '{}',
        },
      ).catch(() => null);
      checks.push({
        name: 'dj-profile üres kéréssel (nem ír semmit)',
        ok: emptyEdit !== null && emptyEdit.status === 400,
        detail: emptyEdit === null ? 'hálózati hiba' : `status=${emptyEdit.status}`,
        hint: '400 = „Nem érkezett menthető mező" — üres kérés nem módosít adatot',
      });
    } else {
      console.log('FIGYELEM  a WordPress titkok nem olvashatók — a hitelesített ellenőrzések kimaradnak.');
    }

    // A nyilvános út viszont TOVÁBBRA IS cache-elhető: a kizárás csak a privát
    // al-útvonalakra vonatkozik, ezért a gyorsítótár jelzőjének meg kell lennie.
    const publicRoute = await fetch(`${WORDPRESS_BASE_URL}/artists/${artistId}`).catch(
      () => null,
    );
    const cacheMarker = publicRoute?.headers?.get('x-huhs-cache') || '';
    checks.push({
      name: 'nyilvános /artists/<id> továbbra is gyorsítótárazott',
      ok: publicRoute !== null && publicRoute.status === 200 && cacheMarker !== '',
      detail:
        publicRoute === null
          ? 'hálózati hiba'
          : `status=${publicRoute.status}  X-HUHS-Cache=${cacheMarker || '(nincs)'}`,
      hint: 'ha nincs jelző: a kizárás túl széles lett, a nyilvános cache elesett',
    });

    console.log(`Privát végpontok vizsgálata (artist=${artistId}):`);
    console.log('');
    let failed = 0;
    for (const check of checks) {
      if (!check.ok) failed += 1;
      console.log(
        `${check.ok ? 'OK   ' : 'HIBA '} ${check.name} — ${check.detail}${check.ok ? '' : `  (${check.hint})`}`,
      );
    }
    console.log('');
    console.log(
      failed === 0
        ? 'MINDEN ELLENŐRZÉS RENDBEN'
        : `${failed} ellenőrzés bukott — nézd meg a fentieket.`,
    );
    return failed === 0 ? 0 : 1;
  }

  // A privát végpont él-e? (A plugin 2.6.0 hozza; a claim ehhez kell.)
  const pingIndex = args.indexOf('--ping');
  if (pingIndex >= 0) {
    const artistId = Number(args[pingIndex + 1]);
    if (!Number.isInteger(artistId) || artistId <= 0) {
      console.error('HIBA  a --ping után egy DJ-adatlap azonosító kell (pl. --ping 12812)');
      return 1;
    }
    if (!authorization) {
      console.error('HIBA  a WordPress titkok nem olvashatók a Secret Managerből.');
      return 1;
    }
    const emails = await fetchClaimEmailsWithStatus(artistId, authorization);
    if (!emails.ok) {
      console.log(`A privát végpont NEM érhető el (status=${emails.status}) — a plugin 2.6.0 még nincs fent?`);
      return 1;
    }
    console.log(
      `artist=${artistId}  booking=${maskEmail(emails.value?.booking_email)}  privát=${maskEmail(emails.value?.contact_email)}`,
    );
    return 0;
  }

  // Melyik adatlapon van egyáltalán claimhez használható cím? (csak olvas)
  if (args.includes('--scan-emails')) {
    if (!authorization) {
      console.error('HIBA  a WordPress titkok nem olvashatók a Secret Managerből.');
      return 1;
    }
    const ids = await fetchPublishedArtistIds();
    const withEmail = [];
    const withoutEmail = [];
    await forEachLimited(ids, 6, async (id) => {
      const emails = await fetchClaimEmails(id, authorization);
      if (emails && (emails.booking_email || emails.contact_email)) {
        withEmail.push({ id, ...emails });
      } else {
        withoutEmail.push(id);
      }
    });
    console.log(`${ids.length} publikált DJ-adatlap vizsgálva.`);
    console.log('');
    for (const row of withEmail.sort((a, b) => a.id - b.id)) {
      const title = await fetchArtistTitle(row.id);
      console.log(
        `CÍM VAN  artist=${row.id}${title ? ` „${title}"` : ''}  booking=${maskEmail(row.booking_email)}  privát=${maskEmail(row.contact_email)}`,
      );
    }
    if (withoutEmail.length) {
      console.log('');
      for (const id of withoutEmail.sort((a, b) => a - b)) {
        const title = await fetchArtistTitle(id);
        console.log(
          `⚠️ NINCS CÍM  artist=${id}${title ? ` „${title}"` : ''} — ezt az adatlapot a DJ **nem tudja** claimelni (a booking vagy privát e-mail hiányzik a WordPressben)`,
        );
      }
    }
    console.log('');
    console.log(
      `Összegzés: ${withEmail.length} adatlapon van cím, ${withoutEmail.length} adatlapon NINCS (azok nem claimelhetők).`,
    );
    return withoutEmail.length ? 1 : 0;
  }

  // A **privát címek pótlása** a korábban jóváhagyott adatlapokra (idempotens).
  if (args.includes('--backfill')) {
    if (!authorization) {
      console.error('HIBA  a WordPress titkok nem olvashatók a Secret Managerből.');
      return 1;
    }
    if (!confirm) {
      console.log('Csak jelzés: a pótláshoz add meg a --confirm kapcsolót is.');
      return 1;
    }
    const response = await fetch(`${WORDPRESS_BASE_URL}/artists/claim-emails/backfill`, {
      method: 'POST',
      headers: { Authorization: authorization },
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error(`HIBA  a pótlás nem sikerült (status=${response.status}).`);
      return 1;
    }
    console.log(
      `KÉSZ: pótolva ${Number(payload?.updated ?? 0)} adatlap, kihagyva ${Number(payload?.skipped ?? 0)} (ahol már volt cím, vagy nem DJ-adatlap).`,
    );
    return 0;
  }

  const claims = await firestoreList('artist_claims', {
    fields: ['artistId', 'uid', 'email', 'status'],
  });

  if (shouldRelease) {
    const artistId = Number(args[releaseIndex + 1]);
    if (!Number.isInteger(artistId) || artistId <= 0) {
      console.error('HIBA  a --release után egy DJ-adatlap azonosító kell (pl. --release 12345)');
      return 1;
    }
    const claim = claims.find((row) => Number(row.artistId) === artistId) || null;
    if (!claim) {
      console.log(`Nincs claim a(z) ${artistId} adatlapon — nincs mit tenni.`);
      return 0;
    }
    const title = await fetchArtistTitle(artistId);
    console.log(
      `TÖRLÉS: artist=${artistId}${title ? ` (${title})` : ''} claim=${maskEmail(claim.email)} uid=${shortHash(String(claim.uid || ''))}`,
    );
    if (!confirm) {
      console.log('Csak jelzés: a törléshez add meg a --confirm kapcsolót is.');
      return 1;
    }
    await firestoreDelete(`artist_claims/${artistId}`);
    console.log(`KÉSZ: a(z) ${artistId} adatlap claimje törölve.`);
    return 0;
  }

  console.log(`artist_claims: ${claims.length} bejegyzés`);
  console.log('');
  let unjustified = 0;
  let unknown = 0;
  for (const claim of claims) {
    const artistId = Number(claim.artistId);
    const title = await fetchArtistTitle(artistId);
    const emails = await fetchClaimEmails(artistId, authorization);
    const verdict = claimVerdict({
      claimEmail: claim.email,
      emailVerified: true,
      artist: emails,
      claim: { uid: claim.uid },
      uid: claim.uid,
    });
    if (verdict === 'unjustified') unjustified += 1;
    if (verdict === 'unknown') unknown += 1;
    const mark = verdict === 'unjustified' ? '⚠️ JOGOSULATLAN' : verdict === 'unknown' ? '? nem eldönthető' : 'OK';
    console.log(
      `${mark}  artist=${artistId}${title ? ` „${title}"` : ''}  claim=${maskEmail(claim.email)}  uid=${shortHash(String(claim.uid || ''))}`,
    );
    if (verdict === 'unjustified') {
      console.log(
        `         az adatlap címkéi: booking=${maskEmail(emails?.booking_email)} privát=${maskEmail(emails?.contact_email)}`,
      );
    }
    if (verdict === 'unknown' && !emails) {
      console.log('         (a privát végpont még nem érhető el — plugin 2.6.0 kell hozzá)');
    }
  }
  console.log('');
  console.log(
    `Összegzés: ${claims.length} claim, ebből ${unjustified} jogosulatlan, ${unknown} nem eldönthető.`,
  );
  return unjustified > 0 ? 1 : 0;
}

/** A tiszta logika önellenőrzése (hálózat és Firestore nélkül). */
function selfTest() {
  const cases = [];
  const check = (label, actual, expected) => {
    const ok = actual === expected;
    cases.push(`${ok ? 'OK  ' : 'HIBA'}  ${label}${ok ? '' : ` — várt: ${expected}, kapott: ${actual}`}`);
    return ok;
  };

  check('maszkolás: gmail', maskEmail('djdeeroy@gmail.com'), 'd***@gmail.com');
  check('maszkolás: üres', maskEmail(''), '(nincs)');
  check('maszkolás: hibás cím', maskEmail('nincs-kukac'), '***');
  check('maszkolás: kisbetűsít', maskEmail('  DJ@Example.HU '), 'd***@example.hu');

  const artist = { booking_email: 'booking@sunshite.hu', contact_email: 'sunshite@gmail.com' };
  check(
    'jogosult: booking egyezik',
    claimVerdict({ claimEmail: 'booking@sunshite.hu', artist }),
    'justified',
  );
  check(
    'jogosult: privát egyezik',
    claimVerdict({ claimEmail: 'SUNSHITE@gmail.com', artist }),
    'justified',
  );
  check(
    'jogosult: `info@` MÁS domainen (a DJ privát címe lehet)',
    claimVerdict({
      claimEmail: 'info@sajatdomain.hu',
      artist: { booking_email: '', contact_email: 'info@sajatdomain.hu' },
    }),
    'justified',
  );
  check(
    '⚠️ jogosulatlan: a ház DOMAINJÉRE eső cím (booking@…)',
    claimVerdict({ claimEmail: 'booking@hungarianhardstyle.hu', artist }),
    'unjustified',
  );
  check('a ház domainje felismerése', isHouseEmail('info@hungarianhardstyle.hu'), true);
  check('más domain nem ház', isHouseEmail('info@sajatdomain.hu'), false);
  check(
    '⚠️ jogosulatlan: az admin címe idegen adatlapon',
    claimVerdict({ claimEmail: 'djdeeroy@gmail.com', artist }),
    'unjustified',
  );
  check(
    'nem eldönthető: nincs cím az adatlapon',
    claimVerdict({
      claimEmail: 'x@gmail.com',
      artist: { booking_email: '', contact_email: '' },
    }),
    'unknown',
  );
  check(
    'nem eldönthető: nincs adat',
    claimVerdict({ claimEmail: 'x@gmail.com', artist: null }),
    'unknown',
  );

  console.log(cases.join('\n'));
  const failed = cases.filter((line) => line.startsWith('HIBA')).length;
  console.log('');
  console.log(`${cases.length - failed}/${cases.length} ellenőrzés rendben${failed ? ` — ${failed} HIBA` : ''}`);
  return failed ? 1 : 0;
}

main()
  .then((code) => process.exit(code))
  .catch((error) => {
    console.error('HIBA', error?.message || error);
    process.exit(1);
  });
