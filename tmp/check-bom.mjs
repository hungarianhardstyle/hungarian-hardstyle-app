// BOM-ellenőrzés az imént módosított fájlokon (a PowerShell-írás veszélye).
import fs from 'node:fs';

const files = [
  'lib/screens/news/news_detail_screen.dart',
  'lib/screens/events/event_detail_screen.dart',
  'lib/screens/releases/release_detail_screen.dart',
  'lib/screens/artists/artist_detail_screen.dart',
];
let bad = 0;
for (const file of files) {
  const bytes = fs.readFileSync(file);
  const bom = bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf;
  const crlf = bytes.includes(Buffer.from('\r\n'));
  console.log(`${bom ? 'BOM VAN ' : 'OK      '} ${file}  (CRLF: ${crlf ? 'igen' : 'nem'}, ${bytes.length} bájt)`);
  if (bom) bad += 1;
}
console.log(`\n${files.length - bad}/${files.length} fájl BOM nélkül`);
process.exitCode = bad ? 1 : 0;
