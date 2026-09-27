#!/usr/bin/env node
/**
 * A **gyermekbiztonsági normák** oldal létrehozása/frissítése a honlapon (WordPress).
 *
 * MIÉRT KELL (2026-09-27): a Google Play **Közösségi** kategóriába átsorolt appnál
 * kötelező a **Gyermekbiztonsági normák nyilatkozat** kitöltése, amihez a Google
 * az alábbiakat kéri (mért forrás: a Play súgója,
 * https://support.google.com/googleplay/android-developer/answer/14747720):
 *   1. **közzétett normák** egy világszerte elérhető webes forráson (működik,
 *      releváns: említi a gyermekek elleni szexuális visszaélést/kizsákmányolást,
 *      és szerepel benne az **app vagy a fejlesztő neve**),
 *   2. **alkalmazáson belüli bejelentési mechanizmus**,
 *   3. a **CSAM** kezelése (eltávolítás, amint tudomást szerzünk róla),
 *   4. a gyermekbiztonsági **jogszabályok** betartása,
 *   5. **gyermekbiztonsági kapcsolattartó** megadása a Play Console-ban.
 *
 * Ez a szkript az **1. pontot** szolgálja ki: közzéteszi a normákat a honlapon, és
 * kiírja a Play Console-ba másolandó linket. (Az app-oldali bejelentés a
 * `chat_reports` úton működik: hozzászólás, Chat-üzenet és **privát chat** is.)
 *
 * ⚠️ A SZÖVEG NEM TALÁLGATÁS: a valós működést írja le (bejelentés helyei, mit
 * teszünk, milyen határidővel). Ha a moderációs folyamat változik, ezt is
 * frissíteni kell — ezért él a szöveg itt, verziókezelve, nem a WordPressben.
 *
 * ⚠️ ÍR a honlapra: csak `--confirm`-mal fut le. Alapból csak **megnézi**, hogy
 * létezik-e már az oldal.
 *
 * Futtatás:
 *   node tools/create-child-safety-page.mjs                        (ellenőrzés)
 *   node tools/create-child-safety-page.mjs --confirm               (létrehozza)
 *   node tools/create-child-safety-page.mjs --confirm --update      (frissíti)
 */
import { secretAsync } from './lib/live-firebase.mjs';

const BASE = 'https://hungarianhardstyle.hu';
const SLUG = 'gyermekbiztonsag';
const TITLE = 'Gyermekbiztonsági normák';
const CONTACT = 'info@hungarianhardstyle.hu';
const APP_NAME = 'Hungarian Hardstyle';
const PACKAGE = 'hu.hungarianhardstyle.app';

const confirmed = process.argv.includes('--confirm');
const update = process.argv.includes('--update');

