#!/usr/bin/env node
/**
 * **Az `androidx.activity.EdgeToEdge` osztály a 377-es DEX-ben** — a Play
 * „teljes képernyős mód" ellenőrzése a DEX-ből olvas, ezért azt kell mérni,
 * hogy a **hívás neve** tényleg benne van-e (és milyen alakban).
 *
 * Használat: node tmp/probe-edge-to-edge-dex.mjs [aab]
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const AAB = process.argv[2] ?? 'build/HUHS-v1.0.0+377-release.aab';
const OUT = path.join(os.tmpdir(), 'huhs-edge-dex');
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
execFileSync('tar', ['-xf', AAB, '-C', OUT], { maxBuffer: 1024 * 1024 * 256 });

const buildTools = 'C:/Users/deero/AppData/Local/Android/Sdk/build-tools';
const dexdump = path.join(buildTools, fs.readdirSync(buildTools).sort().pop(), 'dexdump.exe');
const dexDir = path.join(OUT, 'base', 'dex');

for (const name of fs.readdirSync(dexDir).filter((file) => file.endsWith('.dex'))) {
  const dump = execFileSync(dexdump, ['-d', path.join(dexDir, name)], {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 512,
  });
  const lines = dump.split('\n');
  console.log(`\n=== ${name} (${(fs.statSync(path.join(dexDir, name)).size / 1024 / 1024).toFixed(1)} MB)`);
  console.log(`  'androidx/activity/EdgeToEdge' előfordulás: ${dump.split('androidx/activity/EdgeToEdge').length - 1}`);
  console.log(`  'enableEdgeToEdge' előfordulás: ${dump.split('enableEdgeToEdge').length - 1}`);
  // Az osztály metódusai: a Class descriptor utáni sorokból.
  for (let index = 0; index < lines.length; index++) {
    if (!lines[index].includes("Class descriptor  : 'Landroidx/activity/EdgeToEdge;'")) continue;
    console.log('  --- az osztály metódusai (a dexdump kivonata):');
    for (let next = index; next < Math.min(lines.length, index + 60); next++) {
      const line = lines[next];
      const method = /name\s*:\s*'([^']+)'/.exec(line);
      if (method) console.log(`      ${method[1]}`);
    }
    break;
  }
  // Hol hívják? (A hívó osztály neve a Class descriptor sorból.)
  let callerShown = 0;
  for (let index = 0; index < lines.length && callerShown < 3; index++) {
    if (!lines[index].includes('Landroidx/activity/EdgeToEdge;')) continue;
    for (let back = index; back > Math.max(0, index - 500); back--) {
      const match = /Class descriptor\s*:\s*'L([^;]+);'/.exec(lines[back]);
      if (match) {
        console.log(`  hivatkozó osztály: ${match[1]}`);
        callerShown += 1;
        break;
      }
    }
  }
}
