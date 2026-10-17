#!/usr/bin/env node
// A push-kör TELJES állapota a plugin diagnosztikai fejlécéből (minden mező),
// néhányszor egymás után — a kézbesítés szeletekben fut (WP-Cron).
const SITE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';
const rounds = Number((process.argv.find((a) => a.startsWith('--rounds=')) || '').split('=')[1] || 6);

const pick = (header, key) => new RegExp(`${key}=([^\\s]+)`).exec(header)?.[1] ?? '';
for (let round = 1; round <= rounds; round += 1) {
  const response = await fetch(
    `${SITE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=${Date.now()}-${round}`,
    { headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' } },
  );
  const header = response.headers.get('x-huhs-health') || '';
  const keys = ['api', 'push_tokens', 'push_last', 'push_job', 'push_active', 'recipients', 'processed', 'sent', 'failed', 'dead'];
  const line = keys.map((key) => `${key}=${pick(header, key) || '-'}`).join(' ');
  console.log(`[${round}] ${line}`);
  const active = pick(header, 'push_active');
  if (round > 1 && (!active || active === 'no' || active === '0')) break;
  await new Promise((resolve) => setTimeout(resolve, 6000));
}