const CONTENT = `
<p><strong>A ${APP_NAME} alkalmazás (csomagnév: ${PACKAGE}) üzemeltetője
nulla toleranciát alkalmaz a gyermekek elleni szexuális visszaéléssel és
kizsákmányolással (CSAE), valamint a gyermekekkel történő szexuális visszaéléssel
kapcsolatos anyagokkal (CSAM) szemben.</strong> Ez az oldal leírja, mi tilos, hogyan
jelentheted be a problémát, és mit teszünk a bejelentések nyomán.</p>

<h2>1. Mi tilos?</h2>
<ul>
  <li>Bármilyen olyan tartalom vagy viselkedés, amely gyermekek szexuális
      kizsákmányolására, bántalmazására vagy veszélyeztetésére irányul — ideértve a
      gyermekek szexuális célú megkörnyékezését („grooming”), a szexuális tartalmú
      zsarolást, a gyermekkereskedelmet és a gyermekek szexuális kizsákmányolását
      ábrázoló anyagokat (fotó, videó, számítógéppel előállított kép is).</li>
  <li>Kiskorú zaklatása, fenyegetése, zaklató megkeresése, illetve kiskorúval
      folytatott szexuális tartalmú beszélgetés kezdeményezése.</li>
  <li>Kiskorúról készült kép vagy személyes adat közzététele a hozzájárulása nélkül.</li>
</ul>
<p>Az ilyen tartalmakat és felhasználói fiókokat <strong>eltávolítjuk</strong>, és a
szükséges esetekben <strong>a hatóságoknak is bejelentjük</strong>.</p>

<h2>2. Hogyan jelentheted be? (alkalmazáson belül)</h2>
<p>A bejelentés az appon belül, néhány koppintással elérhető — nem kell kilépni az
alkalmazásból:</p>
<ul>
  <li><strong>Hozzászólás vagy Chat-üzenet:</strong> a bejegyzés melletti menüben a
      <em>Jelentés</em> pont.</li>
  <li><strong>Privát beszélgetés:</strong> a beszélgetés fejlécében a menü
      (<em>Felhasználó jelentése</em>) — ugyanott, ahol a blokkolás és a beszélgetés
      törlése van.</li>
  <li><strong>Bármi más esetben:</strong> írj a
      <a href="mailto:${CONTACT}">${CONTACT}</a> címre.</li>
</ul>
<p>A bejelentéshez regisztrált fiók szükséges, és a bejelentést a moderátorok
nézik meg. A bejelentő személyazonosságát a bejelentett fél nem látja.</p>

<h2>3. Mit teszünk a bejelentés után?</h2>
<ul>
  <li>A bejelentéseket <strong>24 órán belül</strong> megvizsgáljuk.</li>
  <li>Ha a tartalom sérti a normáinkat, <strong>eltávolítjuk</strong>, és a fiókot
      <strong>korlátozzuk vagy véglegesen kitiltjuk</strong>.</li>
  <li>Gyermekek elleni szexuális visszaélésre utaló esetben a bejelentést
      <strong>a hatóságoknak továbbítjuk</strong> (Magyarországon a rendőrségnek;
      névtelen bejelentés a
      <a href="https://www.biztonsagosinternet.hu" target="_blank" rel="noopener">Biztonságosinternet Hotline</a>
      felületén is tehető).</li>
  <li>A felhasználók egymást is <strong>blokkolhatják</strong>, és a beszélgetést
      bármikor törölhetik.</li>
</ul>

<h2>4. Kiskorúak védelme az alkalmazásban</h2>
<ul>
  <li>A közösségi funkciók használatához a <strong>születési dátum megadása
      kötelező</strong>; a dátum a profilodon <strong>alapértelmezésben nem
      látható</strong>, és te döntesz róla, hogy látható legyen-e.</li>
  <li>A kiskorúakat érintő bejelentéseket kiemelten kezeljük.</li>
  <li>Az alkalmazás nem tartalmaz kiskorúaknak szánt külön felületet, és a
      hirdetések beállításánál a Google irányelveit követjük.</li>
</ul>

<h2>5. Jogszabályok és kapcsolat</h2>
<p>Az üzemeltető a gyermekek biztonságára vonatkozó hatályos jogszabályoknak
megfelelően jár el, és a tudomására jutott, gyermekeket érintő visszaéléseket
kivizsgálja. <strong>Gyermekbiztonsági kapcsolattartó:</strong>
<a href="mailto:${CONTACT}">${CONTACT}</a> (a ${APP_NAME} üzemeltetője).</p>

<p><em>Ez a tájékoztató a ${APP_NAME} mobilalkalmazásra vonatkozik
(csomagnév: ${PACKAGE}). Utolsó frissítés: 2026. szeptember 27.</em></p>

<hr>

<h2>Child Safety Standards (English)</h2>
<p><strong>The operator of the ${APP_NAME} application (package name: ${PACKAGE})
has zero tolerance for child sexual abuse and exploitation (CSAE) and for child
sexual abuse material (CSAM).</strong> This page explains what is prohibited, how
to report a problem, and what we do about reports.</p>

<h3>1. What is prohibited?</h3>
<ul>
  <li>Any content or behaviour that sexualises, abuses or endangers children —
      including grooming, sextortion, child trafficking and any material depicting
      child sexual abuse (photographs, videos or computer-generated images).</li>
  <li>Harassing, threatening or sexually soliciting a minor.</li>
  <li>Publishing images or personal data of a minor without consent.</li>
</ul>
<p>Such content and accounts are <strong>removed</strong>, and where required we
<strong>report them to the authorities</strong>.</p>

<h3>2. How to report (inside the app)</h3>
<p>Reporting is available in the app, without leaving it:</p>
<ul>
  <li><strong>Comment or Chat message:</strong> the <em>Report</em> item in the
      menu next to the post.</li>
  <li><strong>Private conversation:</strong> the menu in the conversation header
      (<em>Report user</em>) — the same place as blocking and deleting the
      conversation.</li>
  <li><strong>Anything else:</strong> write to
      <a href="mailto:${CONTACT}">${CONTACT}</a>.</li>
</ul>
<p>Reporting requires a registered account; reports are reviewed by moderators and
the reported user never sees who reported them.</p>

<h3>3. What happens after a report?</h3>
<ul>
  <li>We review reports <strong>within 24 hours</strong>.</li>
  <li>Content that violates these standards is <strong>removed</strong> and the
      account is <strong>restricted or permanently banned</strong>.</li>
  <li>Where there is an indication of child sexual abuse, we <strong>forward the
      report to the authorities</strong> (in Hungary: the police; anonymous reports
      can also be filed via the
      <a href="https://www.biztonsagosinternet.hu" target="_blank" rel="noopener">Biztonságosinternet Hotline</a>).</li>
  <li>Users can also <strong>block</strong> each other and delete any conversation
      at any time.</li>
</ul>

<h3>4. Protection of minors in the app</h3>
<ul>
  <li>Using the community features requires providing a <strong>date of
      birth</strong>; it is <strong>hidden by default</strong> on your profile and
      you decide whether to show it.</li>
  <li>Reports involving minors are treated as a priority.</li>
  <li>The app has no separate experience for minors and follows Google's policies
      for ad settings.</li>
</ul>

<h3>5. Legal compliance and contact</h3>
<p>The operator complies with applicable child safety laws and investigates any
reported abuse involving children. <strong>Child safety contact:</strong>
<a href="mailto:${CONTACT}">${CONTACT}</a> (operator of ${APP_NAME}).</p>

<p><em>This notice applies to the ${APP_NAME} mobile application
(package name: ${PACKAGE}). Last updated: 27 September 2026.</em></p>
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
    console.log('Az oldal létezik, és --update nélkül nem írom felül.');
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

  // ÉLES ellenőrzés: a nyilvános oldal elérhető-e, és megvannak-e a Play által
  // kért elemek (működik, releváns, szerepel benne az app neve).
  const publicResponse = await fetch(link, { headers: { Accept: 'text/html' } });
  const html = await publicResponse.text();
  const checks = [
    ['az oldal elérhető (HTTP 200)', publicResponse.status === 200, `status=${publicResponse.status}`],
    ['a cím megjelenik', html.includes('Gyermekbiztonsági normák'), ''],
    ['az ékezetek helyesek', html.includes('visszaéléssel') && !html.includes('visszaÃ©lÃ©ssel'), ''],
    ['említi a gyermekek elleni szexuális visszaélést (CSAE)', /CSAE|szexuális visszaélés/i.test(html), ''],
    ['említi a CSAM-et', html.includes('CSAM'), ''],
    ['benne van az app neve', html.includes(APP_NAME), ''],
    ['benne van a csomagnév', html.includes(PACKAGE), ''],
    ['benne van az alkalmazáson belüli bejelentés', /alkalmazáson belül|inside the app/i.test(html), ''],
    ['benne van a kapcsolat', html.includes(CONTACT), ''],
    ['van angol szakasz', html.includes('Child Safety Standards (English)'), ''],
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
      : `Az oldal él. Ezt az URL-t kell a Play Console gyermekbiztonsági nyilatkozatába írni: ${link}`,
  );
  return failed ? 1 : 0;
}

const code = await main();
process.exit(code ?? 0);
