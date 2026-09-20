#!/usr/bin/env node
/**
 * Nyereményjáték — „valóban random a sorsolás?"
 *
 * MIÉRT: a tulajdonos jelzése: *„nyereményjáték sorolás teszt: az elsőnél a
 * legelső beküldő nyert, a másodiknál a legutolsó — biztos random?"*
 *
 * A sorsolás a **Cloud Functionben** fut (`drawPrizeWinnerForPrizes`), és a
 * `crypto.randomInt(0, eligible)` a Node kriptográfiailag biztonságos
 * generátorát használja — vagyis a döntés **tényleg véletlen**. Ez az eszköz
 * két dolgot mér, mert a „random" állítás önmagában nem bizonyíték:
 *
 *   1. **A generátor egyenletessége** (`--self-test`): ugyanaz a
 *      kiválasztási szabály 200 000 húzással, 2/3/5 jelölttel — és egy
 *      **szándékosan elrontott** szabállyal (mindig az első) megmutatja, hogy a
 *      mérés **elkapja** a hibát. Enélkül a zöld eredmény semmit nem érne.
 *   2. **A megtörtént húzások** (éles): a `prize_draws` dokumentumból (és
 *      kiegészítésképp a naplóból) kiírja, hány jogosult volt a kalapban,
 *      hányadikat húzta, és hogy ez a kimenet **mekkora valószínűségű** volt
 *      (1/eligible). Így az látszik, hogy a „legelső nyert" szerencse volt-e,
 *      vagy **az egyetlen** jelölt.
 *
 * Titkot nem ír, és nem módosít semmit: a Firebase CLI bejelentkezését
 * használja. **Kivétel:** a `--participants` kapcsoló a WordPress-jelszót
 * (Secret Manager) olvassa, hogy a régi, audit-adat nélküli húzásnál is
 * megmondja a nyertes helyét a mai jelöltlistában — ez is csak olvasás.
 *
 * Futtatás:
 *   node tools/check-prize-draws.mjs --self-test
 *   node tools/check-prize-draws.mjs [--days 30] [--participants]
 * Kilépési kód: 0 = rendben, 1 = a mérés vagy az önteszt hibát talált.
 */
import crypto from 'node:crypto';
import { accessToken, PROJECT } from './lib/live-firebase.mjs';

const DRAWS = 200_000;

const WORDPRESS_BASE_URL = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

/**
 * A **nyertes helye** a jelöltlistán, a WordPress `/prize/participants`
 * végpontjából (`--participants` kapcsolóval).
 *
 * MIÉRT: a régi függvényverzió húzásánál (`#12709`) sem a dokumentumban, sem a
 * naplóban nincs benne a húzott sorszám — a jelöltlista viszont **még ma is**
 * lekérdezhető, és a benne elfoglalt hely megmutatja, hányadikként húzta a
 * rendszer a nyertest (a lista a beküldés sorrendje: `meta_id`).
 *
 * ⚠️ ŐSZINTE KORLÁT: ez **utólagos rekonstrukció**, nem a húzás pillanatában
 * naplózott adat. Ha a játékot azóta szerkesztették vagy újranyitották, a lista
 * megváltozhatott — ezért az eredményt „a mai lista szerint" értelemben kell
 * olvasni, és a napló/dokumentum audit-adata mindig erősebb bizonyíték.
 * A végpont jelszóval védett, ezért a titkot a Secret Managerből olvassuk
 * (ugyanaz, amit a sorsoló függvény használ); **írni nem írunk semmit**.
 */
