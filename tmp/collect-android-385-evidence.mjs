#!/usr/bin/env node
/**
 * A 385-ös **Android-bizonyíték** rögzítése (emulátor, mért állapot).
 *
 * MIÉRT: a képernyőkép önmagában nem mondja meg, MI volt a szóló szám és hogy
 * a médiamenet valóban a mi szolgáltatásunktól jön. Ez a szkript a
 * `dumpsys` kimenetéből szedi ki a mért értékeket, és szövegesen rögzíti —
 * így a kép mellett a számok is megmaradnak.
 *
 * Használat: node tmp/collect-android-385-evidence.mjs
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const adb = `${process.env.LOCALAPPDATA}\\Android\\Sdk\\platform-tools\\adb.exe`;
const sh = (...args) => execFileSync(adb, ['shell', ...args], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });

const lines = [];
const say = (line = '') => {
  console.log(line);
  lines.push(line);
};

const notifications = sh('dumpsys', 'notification', '--noredact');
const session = sh('dumpsys', 'media_session');
const pkg = sh('dumpsys', 'package', 'hu.hungarianhardstyle.app');

const pick = (text, pattern, count = 6) =>
  text.split(/\r?\n/).filter((line) => pattern.test(line)).slice(0, count).map((line) => line.trim());

say('=== 385-ös Android-bizonyíték (emulátor, Android 14 / API 34) ===');
say(`méret időpontja: ${new Date().toISOString()}`);
say('');
say('--- verzió a telepített csomagból ---');
for (const line of pick(pkg, /versionCode=|versionName=/)) say(`  ${line}`);
say('');
say('--- a rádió médiamentje (channel=huhs_radio) ---');
for (const line of pick(notifications, /NotificationRecord\(.*hu\.hungarianhardstyle\.app/)) say(`  ${line}`);
say('');
say('--- a ment tartalma (ez a lényeg: a szóló szám + a rádió neve) ---');
for (const line of pick(notifications, /android\.(title|text)=String/)) say(`  ${line}`);
say('');
say('--- a ment nagy ikonja (a Real Hardstyle logó kell legyen) ---');
const iconBlock = notifications.split(/\r?\n/);
const iconIndex = iconBlock.findIndex((line) => /NotificationRecord\(.*hu\.hungarianhardstyle\.app/.test(line));
for (const line of iconBlock.slice(iconIndex, iconIndex + 40)) {
  if (/icon=|largeIcon|channel=|category=/.test(line)) say(`  ${line.trim()}`);
}
say('');
say('--- MediaSession (a lejátszó állapota) ---');
for (const line of pick(session, /hu\.hungarianhardstyle|state=PlaybackState.*state=PLAYING/, 8)) say(`  ${line}`);

const out = 'tmp/emu-385-evidence.txt';
fs.writeFileSync(out, `${lines.join('\n')}\n`, 'utf8');
say('');
say(`jegyzőkönyv: ${out}`);
