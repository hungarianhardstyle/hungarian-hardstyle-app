// A `logWarning` segéd behúzása az `index.js`-be (CRLF-tudatosan, egyszer futva).
import fs from 'node:fs';

const file = 'functions/index.js';
const source = fs.readFileSync(file, 'utf8');
const eol = source.includes('\r\n') ? '\r\n' : '\n';
const anchor = "const { generateAuthActionLink } = require('./auth_action_link');";
const line = "const { logWarning } = require('./log-warning');";

if (source.includes(line)) {
  console.log('már benne van — nincs teendő');
  process.exit(0);
}
const occurrences = source.split(anchor).length - 1;
if (occurrences !== 1) {
  console.error(`HIBA: a horgony ${occurrences}-szor szerepel (pontosan 1 kell)`);
  process.exit(1);
}
const updated = source.replace(anchor, `${anchor}${eol}${line}`);
fs.writeFileSync(file, updated, 'utf8');
console.log(`kész: 1 beszúrás, ${source.length} -> ${updated.length} bájt`);
console.log(`ellenőrzés: ${updated.split(eol).filter((text) => text === line).length} sor egyezik`);