async function participantPositions() {
  const { secret } = await import('./lib/live-firebase.mjs');
  const credentials = `${secret('WORDPRESS_USERNAME')}:${secret('WORDPRESS_APPLICATION_PASSWORD')}`;
  const authorization = `Basic ${Buffer.from(credentials).toString('base64')}`;
  return async (prizeId, winnerUid) => {
    const response = await fetch(`${WORDPRESS_BASE_URL}/prize/participants?prizeId=${prizeId}`, {
      headers: { Authorization: authorization, Accept: 'application/json' },
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return winnerPosition(payload?.players, winnerUid);
  };
}

/**
 * A nyertes **helye** a jelöltlistában (0-tól), tiszta függvény — hogy a
 * „hányadik volt" kérdés önmagában mérhető legyen (lásd `--self-test`).
 *
 * A `players` a WordPress válasza (a beküldés sorrendjében); a hiányzó nyertes
 * `-1`-et ad, mert akkor a rekonstrukció **nem** mondható ki (nem tippelünk).
 */
export function winnerPosition(players, winnerUid) {
  const list = Array.isArray(players) ? players : [];
  const wanted = String(winnerUid || '').trim();
  if (!wanted) return { total: list.length, index: -1 };
  const index = list.findIndex((player) => String(player?.uid || '').trim() === wanted);
  return { total: list.length, index };
}

/** A sorsolás szabálya — pontosan ugyanaz, mint a Cloud Functionben. */
export function pickIndex(eligible) {
  return crypto.randomInt(0, eligible);
}

/** `DRAWS` húzás `eligible` jelölttel; visszaadja az indexenkénti darabszámot. */
export function measure(eligible, draws = DRAWS) {
  const counts = new Array(eligible).fill(0);
  for (let i = 0; i < draws; i += 1) counts[pickIndex(eligible)] += 1;
  const expected = draws / eligible;
  const maxDeviation = Math.max(...counts.map((count) => Math.abs(count - expected)));
  return {
    counts,
    expected,
    // Százalékpontban: mennyivel tér el a legnagyobb eltérés az egyenletestől.
    maxDeviationPercent: (maxDeviation / draws) * 100,
  };
}

function selfTest() {
  const results = [];
  let failed = 0;
  const check = (label, ok, detail = '') => {
    results.push(`${ok ? 'OK   ' : 'HIBA '} ${label}${detail ? ` — ${detail}` : ''}`);
    if (!ok) failed += 1;
  };

  // 1. A valódi szabály egyenletes: a legnagyobb eltérés 1 százalékpont alatt
  //    (200 000 húzásnál ez ~10+ szórás, tehát nem „flaky").
  for (const eligible of [2, 3, 5]) {
    const { counts, maxDeviationPercent } = measure(eligible);
    const allPositive = counts.every((count) => count > 0);
    check(
      `${eligible} jelöltnél egyenletes az eloszlás`,
      allPositive && maxDeviationPercent < 1,
      `eltérés ${maxDeviationPercent.toFixed(3)} százalékpont, darabszámok: ${counts.join('/')}`,
    );
  }

  // 2. A mérés ELKAPJA a hibát: egy „mindig az első" szabály nem mehet át.
  const broken = { counts: new Array(3).fill(0) };
  broken.counts[0] = DRAWS;
  const brokenDeviation = (DRAWS - DRAWS / 3) / DRAWS * 100;
  check(
    'a mérés elkapja a „mindig az első" hibát',
    brokenDeviation >= 1,
    `a hamis szabály eltérése ${brokenDeviation.toFixed(1)} százalékpont lenne`,
  );

  // 3. A tartomány helyes: a húzás sosem esik a jelöltlistán kívülre
  //    (a `crypto.randomInt(0, n)` felső határa kizáró).
  let outOfRange = 0;
  for (let i = 0; i < 20_000; i += 1) {
    const index = pickIndex(4);
    if (index < 0 || index > 3) outOfRange += 1;
  }
  check('a húzás a jelöltlistán belül marad (0..n-1)', outOfRange === 0);

  // 4. A REKONSTRUKCIÓ helyes: a régi húzásnál ebből derül ki, hányadikként
  //    húzta a rendszer a nyertest. Ha ez a számolás hibázna, akkor a
  //    „legelső nyert" megfigyelés **hamis** lenne — ezért önteszt védi.
  const sample = [
    { uid: 'uid-elso', name: 'Első' },
    { uid: 'uid-masodik', name: 'Második' },
    { uid: 'uid-harmadik', name: 'Harmadik' },
  ];
  const first = winnerPosition(sample, 'uid-elso');
  check(
    'a rekonstrukció megtalálja a nyertest a jelöltlistában (első hely)',
    first.index === 0 && first.total === 3,
    `${first.index + 1}. / ${first.total}`,
  );
  const last = winnerPosition(sample, ' uid-harmadik ');
  check(
    'a szóközzel átadott UID is a helyére kerül (utolsó hely)',
    last.index === 2 && last.total === 3,
    `${last.index + 1}. / ${last.total}`,
  );
  const missing = winnerPosition(sample, 'nincs-ilyen');
  check(
    'ismeretlen nyertesnél NEM tippelünk (nincs találat)',
    missing.index === -1,
    'ilyenkor a húzott sorszám ismeretlen marad',
  );
  const empty = winnerPosition(null, 'barmi');
  check('üres jelöltlistánál sincs találat és nincs hiba', empty.index === -1 && empty.total === 0);

  console.log(results.join('\n'));
  console.log('');
  console.log(
    failed === 0
      ? `${results.length}/${results.length} ellenőrzés rendben`
      : `${failed} HIBA`,
  );
  return failed === 0 ? 0 : 1;
}

/**
 * A sorsolás NAPLÓJA (`prize_draw_choice`) a Cloud Loggingból — **kiegészítés**,
 * nem elsődleges forrás: a napló 30 nap után lejár, a `prize_draws` dokumentum
 * viszont megmarad. Arra jó, hogy a **régi függvényverzió** húzását (amelynek a
 * dokumentumában nincs `chosenIndex`) is megmutassa, amíg a napló megvan.
 *
 * ⚠️ MÉRVE: a 2. generációs függvények naplója `cloud_run_revision` alatt
 * jelenik meg, nem `cloud_function` alatt — ezért MINDKETTŐt kérjük. A gen1
 * függvények `console.info(JSON.stringify(...))` kimenete `jsonPayload`, de
 * előfordulhat `textPayload` is, ezért mindkét alakot keressük.
 */
async function drawLogEntries(sinceIso) {
  const { accessToken, PROJECT } = await import('./lib/live-firebase.mjs');
  const token = await accessToken();
  const entries = [];
  for (const filter of [
    `resource.type=("cloud_function" OR "cloud_run_revision") AND timestamp>="${sinceIso}" AND jsonPayload.event="prize_draw_choice"`,
    `resource.type=("cloud_function" OR "cloud_run_revision") AND timestamp>="${sinceIso}" AND textPayload:"prize_draw_choice"`,
  ]) {
    let pageToken = '';
    for (let page = 0; page < 10; page += 1) {
      const response = await fetch('https://logging.googleapis.com/v2/entries:list', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resourceNames: [`projects/${PROJECT}`],
          filter,
          orderBy: 'timestamp desc',
          pageSize: 200,
          ...(pageToken ? { pageToken } : {}),
        }),
      });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) break;
      for (const entry of body.entries || []) {
        const payload = entry?.jsonPayload || null;
        if (payload && Number(payload.prizeId) > 0) entries.push(payload);
      }
      pageToken = body.nextPageToken || '';
      if (!pageToken) break;
    }
  }
  const byPrize = new Map();
  for (const payload of entries) {
    const prizeId = String(payload.prizeId);
    if (!byPrize.has(prizeId)) byPrize.set(prizeId, payload);
  }
  return byPrize;
}

