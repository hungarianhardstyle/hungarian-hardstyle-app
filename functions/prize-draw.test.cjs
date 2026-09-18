const { test, before, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

/**
 * A nyeremenyjatek sorsolasanak VALODI viselkedese.
 *
 * A tulajdonosi szabalyok, amelyeket ez a teszt lefed:
 *  * CSAK helyes valaszt adott jatekos nyerhet;
 *  * a nyertes bekerul a WordPressbe (a szerver oldal a "forras"),
 *    a Firebase pedig ertesit (app-ertesites + push + e-mail);
 *  * a nyertes E-MAIL-CIME a Firebase Auth-bol jon, nem a WordPressbol;
 *  * a sorsolas IDEMPOTENS: a negyedes fuves utemezes nem hirdet masodik
 *    nyertest, es nem kuld masodik levelet sem;
 *  * a nyertes nevere/kerdesere a level HTML-jeben escape kerul (nincs
 *    HTML-beszuras egy felhasznaloi neven keresztul).
 *
 * A teszt a VALODI `__drawPrizeWinnerForTests` fuggvenyt hivja a
 * Firestore-emulatoron, KIZAROLAG a halozati hivast (`fetch`), a WordPress
 * jelszot, az Auth-keresest es a levelkuldest helyettesitve. Igy a
 * tranzakcio, a jelzo-dokumentum es az elagazasok tenylegesen futnak.
 *
 * Futtatas (a repository gyokerebol):
 *   npx firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/prize-draw.test.cjs"
 */

const projectId = process.env.GCLOUD_PROJECT || 'demo-huhs';
const databaseId = 'hungarian-hardstyle';

// FONTOS a sorrend: a `./index.js` betolteskor `admin.initializeApp()`-et hiv,
// ezert a DEFAULT appnak MAR LETEZNIE kell ugyanazzal a projekt-azonosítóval.
const app = initializeApp({ projectId });
const db = getFirestore(app, databaseId);

const { __drawPrizeWinnerForTests: draw } = require('./index.js');

const PENDING = {
  id: 4242,
  question: 'Melyik evben alakult a HUHS?',
  prize_type: 'HUHS póló',
  prize_description: 'Méret egyeztetés után postázzuk.',
  correct_count: 2,
};

const PLAYERS = [
  { hash: 'hash-a', name: 'Első Játékos', uid: 'uid-alpha' },
  { hash: 'hash-b', name: 'Második Játékos', uid: 'uid-beta' },
];

let fetchCalls = [];
let participantPayload = { prizeId: 4242, correctCount: 2, players: PLAYERS, hashes: ['hash-a', 'hash-b'] };
let winnerPayload = { ok: true, alreadyDrawn: false, winner: 'Első Játékos' };
let participantsStatus = 200;
let winnerStatus = 200;
let participantsError = null;
let winnerError = null;
let emails = [];
let emailFailure = null;
let authEmails = { 'uid-alpha': 'alpha@example.com', 'uid-beta': 'beta@example.com' };
let authLookupFailure = null;

/** A halozati hatar egyetlen helyen: minden WordPress hivas itt landol. */
function installFetchStub() {
  globalThis.fetch = async (url, options = {}) => {
    const record = {
      url: String(url),
      method: String(options.method || 'GET'),
      authorization: String(options.headers?.Authorization || ''),
      body: options.body ? JSON.parse(options.body) : null,
    };
    fetchCalls.push(record);
    if (record.url.includes('/prize/participants')) {
      if (participantsError) throw new Error(participantsError);
      return {
        ok: participantsStatus >= 200 && participantsStatus < 300,
        status: participantsStatus,
        json: async () => participantPayload,
      };
    }
    if (record.url.includes('/prize/winner')) {
      if (winnerError) throw new Error(winnerError);
      return {
        ok: winnerStatus >= 200 && winnerStatus < 300,
        status: winnerStatus,
        json: async () => winnerPayload,
      };
    }
    throw new Error(`Váratlan URL a tesztben: ${record.url}`);
  };
}

/** A Firebase Auth helyettese: a cimet UID alapjan adja. */
const authStub = {
  getUser: async (uid) => {
    if (authLookupFailure) throw new Error(authLookupFailure);
    if (!(uid in authEmails)) {
      const error = new Error('no user record');
      error.code = 'auth/user-not-found';
      throw error;
    }
    return { uid, email: authEmails[uid] };
  },
};

function deps() {
  return {
    db,
    auth: authStub,
    credentials: 'test-user:test-pass',
    sendMail: async (message) => {
      if (emailFailure) throw Object.assign(new Error('smtp-send-failed'), { smtpCode: emailFailure });
      emails.push(message);
      return { attempts: 1, messageId: 'test' };
    },
  };
}

/** A push es az app-ertesites kimenetet figyeljük, hogy ne menjen ki valodi kereses. */
async function resetDatabase() {
  for (const name of ['prize_draws', 'notifications']) {
    const snapshot = await db.collection(name).get();
    if (snapshot.empty) continue;
    const batch = db.batch();
    for (const document of snapshot.docs) batch.delete(document.ref);
    await batch.commit();
  }
}

before(() => {
  installFetchStub();
  // A push-utvonal nem eri el a valodi FCM-et: nincs beregisztrált eszkoz-token a
  // friss emulatoros adatbazisban, ezert a `sendAchievementPushBestEffort()`
  // meg sem probal kuldeni (a `getPushTokens()` ures listat ad).
});

beforeEach(async () => {
  fetchCalls = [];
  emails = [];
  participantPayload = { prizeId: 4242, correctCount: 2, players: PLAYERS, hashes: ['hash-a', 'hash-b'] };
  winnerPayload = { ok: true, alreadyDrawn: false, winner: 'Első Játékos' };
  participantsStatus = 200;
  winnerStatus = 200;
  participantsError = null;
  winnerError = null;
  emailFailure = null;
  authEmails = { 'uid-alpha': 'alpha@example.com', 'uid-beta': 'beta@example.com' };
  authLookupFailure = null;
  installFetchStub();
  await resetDatabase();
});

/* --- 1. Ki nyerhet egyaltalan ------------------------------------------ */

test('helyes valasz nelkul nincs sorsolas (nincs kit hirdetni)', async () => {
  participantPayload = { prizeId: 4242, correctCount: 0, players: [], hashes: [] };
  const drawn = await draw([PENDING], deps());
  assert.deepEqual(drawn, []);
  assert.equal(fetchCalls.some((call) => call.url.includes('/prize/winner')), false);
  assert.equal(emails.length, 0);
});

test('a nyertes MINDIG a helyes valaszt adok kozul kerul ki', async () => {
  // A WordPress csak a helyeseket adja vissza; a sorsolas ebbol a listabol valaszt.
  await draw([PENDING], deps());
  const winnerCall = fetchCalls.find((call) => call.url.includes('/prize/winner'));
  assert.ok(winnerCall, 'a nyertest be kellett irni a WordPressbe');
  assert.ok(PLAYERS.some((player) => player.uid === winnerCall.body.uid));
});

test('a sorsolas tobb jatekosnal is a listan belul valaszt (20 futas)', async () => {
  for (let index = 0; index < 20; index += 1) {
    await resetDatabase();
    fetchCalls = [];
    await draw([PENDING], deps());
    const call = fetchCalls.find((entry) => entry.url.includes('/prize/winner'));
    assert.ok(PLAYERS.some((player) => player.uid === call.body.uid));
  }
});

test('a sorsolas NEM favorizalja az ELSO bekuldot (200 huzas, valodi veletlen)', async () => {
  // A tulajdonos jelzese: „azt is nézd meg, hogy valóban random e a sorsolás,
  // mivel én voltam az első beküldő és engem sorsolt nyertesnek".
  //
  // Ez a legfontosabb kerdes: ha a sorsolas mindig az ELSO jelolttel kezdene
  // (peldaul `players[0]` vagy egy rossz index), akkor aki elsonek jatszott,
  // mindig nyerne. Ezert itt a VALODI sorsolast futtatjuk sokszor ugyanazzal a
  // jeloltlistaval, es megnezzuk, hogy az elso jatekos nem nyer mindig.
  //
  // A `crypto.randomInt` a Node kriptografiailag biztonsagos generatora; a
  // mérés 200 huzas, tehat ha barmilyen elfogultsag lenne az elso index fele,
  // az itt azonnal latszana.
  const runs = 200;
  let firstPlayerWins = 0;
  for (let index = 0; index < runs; index += 1) {
    await resetDatabase();
    fetchCalls = [];
    await draw([PENDING], deps());
    const call = fetchCalls.find((entry) => entry.url.includes('/prize/winner'));
    if (call.body.uid === PLAYERS[0].uid) firstPlayerWins += 1;
  }

  // Elvaras: mindenki kb. a huzasok harmadat nyeri (2 jelolt -> ~50%).
  // A hatar szandekosan tag, hogy NE legyen „flaky": a lenyeg az, hogy az elso
  // jatekos NEM nyer mindig, es a tobbiek is nyernek.
  assert.ok(
    firstPlayerWins > 0 && firstPlayerWins < runs,
    `az elso jatekos nem nyerhet mindig (nyert: ${firstPlayerWins}/${runs})`,
  );
  assert.ok(
    firstPlayerWins > runs * 0.2 && firstPlayerWins < runs * 0.8,
    `az elso jatekos nyerese korulbelul fele legyen (nyert: ${firstPlayerWins}/${runs})`,
  );
  assert.ok(
    runs - firstPlayerWins > 0,
    'a masodik jatekos is nyer legalabb egyszer',
  );
});

test('a sorsolas dontese naplozva van (hany jogosult, melyik sorszam)', async () => {
  // Audit: a tulajdonos visszamenoleg ellenorizhesse, mi tortent.
  await draw([PENDING], deps());
  const claim = await db.collection('prize_draws').doc('4242').get();
  const data = claim.data();
  assert.equal(data.eligibleCount, PLAYERS.length);
  assert.ok(Number.isInteger(data.chosenIndex));
  assert.ok(data.chosenIndex >= 0 && data.chosenIndex < PLAYERS.length);
  assert.equal(data.winnerUid, PLAYERS[data.chosenIndex].uid, 'a nyertes a naplozott sorszam');
  assert.equal(typeof data.candidatesHash, 'string');
  assert.equal(data.candidatesHash.length, 32);
});

/* --- 2. A WordPress-be iras -------------------------------------------- */

test('a nyertes bekerul a WordPressbe, a jatekos NEVEl es a UID-javal', async () => {
  await draw([PENDING], deps());
  const winnerCall = fetchCalls.find((call) => call.url.includes('/prize/winner'));
  assert.equal(winnerCall.method, 'POST');
  assert.equal(winnerCall.body.prizeId, 4242);
  assert.equal(winnerCall.body.displayName, PLAYERS.find((p) => p.uid === winnerCall.body.uid).name);
  assert.match(winnerCall.authorization, /^Basic /);
});

test('a sorsolas elfogadja, ha a WordPress szerint MAR volt nyertes (nincs ertesites)', async () => {
  winnerPayload = { ok: true, alreadyDrawn: true, winner: 'Korabbi Nyertes' };
  const drawn = await draw([PENDING], deps());
  assert.deepEqual(drawn, []);
  assert.equal(emails.length, 0);
  const claim = await db.collection('prize_draws').doc('4242').get();
  assert.equal(claim.exists, false, 'a jelzot sem szabad kirakni, mert nem a mi nyertesunk');
});

test('a WordPress hibaja nem allitja meg a tobbi jatekot', async () => {
  const second = { ...PENDING, id: 4243, question: 'Masodik kerdes' };
  // Az elso jatek beirasa 500-at kap, a masodike sikerul.
  globalThis.fetch = async (url, options = {}) => {
    const target = String(url);
    const record = {
      url: target,
      method: String(options.method || 'GET'),
      authorization: String(options.headers?.Authorization || ''),
      body: options.body ? JSON.parse(options.body) : null,
    };
    fetchCalls.push(record);
    if (target.includes('/prize/participants')) {
      return {
        ok: true,
        status: 200,
        json: async () => ({ ...participantPayload, prizeId: target.includes('4242') ? 4242 : 4243 }),
      };
    }
    if (target.includes('/prize/winner')) {
      if (record.body.prizeId === 4242) {
        return { ok: false, status: 500, json: async () => ({ message: 'Szerverhiba' }) };
      }
      return { ok: true, status: 200, json: async () => winnerPayload };
    }
    throw new Error(`Váratlan URL a tesztben: ${target}`);
  };
  const drawn = await draw([PENDING, second], deps());
  assert.deepEqual(
    drawn.map((item) => item.prizeId),
    [4243],
    'csak a sikeresen beirt jatek szamit sorsolasnak',
  );
  assert.equal(emails.length, 1, 'a hibas jatekhoz nem megy level');
});

test('a /prize/participants hibat kap -> abban a korben nincs sorsolas', async () => {
  participantsStatus = 403;
  participantPayload = { message: 'Nincs jogosultság.' };
  const drawn = await draw([PENDING], deps());
  assert.deepEqual(drawn, []);
  assert.equal(fetchCalls.some((call) => call.url.includes('/prize/winner')), false);
});

/* --- 3. Idempotencia ---------------------------------------------------- */

test('a masodik futas NEM hirdet uj nyertest es NEM kuld uj levelet', async () => {
  await draw([PENDING], deps());
  const firstEmails = emails.length;
  assert.equal(firstEmails, 1);
  // A VALODI WordPress a masodik beirast mar elutasítja: `alreadyDrawn: true`.
  // Ezt a valaszt a stub adja vissza, tehat a „masodik kor” husege a lenyeg.
  winnerPayload = { ok: true, alreadyDrawn: true, winner: 'Első Játékos' };
  const second = await draw([PENDING], deps());
  assert.deepEqual(second, [], 'a WordPress „alreadyDrawn” jelzese utan nincs uj nyertes');
  assert.equal(emails.length, firstEmails, 'a level csak egyszer megy ki');
  // A WordPress idempotens beirasa probalkozik megint (ez a vedelem masodik retege),
  // de nem hirdet mast.
  assert.equal(fetchCalls.filter((call) => call.url.includes('/prize/winner')).length, 2);
});

test('az ertesitesi jelzo a jatek azonositojaval keletkezik', async () => {
  await draw([PENDING], deps());
  const claim = await db.collection('prize_draws').doc('4242').get();
  assert.equal(claim.exists, true);
  assert.equal(claim.data().winnerUid, fetchCalls.find((c) => c.url.includes('/prize/winner')).body.uid);
});

/* --- 4. Az e-mail ------------------------------------------------------- */

test('a nyertes e-mail-cime a Firebase Auth-bol jon, nem a WordPressbol', async () => {
  await draw([PENDING], deps());
  assert.equal(emails.length, 1);
  const winnerUid = fetchCalls.find((call) => call.url.includes('/prize/winner')).body.uid;
  assert.equal(emails[0].to, authEmails[winnerUid]);
  // A WordPress fele menő testben SOHA nem lehet e-mail-cim.
  for (const call of fetchCalls) {
    assert.equal(JSON.stringify(call.body || {}).includes('@'), false, 'e-mail-cim nem mehet a WordPressbe');
  }
});

test('a level tartalmazza a nyeremeny nevet es leirasat', async () => {
  await draw([PENDING], deps());
  assert.match(emails[0].subject, /nyereményjáték/);
  assert.ok(emails[0].text.includes('HUHS póló'));
  assert.ok(emails[0].text.includes('Méret egyeztetés után postázzuk.'));
});

test('a level HTML-jeben escape kerul a jatekos nevere (nincs beszuras)', async () => {
  participantPayload = {
    prizeId: 4242,
    correctCount: 1,
    players: [{ hash: 'hash-x', name: '<img src=x onerror=alert(1)>', uid: 'uid-alpha' }],
    hashes: ['hash-x'],
  };
  await draw([PENDING], deps());
  assert.equal(emails.length, 1);
  assert.equal(emails[0].html.includes('<img src=x'), false);
  assert.ok(emails[0].html.includes('&lt;img src=x onerror=alert(1)&gt;'));
});

test('ha a fiok megszunt (nincs Auth-cim), az ertesites akkor is megtortenik', async () => {
  authLookupFailure = 'auth/user-not-found';
  const drawn = await draw([PENDING], deps());
  assert.equal(drawn.length, 1, 'a sorsolas eredmenye nem veszik el');
  assert.equal(emails.length, 0);
  const claim = await db.collection('prize_draws').doc('4242').get();
  assert.equal(claim.exists, true, 'a jelzo akkor is kirakva, hogy ne probalkozzon orokke');
});

test('az SMTP-hiba nem boritja fel a sorsolast', async () => {
  emailFailure = 'EAUTH';
  const drawn = await draw([PENDING], deps());
  assert.equal(drawn.length, 1);
  assert.equal(emails.length, 0);
});

test('a WordPress hivasok application password-del mennek (a jatekos UID-ja nem kliens-adat)', async () => {
  await draw([PENDING], deps());
  for (const call of fetchCalls) {
    assert.match(call.authorization, /^Basic /);
  }
});

/* --- 5. Forras-invariansok --------------------------------------------- */

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const codeOnly = source
  .split('\n')
  .filter((line) => {
    const trimmed = line.trim();
    return !trimmed.startsWith('//') && !trimmed.startsWith('*') && !trimmed.startsWith('/*');
  })
  .join('\n');

test('a sorsolo utemezes 5 percenkent fut, a WordPress es SMTP titkokkal', () => {
  const start = codeOnly.indexOf('exports.drawPrizeWinner = onSchedule(');
  assert.ok(start > 0, 'letezik a drawPrizeWinner utemezett fuggveny');
  const section = codeOnly.slice(start, start + 700);
  assert.match(section, /schedule: 'every 5 minutes'/);
  assert.match(section, /timeZone: 'Europe\/Budapest'/);
  assert.ok(section.includes('WORDPRESS_USERNAME'));
  assert.ok(section.includes('WORDPRESS_APPLICATION_PASSWORD'));
  assert.ok(section.includes('...SMTP_SECRETS'));
});

test('a sorsolas a lezart, meg nem sorsolt jatekokat keri le', () => {
  assert.ok(codeOnly.includes("`${WORDPRESS_BASE_URL}/prize/pending`"));
});

test('a helyességet a szerver donti el, a kliens csak indexet kuld', () => {
  const start = codeOnly.indexOf('exports.prizeVote = functions');
  const end = codeOnly.indexOf('/** A nyertesnek szolo level');
  const section = codeOnly.slice(start, end);
  assert.ok(section.includes('answerIndex'), 'a kliens csak a valasztott indexet kuldheti');
  assert.equal(
    /correctIndex|correct_index|correctAnswer/.test(section),
    false,
    'a kliens oldali fuggveny nem ismerheti a helyes valaszt',
  );
  assert.ok(codeOnly.includes("'/prize/enter'"));
  assert.ok(codeOnly.includes("'/prize/status'"));
});

test('a prizeVote regisztralt fiokot igenyel es rate-limitelt', () => {
  const start = codeOnly.indexOf('exports.prizeVote = functions');
  const section = codeOnly.slice(start, start + 1800);
  assert.ok(section.includes('requireRegisteredViewer(context)'));
  assert.ok(section.includes("allowCall(uid, 'prize_vote', 20)"));
});

test('a nyertes ertesitese egyszeri jelzohoz kotott (nem kuld ketszer)', () => {
  const start = codeOnly.indexOf('async function drawPrizeWinnerForPrizes(');
  const section = codeOnly.slice(start, start + 6000);
  assert.ok(section.includes("collection('prize_draws')"));
  assert.ok(section.includes('if (snapshot.exists) return;'));
  assert.ok(section.includes('if (!fresh) {'));
});

test('a nyertes e-mail-cime kizarolag az Auth-bol jon', () => {
  const start = codeOnly.indexOf('async function drawPrizeWinnerForPrizes(');
  const section = codeOnly.slice(start, start + 6000);
  assert.ok(section.includes('authApi.getUser(winnerUid)'));
  assert.equal(
    /email\s*[:=]\s*.*payload|correct_count.*email/i.test(section),
    false,
    'a WordPress valaszabol nem olvasunk e-mail-cimet',
  );
});

test('az idempotencia a WordPress oldalon is vedett (alreadyDrawn)', () => {
  assert.ok(codeOnly.includes("result?.alreadyDrawn === true"));
});
