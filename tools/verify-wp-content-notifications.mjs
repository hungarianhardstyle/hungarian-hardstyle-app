/**
 * Az app-értesítéslista feltöltésének ellenőrzése.
 *
 * A functions/index.js `pollWordPressContentNotifications()` logikáját tükrözi:
 * a WordPress nyilvános listáit figyeli, és a "publikálási dátum" (date)
 * változását tekinti új közzétételnek.
 *
 * MIÉRT: a tulajdonos visszajelzése szerint „elsőre ment, a visszavonás és újra
 * publikálás után nem" — a cikk push-t kapott, de az app Értesítések listájába
 * nem került be, mert a job csak az azonosítót figyelte, azt pedig már ismerte.
 *
 * Futtatás: node tools/verify-wp-content-notifications.mjs
 */

const check = (name, condition, detail) => {
  console.log(`${condition ? 'OK   ' : 'HIBA '} ${name}${condition ? '' : ` — ${detail}`}`);
  return condition ? 0 : 1;
};

/** A functions/index.js ciklusának tükrözése (egy "futás" egy endpoint-listára). */
const runPoll = (items, state) => {
  const previousIds = state?.ids || {};
  const previousRevisions = state?.revisions || {};
  const hasRevisions = Object.keys(previousRevisions).length > 0;
  const current = {};
  const currentRevisions = {};
  const newlyPublished = [];

  const ids = items.map((item) => String(item.id)).slice(0, 100);
  current.news = ids;
  const revisions = {};
  for (const item of items) {
    const revision = String(item.date || '').trim();
    if (revision) revisions[String(item.id)] = revision;
  }
  currentRevisions.news = revisions;

  if (state) {
    const oldIds = new Set(previousIds.news || []);
    const oldRevisions = previousRevisions.news || {};
    for (const item of items) {
      const id = String(item.id);
      const revision = revisions[id] || '';
      if (!oldIds.has(id)) {
        newlyPublished.push({ id, revision });
        continue;
      }
      if (hasRevisions && revision && oldRevisions[id] && revision !== oldRevisions[id]) {
        newlyPublished.push({ id, revision });
      }
    }
  }

  return { nextState: { ids: current, revisions: currentRevisions }, newlyPublished };
};

/** A dedupe-kulcs: ugyanarra a cikkre, ugyanarra a közzétételre egyszer szól. */
const dedupeKey = (item, uid) => `wordpress_content:news:${item.id}:${item.revision || ''}:${uid}`;

let failures = 0;

const ARTICLE = { id: 12684, date: '2026-09-18T14:52:19+02:00' };
const REPUBLISHED = { id: 12684, date: '2026-09-18T15:21:24+02:00' };
const OTHER = { id: 12679, date: '2026-09-18T12:29:36+02:00' };

// 1. Elso futas: nincs allapot -> csak bázis, nincs ertesites-vihar.
{
  const { nextState, newlyPublished } = runPoll([ARTICLE, OTHER], null);
  failures += check('első futás: nincs értesítés (csak bázis)', newlyPublished.length === 0, JSON.stringify(newlyPublished));
  failures += check('első futás: a revision-térkép eltárolódik', Object.keys(nextState.revisions.news).length === 2, JSON.stringify(nextState.revisions));
}

// 2. Masodik futas valtozatlan listaval: semmi.
{
  const first = runPoll([ARTICLE, OTHER], null);
  const second = runPoll([ARTICLE, OTHER], first.nextState);
  failures += check('változatlan lista: nincs értesítés', second.newlyPublished.length === 0, JSON.stringify(second.newlyPublished));
}

// 3. Uj cikk: megy.
{
  const first = runPoll([ARTICLE, OTHER], null);
  const fresh = { id: 12700, date: '2026-09-18T16:00:00+02:00' };
  const second = runPoll([fresh, ARTICLE, OTHER], first.nextState);
  failures += check('új cikk: pontosan egy értesítés', second.newlyPublished.length === 1 && second.newlyPublished[0].id === '12700', JSON.stringify(second.newlyPublished));
}

// 4. A TULAJDONOS ESETE: ugyanaz a cikk, uj publikalasi datummal.
{
  const first = runPoll([ARTICLE, OTHER], null);
  const second = runPoll([REPUBLISHED, OTHER], first.nextState);
  failures += check(
    'VISSZAVONÁS + ÚJRA PUBLIKÁLÁS: mégis megy értesítés',
    second.newlyPublished.length === 1 && second.newlyPublished[0].id === '12684',
    JSON.stringify(second.newlyPublished),
  );
  failures += check(
    'az új közzététel kulcsa eltér a korábbitól (nem ütközik)',
    dedupeKey(second.newlyPublished[0], 'uid1') !== dedupeKey(ARTICLE, 'uid1'),
    dedupeKey(second.newlyPublished[0], 'uid1'),
  );
  const third = runPoll([REPUBLISHED, OTHER], second.nextState);
  failures += check('a második futás ugyanarra a közzétételre már nem szól', third.newlyPublished.length === 0, JSON.stringify(third.newlyPublished));
}

// 5. Regi allapot (csak ids, nincs revisions): nincs ertesites-vihar.
{
  const legacy = { ids: { news: ['12684', '12679'] } };
  const after = runPoll([REPUBLISHED, OTHER], legacy);
  failures += check('régi állapotformátumnál nincs visszamenőleges értesítés-vihar', after.newlyPublished.length === 0, JSON.stringify(after.newlyPublished));
  failures += check('utána a revision-térkép már feltöltődik', Object.keys(after.nextState.revisions.news).length === 2, JSON.stringify(after.nextState.revisions));
}

// 6. Hiányzó dátum: nem használjuk revisionnak, nincs téves értesítés.
{
  const noDate = { id: 12684, date: '' };
  const first = runPoll([ARTICLE], null);
  const second = runPoll([noDate], first.nextState);
  failures += check('hiányzó dátum nem okoz téves értesítést', second.newlyPublished.length === 0, JSON.stringify(second.newlyPublished));
}

console.log(failures === 0 ? '\nMinden ellenőrzés sikeres.' : `\n${failures} ellenőrzés hibás.`);
process.exit(failures === 0 ? 0 : 1);
