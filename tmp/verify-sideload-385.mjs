#!/usr/bin/env node
/**
 * A 385-ös sideload **független igazolása** a Sideloadly saját adatbázisából.
 *
 * MIÉRT: a felület „Done. 100%" szövege nem bizonyíték — a `stored_files` sor
 * mondja meg, MELYIK IPA ment fel (név + bájtok), a `devices` sor pedig azt,
 * hogy a telepítés nem hibázott. Ez a mérés a 385-ös artifacthoz köti a
 * telepítést (a 23 078 043 bájt a CI-artefakt mérete).
 *
 * Használat: node tmp/verify-sideload-385.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const EXPECTED_BYTES = 23_078_043;

const candidates = [
  path.join(process.env.LOCALAPPDATA ?? '', 'Sideloadly', 'installations.db'),
  path.join(process.env.APPDATA ?? '', 'sideloadly', 'installations.db'),
];
const dbPath = candidates.find((candidate) => fs.existsSync(candidate));
if (!dbPath) {
  console.log(`HIBA  nincs Sideloadly adatbázis (${candidates.join(' | ')})`);
  process.exit(1);
}

const db = new DatabaseSync(dbPath, { readOnly: true });
const installation = db.prepare('SELECT * FROM installations ORDER BY id DESC LIMIT 1').get();
const ipa = db.prepare('SELECT * FROM stored_files WHERE id = ?').get(installation?.ipa_id);
const device = db.prepare('SELECT * FROM devices WHERE udid = ?').get(installation?.device_udid)
  ?? db.prepare('SELECT * FROM devices ORDER BY rowid DESC LIMIT 1').get();
const fileColumns = db.prepare('PRAGMA table_info(stored_files)').all().map((row) => row.name);
db.close();

const sizeOf = (row) => {
  for (const key of ['size', 'byte_size', 'length', 'file_size', 'bytes']) {
    if (row && row[key] != null) return Number(row[key]);
  }
  // Ha nincs méret-oszlop: a fájl a lemezen (a `path` mező) mérhető.
  for (const key of ['path', 'file_path', 'location']) {
    if (row && row[key] && fs.existsSync(String(row[key]))) return fs.statSync(String(row[key])).size;
  }
  return null;
};

const nickname = ipa?.nickname ?? ipa?.name ?? '';
const bytes = sizeOf(ipa);
const checks = [
  ['van telepítési rekord', Boolean(installation), `id=${installation?.id ?? 'nincs'}`],
  ['a telepítés nem hibázott (last_error üres)',
    (installation?.last_error ?? '') === '', JSON.stringify(installation?.last_error ?? '')],
  ['a hibaszámláló nulla', Number(installation?.failures_count ?? -1) === 0,
    String(installation?.failures_count)],
  ['a feltöltött IPA a 385-ös (hh385.ipa)', String(nickname).includes('385'), String(nickname)],
  [`az IPA bájtazonos méretű (${EXPECTED_BYTES})`, bytes === EXPECTED_BYTES, String(bytes)],
  ['a bundle ID a várt (hu.hungarianhardstyle.app.JQPJ793V65)',
    String(installation?.final_bundle_id ?? '') === 'hu.hungarianhardstyle.app.JQPJ793V65',
    String(installation?.final_bundle_id)],
  ['az aláírás 7 napos (known_ttl)', Number(installation?.known_ttl ?? -1) === 7,
    String(installation?.known_ttl)],
];

console.log(`adatbázis: ${dbPath}`);
console.log(`stored_files oszlopai: ${fileColumns.join(', ')}`);
console.log(`telepítés: id=${installation?.id} név=${installation?.name} `
  + `updated_at=${installation?.updated_at}`);
console.log(`IPA: id=${ipa?.id} nickname=${nickname} bytes=${bytes}`);
console.log(`eszköz: ${device?.name ?? device?.device_name ?? '?'} udid=${device?.udid ?? device?.device_udid}`);
console.log('');

let failed = 0;
for (const [label, ok, detail] of checks) {
  if (!ok) failed += 1;
  console.log(`${ok ? 'OK  ' : 'HIBA'} ${label}${detail ? ` — ${detail}` : ''}`);
}
console.log(failed ? `\nHIBA — ${failed} ellenőrzés bukott` : '\nMINDEN ELLENŐRZÉS RENDBEN');
process.exitCode = failed ? 1 : 0;
