#!/usr/bin/env node
/**
 * A 2.14.28-as admin kiadásjegyzék helyének beírása a kiadási jegyzetbe.
 *
 * Futás: node tmp/update-docs-1428.mjs
 */
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
let text = fs.readFileSync(file, 'utf8');
const before = text;

const anchor = '**HUHS Mobile API WordPress-plugin — kiadásjegyzék (a csomagban `readme.txt`-ként is):**';
const extra = [
  '**Hol látszik a changelog?** (a tulajdonos kérdése: *„hol a changelog?”*)',
  '',
  '| Hol | Mit lát |',
  '|---|---|',
  '| **WordPress admin** | **HUHS Mobile → Kiadásjegyzék** (plugin 2.14.28-tól) — ezt a listát mutatja, a `readme.txt`-ből |',
  '| A plugin csomagja | `readme.txt` → `== Changelog ==` (2.14.19 → 2.14.28) |',
  '| Az app | **Több → Névjegy → Újdonságok** (build 405 bejegyzés, magyarul és angolul) |',
  '| Play Console | ez a fejezet (a HU/EN blokkok fent) |',
  '',
  anchor,
].join('\n');

if (text.includes(anchor) && !text.includes('**Hol látszik a changelog?**')) {
  text = text.replace(anchor, extra);
}

if (text !== before) {
  fs.writeFileSync(file, text, 'utf8');
  console.log('docs frissítve (hol látszik a changelog)');
} else {
  console.log('nem változott');
}
