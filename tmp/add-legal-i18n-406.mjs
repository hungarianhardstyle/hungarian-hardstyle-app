#!/usr/bin/env node
/**
 * A 406-os jogi linkek szótári és changelog bejegyzései.
 *
 * Futás: node tmp/add-legal-i18n-406.mjs
 */
import fs from 'node:fs';

const labels = {
  'Felhasználási feltételek (ÁSZF)': 'Terms of Service',
  'Adatkezelési tájékoztató': 'Privacy policy',
};

const dictPath = 'assets/i18n/en.json';
const dict = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
let added = 0;
for (const [hu, en] of Object.entries(labels)) {
  if (!Object.prototype.hasOwnProperty.call(dict, hu)) {
    dict[hu] = en;
    added += 1;
  }
}
fs.writeFileSync(dictPath, JSON.stringify(dict, null, 2) + '\n', 'utf8');

const changeLine = 'ÚJ: a Névjegy alatt elérhető a Felhasználási feltételek (ÁSZF) és az Adatkezelési tájékoztató.';
const changeEn = 'NEW: Terms of Service and the Privacy policy are now linked from the About screen.';

const changelogPath = 'lib/data/app_changelog.dart';
let changelog = fs.readFileSync(changelogPath, 'utf8');
let changelogChanged = false;
if (!changelog.includes('build: 406')) {
  changelog = changelog.replace(
    'const appChangelog = <AppReleaseNotes>[\n',
    "const appChangelog = <AppReleaseNotes>[\n  AppReleaseNotes(\n    version: '1.0.0',\n    build: 406,\n    changes: [\n      '" + changeLine + "',\n    ],\n  ),\n",
  );
  changelogChanged = true;
  fs.writeFileSync(changelogPath, changelog, 'utf8');
}

if (!Object.prototype.hasOwnProperty.call(dict, changeLine)) {
  const refreshed = JSON.parse(fs.readFileSync(dictPath, 'utf8'));
  refreshed[changeLine] = changeEn;
  fs.writeFileSync(dictPath, JSON.stringify(refreshed, null, 2) + '\n', 'utf8');
  added += 1;
}

const pubspecPath = 'pubspec.yaml';
let pubspec = fs.readFileSync(pubspecPath, 'utf8');
pubspec = pubspec.replace(/^version: .*$/m, 'version: 1.0.0+406');
fs.writeFileSync(pubspecPath, pubspec, 'utf8');

console.log(`szótár: +${added} kulcs | changelog 406: ${changelogChanged} | pubspec: ${/^version: .*$/m.exec(pubspec)[0]}`);
