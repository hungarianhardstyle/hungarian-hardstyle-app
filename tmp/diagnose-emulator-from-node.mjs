// Diagnosztika: hogyan futtatható a firebase emulátor a Node-ból (mért hiba kell).
import { execFileSync } from 'node:child_process';

const attempts = [
  ['npx (shell: true)', 'npx', ['firebase', 'emulators:exec', '--only', 'firestore', '--project', 'demo-huhs', 'node functions/twitch-live.test.cjs'], { shell: true }],
  ['cmd /c npx', 'cmd', ['/c', 'npx', 'firebase', 'emulators:exec', '--only', 'firestore', '--project', 'demo-huhs', 'node functions/twitch-live.test.cjs'], {}],
];

for (const [label, file, args, extra] of attempts) {
  try {
    const out = execFileSync(file, args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...extra });
    const tail = out.split(/\r?\n/).filter((line) => /pass|fail/.test(line)).slice(-3).join(' | ');
    console.log(`== ${label}: OK — ${tail}`);
  } catch (error) {
    console.log(`== ${label}: HIBA code=${error.code} status=${error.status}`);
    const out = `${error.stdout ?? ''}${error.stderr ?? ''}`;
    console.log(`   kimenet (első 6 sor): ${out.split(/\r?\n/).slice(0, 6).join(' ⏎ ')}`);
    console.log(`   message: ${(error.message ?? '').split('\n')[0]}`);
  }
}
