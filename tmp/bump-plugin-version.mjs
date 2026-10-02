// A plugin verziójának léptetése (a PowerShell `node -e` idézőjel-problémái miatt
// külön szkript — a projekt visszatérő tanulsága).
import fs from 'node:fs';

const file = process.argv[2] ?? 'tmp/plugin-2154/huhs-mobile-api/huhs-mobile-api.php';
const from = process.argv[3] ?? '2.14.16';
const to = process.argv[4] ?? '2.14.17';

let source = fs.readFileSync(file, 'utf8');
const before = source;
source = source.replace(`* Version: ${from}`, `* Version: ${to}`);
source = source.replace(`define('HUHS_API_VERSION', '${from}')`, `define('HUHS_API_VERSION', '${to}')`);
if (source === before) {
  console.log(`nincs változás — nem találtam a(z) ${from} verziót`);
  process.exit(1);
}
fs.writeFileSync(file, source);
const header = /^\s*\*\s*Version:\s*(\S+)/m.exec(source)?.[1];
const constant = /define\('HUHS_API_VERSION',\s*'([^']+)'\)/.exec(source)?.[1];
console.log(`fejléc: ${header} | konstans: ${constant}`);
process.exit(header === to && constant === to ? 0 : 1);
