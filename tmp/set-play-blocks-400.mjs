#!/usr/bin/env node
// A Play-jegyzet 400-as blokkjai + a 400-as tételes szakasz (PowerShell helyett .mjs,
// mert a magyar ékezetek és a `node -e` idézőjelei korábban elhasaltak).
import fs from 'node:fs';

const DOC = 'docs/PLAY-KIADASI-JEGYZET.md';
let doc = fs.readFileSync(DOC, 'utf8');

const oldFirst = `- Javítva: a rádió zárképernyőjén és értesítési sávjában is megjelenik a Szüneteltetés gomb (Android, iPhone).
- Javítva: szüneteltetéskor a vezérlő a helyén marad, és a rendszer a helyes állapotot mutatja.
- Javítva: fekvő módban a friss hírek, a kiemelt hír és a Twitch-kártya sem óriási.
- ÚJ: ha megy a Twitch-adás, a főoldali kártyán a stream mozgóképe látszik.`;

const newFirst = `- Javítva: a rádió Szüneteltetés gombja megjelenik a zárképernyőn és az értesítési sávban (Android, iPhone).
- Javítva: a gomb a rádió valódi állapotát követi (indulás után is), és szünetnél sem tűnik el.
- Javítva: fekvő módban a friss hírek, a kiemelt hír és a Twitch-kártya sem óriási.
- ÚJ: ha megy a Twitch-adás, a főoldali kártyán a stream mozgóképe látszik.`;

const oldEles = `- ÚJ: Twitch-adás az appban, külön stream-chattal; élő adásnál a stream mozgóképe a főoldali kártyán.
- Javítva: a rádió zárképernyőjén és értesítési sávjában is ott a Szüneteltetés gomb (Android, iPhone).
- ÚJ: a rádió „most szól” a zárképernyőn; a főoldali Twitch-kártya azonnal betölt.
- Javítva: fekvő módban a hírek, a kiemelt hír és a Twitch-kártya sem lesz óriási.
- ÚJ: a regisztrációd törlésével a nyereményjátékból is kikerülsz (nem nyerhetsz jegyet).`;

const newEles = `- ÚJ: Twitch-adás az appban, külön stream-chattal; élő adásnál a stream mozgóképe a főoldali kártyán.
- Javítva: a rádió Szüneteltetés gombja megjelenik a zárképernyőn és az értesítési sávban (Android, iPhone).
- ÚJ: a rádió „most szól” a zárképernyőn; a főoldali Twitch-kártya azonnal betölt.
- Javítva: fekvő módban a hírek, a kiemelt hír és a Twitch-kártya sem lesz óriási.
- ÚJ: a regisztrációd törlésével a nyereményjátékból is kikerülsz (nem nyerhetsz jegyet).`;

function swap(from, to, label, { all = false } = {}) {
  const count = doc.split(from).length - 1;
  if (count === 0) {
    console.log(`ELTÉR  ${label}: a minta nem található`);
    process.exitCode = 1;
    return;
  }
  doc = all ? doc.split(from).join(to) : doc.replace(from, to);
  console.log(`OK     ${label}: ${all ? count : 1} csere`);
}

swap(oldFirst, newFirst, '1. blokk + 1d (zárt teszt)', { all: true });
swap(oldEles, newEles, '2b blokk (éles sáv)');

