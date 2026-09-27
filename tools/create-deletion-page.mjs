#!/usr/bin/env node
/**
 * A **fióktörlési weboldal** létrehozása/frissítése a honlapon (WordPress).
 *
 * MIÉRT KELL: a Google Play a **fiókot létrehozó** appoknál a Data safety
 * szakaszban kötelezően kér egy **URL-t**, ahol a felhasználó **az app nélkül**
 * is kérheti a fiókja törlését. Az appban **van** törlés, a webes hivatkozás
 * pedig a `…/fiok-torles/` oldal.
 *
 * ⚠️ 2026-09-27: a Play **elutasította** a frissítést
 * (*„Felhasználói adatok – Fióktörlési követelmény: Érvénytelen adattörlési link
 * az Adatbiztonsági űrlapon"*). A mérés szerint az oldal **élt** (HTTP 200), a
 * hiba a **Play-űrlapon** volt (a link mező üresen maradt), **és** az oldal
 * rossz **appon belüli menüutat** írt le: „Több → Beállítások → Fiók törlése" —
 * ilyen menüpont **nincs** az appban. A valódi út:
 * **Chat fül → jobb felső „Profil" ikon → „Profil szerkesztése" → a lap alján
 * „Profil törlése"**. A Google a linknél azt is megköveteli, hogy a törlési
 * útvonal **feltűnően látható** legyen, és az oldal **hivatkozzon az appra**
 * (ezért van most **angol szakasz** is a lapon).
 *
 * ⚠️ A SZÖVEG NEM TALÁLGATÁS: a `functions/index.js` `deleteUserReferences()`
 * és `deleteCommunityUser()` **tényleges** viselkedését írja le (mi törlődik, mi
 * marad, mennyi idő alatt). Ha az éles törlés változik, **ezt a szöveget is**
 * frissíteni kell — ezért él a szöveg itt, verziókezelve, nem a WordPressben.
 *
 * ⚠️ ÍR a honlapra: csak `--confirm`-mal fut le. Alapból csak **megnézi**, hogy
 * létezik-e már az oldal.
 *
 * Futtatás:
 *   node tools/create-deletion-page.mjs                 (ellenőrzés, nem ír)
 *   node tools/create-deletion-page.mjs --confirm       (létrehozza)
 *   node tools/create-deletion-page.mjs --confirm --update   (frissíti a szöveget)
 */
import { secretAsync } from './lib/live-firebase.mjs';

const BASE = 'https://hungarianhardstyle.hu';
const SLUG = 'fiok-torles';
const TITLE = 'Fiók törlése';
const CONTACT = 'info@hungarianhardstyle.hu';

const confirmed = process.argv.includes('--confirm');
const update = process.argv.includes('--update');

/**
 * A törlési tájékoztató szövege.
 *
 * A tények forrása: `functions/index.js`
 *  - `deleteCommunityUser` (4753+): az Auth-fiók azonnal törlődik, a törlési
 *    rekord (`account_deletions`) **48 óráig** marad meg a kép-takarítás
 *    befejezéséhez (`expiresAt: +48 óra`, 4913. sor).
 *  - `deleteUserReferences` (4491+): profil, képek, chat, kommentek,
 *    értesítések, játékeredmények, pontok, szavazatok, jelentések, DJ-átvételek,
 *    **vásárlási jogosultságok és vásárlás-azonosítók**, reklámos feloldások,
 *    beküldés-szerző megfeleltetés, napi aktivitás.
 *  - A **Google Play-vásárlás** nem nálunk van: a Google-fiókhoz tartozik, ezért
 *    azt nem töröljük (és nem is tudjuk) — új fiókkal újra ellenőrizhető.
 */
