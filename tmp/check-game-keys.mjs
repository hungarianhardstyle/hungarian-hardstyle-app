// A játék-képernyő címkéinek szótári lefedettsége — mérés, nem tipp.
// Használat: node tmp/check-game-keys.mjs
import { readFileSync } from 'node:fs';

const dict = JSON.parse(readFileSync('assets/i18n/en.json', 'utf8'));

// A `game_screen.dart`-ban előforduló, MEGJELENÍTETT szövegek.
const visible = [
  'Játék eredményei',
  'Az eredménylista most nem tölthető be.',
  'Próbáld ki magad!',
  'Az eredményeket a játék lezárása után láthatod{d}.',
  ' (eddig: {d})',
];
// Az `AppText`-tel már fordított (elméletileg meglévő) szövegek.
const alreadyTranslated = [
  'Eredménylista',
  'JÁTÉK',
  'Ebben a kvízben már játszottál',
  'Egy pillanat — betöltjük az eredményedet.',
  'Regisztráció szükséges',
  'A játékot meg tudod nézni, de a válaszadáshoz regisztrált felhasználói fiók kell.',
  'Rendezd időrendbe',
  'Tartsd hosszan az elemet, majd húzd a helyére.',
  'Köszönjük a játékodat!',
  'Újrapróbálás',
  'Zenerészlet lejátszása',
  'Minden kérdésre válaszolj a beküldés előtt.',
  'A hangrészlet most nem tölthető be.',
  'Ehhez a játékhoz még nincs megjeleníthető eredmény.',
];

function report(title, keys) {
  const missing = keys.filter((key) => !Object.prototype.hasOwnProperty.call(dict, key));
  console.log(`=== ${title}: ${keys.length - missing.length}/${keys.length} a szótárban`);
  for (const key of keys) {
    const value = dict[key];
    const mark = Object.prototype.hasOwnProperty.call(dict, key) ? 'VAN ' : 'HIÁNYZIK';
    console.log(`  ${mark} ${JSON.stringify(key)}${value ? ` -> ${JSON.stringify(value)}` : ''}`);
  }
  return missing;
}

const missingRaw = report('nyers (Text) címkék', visible);
report('AppText-tel fordított címkék', alreadyTranslated);

console.log(
  missingRaw.length === 0
    ? '\nMINDEN nyers címke kulcsa megvan a szótárban'
    : `\nHIÁNYZÓ kulcsok: ${missingRaw.length}`,
);
process.exitCode = missingRaw.length === 0 ? 0 : 1;
