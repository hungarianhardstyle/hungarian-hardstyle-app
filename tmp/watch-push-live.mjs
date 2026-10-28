#!/usr/bin/env node
/**
 * Élő push-figyelő (2.14.24 utáni mérés).
 *
 * MIÉRT: a lánc helyreállása csak ÚJ közzétételnél mérhető (nem spamoljuk a
 * felhasználókat próbaküldéssel). Ezért ez a szkript halkan figyeli a
 * diagnosztikai fejlécet, és CSAK a változást írja ki: mikor indul kör
 * (`push_jobs` 0→1), mikor halad (`processed`), és mikor fejeződik be
 * (`push_jobs` 1→0, `processed == recipients`).
 *
 * Futás: node tmp/watch-push-live.mjs [--minutes=12]
 */
const SITE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
const minutes = Number((process.argv.find((a) => a.startsWith('--minutes=')) || '').split('=')[1] || 12);
const deadline = Date.now() + minutes * 60 * 1000;

const pick = (header, key) => new RegExp(`${key}=([^\\s]+)`).exec(header)?.[1] ?? '';
const KEYS = ['push_last', 'at', 'push_jobs', 'push_job', 'push_active', 'recipients', 'processed', 'sent', 'failed', 'dead', 'news_scan', 'cron_overdue'];

let previous = null;
let samples = 0;
while (Date.now() < deadline) {
  samples++;
  let line = '';
  try {
    const response = await fetch(
      `${SITE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=watch-${Date.now()}`,
      { headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' } },
    );
    const header = response.headers.get('x-huhs-health') || '';
    const api = pick(header, 'api');
    line = `api=${api} ` + KEYS.map((key) => `${key}=${pick(header, key) || '-'}`).join(' ');
  } catch (error) {
    line = `HIBA: ${error.message}`;
  }
  if (line !== previous) {
    const stamp = new Date().toISOString().slice(11, 19);
    console.log(`${stamp} ${line}`);
    previous = line;
  }
  await new Promise((resolve) => setTimeout(resolve, 15000));
}
console.log(`\nFIGYELÉS VÉGE — ${samples} minta, ${minutes} perc`);
