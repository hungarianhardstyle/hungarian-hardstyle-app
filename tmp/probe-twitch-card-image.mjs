// A Twitch-beharangozó KÉPÉNEK valódi elérhetősége (ezt tölti le az app).
// Csak olvas: HEAD + GET az első bájtokra, és megmondja, mit látna a telefon.
import https from 'node:https';
import http from 'node:http';

const PLUGIN = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/twitch-card';

function get(url, { method = 'GET', headers = {}, maxBytes = 64 } = {}) {
  return new Promise((resolve) => {
    const lib = url.startsWith('https:') ? https : http;
    const req = lib.request(url, { method, headers }, (res) => {
      const chunks = [];
      let size = 0;
      res.on('data', (c) => {
        if (size < maxBytes) chunks.push(c);
        size += c.length;
        if (method === 'GET' && size > 4 * 1024 * 1024) res.destroy();
      });
      res.on('end', () =>
        resolve({ status: res.statusCode, headers: res.headers, head: Buffer.concat(chunks), bytes: size }),
      );
      res.on('close', () =>
        resolve({ status: res.statusCode, headers: res.headers, head: Buffer.concat(chunks), bytes: size }),
      );
    });
    req.on('error', (e) => resolve({ error: e.message }));
    req.setTimeout(20000, () => {
      req.destroy();
      resolve({ error: 'timeout' });
    });
    req.end();
  });
}

function sniff(buf) {
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'PNG';
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'JPEG';
  if (buf.length >= 6 && buf.subarray(0, 3).toString('latin1') === 'GIF') return 'GIF';
  if (buf.length >= 12 && buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP') return 'WEBP';
  return `ismeretlen (${buf.subarray(0, 4).toString('hex')})`;
}

// PNG méret (IHDR) és JPEG méret (SOF) – hogy tudjuk, mekkora a kártya képe.
function imageSize(buf) {
  if (buf.length > 24 && buf.subarray(1, 4).toString('latin1') === 'PNG') {
    return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
  }
  if (buf.length > 4 && buf[0] === 0xff && buf[1] === 0xd8) {
    let i = 2;
    while (i + 9 < buf.length) {
      if (buf[i] !== 0xff) { i++; continue; }
      const marker = buf[i + 1];
      const len = buf.readUInt16BE(i + 2);
      if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
        return { h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
      }
      i += 2 + len;
    }
  }
  return null;
}

const problems = [];

console.log('=== 1) A plugin végpontja (innen jön az URL) ===');
const cfgRes = await get(PLUGIN, { headers: { 'Cache-Control': 'no-cache' } });
if (cfgRes.error) {
  console.log(`  HIBA: ${cfgRes.error}`);
  problems.push(`a végpont nem érhető el: ${cfgRes.error}`);
} else {
  console.log(`  HTTP ${cfgRes.status}`);
  let cfg = null;
  try {
    cfg = JSON.parse(cfgRes.head.toString('utf8'));
  } catch {
    console.log(`  a válasz nem JSON: ${cfgRes.head.toString('utf8').slice(0, 120)}`);
  }
  if (cfg) {
    console.log(`  imageUrl="${cfg.imageUrl}" enabled=${cfg.enabled} showOffline=${cfg.showWhenOffline}`);
    const url = cfg.imageUrl;

    console.log('\n=== 2) A KÉP, ahogy az app letöltené ===');
    if (!url) {
      console.log('  nincs kép URL – a kártya a Twitch előnézetét használná');
    } else {
      const head = await get(url, { method: 'HEAD' });
      if (head.error) {
        console.log(`  HEAD HIBA: ${head.error}`);
        problems.push(`a kép HEAD kérése hibára futott: ${head.error}`);
      } else {
        console.log(`  HEAD HTTP ${head.status}  content-type=${head.headers['content-type']}  content-length=${head.headers['content-length']}`);
      }
      const full = await get(url, { maxBytes: 1024 * 1024 });
      if (full.error) {
        console.log(`  GET HIBA: ${full.error}`);
        problems.push(`a kép letöltése hibára futott: ${full.error}`);
      } else {
        const kind = sniff(full.head);
        const size = imageSize(full.head);
        console.log(`  GET  HTTP ${full.status}  formátum=${kind}  letöltött=${full.bytes} bájt${size ? `  méret=${size.w}x${size.h}` : ''}`);
        console.log(`  szerver=${full.headers['server'] ?? '(nincs)'}  cache=${full.headers['cache-control'] ?? '(nincs)'}`);
        if (full.status !== 200) problems.push(`a kép HTTP ${full.status}-at ad (a kártyán üres hely lenne)`);
        if (kind === 'ismeretlen' || kind.includes('ismeretlen')) {
          problems.push(`a kép tartalma nem képformátum (${kind}) – a Flutter nem tudja kirajzolni`);
        }
      }
      // Hotlink-védelem: böngésző nélkül, az app User-Agent-jével
      const ua = await get(url, {
        headers: { 'User-Agent': 'Dart/3.13 (dart:io)', Accept: 'image/*,*/*' },
      });
      if (!ua.error) console.log(`  Dart User-Agenttel: HTTP ${ua.status} (${sniff(ua.head)})`);
    }
  }
}

console.log('\n=== 3) ÍTÉLETET ===');
if (problems.length === 0) {
  console.log('  A kép URL-je ÉL, valódi képfájlt ad, és a végpont engedélyezi a kártyát.');
} else {
  for (const p of problems) console.log(`  ⚠️  ${p}`);
}
process.exit(problems.length === 0 ? 0 : 1);
