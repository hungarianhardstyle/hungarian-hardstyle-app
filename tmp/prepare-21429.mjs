#!/usr/bin/env node
/**
 * 2.14.29: a 14. kör (PUSH-ONCE) bekötése + readme bejegyzés + verzió.
 *
 * Futás: node tmp/prepare-21429.mjs
 */
import fs from 'node:fs';

// 1) A harness kör-listája.
const sh = 'tools/php/run-plugin-tests.sh';
let shText = fs.readFileSync(sh, 'utf8');
if (!shText.includes('verify-push-once.php')) {
  shText = shText.replace(
    'exit $fail',
    [
      '# A 2.14.29 ujdonsaga: a tulajdonos negy push-keresere a MERES.',
      '#  1-3) hir / esemeny / kiadvany / emlekezteto push MINDEN eszkoznek megy',
      '#       (a token-tarbol, a vendegek is benne vannak);',
      '#  4) egy eszkoz EGYSZER kap (token-ertekre dedupalva), es az emlekezteto/',
      '#       esemeny-push nem megy ki ketszer, ha a cron ES a scan osszefut.',
      'echo ""',
      'echo "=== 14) Push mindenkinek, es csak egyszer (2.14.29)"',
      'if php /work/tools/verify-push-once.php "$PLUGIN"; then',
      '  echo "PUSH-ONCE OK"',
      'else',
      '  echo "PUSH-ONCE HIBA"',
      '  fail=1',
      'fi',
      '',
      'exit $fail',
    ].join('\n'),
  );
  fs.writeFileSync(sh, shText, 'utf8');
}

// 2) Kötelező jelző.
const mjs = 'tools/run-php-plugin-tests.mjs';
let mjsText = fs.readFileSync(mjs, 'utf8');
if (!mjsText.includes("'PUSH-ONCE OK'")) {
  mjsText = mjsText.replace("'CHANGELOG-PAGE OK'];", "'CHANGELOG-PAGE OK', 'PUSH-ONCE OK'];");
  fs.writeFileSync(mjs, mjsText, 'utf8');
}

// 3) readme: kiadásjegyzék.
const readme = 'tmp/plugin-2154/huhs-mobile-api/readme.txt';
let readmeText = fs.readFileSync(readme, 'utf8');
const version = /Version:\s*(\S+)/.exec(fs.readFileSync('tmp/plugin-2154/huhs-mobile-api/huhs-mobile-api.php', 'utf8'))[1];
readmeText = readmeText.replace(/Stable tag: [0-9.]+/, `Stable tag: ${version}`);
if (!readmeText.includes(`= ${version} =`)) {
  readmeText = readmeText.replace(
    '== Changelog ==\n\n',
    [
      `== Changelog ==`,
      '',
      `= ${version} =`,
      '* Javítva: egy készülék **egy** értesítést kap egy körből (a token-tárban egy eszköz több kulcson is szerepelhetett → 2-3 push ugyanarra a telefonra).',
      '* Javítva: az **esemény-emlékeztető**, az **esemény/kiadvány push** és a **nyitás-értesítés** nem megy ki kétszer, ha a pontos cron-esemény és az ötperces biztonsági scan ugyanabba az ablakba esik (foglalás a küldés előtt).',
      '* Javítva: az esemény/kiadvány adatcsomagjában a követett DJ-k/szervezők listája szövegként megy ki (`Array` helyett).',
      '* Új: `push_dup=` diagnosztika — hány duplikált token van a tárban.',
      '',
    ].join('\n'),
  );
  fs.writeFileSync(readme, readmeText, 'utf8');
}

console.log('kör bekötve:', fs.readFileSync(sh, 'utf8').includes('verify-push-once.php'));
console.log('jelző:', /REQUIRED_MARKERS = \[[^\]]*\]/.exec(fs.readFileSync(mjs, 'utf8'))[0].includes('PUSH-ONCE OK'));
console.log('readme verzió:', version, '| bejegyzés:', fs.readFileSync(readme, 'utf8').includes(`= ${version} =`));
