// A Play-jegyzet átállítása a 389-es buildre (mért értékekkel).
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
const before = fs.readFileSync(file, 'utf8');
let text = before;
const swaps = [
  ['currentBuild: 388', 'currentBuild: 389'],
  ['aab: build/HUHS-v1.0.0+388-release.aab', 'aab: build/HUHS-v1.0.0+389-release.aab'],
  ['sha256: 31C5CA3F17190D253788E8178D8923A841FD1EDDB036CA859887EFF6C5081E90', 'sha256: 28D9D5D053512E6CEBACF7BFBC622B5C2A215C4D16475B9B5C18A3FCFABDF482'],
  ['| `build/HUHS-v1.0.0+388-release.aab` |', '| `build/HUHS-v1.0.0+389-release.aab` |'],
  ['| Verziókód | **388** (a merge-elt', '| Verziókód | **389** (a merge-elt'],
  ['| Méret | 83 416 226 bájt (79,6 MiB)', '| Méret | 83 430 168 bájt (79,6 MiB)'],
  ['| SHA-256 | `31C5CA3F17190D253788E8178D8923A841FD1EDDB036CA859887EFF6C5081E90` |', '| SHA-256 | `28D9D5D053512E6CEBACF7BFBC622B5C2A215C4D16475B9B5C18A3FCFABDF482` |'],
  ['**⚠️ A 388 a feltöltendő csomag** (versionCode **388**', '**⚠️ A 389 a feltöltendő csomag** (versionCode **389**'],
  ['ezért a 388-nál kisebb kódú csomagot a Play', 'ezért a 389-nél kisebb kódú csomagot a Play'],
  ['a 388 a 384 minden javítását is tartalmazza', 'a 389 a 384 minden javítását is tartalmazza'],
  ['**A 385-öt, a 386-ot és a 387-et nem', '**A 385–388-at nem'],
  ['(a 388 azokat is tartalmazza) — a 388 újdonságai', '(a 389 azokat is tartalmazza) — a 389 újdonságai'],
  ['**A következő nyilvános kiadás a 388**', '**A következő nyilvános kiadás a 389**'],
  ['a `build/HUHS-v1.0.0+388-release.aab` feltöltése', 'a `build/HUHS-v1.0.0+389-release.aab` feltöltése'],
  ['**384 → 388** lépéshez', '**384 → 389** lépéshez'],
  ['- Javítva: a rádiónál a zárképernyőn és az értesítésben is van Leállítás gomb.', '- Javítva: a rádiónál a zárképernyőn és az értesítésben is van Leállítás gomb.'],
  ['- ÚJ: a Twitch-kártya beharangozója a WordPress-adminban állítható (kép, felirat).', '- ÚJ: a Twitch-beharangozó kártya a WordPress-adminban állítható, és magától frissül.'],
];

let failed = 0;
for (const [from, to] of swaps) {
  const count = text.split(from).length - 1;
  if (count === 0) {
    console.log(`HIBA  nem található: ${from.slice(0, 60)}`);
    failed += 1;
    continue;
  }
  text = text.split(from).join(to);
}
if (!failed) fs.writeFileSync(file, text, 'utf8');
console.log(failed ? `\n${failed} csere nem illeszkedett (a fájl változatlan)` : `\nMINDEN CSERE RENDBEN (${before !== text ? 'frissült' : 'nem volt változás'})`);
process.exitCode = failed ? 1 : 0;
