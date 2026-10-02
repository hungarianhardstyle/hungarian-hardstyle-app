// A Real Hardstyle FM logó megkeresése (a zárképernyő/értesítés nagy ikonjához).
const response = await fetch('https://realhardstyle.nl', {
  headers: { 'User-Agent': 'Mozilla/5.0 (HUHS app asset lookup)' },
});
const html = await response.text();
console.log(`HTTP ${response.status} | ${html.length} bájt`);

const ogImage = [...html.matchAll(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/gi)].map((m) => m[1]);
const icons = [...html.matchAll(/<link[^>]+rel=["'][^"']*icon[^"']*["'][^>]+href=["']([^"']+)["']/gi)].map((m) => m[1]);
const images = [...html.matchAll(/<img[^>]+src=["']([^"']+)["']/gi)].map((m) => m[1]);
const logoish = images.filter((url) => /logo|brand|rhs/i.test(url));

console.log('og:image:', ogImage.slice(0, 2).join(' | ') || '(nincs)');
console.log('ikon:', icons.slice(0, 4).join(' | ') || '(nincs)');
console.log('logó-szerű képek:');
for (const url of logoish.slice(0, 8)) console.log('   ', url);
console.log('első képek:');
for (const url of images.slice(0, 8)) console.log('   ', url);

// Néhány tipikus útvonal, hátha közvetlenül elérhető (méret + típus).
const candidates = [
  ...logoish,
  ...ogImage,
  ...icons,
  'https://realhardstyle.nl/wp-content/uploads/2021/01/logo.png',
  'https://realhardstyle.nl/logo.png',
  'https://realhardstyle.nl/wp-content/uploads/logo.png',
];
const seen = new Set();
for (const url of candidates) {
  const absolute = url.startsWith('http') ? url : new URL(url, 'https://realhardstyle.nl').toString();
  if (seen.has(absolute)) continue;
  seen.add(absolute);
  try {
    const head = await fetch(absolute, { method: 'GET', headers: { 'User-Agent': 'HUHS asset lookup' } });
    const type = head.headers.get('content-type') ?? '';
    const length = head.headers.get('content-length') ?? '?';
    const isImage = type.startsWith('image/');
    console.log(`${isImage ? 'KÉP ' : 'nem '} HTTP ${head.status} ${type} ${length} bájt — ${absolute}`);
  } catch (error) {
    console.log(`hiba: ${absolute} (${error.message})`);
  }
}
