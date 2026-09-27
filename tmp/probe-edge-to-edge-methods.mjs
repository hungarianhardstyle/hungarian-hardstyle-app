#!/usr/bin/env node
/**
 * Az `androidx.activity.EdgeToEdge` osztály **metódusainak** mérése a DEX-ben
 * (a `-keep` szabály hatásának ellenőrzése).
 *
 * Használat: node tmp/probe-edge-to-edge-methods.mjs [aab]
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const AAB = process.argv[2] ?? 'build/HUHS-v1.0.0+377-release.aab';
const OUT = path.join(os.tmpdir(), 'huhs-edge-methods');
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
  const marker = "Class descriptor  : 'Landroidx/activity/EdgeToEdge;'";
  const start = dump.indexOf(marker);
  if (start < 0) continue;
  const block = dump.slice(start, start + 40000);
  const methodNames = [...block.matchAll(/name\s*:\s*'([^']+)'/g)].map((match) => match[1]);
  // Csak a metódus-szakasz érdekel: a mezők után jönnek a metódusok.
  const directMethods = [...block.matchAll(/#\d+\s+\(\s*in\s+[^)]*\)\s+name\s*:\s*'([^']+)'/g)].map((m) => m[1]);
  console.log(`\n=== ${name}`);
  console.log(`  az osztály nevei (első 25): ${methodNames.slice(0, 25).join(', ')}`);
  console.log(`  metódus-szerű nevek: ${directMethods.slice(0, 25).join(', ') || '(nincs)'}`);
  for (const candidate of ['enableEdgeToEdge', 'enable', 'enable$default']) {
    console.log(`  '${candidate}': ${block.split(candidate).length - 1}`);
  }
}