const headings = [
  ['## 1b-2. Play Console — a **361–399** összesítő (a 384 után)', '## 1b-2. Play Console — a **361–400** összesítő (a 384 után)'],
  ['amelyek a **361–399** között készültek', 'amelyek a **361–400** között készültek'],
  ['## 1b-3. Play Console — a **BÉTA** sávhoz (**355–399** összesítő)', '## 1b-3. Play Console — a **BÉTA** sávhoz (**355–400** összesítő)'],
  ['ha a 399-et a béta (nyílt teszt) sávra teszed fel', 'ha a 400-at a béta (nyílt teszt) sávra teszed fel'],
  ['## 1d. Play Console — a **ZÁRT TESZTRE** (398 → 399: ugyanaz, mint az 1. blokk)', '## 1d. Play Console — a **ZÁRT TESZTRE** (398 → 400: ugyanaz, mint az 1. blokk)'],
  ['⚠️ A **399**-et az **éles** sávra téve nem ez a blokk való', '⚠️ A **400**-at az **éles** sávra téve nem ez a blokk való'],
  ['## 2b. Play Console — az **ÉLES** sávra (384 → 399, egyetlen blokk)', '## 2b. Play Console — az **ÉLES** sávra (384 → 400, egyetlen blokk)'],
  ['**385–399** közötti újdonságok az újak', '**385–400** közötti újdonságok az újak'],
  ['**1. blokk** és a **361–399** összesítő együtt', '**1. blokk** és a **361–400** összesítő együtt'],
  ['hanem az **1. blokk** (`tmp/play-399-zart.txt`)', 'hanem az **1. blokk** (`tmp/play-400-zart.txt`)'],
  ['A kész, másolható változat: `tmp/play-399-eles.txt`', 'A kész, másolható változat: `tmp/play-400-eles.txt`'],
];
for (const [from, to] of headings) swap(from, to, from.slice(0, 42));

const section400 = `### 400 — a rádió Szüneteltetés gombja tényleg megjelenik a zárképernyőn (iPhone)
- **A tulajdonos jelzése (2026-10-04, iPhone):** *„nem nincs pause gomb, play van meg stop és ha rányomok a playre, egy pillre pause lesz belőle aztán visszaáll stop gombra és szól a rádió”*.
- **A MÉRT GYÖKÉR HÁROM RÉTEGE:** (1) a kártyát a **rendszer** rajzolja a **saját** állapotából — iOS-en a \`MPNowPlayingInfoCenter.playbackState\`-ből **és** a \`nowPlayingInfo\` \`playbackRate\` értékéből —, nem az értesítés akció-sorából; (2) a **\`playbackRate\` beleragadt a 0-ba**, mert a \`metadata\` (15 másodpercenként) szándékosan **megőrizte** a szótárban lévő régi értéket, a „szól” állapot pedig csak **egyszer**, a kattintás pillanatában ment ki — a hang viszont csak a stream betöltése **után** indul; (3) a Dart oldali állapot-üzenet **el sem indult**: a \`NowPlayingReporter.reportState\` a **megadott** paraméterekből épített csatornalistát, ezért a valódi hívás (csatorna nélkül) **egyetlen csatornára sem** küldött. ⚠️ **A saját tesztem ezt elfedte** (explicit csatornával hívott), ezért a 399 zöld kapui mellett a hiba élve maradt.
- **A JAVÍTÁS:** (1) a Swift-oldalon **egy helyen** dől el minden (\`applyPlaybackState\`): \`playbackState\`, a \`playbackRate\` (mindig az utoljára jelentett állapotból) és egy **5 másodperces szívverés**, ami ismétli — álló rádiónál nincs; (2) a Dart-oldal a **valódi hangindulást** is jelzi (\`radioAudioPlayingState\` a \`playerStateStream\`-ből: \`ready\` + \`playing\`), és az állapot minden váltáskor + a hang indulásakor kimegy; (3) a \`reportState\` **alapból az iOS-csatornára** küld (a hívó nem tud csatorna nélkül hívni).
- **A kapu mérése:** új viselkedési kör (\`test/services/radio_now_playing_sync_test.dart\`, 3 eset: a hang indulása kiváltja a kiírást, 5 másodperces szívverés, leállítás után nincs ismétlés és nem marad időzítő) + a Swift-oldal forrás-lintjei (a rate az állapotból jön, a „megőrző” ág eltűnt, szívverés); \`flutter test\` **1563/1563**, \`flutter analyze lib test\` **0 hiba**.

### 399 — a rádió Szüneteltetés gombja megjelenik a zárképernyőn és az értesítési sávban`;

swap('### 399 — a rádió Szüneteltetés gombja megjelenik a zárképernyőn és az értesítési sávban', section400, '400-as tételes szakasz');

fs.writeFileSync(DOC, doc, 'utf8');
console.log(process.exitCode === 1 ? '\nHIBA: valamelyik minta nem illett' : '\nMINDEN CSERE RENDBEN');
