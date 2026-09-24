/**
 * A cselekvő nevének kiválasztása az értesítésekhez — `actor-name-plan.js`.
 *
 * **A tulajdonos jelzése (2026-09-24):** *„jön notify hogy kedvelték egy chat
 * üzenetem, meg arról is hogy valaki írt egy hírhez kommentet, de odaírhatná,
 * hogy KI likeolta"*.
 *
 * **A mért adat (éles `notifications` gyűjtemény, csak olvasva):** az 5
 * chat-lájk értesítésből **2-ben nem volt név** („Egy HUHS tag kedvelte a
 * Chat-üzenetedet."), viszont a küldő profiljában **mindkét esetben volt**
 * `displayName` (`community_profiles` ÉS `public_profiles`) — vagyis a név
 * elérhető, csak egyetlen forrásból olvastuk.
 *
 * Ez a teszt a **kiválasztás szabályát** rögzíti: sorrend, üres értékek,
 * hosszkorlát, és hogy ismeretlen névnél **nem találgatunk**.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  MAX_NAME_LENGTH,
  pickActorName,
  actorNameOrGeneric,
} = require('./actor-name-plan.js');

test('a közösségi profil a hiteles forrás', () => {
  assert.equal(
    pickActorName({
      communityName: 'Szintus',
      publicName: 'Maske',
      authName: 'auth-name',
    }),
    'Szintus',
  );
});

test('ha a közösségi profil üres, a nyilvános profil jön', () => {
  assert.equal(pickActorName({ communityName: '', publicName: 'Szintus' }), 'Szintus');
  assert.equal(
    pickActorName({ communityName: '   ', publicName: 'Andrew Louis Smith' }),
    'Andrew Louis Smith',
  );
});

test('ha mindkét profil üres, az Auth-név a tartalék', () => {
  assert.equal(pickActorName({ authName: 'gyulahardstylehardcorefanhun' }), 'gyulahardstylehardcorefanhun');
});

test('ha egyik forrásban sincs név, üres marad (nem találgatunk)', () => {
  assert.equal(pickActorName({}), '');
  assert.equal(pickActorName({ communityName: '', publicName: '  ', authName: null }), '');
  assert.equal(pickActorName(), '');
});

test('a név hossza korlátozott (a szöveg ne hízjon el)', () => {
  const long = 'a'.repeat(200);
  assert.equal(pickActorName({ communityName: long }).length, MAX_NAME_LENGTH);
});

test('a megjelenített szöveghez általános alak jön, ha nincs név', () => {
  assert.equal(actorNameOrGeneric({ communityName: 'Kobakologia' }), 'Kobakologia');
  assert.equal(actorNameOrGeneric({}), 'Egy HUHS tag');
  assert.equal(actorNameOrGeneric({}, 'Valaki'), 'Valaki');
});