const CONTENT = `
<p><strong>A Hungarian Hardstyle appban a fiókodat bármikor törölheted.</strong>
Ez az oldal elmondja, hogyan kérheted, mi törlődik, mi marad meg, és mennyi ideig tart.</p>

<h2>1. Hogyan kérheted a törlést?</h2>
<ul>
  <li><strong>Az appban (ez a leggyorsabb):</strong> nyisd meg a <strong>Chat fület</strong>,
      koppints a jobb felső <strong>„Profil" ikonra</strong> (a profilképed), majd a
      <em>Profil szerkesztése</em> gombra — a lap alján találod a
      <strong>„Profil törlése"</strong> gombot. A megerősítés után a törlés azonnal elindul.</li>
  <li><strong>E-mailben:</strong> írj a <a href="mailto:${CONTACT}">${CONTACT}</a> címre a
      <em>fiókhoz tartozó e-mail címről</em>, „Fiók törlése" tárggyal. Legkésőbb
      <strong>30 napon belül</strong> elvégezzük (a gyakorlatban ennél jóval hamarabb).</li>
</ul>

<h2>2. Mi törlődik?</h2>
<ul>
  <li>a <strong>fiókod és a bejelentkezési adataid</strong> (e-mail cím, jelszó),</li>
  <li>a <strong>közösségi profilod</strong> (név, bemutatkozás, profilkép),</li>
  <li><strong>chat-üzeneteid</strong> és a privát beszélgetéseid,</li>
  <li><strong>cikk-hozzászólásaid</strong>, kedveléseid és a kapcsolódási kéréseid,</li>
  <li><strong>értesítéseid</strong>,</li>
  <li><strong>játék- és kvízeredményeid</strong>, valamint az <strong>achievement-pontjaid</strong>
      és a napi aktivitási előzményeid,</li>
  <li><strong>szavazataid</strong> (közönségszavazás, kérdőív),</li>
  <li>a <strong>bejelentéseid</strong> és a rólad szóló bejelentések,</li>
  <li>a <strong>DJ-adatlap átvételeid</strong>,</li>
  <li>a <strong>vásárlási jogosultsági rekordjaid</strong> (hogy melyik kiadványt vetted meg)
      és a hozzájuk tartozó vásárlás-azonosítók,</li>
  <li>a <strong>reklámos feloldásaid</strong>,</li>
  <li>az általad <strong>feltöltött képek</strong> (profilkép, hírekhez és beszélgetésekhez
      feltöltött képek).</li>
</ul>

<h2>3. Mi marad meg, és miért?</h2>
<ul>
  <li><strong>A Google Play-vásárlásod</strong> a <strong>Google-fiókodnál</strong> marad — ez nem
      nálunk van, ezért nem is tudjuk törölni. Ez jó hír: ha később új fiókot regisztrálsz, a
      megvásárolt kiadványokat <strong>újra ellenőrizni tudod</strong>, és ismét elérhetők lesznek
      — <strong>nem kell újra fizetned</strong>.</li>
  <li>A <strong>számlázási és vásárlási előzmények</strong> a Google-nál, illetve a
      jogszabályban előírt megőrzési időn belül maradnak meg.</li>
  <li>Az <strong>általad beküldött, de még el nem fogadott</strong> DJ- vagy szervező-adatlap
      tartalma a beküldés feldolgozásához szükséges ideig maradhat meg.</li>
</ul>

<h2>4. Mennyi ideig tart?</h2>
<ul>
  <li>A <strong>fiók és a profil törlése azonnal</strong> megtörténik.</li>
  <li>A <strong>feltöltött képek</strong> törlése a háttérben fejeződik be,
      <strong>legfeljebb 48 órán belül</strong> (ha egy lépés megszakad, a rendszer újrapróbálja).</li>
  <li>Az e-mailes kérés esetén legkésőbb <strong>30 napon belül</strong> elvégezzük a törlést, és
      visszaigazoljuk.</li>
</ul>

<h2>5. Kérdésed van?</h2>
<p>Írj a <a href="mailto:${CONTACT}">${CONTACT}</a> címre — szívesen segítünk.</p>

<p><em>Ez a tájékoztató a Hungarian Hardstyle mobilalkalmazásra vonatkozik
(csomagnév: hu.hungarianhardstyle.app).</em></p>

<hr>

<h2>Delete your account (English)</h2>
<p><strong>In the Hungarian Hardstyle mobile app (package name:
hu.hungarianhardstyle.app) you can delete your account at any time.</strong>
This page explains how to request deletion, what is deleted, what is kept, and
how long it takes.</p>

<h3>1. How to request deletion</h3>
<ul>
  <li><strong>In the app (fastest):</strong> open the <strong>Chat tab</strong>, tap the
      <strong>“Profile” icon</strong> in the top right corner (your profile picture), then tap
      <em>Profil szerkesztése</em> (Edit profile) — the
      <strong>“Profil törlése”</strong> (Delete profile) button is at the bottom of that page.
      Deletion starts immediately after you confirm.</li>
  <li><strong>By e-mail:</strong> write to
      <a href="mailto:${CONTACT}">${CONTACT}</a> from the e-mail address of your account,
      with the subject “Account deletion”. We complete the deletion within
      <strong>30 days</strong> at the latest (in practice much sooner).</li>
</ul>

<h3>2. What is deleted</h3>
<ul>
  <li>your <strong>account and sign-in data</strong> (e-mail address, password),</li>
  <li>your <strong>community profile</strong> (name, bio, profile picture),</li>
  <li>your <strong>chat messages</strong> and private conversations,</li>
  <li>your <strong>article comments</strong>, likes and friend requests,</li>
  <li>your <strong>notifications</strong>,</li>
  <li>your <strong>game and quiz results</strong>, your <strong>achievement points</strong>
      and daily activity history,</li>
  <li>your <strong>votes</strong> (public voting, polls),</li>
  <li>your <strong>reports</strong> and the reports about you,</li>
  <li>your <strong>DJ page claims</strong>,</li>
  <li>your <strong>purchase entitlement records</strong> (which releases you bought) and the
      related purchase identifiers,</li>
  <li>your <strong>rewarded-ad unlocks</strong>,</li>
  <li>the <strong>images you uploaded</strong> (profile picture, images uploaded to news and
      conversations).</li>
</ul>

<h3>3. What is kept, and why</h3>
<ul>
  <li>Your <strong>Google Play purchase</strong> stays with your <strong>Google account</strong> —
      it is not stored by us, so we cannot delete it. This is good news: if you register a new
      account later, you can <strong>verify the purchased releases again</strong> and they become
      available — <strong>you do not have to pay twice</strong>.</li>
  <li><strong>Billing and purchase history</strong> remain with Google and for the retention
      period required by law.</li>
  <li>The content of a DJ or organizer page you <strong>submitted but that has not yet been
      approved</strong> may be kept for as long as needed to process the submission.</li>
</ul>

<h3>4. How long does it take</h3>
<ul>
  <li>Deleting the <strong>account and the profile happens immediately</strong>.</li>
  <li><strong>Uploaded images</strong> are removed in the background within
      <strong>at most 48 hours</strong> (if a step is interrupted, the system retries).</li>
  <li>For an e-mail request we complete the deletion within <strong>30 days</strong> at the
      latest and confirm it.</li>
</ul>

<h3>5. Questions</h3>
<p>Write to <a href="mailto:${CONTACT}">${CONTACT}</a> — we are happy to help.</p>

<p><em>This notice applies to the Hungarian Hardstyle mobile application
(package name: hu.hungarianhardstyle.app).</em></p>
`.trim();

