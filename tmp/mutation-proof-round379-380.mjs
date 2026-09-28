// MUTÁCIÓS BIZONYÍTÉK a 379–380-as kör kapuihoz.
//
// Minden mutáció egy VALÓDI hibát idéz elő; a hozzá tartozó tesztnek EL KELL
// kapnia. A szkript bájtazonos állapotot állít vissza, és a végén ellenőrzi,
// hogy a fa újra pontosan az eredeti (SHA-256 egyezés), majd hogy a kapuk zöldek.
//
// Futtatás: node tmp/mutation-proof-round379-380.mjs            (végigfuttat)
//           node tmp/mutation-proof-round379-380.mjs --dry      (csak horgony-ellenőrzés)
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const dryRun = process.argv.includes('--dry');

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

/** Egy mutáció: fájl, mit cserélünk mire, és melyik tesztnek kell elkapnia. */
const mutations = [
  {
    label: '379: a DJ-adatlapról eltűnik a megosztás gomb',
    file: 'lib/screens/artists/artist_detail_screen.dart',
    from: '          ContentShareButton(\n',
    to: '',
    test: ['flutter', ['test', 'test/services/share_links_test.dart']],
  },
  {
    label: '379: a megosztott link mindig a weboldal gyökere (nem a tartalomé)',
    file: 'lib/services/share_links.dart',
    from: "  if (canonical.isNotEmpty) return canonical;\n",
    to: "  if (canonical.isNotEmpty) return siteBaseUrl;\n  if (canonical.isEmpty) return siteBaseUrl;\n",
    test: ['flutter', ['test', 'test/services/share_links_test.dart']],
  },
  {
    label: '380: a `digest` kikerül a Firestore beállításokból',
    file: 'lib/services/push_notification_service.dart',
    from: "            'digest': digest,\n",
    to: '',
    test: ['flutter', ['test', 'test/services/follow_and_digest_test.dart']],
  },
  {
    label: '380: a Beállítások nem adja tovább a heti összefoglaló kapcsolóját',
    file: 'lib/screens/more/settings_screen.dart',
    from: '        digest: _digestNotificationsEnabled,\n',
    to: '',
    test: ['flutter', ['test', 'test/services/follow_and_digest_test.dart']],
  },
  {
    label: 'követés: a heti kulcs elveszti a tartalom azonosítóját (dupla küldés)',
    file: 'functions/favorite-follow-plan.js',
    from: "  return `favorite-follow:${type}:${id}:${user}`;\n",
    to: "  return `favorite-follow:${type}:${user}`;\n",
    test: ['node', ['--test', 'functions/favorite-follow-plan.test.cjs']],
  },
  {
    label: 'követés: a fan-out nem a `created` eredményt használja (néma duplázás)',
    file: 'functions/index.js',
    from: '    for (const uid of recipientUids) {\n      const created = await createNotificationBestEffort({\n',
    to: '    for (const uid of recipientUids) {\n      const created = await createNotification({\n',
    test: ['node', ['--test', 'functions/favorite-follow-plan.test.cjs']],
  },
];

const results = [];
const originals = new Map();
let aborted = false;

/** ⚠️ EOL-TUDATOS horgony: a fájl saját sorvégét használjuk (CRLF vs LF). */
function withFileEol(text, pattern) {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  return pattern.replaceAll('\n', eol);
}

for (const mutation of mutations) {
  if (!fs.existsSync(mutation.file)) {
    results.push({ ...mutation, status: 'HIÁNYZÓ FÁJL' });
    aborted = true;
    continue;
  }
  const original = fs.readFileSync(mutation.file);
  originals.set(mutation.file, original);
  const text = original.toString('utf8');
  const from = withFileEol(text, mutation.from);
  const to = withFileEol(text, mutation.to);
  const occurrences = text.split(from).length - 1;
  if (occurrences !== 1) {
    results.push({ ...mutation, status: `HORGONY-HIBA (${occurrences} találat)` });
    aborted = true;
    continue;
  }
  if (dryRun) {
    results.push({ ...mutation, status: 'HORGONY RENDBEN' });
    continue;
  }

  fs.writeFileSync(mutation.file, text.replace(from, to), 'utf8');
  let caught = false;
  let detail = '';
  try {
    execFileSync(mutation.test[0], mutation.test[1], { encoding: 'utf8', stdio: 'pipe', shell: true });
  } catch (error) {
    caught = true;
    const output = `${error.stdout || ''}${error.stderr || ''}`;
    detail = /(\d+) (?:test|teszt)[^\n]*failed|BUKÓ|fail \d+/i.exec(output)?.[0] || 'bukó futás';
  } finally {
    fs.writeFileSync(mutation.file, original);
  }
  const restored = sha256(mutation.file) === crypto.createHash('sha256').update(original).digest('hex');
  results.push({
    ...mutation,
    status: caught ? 'ELKAPVA' : 'NEM KAPTA EL',
    detail,
    restored,
  });
  if (!caught) aborted = true;
}

console.log('=== MUTÁCIÓS BIZONYÍTÉK (379–380) ===');
for (const result of results) {
  const mark = result.status === 'ELKAPVA' || result.status === 'HORGONY RENDBEN' ? 'OK  ' : 'HIBA';
  console.log(`${mark} ${result.label} → ${result.status}${result.detail ? ` (${result.detail})` : ''}`);
}

if (!dryRun) {
  const uniqueFiles = [...new Set([...originals.keys()])];
  const allRestored = uniqueFiles.every((file) => {
    const original = originals.get(file);
    return sha256(file) === crypto.createHash('sha256').update(original).digest('hex');
  });
  console.log(`\nbájtazonos visszaállítás: ${allRestored ? 'IGEN' : 'NEM'}`);
  const caughtCount = results.filter((result) => result.status === 'ELKAPVA').length;
  console.log(`elkapott mutációk: ${caughtCount}/${results.length}`);
  console.log(aborted ? '\nEREDMÉNY: HIBA (valamelyik mutációt nem kapta el a kapu)' : '\nEREDMÉNY: MINDEN MUTÁCIÓT ELKAPOTT A KAPU');
  process.exitCode = aborted || !allRestored ? 1 : 0;
} else {
  const bad = results.filter((result) => result.status !== 'HORGONY RENDBEN').length;
  console.log(`\n${results.length - bad}/${results.length} horgony rendben`);
  process.exitCode = bad ? 1 : 0;
}
