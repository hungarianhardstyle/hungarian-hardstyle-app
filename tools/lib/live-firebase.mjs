/**
 * Közös segédek a VALÓDI (éles) állapotot mérő eszközöknek.
 *
 * MIÉRT: a 2026-09-19-i hibavadászat közben több ideiglenes szkript készült
 * (Firestore-állapot, plugin-végpontok, Play-oldal). Ezek hasznosak voltak, de
 * nem voltak verziókezelve — így a következő agens (vagy a tulajdonos) nem látta
 * őket. Ez a modul azok közös része: hitelesítés és olvasás.
 *
 * ALAPSZABÁLYOK:
 *  * **Titkot soha nem tárolunk a repóban.** A Firebase CLI saját bejelentkezését
 *    használjuk (a token csak memóriában van, a token-tároló fájlhoz nem nyúlunk),
 *    a WordPress/Cloudinary titkokat pedig futásidőben kérdezzük le a Secret
 *    Managerből (`firebase functions:secrets:access`).
 *  * **Olvasás.** Az ellenőrző eszközök nem írnak az éles adatbázisba.
 *  * **Nem kell hozzá kulcsfájl**: elég, ha ezen a gépen `firebase login` volt.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

export const PROJECT = 'hungarian-hardstyle';
export const DATABASE = 'hungarian-hardstyle';

// A firebase-tools nyilvános (telepített alkalmazáshoz tartozó) azonosítója.
// Nem titok: a CLI forráskódjában is benne van; a refresh token a titok, az
// pedig a felhasználó gépén marad.
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents`;

/** A Firebase CLI tárolt bejelentkezéséből kér egy érvényes access tokent. */
export async function accessToken() {
  const storePath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(storePath)) {
    throw new Error(
      `Nincs Firebase CLI bejelentkezés (${storePath}). Futtasd: npx firebase login`,
    );
  }
  const store = JSON.parse(fs.readFileSync(storePath, 'utf8'));
  const tokens = store.tokens || {};
  if (tokens.access_token && Number(tokens.expires_at || 0) > Date.now() + 60_000) {
    return tokens.access_token;
  }
  if (!tokens.refresh_token) throw new Error('A Firebase CLI token-tárolója nem tartalmaz refresh tokent.');
  const body = new URLSearchParams({
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: String(tokens.refresh_token),
    grant_type: 'refresh_token',
  });
  const response = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', body });
  const json = await response.json().catch(() => ({}));
  if (!response.ok || !json.access_token) {
    throw new Error(`Token-frissítés sikertelen (status=${response.status}, ${json.error || 'ismeretlen'}).`);
  }
  return json.access_token;
}

/** A naplókban használt, visszafejthetetlen UID-rövidítés (ugyanaz, mint a függvényekben). */
export function shortHash(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex').slice(0, 16);
}

function firestoreValue(field) {
  if (!field) return undefined;
  if ('stringValue' in field) return field.stringValue;
  if ('booleanValue' in field) return field.booleanValue;
  if ('integerValue' in field) return Number(field.integerValue);
  if ('doubleValue' in field) return Number(field.doubleValue);
  if ('timestampValue' in field) return field.timestampValue;
  if ('nullValue' in field) return null;
  if ('arrayValue' in field) return (field.arrayValue.values || []).map(firestoreValue);
  if ('mapValue' in field) {
    return Object.fromEntries(
      Object.entries(field.mapValue.fields || {}).map(([key, value]) => [key, firestoreValue(value)]),
    );
  }
  return undefined;
}

function decodeDocument(document) {
  return {
    id: document.name.split('/').pop(),
    ...Object.fromEntries(Object.entries(document.fields || {}).map(([key, value]) => [key, firestoreValue(value)])),
  };
}

