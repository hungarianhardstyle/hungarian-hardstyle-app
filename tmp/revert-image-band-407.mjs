#!/usr/bin/env node
/**
 * A 405-ös képkísérlet ELTÁVOLÍTÁSA (a tulajdonos kérése: „inkább legyen a régi
 * vissza"). A `FeaturedNewsImageBand` osztály (elmosott háttér + contain) kikerül
 * a fájlból; a kártya a régi, egyszerű `cover` képet használja.
 *
 * Futás: node tmp/revert-image-band-407.mjs
 */
import fs from 'node:fs';

const file = 'lib/widgets/featured_news_card.dart';
let text = fs.readFileSync(file, 'utf8');
const before = text;

// 1) A `dart:ui` import csak az elmosáshoz kellett.
text = text.replace("import 'dart:ui' as ui;\n\n", '');

// 2) A képkísérlet osztálya: a magyarázó blokk + az osztály (a fájl végéig).
const classAt = text.indexOf('class FeaturedNewsImageBand');
if (classAt > 0) {
  let start = text.lastIndexOf('///', classAt);
  // A magyarázó blokk az osztály előtti sorokban kezdődik.
  while (start > 0) {
    const prevLineStart = text.lastIndexOf('\n', start - 1) + 1;
    const line = text.slice(prevLineStart, start);
    if (line.trim() === '' || line.trim().startsWith('///')) {
      start = prevLineStart - 1 > 0 ? prevLineStart - 1 : 0;
      if (text.slice(start).trimStart().startsWith('///') === false) break;
      continue;
    }
    break;
  }
  const blockStart = text.lastIndexOf('\n\n///', classAt);
  const cutFrom = blockStart > 0 ? blockStart + 1 : classAt;
  text = text.slice(0, cutFrom).trimEnd() + '\n';
  console.log('képkísérlet osztály eltávolítva');
}

if (text !== before) {
  fs.writeFileSync(file, text, 'utf8');
}
console.log('dart:ui import:', text.includes("import 'dart:ui'"));
console.log('FeaturedNewsImageBand maradt:', text.includes('FeaturedNewsImageBand'));
console.log('fájl hossz:', text.length);
