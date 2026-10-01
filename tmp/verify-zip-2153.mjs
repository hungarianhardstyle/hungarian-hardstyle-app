// A szállítandó ZIP tartalmának ellenőrzése (nem a forráskönyvtáré).
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const zip = process.argv[2] ?? 'build/huhs-mobile-api-2.14.13.zip';
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zipcheck-'));
execFileSync('tar', ['-xf', zip, '-C', dir]);
const read = (rel) => fs.readFileSync(path.join(dir, 'huhs-mobile-api', rel), 'utf8');
const push = read('includes/push.php');
const main = read('huhs-mobile-api.php');
const diag = read('includes/diagnostics.php');

const has = (source, needle) => (source.includes(needle) ? 'OK' : 'HIÁNYZIK');
const count = (source, needle) => source.split(needle).length - 1;

console.log(`csomag: ${zip}`);
console.log(`  verzió 2.14.13:        ${has(main, "define('HUHS_API_VERSION', '2.14.13')")}`);
console.log(`  konkurencia 50:        ${has(push, "define('HUHS_PUSH_CONCURRENCY', 50)")}`);
console.log(`  folytatás +1 másodperc: ${count(push, "wp_schedule_single_event(time() + 1, 'huhs_push_continue'")} előfordulás (2 a várt)`);
console.log(`  push_limits függvény:  ${has(push, 'function huhs_push_diag_limits')}`);
console.log(`  push_limits hívás:     ${has(diag, '$parts[] = huhs_push_diag_limits();')}`);
console.log(`  hír-push őr bent van:  ${has(push, 'function huhs_push_scan_missing_news')}`);
console.log(`  hír-push őr ütemezve:  ${has(push, "wp_schedule_event(time() + 180, 'huhs_five_minutes', 'huhs_push_news_scan')")}`);
fs.rmSync(dir, { recursive: true, force: true });
