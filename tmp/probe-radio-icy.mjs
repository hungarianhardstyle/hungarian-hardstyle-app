// ICY (Shoutcast/Icecast) metaadat-mérés — „mit szól most a rádió?"
//
// MIÉRT: a tulajdonos kérése, hogy az értesítésben és a zárképernyőn **a szóló
// zenét** lehessen látni. Ehhez a stream metaadatát kell kiolvasni: ha a szerver
// küldi az `icy-metaint` fejlécet, akkor a hangfolyam minden N. bájtja után egy
// metaadat-blokk jön `StreamTitle='…';` tartalommal.
//
// Ez a szkript CSAK OLVAS: lekéri a fejléceket, majd a szükséges bájtmennyiséget.
import { argv, exit } from 'node:process';

const url = argv[2] ?? 'https://stream.realhardstyle.nl';
console.log(`stream: ${url}`);

const response = await fetch(url, {
  headers: { 'Icy-MetaData': '1', 'User-Agent': 'HUHS-App/1.0 (metadata probe)' },
});
console.log(`HTTP ${response.status} | content-type: ${response.headers.get('content-type')}`);
for (const header of ['icy-name', 'icy-genre', 'icy-br', 'icy-metaint', 'icy-url', 'server']) {
  const value = response.headers.get(header);
  if (value) console.log(`  ${header}: ${value}`);
}

const metaint = Number(response.headers.get('icy-metaint') ?? 0);
if (!metaint) {
  console.log('\nNINCS icy-metaint → a stream nem küld zeneszám-metaadatot ezen a fejléckérésen.');
  exit(0);
}

// A hangfolyam első `metaint` bájtja után jön a metaadat-hossz (1 bájt, 16 bájtos
// egységekben), majd a szöveg. Elég az első blokk.
const reader = response.body.getReader();
let received = 0;
const chunks = [];
while (received < metaint + 4080) {
  const { value, done } = await reader.read();
  if (done) break;
  chunks.push(value);
  received += value.length;
}
await reader.cancel().catch(() => {});
const buffer = Buffer.concat(chunks);
if (buffer.length <= metaint) {
  console.log(`\nCsak ${buffer.length} bájt jött (a metaadat-blokk a ${metaint}. bájt után kezdődik).`);
  exit(0);
}
const lengthByte = buffer[metaint];
const textLength = lengthByte * 16;
const raw = buffer.subarray(metaint + 1, metaint + 1 + textLength).toString('utf8').replace(/\0+$/, '');
console.log(`\nmetaadat-blokk (${textLength} bájt): ${JSON.stringify(raw)}`);
const title = /StreamTitle='([^']*)'/.exec(raw)?.[1] ?? '';
const url_ = /StreamUrl='([^']*)'/.exec(raw)?.[1] ?? '';
console.log(`  StreamTitle: ${title || '(üres)'}`);
if (url_) console.log(`  StreamUrl:   ${url_}`);
console.log(
  title
    ? '\n→ A „most szól" cím kiolvasható a streamből, tehát az értesítésbe és a zárképernyőre is kiírható.'
    : '\n→ A blokk létezik, de üres címet ad (a rádió éppen nem küld számot).',
);
