#!/usr/bin/env node
/**
 * A rádió **médiakártya** állapotának mérése (emulátor/készülék, csak olvas).
 *
 * MIÉRT: a tulajdonos jelzése szerint *„nincs stop gomb, a zárképernyőn sincs"*.
 * Azt kell mérni, hogy az új „Leállítás" akció **tényleg benne van-e** abban,
 * amiből a rendszer a kártyát rajzolja:
 *  1. a **MediaSession PlaybackState** akciói és **egyedi akciói** (`custom actions`),
 *  2. az **értesítés** akció-sora (`actions=`) és a kompakt nézet indexei.
 *
 * Használat: node tmp/measure-radio-stop-action.mjs
 */
import { execFileSync } from 'node:child_process';

const adb = `${process.env.LOCALAPPDATA}\\Android\\Sdk\\platform-tools\\adb.exe`;
const sh = (...args) => execFileSync(adb, ['shell', ...args], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });

let failures = 0;
const check = (label, ok, detail = '') => {
  if (!ok) failures += 1;
  console.log(`${ok ? 'OK  ' : 'HIÁNY'} ${label}${detail ? ` — ${detail}` : ''}`);
};

const sessions = sh('dumpsys', 'media_session');
const blocks = sessions.split(/\r?\n/);
const start = blocks.findIndex((line) => line.includes('package=hu.hungarianhardstyle.app'));
const sessionBlock = start >= 0 ? blocks.slice(start, start + 30).join('\n') : '';
const playback = /state=PlaybackState \{([^}]*)\}/.exec(sessionBlock)?.[1] ?? '';
const customActions = /custom actions=\[([^\]]*)\]/.exec(playback)?.[1] ?? '';
const actions = /actions=(\d+)/.exec(playback)?.[1] ?? '';

console.log('=== 1) A médiamunkamenet (ebből rajzol a zárképernyő kártyája) ===');
console.log(`  actions=${actions}  custom actions=[${customActions}]`);
check('van aktív médiamunkamenetünk', start >= 0, start >= 0 ? 'megvan' : 'nincs (indítsd el a rádiót)');
check(
  'a „Leállítás" ott van az EGYEDI akciók között (a kártya ezt rajzolja ki)',
  /Leállítás/.test(customActions),
  customActions || '(üres)',
);
// ACTION_STOP = 1 << 6 = 64; a play/pause is kell, hogy a kártya vezérelhető legyen.
const actionsValue = Number(actions) || 0;
check('a PlaybackState hirdeti a STOP akciót is', (actionsValue & 64) !== 0, String(actionsValue));
check('a PlaybackState hirdeti a lejátszás/szünet akciót is', (actionsValue & 1) !== 0 && (actionsValue & 2) !== 0, String(actionsValue));

console.log('\n=== 2) Az értesítés (árnyékolt sor + kompakt nézet) ===');
const notifications = sh('dumpsys', 'notification', '--noredact');
const noticeStart = notifications.indexOf('hu.hungarianhardstyle.app');
const noticeBlock = noticeStart >= 0 ? notifications.slice(noticeStart, noticeStart + 4000) : '';
const noticeActions = [...noticeBlock.matchAll(/android\.action\.title=String \(([^)]*)\)/g)].map((m) => m[1]);
const hasStopIntent = /hu\.hungarianhardstyle\.app\.radio\.STOP/.test(noticeBlock) || /ServiceIntent/.test(noticeBlock);
console.log(`  akció-címek: ${noticeActions.length ? noticeActions.join(' | ') : '(nincs)'}`);
check('van rádió-értesítés', noticeStart >= 0);
check('az értesítés akció-sorában ott a „Leállítás"', noticeActions.includes('Leállítás'), noticeActions.join(','));
check('az értesítés a médiakártya-stílust használja', /MediaStyle|mStyle|template/i.test(noticeBlock));

console.log(failures ? `\n${failures} ellenőrzés NEM teljesült` : '\nMINDEN ELLENŐRZÉS RENDBEN');
process.exitCode = failures ? 1 : 0;
