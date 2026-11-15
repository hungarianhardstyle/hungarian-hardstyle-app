/** Restore stale queued status only after checking every published audio variant.
 * Usage: node tools/repair-label-audio-status.mjs <releaseId> [--confirm]
 * Uses the supported WordPress XML-RPC custom-field API; never reprocesses audio.
 */
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { secretAsync, firestoreSet } from './lib/live-firebase.mjs';

const require = createRequire(new URL('../functions/index.js', import.meta.url));
const { XMLParser } = require('fast-xml-parser');
const origin = 'https://hungarianhardstyle.hu';
const releaseId = Number(process.argv[2]);
assert(Number.isSafeInteger(releaseId) && releaseId > 0, 'Positive release ID required');
const [username, password] = await Promise.all([
  secretAsync('WORDPRESS_USERNAME'), secretAsync('WORDPRESS_APPLICATION_PASSWORD'),
]);
const headers = {
  Authorization: `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`,
  'Content-Type': 'application/json',
};
const escape = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
function encode(v) {
  if (Array.isArray(v)) return `<array><data>${v.map(x => `<value>${encode(x)}</value>`).join('')}</data></array>`;
  if (v && typeof v === 'object') return `<struct>${Object.entries(v).map(([k, x]) => `<member><name>${escape(k)}</name><value>${encode(x)}</value></member>`).join('')}</struct>`;
  return `<string>${escape(v)}</string>`;
}
function decode(v) {
  if (v.struct) {
    const m = v.struct.member;
    return Object.fromEntries((Array.isArray(m) ? m : [m]).map(x => [x.name, decode(x.value)]));
  }
  if (v.array) {
    const a = v.array.data?.value;
    return a ? (Array.isArray(a) ? a : [a]).map(decode) : [];
  }
  return v.string ?? v.int ?? v.i4 ?? v.boolean ?? v;
}
async function xmlrpc(method, extra) {
  const params = [0, username, password, ...extra];
  const r = await fetch(`${origin}/xmlrpc.php`, {
    method: 'POST', headers: { 'Content-Type': 'text/xml' },
    body: `<methodCall><methodName>${method}</methodName><params>${params.map(v => `<param><value>${encode(v)}</value></param>`).join('')}</params></methodCall>`,
    signal: AbortSignal.timeout(30000),
  });
  assert(r.ok, `XML-RPC HTTP ${r.status}`);
  const response = new XMLParser({ parseTagValue: false }).parse(await r.text()).methodResponse;
  assert(response, 'Invalid XML-RPC response');
  assert(!response.fault, `XML-RPC fault ${response.fault ? JSON.stringify(decode(response.fault.value)) : ''}`);
  return decode(response.params.param.value);
}
async function release() {
  const r = await fetch(`${origin}/wp-json/huhs/v1/releases/${releaseId}`, {
    headers: { ...headers, 'Cache-Control': 'no-cache' }, signal: AbortSignal.timeout(30000),
  });
  assert(r.ok, `Release HTTP ${r.status}`);
  const j = await r.json();
  assert.equal(Number(j.id), releaseId);
  return j;
}
async function checkAudio(url, wav) {
  assert.equal(new URL(url).origin, origin, 'Unexpected audio host');
  const r = await fetch(url, { signal: AbortSignal.timeout(30000) });
  assert(r.ok, `Audio HTTP ${r.status}`);
  const reader = r.body.getReader();
  const first = await reader.read();
  await reader.cancel();
  const b = Buffer.from(first.value || []);
  assert(wav
    ? b.subarray(0, 4).toString() === 'RIFF' && b.subarray(8, 12).toString() === 'WAVE'
    : b.subarray(0, 3).toString() === 'ID3' || b[0] === 255 && (b[1] & 224) === 224,
  'Audio signature does not match expected format');
}

const before = await release();
assert(!before.is_free, 'This repair targets paid releases');
assert.equal(before.audio_status, 'queued', 'Only stale queued records may be repaired');
const post = await xmlrpc('wp.getPost', [releaseId]);
assert.equal(post.post_type, 'huhs_release');
assert.equal(post.post_status, 'publish');
const statusField = post.custom_fields.find(x => x.key === 'audio_processing_status');
assert.equal(statusField?.value, 'queued');
const versions = before.versions.filter(x => x.available).map(x => x.type);
assert(versions.length && versions.every(v => ['radio', 'extended'].includes(v)));
// Completed conversion deletes the source attachments. Live sources need actual
// processing, so never relabel a freshly queued conversion using old outputs.
for (const version of versions) {
  const source = post.custom_fields.find(x => x.key === `huhs_${version}_audio_attachment_id`);
  assert(source && Number(source.value) === 0, 'Source attachment still present; reprocess instead');
  for (const format of ['wav', 'mp3_320']) {
    const variant = `${version}_${format}`;
    const r = await fetch(`${origin}/wp-json/huhs/v1/private-download-token`, {
      method: 'POST', headers, body: JSON.stringify({ releaseId, variant }),
      signal: AbortSignal.timeout(30000),
    });
    assert(r.ok, `Missing protected variant ${variant}: HTTP ${r.status}`);
    const j = await r.json();
    await checkAudio(j.download_url, format === 'wav');
    console.log(`VERIFIED ${variant}`);
  }
}
if (versions.includes('radio')) {
  assert(before.tracks?.[0]?.preview_url, 'Missing preview');
  await checkAudio(before.tracks[0].preview_url, false);
  console.log('VERIFIED preview');
}
const fresh = await xmlrpc('wp.getPost', [releaseId]);
assert.deepEqual(fresh.custom_fields, post.custom_fields, 'Release changed during verification');
assert.deepEqual(fresh.post_modified_gmt, post.post_modified_gmt, 'Release modified during verification');
if (process.argv.includes('--confirm')) {
  assert.equal(await xmlrpc('wp.editPost', [releaseId, {
    custom_fields: [{ id: statusField.id, key: statusField.key, value: 'ready' }],
  }]), '1');
  const saved = await xmlrpc('wp.getPost', [releaseId]);
  assert.equal(saved.custom_fields.find(x => x.key === statusField.key)?.value, 'ready');
  await firestoreSet(`label_product_sync_requests/repair-${releaseId}-${Date.now()}`, {
    releaseId, createdAt: new Date(), source: 'verified-audio-status-repair',
  });
  console.log(`REPAIRED ${releaseId}: ready; normal backend sync queued`);
} else {
  console.log(`VERIFIED ${releaseId}: safe to restore queued -> ready; pass --confirm to apply`);
}
