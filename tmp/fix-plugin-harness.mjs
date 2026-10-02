// A plugin-harness kör-Lista javítása: egyetlen `exit $fail` a fájl végén, LF sorvégek.
import fs from 'node:fs';

const file = 'tools/php/run-plugin-tests.sh';
let source = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
const marker = '=== 10) A nyereményjátékból való törlés (2.14.18)';
if (!source.includes(marker)) {
  console.log('HIBA  nincs benne az új kör');
  process.exit(1);
}
const firstExit = source.indexOf('\nexit $fail');
const lastExit = source.lastIndexOf('\nexit $fail');
if (firstExit !== lastExit) {
  // A régi `exit $fail` (a körök vége ELŐTT) törlése — csak a legutolsó marad.
  source = `${source.slice(0, firstExit)}\n${source.slice(firstExit + '\nexit $fail'.length).replace(/^\n+/, '\n')}`;
  console.log('a korai `exit $fail` törölve');
}
// A blokkok sorrendje: a 10. kör az utolsó `exit` ELŐTT legyen.
const order = ['=== 9)', '=== 10)', 'exit $fail'];
let cursor = -1;
let ordered = true;
for (const token of order) {
  const index = source.indexOf(token, cursor + 1);
  if (index <= cursor) ordered = false;
  cursor = index;
}
fs.writeFileSync(file, source, 'utf8');
console.log(`sorvégek: LF | exit $fail: ${(source.match(/exit \$fail/g) || []).length} db | sorrend rendben: ${ordered}`);
console.log(`méret: ${source.length} karakter`);
process.exit(ordered ? 0 : 1);
