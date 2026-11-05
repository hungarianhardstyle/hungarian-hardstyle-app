#!/usr/bin/env node
/**
 * A `CHANGELOG-PAGE OK` jelző felvétele a kötelező jelzők közé (2.14.28).
 *
 * Futás: node tmp/add-changelog-marker.mjs
 */
import fs from 'node:fs';

const file = 'tools/run-php-plugin-tests.mjs';
let text = fs.readFileSync(file, 'utf8');
const before = text;

if (!text.includes("'CHANGELOG-PAGE OK'")) {
  text = text.replace(
    "'HOME-IMAGE OK'];",
    "'HOME-IMAGE OK', 'CHANGELOG-PAGE OK'];",
  );
}

if (text !== before) {
  fs.writeFileSync(file, text, 'utf8');
  console.log('marker felvéve');
} else {
  console.log('nem változott (már benne van?)');
}
console.log(/REQUIRED_MARKERS = \[[^\]]*\]/.exec(text)[0]);
