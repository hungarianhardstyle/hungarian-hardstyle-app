'use strict';

/**
 * A **WordPress-tartalom értesítések nyelve** — a tulajdonos jelzése:
 * *„most se angol a notifyban a cikk címe"*.
 *
 * A MÉRT GYÖKÉR: a `pollWordPressContentNotifications()` az angol listát már
 * lehúzta (`englishTitles`), de a létrehozáskor **csak a magyar cím** ment ki
 * (`params: { name }`), ezért az angol címzett magyar cikk-címet kapott.
 *
 * ⚠️ Ez a mérés a **használat alakját** kéri számon (nem azt, hogy „létezik"):
 * a `params.name` **nyelvi térkép** kell legyen, és a katalógus a címzett
 * nyelvén kell kiválassza az értéket.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const INDEX = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const { notificationText } = require('./notification-texts.js');

function pollerBody() {
  const start = INDEX.indexOf('async function pollWordPressContentNotifications()');
  assert.ok(start > 0, 'megvan a WordPress-tartalom értesítő kör');
  const end = INDEX.indexOf('exports.pollWordPressContentNotifications', start);
  assert.ok(end > start, 'megvan a kör vége');
  return INDEX.slice(start, end);
}

test('az angol cím is lejön a WordPressből (nyelvenkénti lista)', () => {
  const body = pollerBody();
  assert.match(body, /fetchList\('en'\)/, 'az angol lista lekérése megvan');
  assert.match(body, /englishTitles/, 'az angol címek térképe megvan');
});

test('a létrehozás NYELVI TÉRKÉPET ad át (nem csak a magyar címet)', () => {
  const body = pollerBody();
  assert.match(
    body,
    /const nameEn = String\(item\.englishTitles/,
    'a címzett nyelvéhez tartozó angol cím kiolvasása megvan',
  );
  assert.match(
    body,
    /const localizedName = nameEn && nameEn !== name \? \{ hu: name, en: nameEn \} : name;/,
    'a `name` paraméter nyelvenkénti térkép',
  );
  assert.match(body, /params: \{ name: localizedName \}/, 'a térkép megy ki a létrehozáskor');
});

test('a katalógus a címzett nyelvén választja ki a címet', () => {
  const params = { name: { hu: 'Magyar cím', en: 'English title' } };
  assert.equal(notificationText('new_news', 'en', params).body, 'English title');
  assert.equal(notificationText('new_news', 'hu', params).body, 'Magyar cím');
  assert.equal(notificationText('new_news', 'en', params).title, 'New article');
  assert.equal(notificationText('new_news', 'hu', params).title, 'Új hír érkezett');
});

test('a sima szöveges cím (régi hívó) változatlanul működik', () => {
  const text = notificationText('new_news', 'en', { name: 'Csak magyar cím' });
  assert.equal(text.body, 'Csak magyar cím');
});

test('hiányzó angol címnél a magyar marad (nincs üres értesítés)', () => {
  const text = notificationText('new_news', 'en', { name: { hu: 'Magyar cím' } });
  assert.equal(text.body, 'Magyar cím');
});
