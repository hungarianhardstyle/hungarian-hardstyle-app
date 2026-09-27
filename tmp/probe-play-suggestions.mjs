#!/usr/bin/env node
/**
 * **A Play Console két „javasolt" jelzése** (2026-09-27) mérése:
 *
 *  1. *„Előfordulhat, hogy a teljes képernyős mód nem jelenik meg minden
 *     felhasználónál"* + *„elavult API-kat vagy paramétereket használ a teljes
 *     képernyős megjelenítéshez"* → a csomag **DEX-ében** keressük az
 *     edge-to-edge hívást és az elavult ablak-API-kat;
 *  2. *„teljesítmény javítása bittérképes képoptimalizálással"* → a csomagolt
 *     képek formátuma/mérete/felbontása.
 *
 * Használat: node tmp/probe-play-suggestions.mjs [aab]
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const AAB = process.argv[2] ?? 'build/HUHS-v1.0.0+376-release.aab';
const OUT = path.join(os.tmpdir(), 'huhs-suggestions');

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
execFileSync('tar', ['-xf', AAB, '-C', OUT], { maxBuffer: 1024 * 1024 * 256 });

/* --- 1. Manifest: cél-SDK és ablak-zászlók ---------------------------- */

const manifest = fs.readFileSync(
  'build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml',
  'utf8',
);
console.log('=== MANIFEST ===');
console.log(`  targetSdkVersion: ${/android:targetSdkVersion="(\d+)"/.exec(manifest)?.[1] ?? '(nincs)'}`);
for (const flag of [
  'windowOptOutEdgeToEdgeEnforcement',
  'windowLayoutInDisplayCutoutMode',
  'windowLightStatusBar',
  'statusBarColor',
  'navigationBarColor',
  'windowTranslucentStatus',
  'windowDrawsSystemBarBackgrounds',
  'resizeableActivity',
]) {
  const hits = [...manifest.matchAll(new RegExp(flag, 'g'))].length;
  console.log(`  ${flag}: ${hits}`);
}

/* --- 2. DEX: edge-to-edge és elavult API-k ---------------------------- */

const buildTools = 'C:/Users/deero/AppData/Local/Android/Sdk/build-tools';
const dexdump = fs.existsSync(buildTools)
  ? path.join(
      buildTools,
      fs.readdirSync(buildTools).sort().pop(),
      'dexdump.exe',
    )
  : null;
console.log(`\n=== DEX (dexdump: ${dexdump ?? 'NINCS'}) ===`);

const dexDir = path.join(OUT, 'base', 'dex');
const dexFiles = fs.existsSync(dexDir) ? fs.readdirSync(dexDir).filter((name) => name.endsWith('.dex')) : [];
console.log(`  DEX fájlok: ${dexFiles.length}`);

const needles = [
  'enableEdgeToEdge',
  'EdgeToEdge',
  'setDecorFitsSystemWindows',
  'setStatusBarColor',
  'setNavigationBarColor',
  'setSystemUiVisibility',
  'SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN',
  'SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION',
  'setSystemBarsAppearance',
  'WindowInsetsController',
  'setStatusBarContrastEnforced',
];
const totals = Object.fromEntries(needles.map((needle) => [needle, 0]));
const owners = Object.fromEntries(needles.map((needle) => [needle, new Set()]));
for (const name of dexFiles) {
  const dump = execFileSync(dexdump, ['-d', path.join(dexDir, name)], {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 512,
  });
  for (const needle of needles) {
    const count = dump.split(needle).length - 1;
    totals[needle] += count;
    if (count > 0 && /setStatusBarColor|setNavigationBarColor|setSystemUiVisibility|setDecorFitsSystemWindows/.test(needle)) {
      // Ki használja? A dump „Class descriptor" sorai környékéről olvassuk ki.
      const lines = dump.split('\n');
      for (let index = 0; index < lines.length; index++) {
        if (!lines[index].includes(needle)) continue;
        for (let back = index; back > Math.max(0, index - 400); back--) {
          const match = /Class descriptor\s*:\s*'L([^;]+);'/.exec(lines[back]);
          if (match) {
            owners[needle].add(match[1].replace(/\//g, '.'));
            break;
          }
        }
      }
    }
  }
}
for (const needle of needles) {
  const ownerList = [...owners[needle]].slice(0, 4).join(', ');
  console.log(`  ${needle}: ${totals[needle]}${ownerList ? `  ← ${ownerList}` : ''}`);
}

/* --- 3. Képek a csomagban -------------------------------------------- */

console.log('\n=== KÉPEK (a csomagolt Flutter-assetek) ===');
const assetsDir = path.join(OUT, 'base', 'assets', 'flutter_assets', 'assets');
const images = [];
const walk = (dir) => {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (/\.(png|jpe?g|webp|gif)$/i.test(entry.name)) {
      const stat = fs.statSync(full);
      images.push({ name: path.relative(path.join(OUT, 'base', 'assets', 'flutter_assets'), full), size: stat.size });
    }
  }
};
walk(assetsDir);
images.sort((a, b) => b.size - a.size);
const byExtension = {};
for (const image of images) {
  const extension = path.extname(image.name).toLowerCase();
  byExtension[extension] = byExtension[extension] ?? { count: 0, bytes: 0 };
  byExtension[extension].count += 1;
  byExtension[extension].bytes += image.size;
}
console.log(`  összes kép: ${images.length}, összesen ${(images.reduce((sum, image) => sum + image.size, 0) / 1024 / 1024).toFixed(2)} MB`);
for (const [extension, data] of Object.entries(byExtension)) {
  console.log(`    ${extension}: ${data.count} db, ${(data.bytes / 1024).toFixed(0)} KB`);
}
console.log('  A 12 legnagyobb:');
for (const image of images.slice(0, 12)) {
  console.log(`    ${(image.size / 1024).toFixed(0).padStart(6)} KB  ${image.name}`);
}

/* --- 4. Az androidos erőforrás-képek (mipmap/drawable) ---------------- */

const resDir = path.join(OUT, 'base', 'res');
const resImages = [];
const walkRes = (dir) => {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walkRes(full);
    else if (/\.(png|jpe?g|webp)$/i.test(entry.name)) {
      resImages.push({ name: path.relative(path.join(OUT, 'base'), full), size: fs.statSync(full).size });
    }
  }
};
walkRes(resDir);
resImages.sort((a, b) => b.size - a.size);
console.log(`\n  Android erőforrás-képek: ${resImages.length}, ${(resImages.reduce((sum, image) => sum + image.size, 0) / 1024).toFixed(0)} KB`);
for (const image of resImages.slice(0, 8)) {
  console.log(`    ${(image.size / 1024).toFixed(0).padStart(6)} KB  ${image.name}`);
}
