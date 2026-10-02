// ÉLES mérés: fut-e a Twitch-élő figyelő, és mit lát? (csak olvas)
import { accessToken } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const filter = [
  'resource.type="cloud_function"',
  'resource.labels.function_name="sendTwitchLiveNotice"',
].join(' AND ');

const response = await fetch('https://logging.googleapis.com/v2/entries:list', {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    resourceNames: ['projects/hungarian-hardstyle'],
    filter,
    orderBy: 'timestamp desc',
    pageSize: 20,
  }),
});
const body = await response.json().catch(() => ({}));
console.log(`HTTP ${response.status} | bejegyzések: ${(body.entries || []).length}`);
for (const entry of body.entries || []) {
  const payload = entry.jsonPayload ?? {};
  const text =
    typeof entry.textPayload === 'string' && entry.textPayload.trim()
      ? entry.textPayload.trim()
      : JSON.stringify(payload);
  console.log(`  ${entry.timestamp} ${entry.severity || ''} ${text.slice(0, 200)}`);
}
if (!body.entries) console.log(JSON.stringify(body).slice(0, 400));
