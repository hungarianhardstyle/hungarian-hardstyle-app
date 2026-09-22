const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  SSV_VARIANTS,
  AD_UNLOCK_VARIANTS,
  CLIENT_UNLOCK_LIMITS,
  decodeSsvCustomData,
  normalizeAdUnlockRequest,
  mergeUnlockVariants,
  classifyVerifiedSsvCallback,
} = require('./admob-ssv-plan');

/**
 * Az AdMob jutalmazott **SSV-visszahívás** döntéseinek bizonyítása.
 *
 * A tulajdonos jelzése (2026-09-22): *„feloldó teszt reklám elindult, a terméket
 * nem kaptam meg"*. A mért gyökér: a feloldás kizárólag a szerveroldali
 * visszaigazoláson múlik, azt viszont csak az AdMob aláírt SSV-hívása hozza létre.
 *
 * ⚠️ ÉS a kezelő emellett **elutasította az AdMob konzol saját validátorát**:
 * a `missing reward data` ág az aláírás-ellenőrzés UTÁN futott, a validátor pedig
 * **valódi aláírással, de `custom_data` nélkül** hív (a `custom_data`-t a KLIENS
 * küldi `setServerSideOptions`-szal, a konzol mezője üres). Ezért az URL-t a
 * konzolban **soha nem lehetett érvényesíteni** — a napló háromszor mutatta
 * `{"reason":"missing reward data"}` közvetlenül a validátor kattintásai után.
 *
 * Futtatás: node --test functions/admob-ssv-plan.test.cjs
 */

