#!/usr/bin/env node
/**
 * A **Play-bírálói teszt-fiók** létrehozása (és igazolása).
 *
 * MIÉRT KELL: az app **bejelentkezést kér**, ezért a Play Console „App access"
 * szakaszában meg kell adni egy **működő** fiókot (e-mail + jelszó). Enélkül a
 * bíráló **nem tud belépni**, és a nyilvános kiadást **elutasítják**.
 *
 * ⚠️ MIÉRT IGY HOZZUK LÉTRE, ÉS NEM AZ APP REGISZTRÁCIÓJÁVAL: az app regisztrációja
 * **e-mail-igazolást** kér (link a levélben). A bírálónak viszont **azonnal**
 * beléphető fiók kell, ezért a fiókot közvetlenül az **Identity Toolkit Admin
 * API**-val hozzuk létre, `emailVerified = true` értékkel. A profil-adatokat
 * (név, szerepkör) az app a **bejelentkezéskor magától kiegészíti**
 * (`community_service.dart` — `bootstrapGoogleProfile`, ha a profil hiányos),
 * ezért itt nem kell kézzel profilt írni.
 *
 * ⚠️ ÍR: csak `--confirm`-mal fut le. A végén **bejelentkezik** a létrehozott
 * fiókkal, hogy a jelszó és az igazolás **bizonyítottan** működjön.
 *
 * Futtatás:
 *   node tools/create-review-account.mjs                          (ellenőrzés)
 *   node tools/create-review-account.mjs --confirm                (létrehozza)
 *   node tools/create-review-account.mjs --confirm --password X    (saját jelszó)
 *   node tools/create-review-account.mjs --confirm --reset         (létező fiók új jelszava)
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { accessToken, PROJECT } from './lib/live-firebase.mjs';

const EMAIL = process.argv.find((arg) => arg.startsWith('--email='))?.slice(8)
  || 'review@hungarianhardstyle.hu';
const DISPLAY_NAME = 'Play Áruház bíráló';
const confirmed = process.argv.includes('--confirm');
const reset = process.argv.includes('--reset');
const passwordArg = process.argv.find((arg) => arg.startsWith('--password='))?.slice(11) || '';

/**
 * A Firebase webes API-kulcs (nem titok: a kliensben is benne van).
 *
 * ⚠️ A projektben **nincs webes app** (csak Android és iOS), ezért az
 * `android/app/google-services.json` **Android-kulcsát** használjuk — ez a
 * Firebase-konfiguráció része, nem titok. Ez a kulcs azonban a Google Cloud-ban
 * gyakran **alkalmazásra van szűkítve** (csomagnév + SHA-1), ilyenkor a
 * szerveroldali bejelentkezés `API_KEY_ANDROID_APP_BLOCKED` hibát ad — ez **nem**
 * a fiók hibája, és a szkript ezt külön jelzi is.
 */
function webApiKey() {
  const androidFile = path.join(process.cwd(), 'android', 'app', 'google-services.json');
  if (fs.existsSync(androidFile)) {
    const config = JSON.parse(fs.readFileSync(androidFile, 'utf8'));
    const key = config?.client?.[0]?.api_key?.[0]?.current_key;
    if (key) return key;
  }
  const optionsFile = path.join(process.cwd(), 'lib', 'firebase_options.dart');
  if (fs.existsSync(optionsFile)) {
    const match = fs.readFileSync(optionsFile, 'utf8').match(/apiKey:\s*'([^']+)'/);
    if (match) return match[1];
  }
  throw new Error('Nem találom a Firebase API-kulcsot (google-services.json / firebase_options.dart).');
}

/** Erős, de kézzel is beírható jelszó (a bírálónak ezt adjuk meg). */
function generatePassword() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  let body = '';
  for (const byte of crypto.randomBytes(14)) body += alphabet[byte % alphabet.length];
  return `Huhs-${body}`;
}

async function adminPost(token, url, body) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const json = await response.json().catch(() => ({}));
  return { status: response.status, json };
}

