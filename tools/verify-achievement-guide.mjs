#!/usr/bin/env node
/**
 * Az Achievement-ÚTMUTATÓ szövegét a VALÓS KÓDHOZ köti.
 *
 * MIÉRT: a `Több → Achievementek` képernyő szövegei **elavultak és pontatlanok**
 * voltak, és semmi nem őrizte őket:
 *  * azt írta, hogy a lájk visszavonásakor elvész a pont (a javítás óta nem igaz);
 *  * azt írta, hogy a cikkkommentért naponta **5** jár (valójában **3**);
 *  * két sor („Kiadvány megvásárlása", „Közösségi aktivitás") mögött **nem volt
 *    szabály** a kódban.
 *
 * A GYIK-nél (`tools/verify-faq-content.mjs`) ez a kapu már bevált: a szöveget a
 * kódból kiolvasott értékekhez köti, ezért egy elavulás **elhasal**, nem csendben
 * marad. Ugyanezt teszi itt: a `functions/index.js`-ből olvassa ki a pontértékeket,
 * a napi kereteket és a létező pontforrásokat, majd megköveteli, hogy az útmutató
 * ugyanazt írja.
 *
 * Futtatás: node tools/verify-achievement-guide.mjs
 * Önteszt:  node tools/verify-achievement-guide.mjs --self-test
 */
import fs from 'node:fs';

const FUNCTIONS_PATH = 'functions/index.js';
const GUIDE_PATH = 'lib/screens/more/achievement_guide_screen.dart';

/** Egy sor (tevékenység) blokkja az útmutatóban: a címtől a sor végéig. */
export function rowBlock(source, title) {
  const index = source.indexOf(`title: '${title}'`);
  if (index < 0) return null;
  const end = source.indexOf('\n    ),', index);
  return source.slice(index, end < 0 ? index + 900 : end);
}

function numberFrom(source, pattern) {
  const match = pattern.exec(source);
  if (!match) return null;
  const numbers = [...match[0].matchAll(/-?\d+/g)].map((hit) => Math.abs(Number(hit[0])));
  // A `sourceKey` azonosítójában is lehet szám (pl. `news-like`), ezért a
  // legnagyobb értelmes pontszámot vesszük.
  const candidates = numbers.filter((value) => value > 0 && value <= 1000);
  return candidates.length ? Math.max(...candidates) : null;
}