async function main() {
  const username = await secretAsync('WORDPRESS_USERNAME');
  const password = await secretAsync('WORDPRESS_APPLICATION_PASSWORD');
  const auth = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`;
  const headers = {
    Authorization: auth,
    Accept: 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
  };

  console.log(`honlap: ${BASE}`);
  console.log(`keresett oldal: ${SLUG}`);

  const existingResponse = await fetch(
    `${BASE}/wp-json/wp/v2/pages?slug=${SLUG}&status=publish,draft,pending&per_page=5`,
    { headers },
  );
  if (!existingResponse.ok) {
    console.error(`HIBA  a WordPress nem válaszol (status=${existingResponse.status}).`);
    console.error('      (Ellenőrizd, hogy az alkalmazásjelszó és a felhasználónév érvényes-e.)');
    return 1;
  }
  const existing = await existingResponse.json();
  const found = Array.isArray(existing) ? existing[0] : null;
  if (found) {
    console.log(`OK    az oldal MÁR LÉTEZIK: #${found.id} (${found.status}) — ${found.link}`);
  } else {
    console.log('      az oldal még NINCS meg.');
  }

  if (!confirmed) {
    console.log('');
    console.log('SZÁRAZ FUTÁS — nem írtam semmit. Éles létrehozáshoz: --confirm');
    if (found) console.log('A szöveg frissítéséhez: --confirm --update');
    return 0;
  }
  if (found && !update) {
    console.log('');
    console.log('Az oldal létezik, és --update nélkül nem írom felül. (A szöveg frissítéséhez: --confirm --update)');
    return 0;
  }

  const body = JSON.stringify({ title: TITLE, slug: SLUG, status: 'publish', content: CONTENT });
  const response = await fetch(
    found ? `${BASE}/wp-json/wp/v2/pages/${found.id}` : `${BASE}/wp-json/wp/v2/pages`,
    { method: 'POST', headers, body },
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error(
      `HIBA  a(z) ${found ? 'frissítés' : 'létrehozás'} nem sikerült (status=${response.status}): ${payload?.message || ''}`,
    );
    return 1;
  }
  const link = payload.link || `${BASE}/${SLUG}/`;
  console.log('');
  console.log(`OK    ${found ? 'frissítve' : 'létrehozva'}: #${payload.id} — ${link}`);

  // ÉLES ellenőrzés: a nyilvános oldal elérhető-e, és jó-e az ékezet?
  const publicResponse = await fetch(link, { headers: { Accept: 'text/html' } });
  const html = await publicResponse.text();
  const checks = [
    ['az oldal elérhető (HTTP 200)', publicResponse.status === 200, `status=${publicResponse.status}`],
    ['a cím megjelenik', html.includes('Fiók törlése'), ''],
    ['az ékezetek helyesek', html.includes('törlődik') && !html.includes('tÃ¶rlÅ‘dik'), ''],
    ['benne van a kapcsolat', html.includes(CONTACT), ''],
    ['benne van a Google Play magyarázat', html.includes('Google Play-vásárlás'), ''],
    // ⚠️ 2026-09-27: a Play az „érvénytelen adattörlési linket" is jelezheti, ha az
    // oldalon leírt **appon belüli út nem valódi** — ezért ezt külön mérjük.
    [
      'a helyes appon belüli út van az oldalon (Chat → Profil → Profil szerkesztése)',
      html.includes('Chat fület') && html.includes('Profil szerkesztése') && html.includes('Profil törlése'),
      '',
    ],
    [
      'a régi, nem létező menüút NINCS az oldalon (Több → Beállítások → Fiók törlése)',
      !html.includes('Beállítások') || !html.includes('Fiók törlése</em>'),
      '',
    ],
    ['van angol szakasz (a felülvizsgáló ezt keresi)', html.includes('Delete your account'), ''],
    ['az angol szakaszban is ott a csomagnév', html.includes('hu.hungarianhardstyle.app'), ''],
  ];
  let failed = 0;
  for (const [label, ok, detail] of checks) {
    if (!ok) failed += 1;
    console.log(`${ok ? 'OK   ' : 'HIBA '} ${label}${detail ? ` (${detail})` : ''}`);
  }
  console.log('');
  console.log(
    failed
      ? 'FIGYELEM  a nyilvános oldal ellenőrzése nem teljes — nézd meg kézzel!'
      : 'Az oldal él, és a tartalom rendben van. Ezt az URL-t kell a Play Data safety mezőjébe írni.',
  );
  return failed ? 1 : 0;
}

const code = await main();
process.exit(code ?? 0);