/** A kliens `custom_data`-ja pontosan így épül (lásd label_purchase_service.dart). */
function encodeCustomData(payload) {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

test('a jóváírás csak érvényes, teljes custom_data-ból jön', () => {
  const raw = encodeCustomData({ uid: 'abc123', releaseId: 12405, variant: 'free_link' });
  const decoded = decodeSsvCustomData(raw);
  assert.deepEqual(decoded, { uid: 'abc123', releaseId: 12405, variant: 'free_link' });

  const decision = classifyVerifiedSsvCallback({ customData: raw, decoded });
  assert.equal(decision.action, 'grant');
  assert.equal(decision.uid, 'abc123');
  assert.equal(decision.releaseId, 12405);
  assert.equal(decision.variant, 'free_link');
});

test('a valodi alairassal jott, de URES custom_data az AdMob KONZOL validátora', () => {
  // ⚠️ EZ A JAVÍTÁS LÉNYEGE. Korábban itt 400 (`missing reward data`) jött, ezért
  // a konzol „URL ellenőrzése" mindig hibát írt, és a beállítás bizonytalan volt.
  for (const empty of ['', '   ', undefined, null]) {
    const decision = classifyVerifiedSsvCallback({ customData: empty, decoded: null });
    assert.equal(decision.action, 'validate', `custom_data: ${JSON.stringify(empty)}`);
  }
  // ...és jóváírást TERMÉSZETESEN nem ad, mert nem tudjuk, kinek szólna.
  assert.equal(classifyVerifiedSsvCallback({ customData: '' }).uid, undefined);
});

test('a hibas custom_data NEM validal, hanem elutasit (nem lehet kitalalni a jutalmat)', () => {
  const cases = [
    'nem-base64-json',
    Buffer.from('hello', 'utf8').toString('base64url'),
    encodeCustomData({ uid: 'abc', releaseId: 0, variant: 'free_link' }),
    encodeCustomData({ uid: '', releaseId: 12, variant: 'free_link' }),
    encodeCustomData({ uid: 'abc', releaseId: 1.5, variant: 'free_link' }),
    encodeCustomData({ uid: 'abc', releaseId: -3, variant: 'free_link' }),
    encodeCustomData({ uid: 'abc', releaseId: 12, variant: 'wav' }),
    encodeCustomData({ uid: 'abc', releaseId: 12, variant: 'MP3_128' }),
  ];
  for (const raw of cases) {
    const decoded = decodeSsvCustomData(raw);
    const decision = classifyVerifiedSsvCallback({ customData: raw, decoded });
    assert.equal(decision.action, 'reject', `várt elutasítás: ${raw.slice(0, 40)}`);
    assert.equal(decision.reason, 'invalid reward data');
  }
});

test('az ismeretlen valtozat nem megy at, de az osszes ismert igen', () => {
  for (const variant of SSV_VARIANTS) {
    const raw = encodeCustomData({ uid: 'u', releaseId: 7, variant });
    const decision = classifyVerifiedSsvCallback({
      customData: raw,
      decoded: decodeSsvCustomData(raw),
    });
    assert.equal(decision.action, 'grant', `várt jóváírás: ${variant}`);
  }
  // A `free_link` külön figyelmet érdemel: a 349-es hiba pont ez volt.
  assert.ok(SSV_VARIANTS.includes('free_link'));
});

test('a hianyzo variant alapertelmezese mp3_128 (a regi kliensek miatt)', () => {
  // ⚠️ Az ÜRES és a HIÁNYZÓ változat is `mp3_128` — ez szándékos
  // visszamenőleges kompatibilitás (a régi kliensek nem küldtek változatot),
  // ezért ez NEM hibaeset, hanem elfogadott jóváírás.
  for (const variant of [undefined, '', null]) {
    const raw = encodeCustomData({ uid: 'u', releaseId: 7, variant });
    assert.equal(decodeSsvCustomData(raw).variant, 'mp3_128');
  }
});

test('a szokozoket levagja, de a NAGYBETUT nem fogadja el', () => {
  // A `custom_data` URL-ből jön, ezért a whitespace levágása szándékos
  // (különben egy ártalmatlan szóköz miatt veszne el a jutalom)...
  const padded = encodeCustomData({ uid: ' u7 ', releaseId: 5, variant: ' mp3_96 ' });
  assert.deepEqual(decodeSsvCustomData(padded), {
    uid: 'u7',
    releaseId: 5,
    variant: 'mp3_96',
  });
  // ...a nagybetűs változat viszont NEM ugyanaz, mint a kisbetűs: ne találgassunk.
  const upper = encodeCustomData({ uid: 'u7', releaseId: 5, variant: 'MP3_96' });
  assert.equal(decodeSsvCustomData(upper), null);
});

test('a URL-kodolt custom_data is kibontható', () => {
  const raw = encodeCustomData({ uid: 'u9', releaseId: 3, variant: 'mp3_96' });
  const encoded = encodeURIComponent(raw);
  const decoded = decodeSsvCustomData(encoded);
  assert.deepEqual(decoded, { uid: 'u9', releaseId: 3, variant: 'mp3_96' });
});

test('forras-lint: a kezelo a tiszta modult hasznalja, es NEM ad 400-at a probara', () => {
  // ⚠️ A hiba a BEKÖTÉSBEN élt, nem a szabályban — ezért a forrást is mérjük,
  // különben a döntés visszacsúszhat a kezelőbe, és a teszt zölden elfedné.
  const source = fs
    .readFileSync(path.join(__dirname, 'index.js'), 'utf8')
    .replace(/\r\n/g, '\n');

  assert.match(source, /require\('\.\/admob-ssv-plan'\)/);
  assert.match(source, /classifyVerifiedSsvCallback\(\{ customData, decoded \}\)/);
  assert.match(source, /decodeSsvCustomData\(customData\)/);
  assert.doesNotMatch(
    source,
    /reject\('missing reward data'\)/,
    'a validátor próbája nem utasítható el 400-zal — a konzol akkor nem tudja érvényesíteni az URL-t',
  );

  // Az aláírás-ellenőrzés maradjon AZELŐTT, hogy bármit jóváírnánk: az aláírást
  // nem lehet megkerülni a `custom_data`-val.
  const verifyIndex = source.indexOf("if (!valid) return reject('invalid signature');");
  const grantIndex = source.indexOf('const { uid, releaseId, variant } = decision;');
  assert.ok(verifyIndex > 0 && grantIndex > verifyIndex,
    'a jóváírás CSAK az aláírás-ellenőrzés után történhet');
  assert.doesNotMatch(source, /reject\('invalid reward data'\)/,
    'a döntés a tiszta modulban van, nem a kezelőben');

  // ⚠️ A sikeres jóváírás is legyen mérhető a naplóból: enélkül egy „lefutott a
  // reklám, mégsem nyílt meg" hibát nem lehet visszamérni (csak a Firestore-ból).
  assert.match(source, /event: 'admob_ssv_granted'/);
  assert.match(source, /event: 'admob_ssv_probe_validated'/);
});

test('a KLIENS-oldali azonnali jovairas bemenetet ugyanaz a szabaly ellenorzi', () => {
  // ⚠️ A tulajdonosi döntés (2026-09-22, „B"): a jutalom a kliens
  // visszahívásából AZONNAL jár, az SSV csak utólag igazol. A bemenet
  // ellenőrzése ezért UGYANAZ, mint az SSV-nél — egy helyen él.
  assert.deepEqual(normalizeAdUnlockRequest({ releaseId: 12405, variant: 'free_link' }), {
    ok: true,
    releaseId: 12405,
    variant: 'free_link',
  });
  // A hiányzó változat a kliens alapértéke: mp3_96 (nem mp3_128 — az az SSV
  // visszamenőleges alapértéke).
  assert.deepEqual(normalizeAdUnlockRequest({ releaseId: 7 }), {
    ok: true,
    releaseId: 7,
    variant: 'mp3_96',
  });

  for (const bad of [
    { releaseId: 0, variant: 'free_link' },
    { releaseId: -2, variant: 'free_link' },
    { releaseId: 1.5, variant: 'free_link' },
    { releaseId: 'abc', variant: 'free_link' },
    { releaseId: 12, variant: 'wav' },
    { releaseId: 12, variant: 'PAID' },
  ]) {
    const result = normalizeAdUnlockRequest(bad);
    assert.equal(result.ok, false, `várt elutasítás: ${JSON.stringify(bad)}`);
    assert.ok(result.reason.length > 0);
  }
});

test('a valtozat-térkép bővítése NEM veszíti el a korábbi változatokat', () => {
  // A 349-es hiba pont egy elveszett változat volt (`free_link`): ha a
  // jóváírás felülírná a térképet, a korábban kiváltott jogosultság tűnne el.
  assert.deepEqual(mergeUnlockVariants({ mp3_96: true }, 'free_link'), {
    mp3_96: true,
    free_link: true,
  });
  assert.deepEqual(mergeUnlockVariants(undefined, 'mp3_128'), { mp3_128: true });
  // Szemét bemenet (tömb, szöveg) ne törje el a mentést.
  assert.deepEqual(mergeUnlockVariants(['mp3_96'], 'mp3_96'), { mp3_96: true });
  assert.deepEqual(mergeUnlockVariants('semmi', 'mp3_96'), { mp3_96: true });
  // És a bemenetet NE módosítsa (a Firestore adata közös referenciában él).
  const original = { mp3_96: true };
  mergeUnlockVariants(original, 'free_wav');
  assert.deepEqual(original, { mp3_96: true });
});

test('a kliens-oldali jovairas keretei: percenkenti burst ES napi plafon', () => {
  const { burst, daily } = CLIENT_UNLOCK_LIMITS;
  assert.equal(burst.windowMs, 60_000);
  assert.equal(daily.windowMs, 24 * 60 * 60 * 1000);
  // A napi keret a valódi megkötés: nem szabad kisebbnek lennie a burstnél,
  // különben egy szorgalmas felhasználó a burst miatt akadna el.
  assert.ok(daily.limit > burst.limit, 'a napi keret legyen nagyobb a burstnél');
  // És a két vödör NE ugyanaz a kulcs legyen, különben az egyik keret elnyelné
  // a másikat (a bucket csak az ablak hosszában tér el).
  assert.notEqual(burst.key, daily.key);
});

test('a harom valtozat-lista ugyanaz (nem tud szethuzni)', () => {
  assert.deepEqual([...AD_UNLOCK_VARIANTS], [...SSV_VARIANTS]);
  assert.ok(AD_UNLOCK_VARIANTS.includes('free_link'));
});
