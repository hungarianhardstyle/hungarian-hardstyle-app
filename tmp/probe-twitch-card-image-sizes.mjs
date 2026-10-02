// A tulajdonos beharangozó képének MÉRETEI a WordPressen (van-e kicsinyített változat?).
//
// MIÉRT (a tulajdonos jelzése, 2026-10-02): *„meg ez a twitch kártya a főoldalon
// 100 év mire betölt”* — a kép **1,2 MB / 1672×941**, és a kártya ezt tölti le.
// A WordPress a feltöltésnél készít kisebb változatokat (`-1024x577`, `-768x432`,
// `-300x169`), ezért mérjük, melyik létezik és mekkora.
//
// Használat: node tmp/probe-twitch-card-image-sizes.mjs
const ORIGINAL =
  'https://hungarianhardstyle.hu/wp-content/uploads/2026/10/denioser-stream.png';

const head = async (url) => {
  try {
    const response = await fetch(url, { method: 'HEAD' });
    const length = Number(response.headers.get('content-length') ?? 0);
    return { status: response.status, length };
  } catch (error) {
    return { status: 0, length: 0, error: error.message };
  }
};

const candidates = [ORIGINAL];
for (const size of ['1024', '768', '600', '300', '150']) {
  // A WordPress a szélesség × (arányos magasság) utótagot teszi a fájlnév elé.
  const height = Math.round((941 / 1672) * Number(size));
  candidates.push(ORIGINAL.replace(/\.png$/, `-${size}x${height}.png`));
}
// A WordPress „scaled” változata (nagy képeknél ez a fő változat).
candidates.push(ORIGINAL.replace(/\.png$/, '-scaled.png'));

console.log('eredeti:', ORIGINAL, '\n');
let best = null;
for (const url of candidates) {
  const result = await head(url);
  const kb = result.length ? `${Math.round(result.length / 1024)} KB` : '—';
  console.log(`${result.status === 200 ? 'OK   ' : 'nincs'} ${String(result.status).padEnd(4)} ${kb.padStart(8)}  ${url.split('/').pop()}`);
  if (result.status === 200 && result.length > 0 && (best === null || result.length < best.length)) {
    best = { url, length: result.length };
  }
}

if (best && best.length < 400 * 1024) {
  console.log(`\nA legkisebb elérhető változat: ${best.url} (${Math.round(best.length / 1024)} KB)`);
} else if (best) {
  console.log(`\nA legkisebb elérhető változat is nagy: ${Math.round(best.length / 1024)} KB`);
} else {
  console.log('\nNem találtam kicsinyített változatot — a kliens oldali gyorsítótár/átméretezés marad.');
}
