#!/usr/bin/env node
/**
 * **A beépített képek optimalizálása** (a Play Console „bittérkép-optimalizálás"
 * javaslata, 2026-09-27).
 *
 * A MÉRT OK (`tmp/probe-image-dimensions.mjs`): a csomagolt képek **1254×1254**
 * (navigációs ikonok, 34 logikai képponton!), illetve 1640×856 … 2460×780
 * felbontásban voltak — **összesen 59 MB dekódolt bittérkép-memória** egy olyan
 * felülethez, ahol a legnagyobb valódi megjelenítés ~400 logikai képpont.
 *
 * Ez a szkript **kicsinyít** (nem vág), így a kép aránya és kinézete nem
 * változik — csak a felbontás lesz akkora, amekkora a megjelenítéshez kell
 * (3–5× tartalékkal a nagy felbontású kijelzőkre).
 *
 * Használat:
 *   node tools/optimize-app-images.mjs            # száraz futás
 *   node tools/optimize-app-images.mjs --write    # átírja a képeket
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

/**
 * cél-fájl → { width, height, miért }
 *
 * A „miért" a **mért megjelenítési méret** (a kódban), nem tipp.
 */
const TARGETS = [
  // A navigációs ikonok 34 logikai képponton látszanak (`main_navigation.dart`),
  // ezért 5× tartalék is bőven elég (176 px = 34 dp @ ~5x).
  { file: 'assets/images/nav_home.png', width: 176, height: 176, why: '34 dp az alsó sávban' },
  { file: 'assets/images/nav_news.png', width: 176, height: 176, why: '34 dp az alsó sávban' },
  { file: 'assets/images/nav_events.png', width: 176, height: 176, why: '34 dp az alsó sávban' },
  { file: 'assets/images/nav_chat.png', width: 176, height: 176, why: '34 dp az alsó sávban' },
  { file: 'assets/images/nav_label.png', width: 176, height: 176, why: '34 dp az alsó sávban' },
  { file: 'assets/images/nav_more.png', width: 176, height: 176, why: '34 dp az alsó sávban' },
  // A nyitóképernyő logója a képernyő 82%-a (`startup_gate.dart`), ezért ez a
  // legnagyobb, indokolt méret; 1000 px ~3× egy 330 dp széles telefonon.
  { file: 'assets/logos/huhs_full_logo.png', width: 1000, height: 522, why: 'nyitóképernyő, 0.82 × képernyő' },
  // A fejléc-logó 96 logikai képpont magas, 1.28× nagyítással.
  { file: 'assets/logos/huhs_logo.png', width: 512, height: 267, why: '96 dp magas fejléc-logó' },
  // A sarok-logó 34×48 logikai képpont.
  { file: 'assets/logos/huhs_corner_logo.png', width: 160, height: 241, why: '34×48 dp sarok-logó' },
  // A rádió-logó 110 logikai képpont magas.
  { file: 'assets/logos/real_hardstyle_fm.png', width: 1040, height: 330, why: '110 dp magas rádió-logó' },
];

const write = process.argv.includes('--write');
const pngSize = (file) => {
  const buffer = fs.readFileSync(file);
  return { bytes: buffer.length, width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
};

let before = 0;
let after = 0;
let beforeMemory = 0;
let afterMemory = 0;
const failures = [];

for (const target of TARGETS) {
  if (!fs.existsSync(target.file)) {
    failures.push(`${target.file}: nincs ilyen fájl`);
    continue;
  }
  const original = pngSize(target.file);
  before += original.bytes;
  beforeMemory += original.width * original.height * 4;
  const scratch = `${target.file}.optimized.png`;
  execFileSync(
    'ffmpeg',
    [
      '-y',
      '-loglevel',
      'error',
      '-i',
      target.file,
      '-vf',
      `scale=${target.width}:${target.height}:flags=lanczos`,
      '-pix_fmt',
      'rgba',
      scratch,
    ],
    { stdio: 'inherit' },
  );
  const optimized = pngSize(scratch);
  if (optimized.width !== target.width || optimized.height !== target.height) {
    failures.push(`${target.file}: a kimenet ${optimized.width}×${optimized.height} (várt ${target.width}×${target.height})`);
    fs.rmSync(scratch, { force: true });
    continue;
  }
  after += optimized.bytes;
  afterMemory += optimized.width * optimized.height * 4;
  console.log(
    `${write ? 'ÍRÁS ' : 'DRY  '} ${target.file.padEnd(40)} ` +
      `${original.width}×${original.height} (${(original.bytes / 1024).toFixed(0)} KB) → ` +
      `${optimized.width}×${optimized.height} (${(optimized.bytes / 1024).toFixed(0)} KB) — ${target.why}`,
  );
  if (write) fs.renameSync(scratch, target.file);
  else fs.rmSync(scratch, { force: true });
}

console.log('');
console.log(`fájlméret:  ${(before / 1024 / 1024).toFixed(2)} MB → ${(after / 1024 / 1024).toFixed(2)} MB`);
console.log(
  `dekódolt memória: ${(beforeMemory / 1024 / 1024).toFixed(1)} MB → ${(afterMemory / 1024 / 1024).toFixed(1)} MB`,
);
if (failures.length) {
  console.log(`\nHIBA (${failures.length}):`);
  for (const failure of failures) console.log(`  ${failure}`);
}
process.exitCode = failures.length ? 1 : 0;
