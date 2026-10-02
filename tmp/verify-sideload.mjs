#!/usr/bin/env node
/**
 * A sideload **független igazolása** a Sideloadly saját adatbázisából.
 *
 * MIÉRT: a felület „Done. 100%" szövege nem bizonyíték — a `stored_files` sor
 * mondja meg, MELYIK IPA ment fel (név + bájtok), a `devices` sor pedig azt,
 * hogy a telepítés nem hibázott. Ez a mérés a konkrét artifacthoz köti a
 * telepítést: a **várt bájtszámot a helyi IPA-fájlból** olvassuk (nem kézzel
 * beírva), így a bizonyíték nem tud elcsúszni a valóságtól.
 *
 * Használat:
 *   node tmp/verify-sideload.mjs 386 build/ios-ipa-386/Runner-unsigned.ipa
 *   node tmp/verify-sideload.mjs 385 C:\Users\deero\hh385.ipa
 */
import fs from 'node:fs';
import path from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const build = process.argv[2] ?? '386';
const localIpa = process.argv[3] ?? `C:\\Users\\deero\\hh${build}.ipa`;
if (!fs.existsSync(localIpa)) {
  console.log(`HIBA  nincs ilyen helyi IPA: ${localIpa}`);
  process.exit(2);
}
const expectedBytes = fs.statSync(localIpa).size;

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
db.close();

const nickname = ipa?.nickname ?? ipa?.name ?? '';
const bytes = ipa?.size != null ? Number(ipa.size) : null;
const checks = [
  ['van telepítési rekord', Boolean(installation), `id=${installation?.id ?? 'nincs'}`],
  ['a telepítés nem hibázott (last_error üres)',
    (installation?.last_error ?? '') === '', JSON.stringify(installation?.last_error ?? '')],
  ['a hibaszámláló nulla', Number(installation?.failures_count ?? -1) === 0,
    String(installation?.failures_count)],
  [`a feltöltött IPA a ${build}-es (hh${build}.ipa)`, String(nickname).includes(build), String(nickname)],
  [`az IPA bájtazonos méretű (${expectedBytes})`, bytes === expectedBytes, String(bytes)],
  ['a bundle ID a várt (hu.hungarianhardstyle.app.JQPJ793V65)',
    String(installation?.final_bundle_id ?? '') === 'hu.hungarianhardstyle.app.JQPJ793V65',
    String(installation?.final_bundle_id)],
  ['az aláírás 7 napos (known_ttl)', Number(installation?.known_ttl ?? -1) === 7,
    String(installation?.known_ttl)],
];

console.log(`adatbázis: ${dbPath}`);
console.log(`helyi IPA: ${localIpa} (${expectedBytes} bájt)`);
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
