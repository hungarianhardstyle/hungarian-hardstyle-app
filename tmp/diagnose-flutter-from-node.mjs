#!/usr/bin/env node
// Diagnosztika: miért nem fut le a `flutter test` a Node-ból (mért hiba kell,
// nem tipp). Egy mutációt végzünk, lefuttatjuk a tesztet, és KIÍRJUK a kimenetet.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const SCREEN = 'lib/screens/twitch/twitch_screen.dart';
const original = fs.readFileSync(SCREEN, 'utf8');
fs.writeFileSync(SCREEN, original.replace('WidgetsBinding.instance.addObserver(this);', '// mut'), 'utf8');

for (const [label, file, args, options] of [
  ['flutter.bat (pipe)', 'flutter.bat', ['test', 'test/services/webview_picture_in_picture_test.dart'], { encoding: 'utf8' }],
  ['cmd /c flutter (pipe)', 'cmd', ['/c', 'flutter', 'test', 'test/services/webview_picture_in_picture_test.dart'], { encoding: 'utf8' }],
]) {
  try {
    const out = execFileSync(file, args, { ...options, maxBuffer: 64 * 1024 * 1024 });
    console.log(`== ${label}: OK (nem bukott) — az első sorok:\n${out.split(/\r?\n/).slice(-6).join('\n')}`);
  } catch (error) {
    console.log(`== ${label}: HIBA code=${error.code} status=${error.status}`);
    console.log(`   message: ${(error.message ?? '').split('\n').slice(0, 3).join(' | ')}`);
    const out = `${error.stdout ?? ''}${error.stderr ?? ''}`;
    console.log(`   kimenet (első 12 sor):\n${out.split(/\r?\n/).slice(0, 12).map((l) => `     ${l}`).join('\n')}`);
  }
}

fs.writeFileSync(SCREEN, original, 'utf8');
console.log(`forrás visszaállítva: ${fs.readFileSync(SCREEN, 'utf8') === original}`);
