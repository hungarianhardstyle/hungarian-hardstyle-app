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
import { claimEmailsFor, HOUSE_EMAIL } from '../functions/artist-claim-plan.js';
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
  if (normalized === HOUSE_EMAIL) return 'unjustified';
  if (!emails.length) return 'unknown';
  return emails.includes(normalized) ? 'justified' : 'unjustified';
}

/** A privát végpont válasza (plugin 2.6.0+) vagy `null`, ha még nincs fent. */
async function fetchClaimEmails(artistId, authorization) {
  try {
    const response = await fetch(`${WORDPRESS_BASE_URL}/artists/${artistId}/claim-emails`, {
      headers: authorization ? { Authorization: authorization } : {},
    });
    if (!response.ok) return null;
    const payload = await response.json().catch(() => ({}));
    return {
      booking_email: String(payload?.booking_email || ''),
      contact_email: String(payload?.contact_email || ''),
    };
  } catch {
    return null;
  }
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

async function main() {
  const args = process.argv.slice(2);
  const releaseIndex = args.indexOf('--release');
  const shouldRelease = releaseIndex >= 0;
  const confirm = args.includes('--confirm');

  if (args.includes('--self-test')) {
    return selfTest();
  }

  const claims = await firestoreList('artist_claims', {
    fields: ['artistId', 'uid', 'email', 'status'],
  });

  let authorization = '';
  try {
    authorization = basicAuthorization(
      secret('WORDPRESS_USERNAME'),
      secret('WORDPRESS_APPLICATION_PASSWORD'),
    );
  } catch {
    authorization = '';
  }

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
