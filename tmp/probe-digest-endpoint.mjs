// ÉLES mérés: létezik-e már a heti-összefoglaló végpont a WordPressen?
//
// Ez dönti el, hogy a Cloud Function fan-outja tud-e küldeni, vagy a tartalék-út
// fut (a regisztráltaknak, ~45 fő). Nem tippelünk: hívjuk a végpontot.
const url = 'https://hungarianhardstyle.hu/wp-json/huhs/v1/push/digest';

for (const [label, init] of [
  ['hitelesítés nélkül (401/403 várt, ha létezik)', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }],
  ['GET-tel (a route létezésének próbája)', { method: 'GET' }],
]) {
  try {
    const response = await fetch(url, init);
    const body = await response.text();
    console.log(`${label}: HTTP ${response.status} — ${body.slice(0, 160).replace(/\s+/g, ' ')}`);
  } catch (error) {
    console.log(`${label}: hiba — ${error.message}`);
  }
}

// A plugin verziója (a health fejlécből) — ez mondja meg, fent van-e a 2.14.8.
try {
  const response = await fetch('https://hungarianhardstyle.hu/wp-json/huhs/v1/posts?per_page=1&probe=digest-route', {
    headers: { Accept: 'application/json' },
  });
  console.log(`\nélő plugin: ${response.headers.get('x-huhs-health') || '(nincs health fejléc)'}`);
} catch (error) {
  console.log(`\nélő plugin: hiba — ${error.message}`);
}
