#!/usr/bin/env node
/**
 * Az értesítés-szövegek **nyelvi katalógusának** átemelése az appba.
 *
 * MIÉRT KELL (a tulajdonos jelzése, 2026-09-26): *„a notifyok még mindig
 * magyarul vannak az angol felületen vagy lassan áll át"* → *„nagyon lassan"*.
 *
 * A MÉRT GYÖKÉR: a szerver az értesítés szövegét a **létrehozáskor** rendereli a
 * címzett akkori nyelvén (`createNotification` → `recipientLanguage`), és a
 * Firestore dokumentumba **kész szöveget** ír (`title`/`body`). Ezért a
 * nyelvváltás után a **régi** sorok a régi nyelven maradnak, és csak az **új**
 * értesítések jönnek az új nyelven — ez a „nagyon lassú átállás".
 *
 * A javítás: az app a **megjelenítés helyén** fordítja a tárolt szöveget, ehhez
 * viszont ismernie kell a katalógust. Ez az eszköz a szerveroldali
 * `functions/notification-texts.js`-ből (EGY forrás) generálja az app-oldali
 * `assets/i18n/notification_texts.json`-t — így a kettő nem tud szétcsúszni.
 *
 * Használat:
 *   node tools/generate-notification-texts.mjs            # kiírja a JSON-t
 *   node tools/generate-notification-texts.mjs --check    # eltérés esetén HIBA
 */
import { createRequire } from 'node:module';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const OUT = 'assets/i18n/notification_texts.json';
export const SOURCE = 'functions/notification-texts.js';

const require = createRequire(import.meta.url);

/** A katalógus betöltése a szerveroldali (egyetlen) forrásból. */
export function buildCatalog(sourcePath = path.join(REPO_ROOT, SOURCE)) {
  const module = require(sourcePath);
  const kinds = {};
  for (const kind of Object.keys(module.TEXTS).sort()) {
    const entry = module.TEXTS[kind];
    kinds[kind] = {
      hu: { title: `${entry.hu?.title ?? ''}`, body: `${entry.hu?.body ?? ''}` },
      en: { title: `${entry.en?.title ?? ''}`, body: `${entry.en?.body ?? ''}` },
    };
  }
  const defaults = {};
  for (const key of Object.keys(module.PLACEHOLDER_DEFAULTS ?? {}).sort()) {
    const value = module.PLACEHOLDER_DEFAULTS[key];
    defaults[key] = { hu: `${value.hu ?? ''}`, en: `${value.en ?? ''}` };
  }
  return { defaults, kinds };
}

export function render(catalog) {
  return `${JSON.stringify(catalog, null, 2)}\n`;
}

function main() {
  const mode = process.argv.includes('--check') ? 'check' : 'write';
  const catalog = buildCatalog();
  const json = render(catalog);
  const kinds = Object.keys(catalog.kinds);
  const sha = crypto.createHash('sha256').update(json, 'utf8').digest('hex').toUpperCase();
  const target = path.join(REPO_ROOT, OUT);

  console.log(`forrás: ${SOURCE}`);
  console.log(`típusok (kind): ${kinds.length}`);
  console.log(`nyelvek: hu, en (mindkettő megvan: ${kinds.every((kind) => catalog.kinds[kind].hu && catalog.kinds[kind].en)})`);
  console.log(`SHA-256: ${sha}`);

  if (mode === 'check') {
    if (!fs.existsSync(target)) {
      console.log(`\nHIBA — hiányzik az app-oldali katalógus: ${OUT}`);
      process.exit(1);
    }
    const current = fs.readFileSync(target, 'utf8');
    if (current !== json) {
      console.log(`\nHIBA — az app-oldali katalógus ELAVULT (${OUT}); futtasd: node tools/generate-notification-texts.mjs`);
      const currentKinds = Object.keys(JSON.parse(current).kinds ?? {});
      const missing = kinds.filter((kind) => !currentKinds.includes(kind));
      if (missing.length) console.log(`  hiányzó típusok: ${missing.join(', ')}`);
      process.exit(1);
    }
    console.log('\nRENDBEN — az app-oldali katalógus pontosan a szerveroldali forrásból származik');
    return;
  }

  fs.writeFileSync(target, json, 'utf8');
  console.log(`\nkiírva: ${OUT}`);
}

if (process.argv[1] && process.argv[1].endsWith('generate-notification-texts.mjs')) {
  main();
}
