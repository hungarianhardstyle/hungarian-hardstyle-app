// ÉLES mérés: melyik végpont ad kanonikus linket (megosztható URL-hez)?
const BASE = 'https://hungarianhardstyle.hu/wp-json/huhs/v1';

async function first(path) {
  const response = await fetch(`${BASE}${path}`, { headers: { Accept: 'application/json' } });
  if (!response.ok) return { path, status: response.status };
  const body = await response.json();
  const item = Array.isArray(body) ? body[0] : Array.isArray(body?.items) ? body.items[0] : null;
  if (!item) return { path, status: response.status, item: null };
  const keys = Object.keys(item).sort();
  return {
    path,
    status: response.status,
    id: item.id,
    link: item.link ?? item.url ?? item.permalink ?? '(nincs link mező)',
    linkKeys: keys.filter((key) => /link|url|permalink|slug/i.test(key)),
    keys,
  };
}

for (const path of ['/posts?per_page=1', '/events', '/releases?per_page=1', '/artists?per_page=1']) {
  const result = await first(path);
  console.log(`\n=== ${path} (HTTP ${result.status}) ===`);
  if (!result.item && !result.keys) {
    console.log('  (nincs elem)');
    continue;
  }
  console.log(`  id=${result.id}`);
  console.log(`  link: ${result.link}`);
  console.log(`  link-szerű mezők: ${result.linkKeys.join(', ') || '(egy sem)'}`);
}
