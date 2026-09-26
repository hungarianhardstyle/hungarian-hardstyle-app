import fs from 'node:fs';

const path = 'assets/i18n/en.json';
const dictionary = JSON.parse(fs.readFileSync(path, 'utf8'));

// A NotificationCenter eddig NYERS (ternary-ágban álló) címkéje.
const keys = {
  'Archivált értesítések törlése': 'Delete archived notifications',
  'Értesítés': 'Notification',
};

let added = 0;
for (const [key, value] of Object.entries(keys)) {
  if (dictionary[key] === value) continue;
  if (dictionary[key] !== undefined) console.log(`FIGYELEM: felülírás: ${JSON.stringify(key)}`);
  dictionary[key] = value;
  added += 1;
}

const sorted = {};
for (const key of Object.keys(dictionary).sort((a, b) => a.localeCompare(b, 'hu'))) {
  sorted[key] = dictionary[key];
}
fs.writeFileSync(path, `${JSON.stringify(sorted, null, 2)}\n`, 'utf8');
console.log(`hozzáadva: ${added}, összes kulcs: ${Object.keys(sorted).length}`);