/** Egy gyűjtemény összes dokumentuma (legfeljebb `max` darab), olvasásra. */
export async function firestoreList(collection, { fields = [], token, max = 2000 } = {}) {
  const auth = token || (await accessToken());
  const documents = [];
  let pageToken = '';
  do {
    const url = new URL(`${BASE}/${collection}`);
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    for (const field of fields) url.searchParams.append('mask.fieldPaths', field);
    const response = await fetch(url, { headers: { Authorization: `Bearer ${auth}` } });
    const json = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(`${collection} olvasása sikertelen (status=${response.status}).`);
    }
    for (const document of json.documents || []) documents.push(decodeDocument(document));
    pageToken = json.nextPageToken || '';
  } while (pageToken && documents.length < max);
  return documents;
}

/** Egyetlen dokumentum, vagy `null`, ha nincs. */
export async function firestoreGet(documentPath, { token } = {}) {
  const auth = token || (await accessToken());
  const response = await fetch(`${BASE}/${documentPath}`, { headers: { Authorization: `Bearer ${auth}` } });
  if (response.status === 404) return null;
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`${documentPath} olvasása sikertelen (status=${response.status}).`);
  return decodeDocument({ name: `${BASE}/${documentPath}`, fields: json.fields });
}

/** Egy titok értéke a Secret Managerből (futásidőben; a repóban soha). */
export function secret(name) {
  // A `firebase` CLI néha átmenetileg hibázik (párhuzamos hívásoknál), ezért
  // egyszer újrapróbáljuk — a titok értéke nem változik közben.
  let lastError;
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      const output = execFileSync('npx', ['firebase', 'functions:secrets:access', name], {
        encoding: 'utf8',
        shell: true,
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      const value = output.trim().split(/\r?\n/).pop().trim();
      if (!value) throw new Error('üres érték');
      return value;
    } catch (error) {
      lastError = error;
      if (attempt === 1) execFileSync('node', ['-e', 'setTimeout(()=>{}, 1500)'], { stdio: 'ignore' });
    }
  }
  throw new Error(`A(z) ${name} titok nem olvasható a Secret Managerből (${lastError?.message || 'ismeretlen hiba'}).`);
}

/** A 15 percenkénti takarítás azonnali futtatása (Cloud Scheduler „run”). */
export async function runScheduledJob(jobName, { location = 'europe-central2', token } = {}) {
  const auth = token || (await accessToken());
  const response = await fetch(
    `https://cloudscheduler.googleapis.com/v1/projects/${PROJECT}/locations/${location}/jobs/${jobName}:run`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
      body: '{}',
    },
  );
  return { status: response.status, body: (await response.text()).slice(0, 200) };
}

/** Egyszerű, egységes ellenőrzés-kiíró (a többi tools/*.mjs mintájára). */
export function createChecker() {
  const results = [];
  let checked = 0;
  let failed = 0;
  return {
    check(label, ok, detail) {
      checked += 1;
      if (ok) results.push(`OK    ${label}`);
      else {
        failed += 1;
        results.push(`HIBA  ${label}${detail ? ` — ${detail}` : ''}`);
      }
    },
    report() {
      console.log(results.join('\n'));
      console.log('');
      console.log(`${checked - failed}/${checked} ellenőrzés rendben${failed ? ` — ${failed} HIBA` : ''}`);
      return failed ? 1 : 0;
    },
    get failures() {
      return failed;
    },
  };
}

/** Rekurzívan megkeresi a tiltott kulcsokat egy válaszban (UID/hash-szivárgás). */
export function findForbiddenKeys(value, forbidden = ['uid', 'hash'], trail = '$') {
  const hits = [];
  if (Array.isArray(value)) {
    value.forEach((item, index) => hits.push(...findForbiddenKeys(item, forbidden, `${trail}[${index}]`)));
    return hits;
  }
  if (value && typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      if (forbidden.includes(key.toLowerCase())) hits.push(`${trail}.${key}`);
      hits.push(...findForbiddenKeys(item, forbidden, `${trail}.${key}`));
    }
  }
  return hits;
}
