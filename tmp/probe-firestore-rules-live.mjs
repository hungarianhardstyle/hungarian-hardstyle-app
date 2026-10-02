// A **jelenleg ÉLESBEN lévő** Firestore-szabály kiolvasása és összevetése a
// repóban lévővel — a telepítés ELŐTT (a production változtatás csak mérés után).
//
// MIÉRT: a szabályok telepítése felülírja az élesben lévőt. Ha valaki a
// konzolban kézzel módosított valamit, a `firebase deploy` azt **némán
// eltüntetné** — ezt a kockázatot itt mérjük, nem tippeljük.
//
// Használat: node tmp/probe-firestore-rules-live.mjs
import fs from 'node:fs';
import { accessToken, PROJECT } from '../tools/lib/live-firebase.mjs';

const REPO_RULES = 'firestore.rules';
const LIVE_RULES = 'tmp/live-firestore.rules';

const token = await accessToken();
const headers = { Authorization: `Bearer ${token}` };

const releasesResponse = await fetch(
  `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases`,
  { headers },
);
if (!releasesResponse.ok) {
  console.log(`HIBA  a kiadások lekérése: HTTP ${releasesResponse.status}`);
  console.log(await releasesResponse.text().catch(() => ''));
  process.exit(2);
}
const releases = await releasesResponse.json();
console.log(`kiadások (${(releases.releases || []).length} db):`);
for (const entry of releases.releases || []) {
  console.log(`  ${entry.name}  →  ${entry.rulesetName}`);
}
// ⚠️ FONTOS: a projektnek NÉVES adatbázisa van (`hungarian-hardstyle`), ezért a
// kiadás neve is tartalmazhatja az adatbázist (`cloud.firestore.<db>`). A régi
// `cloud.firestore` kiadás a `(default)` adatbázisé — azt NEM szabad keverni.
const candidates = [
  `projects/${PROJECT}/releases/cloud.firestore.${process.env.HUHS_DB || 'hungarian-hardstyle'}`,
  `projects/${PROJECT}/releases/cloud.firestore/${process.env.HUHS_DB || 'hungarian-hardstyle'}`,
  `projects/${PROJECT}/releases/cloud.firestore`,
];
const release =
  (releases.releases || []).find((entry) => candidates[0] === entry.name) ||
  (releases.releases || []).find((entry) => candidates[1] === entry.name) ||
  (releases.releases || []).find((entry) => entry.name === candidates[2]);
if (!release) {
  console.log('HIBA  nincs használható `cloud.firestore` kiadás — nem lehet összevetni');
  process.exit(2);
}
console.log(`\nvizsgált kiadás: ${release.name}`);
console.log(`  ruleset: ${release.rulesetName}`);

const rulesetResponse = await fetch(`https://firebaserules.googleapis.com/v1/${release.rulesetName}`, { headers });
if (!rulesetResponse.ok) {
  console.log(`HIBA  a ruleset lekérése: HTTP ${rulesetResponse.status}`);
  process.exit(2);
}
const ruleset = await rulesetResponse.json();
const live = (ruleset.source?.files || []).map((file) => file.content).join('\n');
fs.writeFileSync(LIVE_RULES, `${live.replace(/\r\n/g, '\n').trimEnd()}\n`, 'utf8');

const normalize = (text) => text.replace(/\r\n/g, '\n').replace(/\s+$/u, '');
const repoText = fs.readFileSync(REPO_RULES, 'utf8');
const same = normalize(repoText) === normalize(live);
console.log(`\n${LIVE_RULES} kiírva (${live.length} karakter)`);
console.log(`a repó és az élő szabály ${same ? 'AZONOS' : 'ELTÉR'}`);

if (!same) {
  const repoLines = normalize(repoText).split('\n');
  const liveLines = normalize(live).split('\n');
  const liveSet = new Set(liveLines);
  const repoSet = new Set(repoLines);
  const onlyInRepo = repoLines.filter((line) => !liveSet.has(line));
  const onlyInLive = liveLines.filter((line) => !repoSet.has(line));
  console.log(`  csak a repóban: ${onlyInRepo.length} sor, csak az élőben: ${onlyInLive.length} sor`);
  console.log('  --- csak az ÉLESBEN (amit a deploy eltüntetne) ---');
  onlyInLive.slice(0, 20).forEach((line) => console.log(`    + ${line.trim().slice(0, 120)}`));
  if (onlyInLive.length > 20) console.log(`    … összesen ${onlyInLive.length} sor`);
  // Csak az lehet biztonságos, ha az élő minden sora megvan a repóban is.
  const safe = onlyInLive.length === 0;
  console.log(`\nÍTÉLET: ${safe ? 'az élő szabály a repó RÉSZHALMAZA — a telepítés biztonságos' : 'AZ ÉLŐBEN OLYAN SOR VAN, AMI A REPÓBAN NINCS — a telepítés előtt egyeztetni kell!'}`);
  process.exitCode = safe ? 0 : 1;
}
