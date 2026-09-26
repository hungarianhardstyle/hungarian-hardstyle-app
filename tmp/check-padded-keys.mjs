// A szótár kulcsainak alakja: van-e olyan kulcs, amit a futásidejű szótár
// (amely a kulcsokat `trim()`-eli) nem tud kiszolgálni?
import { readFileSync } from 'node:fs';

const dict = JSON.parse(readFileSync('assets/i18n/en.json', 'utf8'));
const padded = Object.keys(dict).filter((key) => key !== key.trim());
const empty = Object.keys(dict).filter((key) => key.trim() === '');
const whitespaceOnlyValue = Object.entries(dict).filter(([, value]) => `${value}`.trim() === '');

console.log(`összes kulcs: ${Object.keys(dict).length}`);
console.log(`\n=== szóközzel körbevett kulcsok: ${padded.length}`);
for (const key of padded) {
  console.log(`  ${JSON.stringify(key)} -> ${JSON.stringify(dict[key])}`);
}
console.log(`\n=== csak szóközből álló kulcs: ${empty.length}`);
console.log(`=== csak szóközből álló érték: ${whitespaceOnlyValue.length}`);
for (const [key, value] of whitespaceOnlyValue) {
  console.log(`  ${JSON.stringify(key)} -> ${JSON.stringify(value)}`);
}
