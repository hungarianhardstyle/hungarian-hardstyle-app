// A munkapéldány sorvégének helyreállítása (LF) a KÖVETETT Dart-fájlokban.
//
// MIÉRT KELL (mért saját hiba, 2026-09-28): a `master` és a `codex/v1.0` ág
// szinkronizálása (`git checkout master` → `git merge --ff-only` → vissza) a
// gépen beállított `core.autocrlf=true` miatt **CRLF-re** írta a munkapéldányt.
// A tesztek egy része viszont a **tárolt** (LF) alakot várja: a
// `test/services/app_analytics_test.dart` adatvédelmi forrás-lintje például
// `'setCrashlyticsCollectionEnabled(\n        kReleaseMode,\n      )'` mintát
// keres, ami CRLF-fel **nem található meg** — a zöld kör egyetlen bukása ez volt.
//
// ⚠️ A GIT-TARTALOM NEM VÁLTOZIK: a blobok LF-esek, a `core.autocrlf=true`
// mellett az LF-es munkapéldány is „változatlannak" számít (a git olvasáskor
// normalizál). Ezért ez a szkript csak a **munkapéldány** sorvégét állítja
// vissza — commit nem születik belőle.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const files = execFileSync('git', ['ls-files'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 })
  .split('\n')
  .filter((file) => file.endsWith('.dart'));

let converted = 0;
const convertedFiles = [];
for (const file of files) {
  let bytes;
  try {
    bytes = fs.readFileSync(file);
  } catch {
    continue;
  }
  if (!bytes.includes(13)) continue; // nincs CR a fájlban
  const text = bytes.toString('utf8');
  const normalized = text.replaceAll('\r\n', '\n');
  fs.writeFileSync(file, normalized, 'utf8');
  converted += 1;
  convertedFiles.push(file);
}

console.log(`átnézett Dart-fájl: ${files.length}`);
console.log(`LF-re állítva: ${converted}`);
for (const file of convertedFiles.slice(0, 10)) console.log(`  ${file}`);
if (convertedFiles.length > 10) console.log(`  … és további ${convertedFiles.length - 10}`);
