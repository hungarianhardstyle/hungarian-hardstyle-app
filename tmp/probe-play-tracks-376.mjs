#!/usr/bin/env node
/**
 * **A Play-sávok pontos mérése** — sávonként az ÖSSZES kiadás (nem csak az
 * „aktuális"), mert a `check-play-track.mjs` sávonként egy sort ír.
 *
 * MIÉRT: a tulajdonos azt mondta, hogy *„kint az update beta meg az éles is"* —
 * ezt ellenőrizni kell, mert a születési dátum emlékeztető **csak a 376-os
 * appban** értelmezhető (a régi buildben nincs dátum-mező, és a koppintás
 * célpontja sem létezik).
 *
 * Használat: node tmp/probe-play-tracks-376.mjs
 */
import { accessToken } from '../tools/lib/live-firebase.mjs';
import { secretAsync } from '../tools/lib/live-firebase.mjs';

const PROJECT = 'hungarian-hardstyle';
const PACKAGE = 'hu.hungarianhardstyle.app';

const raw = await secretAsync('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
const serviceAccount = JSON.parse(raw);
const token = await accessToken();

// A Play API-hoz a szolgáltatói fiók tokene kell (a CLI tokenje más célra van).
const jwt = await (async () => {
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const claims = Buffer.from(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  ).toString('base64url');
  const crypto = await import('node:crypto');
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(`${header}.${claims}`);
  const signature = signer.sign(serviceAccount.private_key).toString('base64url');
  const assertion = `${header}.${claims}.${signature}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  const json = await response.json();
  if (!json.access_token) throw new Error(`token hiba: ${JSON.stringify(json).slice(0, 200)}`);
  return json.access_token;
})();

const base = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/edits`;
const created = await fetch(`${base}?access_token=${jwt}`, { method: 'POST' }).then((r) => r.json());
const editId = created.id;
if (!editId) throw new Error(`edit nem jött létre: ${JSON.stringify(created).slice(0, 200)}`);

const tracks = await fetch(`${base}/${editId}/tracks?access_token=${jwt}`).then((r) => r.json());
console.log('Sávonként az ÖSSZES kiadás:\n');
for (const track of tracks.tracks || []) {
  console.log(`SÁV: ${track.track}`);
  for (const release of track.releases || []) {
    const codes = (release.versionCodes || []).join(', ');
    const status = release.status || '(nincs állapot)';
    const fraction = release.userFraction != null ? `${Math.round(release.userFraction * 100)}%` : '-';
    const name = release.name || '-';
    console.log(`   build=${codes}  állapot=${status}  kigördítés=${fraction}  név=${name}`);
  }
}

await fetch(`${base}/${editId}?access_token=${jwt}`, { method: 'DELETE' });
console.log('\n(a mérő edit törölve)');
void token;