/** A kódból kiolvasott tények (a kapu ezekhez köti a szöveget). */
export function readCodeFacts(functionsSource) {
  const constant = (name) => {
    const match = new RegExp(`${name}\\s*=\\s*(\\d+)`).exec(functionsSource);
    return match ? Number(match[1]) : null;
  };
  return {
    newsLikeLimit: constant('NEWS_LIKE_DAILY_POINT_LIMIT'),
    commentLimit: constant('ARTICLE_COMMENT_DAILY_POINT_LIMIT'),
    submissionLimit: constant('APPROVED_SUBMISSION_DAILY_POINT_LIMIT'),
    submissionPoints: constant('APPROVED_SUBMISSION_POINTS'),
    releasePoints: constant('RELEASE_PURCHASE_POINTS'),
    dailyActivityMax: constant('DAILY_ACTIVITY_MAX_POINTS'),
    newsLike: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*2,\s*`news-like:/),
    comment: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*1,\s*`article-comment:/),
    attendance: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*afterAttending \? [^,]+,\s*`attendance:/),
    meetup: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*-?5,\s*`meetup:/),
    meetupInterest: numberFrom(functionsSource, /awardAchievementPoints\(interestedUid,\s*-?15,\s*`meetup-interest:/),
    eventRating: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*10,\s*`event-rating:/),
    voting: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*10,\s*`voting:/),
    profileComplete: numberFrom(functionsSource, /awardAchievementPoints\(uid,\s*30,\s*'profile-complete'\)/),
    referral: numberFrom(functionsSource, /awardAchievementPoints\(invitedBy,\s*50,\s*`referral:/),
    gameSource: /game:\$\{gameId\}:reward/.test(functionsSource),
    submissionSource: /`submission:\$\{kind\}/.test(functionsSource),
    releaseSource: /`release-purchase:\$\{/.test(functionsSource),
    dailyActivitySource: /`daily-activity:\$\{/.test(functionsSource),
    commentCounter: /recordDailyActivity\(uid, 'comments'\)/.test(functionsSource),
    chatCounter: /recordDailyActivity\(uid, 'chatMessages'\)/.test(functionsSource),
  };
}

/** Az útmutató szövegének vizsgálata (tiszta → önteszttel bizonyítható). */
export function analyzeGuide({ functionsSource, guideSource }) {
  const facts = readCodeFacts(functionsSource);
  const checks = [];
  const check = (label, ok, detail = '') => checks.push({ label, ok: Boolean(ok), detail });

  const row = (title) => rowBlock(guideSource, title);
  const has = (title, needle) => {
    const block = row(title);
    return Boolean(block && block.includes(needle));
  };

  check(
    'a kódból kiolvashatók a pontértékek és a napi keretek',
    facts.newsLikeLimit === 3 &&
      facts.commentLimit === 3 &&
      facts.submissionLimit === 3 &&
      facts.newsLike === 2 &&
      facts.comment === 1 &&
      facts.attendance === 10 &&
      facts.meetup === 5 &&
      facts.meetupInterest === 15 &&
      facts.eventRating === 10 &&
      facts.voting === 10 &&
      facts.profileComplete === 30 &&
      facts.referral === 50 &&
      facts.submissionPoints === 10 &&
      facts.releasePoints === 20 &&
      facts.dailyActivityMax === 5,
    JSON.stringify(facts),
  );

  // 1. Tárgyi hibák, amelyek már egyszer megtörténtek.
  check(
    'a HÍR LÁJK pont véglegessége szerepel (a visszavonás nem veszi el)',
    has('Hír kedvelése', 'végleges') && !/visszavonódik/.test(row('Hír kedvelése') || ''),
  );
  check(
    `a hír-lájk napi kerete a valós értéket írja (${facts.newsLikeLimit})`,
    has('Hír kedvelése', `legfeljebb ${facts.newsLikeLimit} hír`),
  );
  check(
    `a cikkkomment napi kerete a valós értéket írja (${facts.commentLimit}, nem 5)`,
    has('Cikk kommentelése', `legfeljebb ${facts.commentLimit}`) &&
      !guideSource.includes('legfeljebb 5'),
  );
  check(
    'a lemondásnál elvesző pontok ki vannak mondva (esemény, meetup, kapcsolat)',
    has('Eseményen ott leszek', 'elvész') &&
      has('Meetup jelzés', 'elvész') &&
      has('Kölcsönös kapcsolat meetupolóval', 'megszűnik'),
  );
  // Az „egyszer" az ESEMÉNYRE vonatkozik, nem az egész életre — ezt a
  // naplókulcsok is így tartják nyilván (`attendance:<eventId>` stb.).
  check(
    'az esemény/meetup pontoknál kimondva, hogy ESEMÉNYENKÉNT egyszer járnak',
    has('Eseményen ott leszek', 'Eseményenként') &&
      has('Meetup jelzés', 'Meetuponként') &&
      has('Kölcsönös kapcsolat meetupolóval', 'kapcsolatonként') &&
      has('Esemény utáni értékelés', 'Eseményenként') &&
      /attendance:\$\{eventId\}/.test(functionsSource) &&
      /meetup:\$\{eventId\}/.test(functionsSource) &&
      /meetup-interest:\$\{eventId\}:\$\{uid\}:\$\{interestedUid\}/.test(functionsSource) &&
      /event-rating:\$\{eventId\}/.test(functionsSource),
  );

  // 2. A pontértékek egyeznek a kóddal.
  check(`esemény: +${facts.attendance} pont`, has('Eseményen ott leszek', `+${facts.attendance} pont`));
  check(`meetup: +${facts.meetup} pont`, has('Meetup jelzés', `+${facts.meetup} pont`));
  check(
    `meetup-érdeklődés: +${facts.meetupInterest} pont`,
    has('Kölcsönös kapcsolat meetupolóval', `+${facts.meetupInterest} pont`),
  );
  check(`esemény-értékelés: +${facts.eventRating} pont`, has('Esemény utáni értékelés', `+${facts.eventRating} pont`));
  check(`hír kedvelése: +${facts.newsLike} pont`, has('Hír kedvelése', `+${facts.newsLike} pont`));
  check(`cikkkomment: +${facts.comment} pont`, has('Cikk kommentelése', `+${facts.comment} pont`));
  check(`szavazás: +${facts.voting} pont`, has('Éves HUHS szavazás', `+${facts.voting} pont`));
  check(`profil: +${facts.profileComplete} pont`, has('Profil kitöltése', `+${facts.profileComplete} pont`));
  check(`meghívás: +${facts.referral} pont`, has('Meghívott regisztrációja', `+${facts.referral} pont`));

  // 3. A korábban „üres" sorok mögött MOSTANTÓL van szabály a kódban.
  check(
    `kiadvány-vásárlás: +${facts.releasePoints} pont ÉS létezik a forrás`,
    facts.releaseSource &&
      has('Kiadvány megvásárlása', `+${facts.releasePoints} pont`) &&
      has('Kiadvány megvásárlása', 'Google Play'),
  );
  check(
    `jóváhagyott beküldés: +${facts.submissionPoints} pont, napi ${facts.submissionLimit}, ÉS létezik a forrás`,
    facts.submissionSource &&
      has('Jóváhagyott beküldés', `+${facts.submissionPoints} pont`) &&
      has('Jóváhagyott beküldés', `legfeljebb ${facts.submissionLimit}`) &&
      has('Jóváhagyott beküldés', 'jóváhagyáskor'),
  );
  check(
    `napi aktivitási pont: 1–${facts.dailyActivityMax}, ÉS létezik a forrás + a számláló`,
    facts.dailyActivitySource &&
      facts.commentCounter &&
      facts.chatCounter &&
      has('Napi aktivitási pont', `1–${facts.dailyActivityMax}`) &&
      has('Napi aktivitási pont', 'chat'),
  );
  check('a játék-jutalom a valós működést írja (nem „pont járhat érte")', facts.gameSource && has('HUHS játékok', 'sávokban'));

  // 4. A szabály-blokk: nincs technikai zsargon, a keretek kimondva.
  const rulesBlock =
    guideSource.slice(
      guideSource.indexOf('static const rules'),
      guideSource.indexOf('@override'),
    ) || '';
  check(
    'a szabályok kimondják a napi kereteket és a véglegességet',
    rulesBlock.includes('naponta legfeljebb 3-3') &&
      rulesBlock.includes('napi aktivitási pont') &&
      rulesBlock.includes('végleges'),
  );
  check(
    'nincs technikai zsargon a szövegben',
    !/idempotens|Firebase|Firestore|szerveroldalon könyveli/.test(guideSource),
  );

  return { checks, failures: checks.filter((entry) => !entry.ok) };
}

function selfTest() {
  const functionsSource = fs.readFileSync(FUNCTIONS_PATH, 'utf8');
  const guideSource = fs.readFileSync(GUIDE_PATH, 'utf8');
  const results = [];
  const check = (label, ok, detail = '') => results.push({ label, ok: Boolean(ok), detail });

  const good = analyzeGuide({ functionsSource, guideSource });
  check('a valódi forráson minden ellenőrzés rendben', good.failures.length === 0, JSON.stringify(good.failures));

  // 1. A régi hiba (5 komment) visszacsempészve elhasal.
  const oldText = guideSource.replace('legfeljebb 3 elküldött', 'legfeljebb 5 elküldött');
  check(
    'a „naponta legfeljebb 5 komment" szöveg elhasal',
    analyzeGuide({ functionsSource, guideSource: oldText }).failures.length > 0,
  );

  // 2. A „visszavonáskor elvész a pont" régi szöveg elhasal.
  const oldLike = guideSource.replace('A pont végleges', 'A pont elvész');
  check(
    'a „visszavonáskor elvész a lájkpont" szöveg elhasal',
    analyzeGuide({ functionsSource, guideSource: oldLike }).failures.length > 0,
  );

  // 3. Ha a KÓD változik (pl. 3 → 5 a keret), a szöveg nem maradhat csendben.
  const changedCode = functionsSource.replace(
    'const ARTICLE_COMMENT_DAILY_POINT_LIMIT = 3;',
    'const ARTICLE_COMMENT_DAILY_POINT_LIMIT = 5;',
  );
  check(
    'ha a kódban más lesz a komment-keret, a szöveg elhasal',
    analyzeGuide({ functionsSource: changedCode, guideSource }).failures.length > 0,
  );

  // 4. A napi aktivitási sor eltávolítása elhasal.
  const missingRow = analyzeGuide({
    functionsSource,
    guideSource: guideSource.replace(/title: 'Napi aktivitási pont'/, "title: 'Valami más'"),
  });
  check('a hiányzó napi aktivitási sor elhasal', missingRow.failures.length > 0);

  // 5. A fantom sor (nincs mögötte forrás) elhasal.
  const noSource = functionsSource.replace(
    /`release-purchase:\$\{[^`]*`/,
    "'release-purchase:torolt'",
  );
  check(
    'a forrás nélküli kiadvány-sor elhasal',
    analyzeGuide({ functionsSource: noSource, guideSource }).failures.length > 0,
  );

  for (const result of results) console.log(`${result.ok ? 'OK   ' : 'HIBA '} ${result.label}`);
  const failed = results.filter((result) => !result.ok).length;
  console.log('');
  console.log(`${results.length - failed}/${results.length} ellenőrzés rendben${failed ? ` — ${failed} HIBA` : ''}`);
  console.log(failed === 0 ? 'Önteszt: a detektorok működnek.' : 'Önteszt: HIBA!');
  return failed ? 1 : 0;
}

if (process.argv.includes('--self-test')) {
  process.exitCode = selfTest();
} else {
  const functionsSource = fs.readFileSync(FUNCTIONS_PATH, 'utf8');
  const guideSource = fs.readFileSync(GUIDE_PATH, 'utf8');
  const { checks, failures } = analyzeGuide({ functionsSource, guideSource });
  for (const entry of checks) {
    console.log(`${entry.ok ? 'OK   ' : 'HIBA '} ${entry.label}${entry.ok || !entry.detail ? '' : ` — ${entry.detail}`}`);
  }
  console.log('');
  console.log(`${checks.length - failures.length}/${checks.length} ellenőrzés rendben${failures.length ? ` — ${failures.length} HIBA` : ''}`);
  process.exitCode = failures.length ? 1 : 0;
}
