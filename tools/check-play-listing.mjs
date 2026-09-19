#!/usr/bin/env node
/**
 * A NYILVÁNOS Play-oldal állapota (csak olvasás, tájékoztató).
 *
 * MIÉRT: a tulajdonos kérdezte, hogy „látszik-e a boltban”. A válasz nem az,
 * amit az ember vár: amíg az app **zárt tesztben** van, **nincs nyilvános
 * bolt-lap** (ilyenkor a Play 404-et ad), és a zárt teszt buildjei sem ott
 * jelennek meg — azokat csak a jelentkezett teszterek kapják meg. Ez az eszköz
 * ezt a tényt méri, hogy senki ne a rossz helyen keresse a frissítést.
 *
 * Ha az app egyszer nyilvános lesz, ez az eszköz megmutatja, hogy a kiadási
 * szöveg kikerült-e a nyilvános lapra.
 *
 * Futtatás: node tools/check-play-listing.mjs [package.name]
 * Kilépési kód: 0 = a mérés lefutott (akár 404, akár élő lap), 2 = hálózati hiba.
 */
const PACKAGE = process.argv[2] || 'hu.hungarianhardstyle.app';
const EXPECTED_SNIPPETS = ['Chat: a régebbi üzenetek', 'Adminoknak', 'azonnal látszik'];

(async () => {
  const response = await fetch(`https://play.google.com/store/apps/details?id=${PACKAGE}&hl=hu&gl=HU`, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' },
  });
  const html = await response.text();
  console.log(`csomagnév: ${PACKAGE}`);
  console.log(`Play-oldal: status=${response.status}`);

  if (response.status === 404) {
    console.log('  → az app **zárt tesztben** van: nincs nyilvános bolt-lap, ez VÁRT eredmény.');
    console.log('  → a zárt teszt buildjeit a Play Console → Zárt teszt → Kiadások, illetve a teszter telefonja mutatja.');
    return 0;
  }
  if (!response.ok) {
    console.log(`  → nem várt válasz; próbáld később.`);
    return 0;
  }

  const versions = [...new Set(html.match(/\b\d+\.\d+\.\d+\b/g) || [])];
  console.log(`  verziónak látszó szövegek: ${versions.slice(0, 6).join(', ') || 'nincs'}`);
  let found = 0;
  for (const snippet of EXPECTED_SNIPPETS) {
    const present = html.includes(snippet);
    if (present) found += 1;
    console.log(`  „${snippet}”: ${present ? 'megvan a nyilvános lapon' : 'nincs a nyilvános lapon'}`);
  }
  console.log(
    found === 0
      ? '  → a nyilvános lap él, de a legfrissebb kiadási szöveg még nem látszik rajta (a Play késleltethet).'
      : `  → a nyilvános lapon ${found}/${EXPECTED_SNIPPETS.length} várt szövegrész megvan.`,
  );
  return 0;
})()
  .then((code) => {
    process.exitCode = code;
  })
  .catch((error) => {
    console.error(`HIBA: ${error.message}`);
    process.exitCode = 2;
  });