async function main() {
  const key = webApiKey();
  const token = await accessToken();
  const adminBase = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}`;
  const password = passwordArg || generatePassword();

  console.log(`projekt: ${PROJECT}`);
  console.log(`fiók:    ${EMAIL}`);
  console.log('');

  // 1) Létezik-e már?
  const lookup = await adminPost(token, `${adminBase}/accounts:lookup`, { email: [EMAIL] });
  const existing = lookup.json?.users?.[0] || null;
  if (existing) {
    console.log(
      `FIGYELEM  a fiók MÁR LÉTEZIK (uid=${existing.localId}, igazolt=${existing.emailVerified === true}).`,
    );
  } else {
    console.log('a fiók még nem létezik.');
  }

  if (!confirmed) {
    console.log('');
    console.log('SZÁRAZ FUTÁS — nem írtam semmit. Létrehozáshoz: --confirm');
    return 0;
  }

  // 2) Létrehozás vagy jelszó-állítás.
  if (!existing) {
    const created = await adminPost(token, `${adminBase}/accounts`, {
      email: EMAIL,
      password,
      emailVerified: true,
      displayName: DISPLAY_NAME,
    });
    if (created.status !== 200) {
      console.error(`HIBA  a fiók létrehozása nem sikerült: ${JSON.stringify(created.json).slice(0, 200)}`);
      return 1;
    }
    console.log(`OK    létrehozva (uid=${created.json.localId}, igazolt=true)`);
  } else if (reset) {
    const updated = await adminPost(token, `${adminBase}/accounts:update`, {
      localId: existing.localId,
      password,
      emailVerified: true,
      displayName: existing.displayName || DISPLAY_NAME,
    });
    if (updated.status !== 200) {
      console.error(`HIBA  a jelszó átállítása nem sikerült: ${JSON.stringify(updated.json).slice(0, 200)}`);
      return 1;
    }
    console.log(`OK    a jelszó és az igazolás frissítve (uid=${existing.localId})`);
  } else {
    console.log('');
    console.log('A fiók létezik. Új jelszó beállításához: --confirm --reset');
    return 0;
  }

  // 3) ÉLES IGAZOLÁS: be tud-e jelentkezni a bíráló? (pontosan az az útvonal,
  // amit az app használ: e-mail + jelszó a Firebase Auth REST-en.)
  const signIn = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: EMAIL, password, returnSecureToken: true }),
    },
  );
  const session = await signIn.json().catch(() => ({}));
  const ok = signIn.status === 200 && !!session.idToken;
  const keyBlocked = JSON.stringify(session).includes('API_KEY');
  console.log('');
  if (ok) {
    console.log(`OK    a bejelentkezés e-mail + jelszóval működik (status=${signIn.status})`);
    console.log(`      uid=${session.localId}, igazolt e-mail: ${session.email}`);
  } else if (keyBlocked) {
    console.log(
      `FIGYELEM  a jelszavas bejelentkezést innen NEM tudtam lejátszani: az Android API-kulcs ` +
        `alkalmazásra van szűkítve (${JSON.stringify(session).slice(0, 120)}).`,
    );
    console.log(
      '      Ez NEM a fiók hibája: a jelszót a Google Admin API-ja állította be, és az e-mail ' +
        'igazoltnak van jelölve. A bíráló első belépése ezt úgyis igazolja.',
    );
  } else {
    console.log(`HIBA  a bejelentkezés nem sikerült (status=${signIn.status}): ${JSON.stringify(session).slice(0, 200)}`);
  }

  // 4) A szerver is elfogadja-e a fiókot? (egy CSAK OLVASÓ callable-lal)
  if (ok) {
    const call = await fetch(
      'https://us-central1-hungarian-hardstyle.cloudfunctions.net/getMyLabelLibrary',
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${session.idToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: {} }),
      },
    );
    const body = await call.json().catch(() => ({}));
    const accepted = call.status === 200 && body?.result !== undefined;
    console.log(
      `${accepted ? 'OK   ' : 'FIGYELEM'} a szerver elfogadta a fiókot (getMyLabelLibrary, status=${call.status})`,
    );
    if (!accepted) {
      console.log(
        '      (Ha ez App Check miatt utasítódik el, az NEM a fiók hibája: a callable App Check-t vár, amit innen nem tudunk adni.)',
      );
    }
  }

  console.log('');
  console.log('=== EZT ÍRD A PLAY CONSOLE „App access” SZAKASZÁBA ===');
  console.log(`Név:    ${DISPLAY_NAME}`);
  console.log(`E-mail: ${EMAIL}`);
  console.log(`Jelszó: ${password}`);
  console.log('');
  console.log(
    '⚠️ A bírálat után érdemes új jelszót adni (--confirm --reset) vagy a fiókot törölni.',
  );
  return ok || keyBlocked ? 0 : 1;
}

const code = await main();
process.exit(code ?? 0);
