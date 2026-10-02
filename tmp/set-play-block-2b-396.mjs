// A Play-jegyzet „2b." (ÉLES sáv) blokkjának frissítése a 396-os tartalomra.
import fs from 'node:fs';

const file = 'docs/PLAY-KIADASI-JEGYZET.md';
let source = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');

const oldBlock = [
  '- ÚJ: Twitch-adás az appban (külön stream-chattal, emotikonokkal); az élő értesítés az app Twitch-oldalát nyitja.',
  '- Javítva: a Twitch-chat üzenetküldése (eddig mindig hibára futott), a rádiósáv lekerül az oldalról, gépeléskor nagyobb a chat.',
  '- ÚJ: a rádió „most szól” a zárképernyőn a logóval; a főoldali Twitch-kártya azonnal betölt.',
  '- Javítva: a Twitch-chat fekvő módban és tableten is látszik; kis képernyőn csak a videó látszik.',
].join('\n');

const newBlock = [
  '- ÚJ: Twitch-adás az appban (külön stream-chattal, emotikonokkal); az élő értesítés az app Twitch-oldalát nyitja.',
  '- Javítva: a Twitch-chat üzenetküldése, fekvő/tablet nézete; a rádiósáv lekerül az oldalról.',
  '- ÚJ: a rádió „most szól” a zárképernyőn; a főoldali Twitch-kártya azonnal betölt.',
  '- ÚJ: ha törlöd a regisztrációdat, a neved a nyereményjátékból is kikerül (nem nyerhetsz jegyet).',
].join('\n');

if (!source.includes(oldBlock)) {
  console.log('NEM található a 2b blokk (a dokumentum változott?)');
  process.exit(1);
}
source = source.replace(oldBlock, newBlock);
fs.writeFileSync(file, source, 'utf8');
console.log('a 2b blokk frissítve a 396-os tartalomra');
