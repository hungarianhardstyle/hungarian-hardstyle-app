// A 2.14.5 → 2.14.6 plugin-diff előállítása EGY lépésben, UTF-8-ban (nem PowerShell-átirányítással).
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

let raw = '';
try {
  raw = execFileSync(
    'git',
    ['diff', '--no-index', '--src-prefix=a/', '--dst-prefix=b/', 'tmp/plugin-2145-base/huhs-mobile-api', 'tmp/plugin-2146/huhs-mobile-api'],
    { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 },
  );
} catch (error) {
  // A `git diff --no-index` 1-es kilépési kóddal tér vissza, ha VAN eltérés — ez a várt eset.
  raw = String(error.stdout || '');
}
if (!raw.trim()) throw new Error('üres diff — nem jött létre a patch');

const clean = raw
  .split(/\r?\n/)
  .map((line) =>
    /^(diff --git|---|\+\+\+) /.test(line)
      ? line
          .replaceAll('\\', '/')
          .replace(/a\/tmp\/plugin-2145-base\/huhs-mobile-api\//g, 'a/huhs-mobile-api/')
          .replace(/b\/tmp\/plugin-2146\/huhs-mobile-api\//g, 'b/huhs-mobile-api/')
          .replace(/"([ab]\/huhs-mobile-api\/[^"]+)"/g, '$1')
      : line,
  )
  .join('\n');

fs.writeFileSync('tmp/plugin-2146.diff', clean, 'utf8');
fs.writeFileSync('docs/plugin-2.14.6-localized-event-reminders.patch', clean, 'utf8');

const files = [...clean.matchAll(/^diff --git a\/(\S+)/gm)].map((m) => m[1]);
const additions = clean.split('\n').filter((l) => l.startsWith('+') && !l.startsWith('+++')).length;
const removals = clean.split('\n').filter((l) => l.startsWith('-') && !l.startsWith('---')).length;
console.log('érintett fájlok:', files.length);
for (const f of files) console.log('  ' + f);
console.log(`+${additions} / -${removals} sor`);
const headers = clean.split('\n').filter((l) => /^(diff --git|---|\+\+\+) /.test(l));
console.log('a fejlécekben nincs helyi útvonal:', headers.every((l) => !/tmp|plugin-21/.test(l)) ? 'IGEN' : 'NEM');
console.log('első fejléc:', headers[0]);
