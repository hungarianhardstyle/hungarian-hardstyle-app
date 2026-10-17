#!/usr/bin/env node
// ÉLŐ mérés: mennyi eszköz van a plugin push-token tárolójában (vendégek is), és
// mennyi a regisztrált profilokban (Firestore). A plugin diagnosztikai fejlécéből
// olvasunk (`x-huhs-health`), ami a `huhs_push_tokens` option méretét írja ki.
const SITE = 'https://hungarianhardstyle.hu';
const MARKER = 'huhs-boot-probe-2026';

const response = await fetch(
  `${SITE}/wp-json/huhs/v1/posts?per_page=1&huhs_diag=${MARKER}&probe=${Date.now()}`,
  { headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' } },
);
const health = response.headers.get('x-huhs-health') || '';
const pick = (key) => new RegExp(`${key}=([^\\s]+)`).exec(health)?.[1] ?? '';
console.log(`HTTP ${response.status}`);
console.log(`  apiVersion      = ${pick('api')}`);
console.log(`  push_tokens     = ${pick('push_tokens')}`);
console.log(`  push_last       = ${pick('push_last')}`);
console.log(`  recipients      = ${pick('recipients')}`);
console.log(`  sent            = ${pick('sent')}`);
console.log(`\n(fejléc nyers része): ${health.slice(0, 260)}`);