async function live(days, { withParticipants = false } = {}) {
  // ⚠️ ELSŐDLEGES FORRÁS a FIRESTORE (`prize_draws`), nem a napló: a napló
  // lejár (30 nap), a döntés viszont a `prize_draws` dokumentumban **megmarad**
  // (`eligibleCount`, `chosenIndex`, `candidatesHash`). A napló csak azoknál
  // segít, ahol a dokumentum a régi függvényverzióból származik (audit mezők
  // nélkül) — ezért azt is megmutatjuk, nem tüntetjük el.
  const { firestoreList } = await import('./lib/live-firebase.mjs');
  const since = Date.now() - days * 24 * 3600 * 1000;
  let rows = [];
  try {
    rows = await firestoreList('prize_draws', { max: 500 });
  } catch (error) {
    console.error(`HIBA  a prize_draws nem olvasható: ${error?.message || error}`);
    return 1;
  }
  let logged = new Map();
  try {
    logged = await drawLogEntries(new Date(since).toISOString());
  } catch (error) {
    console.log(`(a napló nem kérdezhető le: ${error?.message || error})`);
  }
  const reconstructed = [];
  let reconstruct = null;
  if (withParticipants) {
    try {
      reconstruct = await participantPositions();
    } catch (error) {
      console.log(`(a jelöltlista nem kérdezhető le: ${error?.message || error})`);
    }
  }
  const timeOf = (row) => Date.parse(String(row.notifiedAt || row.drawnAt || '').replace(' ', 'T')) || 0;
  rows = rows.filter((row) => timeOf(row) >= since).sort((a, b) => timeOf(a) - timeOf(b));

  if (!rows.length) {
    console.log(`Nincs sorsolás az elmúlt ${days} napban.`);
    return 0;
  }

  console.log(`Megtörtént sorsolások az elmúlt ${days} napban (${rows.length} db):\n`);
  // Egy sor = egy húzás: `total` a jelöltek száma, `index` a húzott hely (0-tól).
  // A `source` megmondja, honnan tudjuk (`doc` = a dokumentum audit-mezője,
  // `log` = a napló, `rekonstrukcio` = a mai jelöltlista).
  const hits = [];
  let withoutAudit = 0;
  let singleEligible = 0;
  for (const row of rows) {
    const eligible = Number(row.eligibleCount || 0);
    const choice = Number(row.chosenIndex ?? -1);
    const date = String(row.notifiedAt || row.drawnAt || '').slice(0, 19).replace('T', ' ');
    if (!eligible || choice < 0) {
      // A dokumentumból nem derül ki a húzás — de a NAPLÓBAN lehet róla
      // bejegyzés (amíg meg nem jár le). Ez a régi függvényverzió húzásait
      // teszi ellenőrizhetővé, ezért nem tekintünk el tőle.
      const fromLog = logged.get(String(row.prizeId));
      const logEligible = Number(fromLog?.eligible || 0);
      const logChoice = Number(fromLog?.choice ?? -1);
      if (logEligible > 0 && logChoice >= 0) {
        if (logEligible === 1) singleEligible += 1;
        hits.push({ prizeId: row.prizeId, total: logEligible, index: logChoice, source: 'log' });
        console.log(
          `${date}  játék #${row.prizeId}  ${logEligible} jogosult  →  a ${logChoice + 1}. húzva  ` +
            `(esélye ${(100 / logEligible).toFixed(1)}%)  nyertes: ${row.winnerName || fromLog?.winnerName || '?'}  ` +
            '[a naplóból, mert a dokumentumban nincs audit-adat]',
        );
        continue;
      }
      withoutAudit += 1;
      console.log(
        `${date}  játék #${row.prizeId}  nyertes: ${row.winnerName || '?'}  ` +
          '— ehhez a húzáshoz NINCS audit-adat (régi függvényverzió sorsolta, és a napló sem tartja már)',
      );
      if (reconstruct) {
        try {
          const { total, index } = await reconstruct(row.prizeId, String(row.winnerUid || ''));
          if (index >= 0 && total > 0) {
            hits.push({ prizeId: row.prizeId, total, index, source: 'rekonstrukcio' });
            console.log(
              `      ↳ utólagos rekonstrukció a mai jelöltlistából: ${total} jogosult, ` +
                `a nyertes a ${index + 1}. helyen volt (esélye ${(100 / total).toFixed(1)}%)`,
            );
          } else {
            console.log('      ↳ a nyertes a mai jelöltlistában nem található (nem rekonstruálható)');
          }
        } catch (error) {
          console.log(`      ↳ a jelöltlista nem kérdezhető le: ${error?.message || error}`);
        }
      }
      continue;
    }
    if (eligible === 1) singleEligible += 1;
    hits.push({ prizeId: row.prizeId, total: eligible, index: choice, source: 'doc' });
    console.log(
      `${date}  játék #${row.prizeId}  ${eligible} jogosult  →  a ${choice + 1}. húzva  ` +
        `(esélye ${(100 / eligible).toFixed(1)}%)  nyertes: ${row.winnerName || '?'}`,
    );
  }

  console.log('');
  if (hits.length) {
    const audited = hits.filter((hit) => hit.source !== 'rekonstrukcio');
    console.log(
      `Húzott sorszámok: ${hits.map((hit) => hit.index + 1).join(', ')} — ` +
        `${new Set(hits.map((hit) => hit.index)).size} különböző pozíció, ` +
        `${audited.length} auditált húzásból${hits.length !== audited.length ? ` (+${hits.length - audited.length} rekonstruált)` : ''}.`,
    );
  } else {
    console.log('Húzott sorszámot egyik forrás sem adja meg.');
  }
  if (singleEligible) {
    console.log(
      `⚠️  ${singleEligible} olyan játék volt, ahol csak EGY jogosult volt — ott nem szerencse kérdése, hogy ő nyert.`,
    );
  }
  if (withoutAudit) {
    console.log(
      `⚠️  ${withoutAudit} húzás régi függvényverzióból való: ott sem a dokumentum, sem a napló nem őrzi a húzott sorszámot` +
        (reconstruct ? ' (a ↳ sor a mai jelöltlistából pótolja).' : ' — a `--participants` kapcsoló pótolhatja a mai jelöltlistából.'),
    );
  }
  if (reconstructed.length) {
    console.log('');
    console.log(
      'Utólagos rekonstrukció (a MAI jelöltlistából, nem a húzás pillanatából): ' +
        reconstructed
          .map((item) => `#${item.prizeId}: ${item.total} jogosult → ${item.index + 1}.`)
          .join(', '),
    );
  }
  // A tulajdonos konkrét kérdése: „az elsőnél a legelső beküldő nyert, a
  // másodiknál a legutolsó — biztos random?" Ezért megmondjuk, hány húzás esett
  // a lista SZÉLÉRE (első/utolsó). Ez **megfigyelés**, nem ítélet: két húzásnál
  // a szélsőség esélye kicsi, de nem nulla (2 jelöltnél épp 100%), ezért csak
  // akkor szólunk, ha van mit összevetni (legalább 2 húzás), és a szöveg is
  // kimondja, hogy ez önmagában nem bizonyíték.
  const comparable = hits.filter((hit) => hit.total > 1);
  const edge = comparable.filter((hit) => hit.index === 0 || hit.index === hit.total - 1);
  if (comparable.length >= 2 && edge.length) {
    console.log(
      `Megfigyelés: ${comparable.length} összevethető húzásból ${edge.length} esett a lista szélére (első/utolsó): ` +
        edge.map((hit) => `#${hit.prizeId} → ${hit.index + 1}/${hit.total}`).join(', ') +
        '. Ez önmagában NEM elfogultság (minden hely 1/n eséllyel jön ki), de a következő sorsolásoknál figyeljük.',
    );
  }
  console.log('');
  console.log('KÉT húzásból NEM lehet elfogultságra következtetni (bármelyik sorszám 1/n eséllyel jön ki,');
  console.log('és a „legelső" ugyanolyan valószínű, mint bármelyik másik). Az elfogultságot a generátor');
  console.log('200 000 húzásos mérése zárja ki: `node tools/check-prize-draws.mjs --self-test`.');
  return 0;
}

const invokedDirectly =
  process.argv[1] && process.argv[1].replace(/\\/g, '/').endsWith('tools/check-prize-draws.mjs');

if (invokedDirectly) {
  if (process.argv.includes('--self-test')) {
    process.exit(selfTest());
  }
  const daysArg = process.argv.indexOf('--days');
  const days = daysArg > 0 ? Number(process.argv[daysArg + 1]) || 30 : 30;
  live(days, { withParticipants: process.argv.includes('--participants') })
    .then((code) => process.exit(code))
    .catch((error) => {
      console.error(`HIBA  ${error?.message || error}`);
      process.exit(1);
    });
}
