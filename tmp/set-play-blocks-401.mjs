#!/usr/bin/env node
// A Play-jegyzet 401-es blokkjai (a 400-as minta alapján).
import fs from 'node:fs';

const DOC = 'docs/PLAY-KIADASI-JEGYZET.md';
let doc = fs.readFileSync(DOC, 'utf8');
let bad = 0;

function swap(from, to, label, { all = false } = {}) {
  const count = doc.split(from).length - 1;
  if (count === 0) {
    console.log(`ELTÉR  ${label}: a minta nem található`);
    bad += 1;
    return;
  }
  doc = all ? doc.split(from).join(to) : doc.replace(from, to);
  console.log(`OK     ${label}: ${all ? count : 1} csere`);
}

// 1) A fejléc-blokk (1. blokk + 1d) a 401-es változásra.
const oldFirst = `- Javítva: a rádió Szüneteltetés gombja megjelenik a zárképernyőn és az értesítési sávban (Android, iPhone).
- Javítva: a gomb a rádió valódi állapotát követi (indulás után is), és szünetnél sem tűnik el.
- Javítva: fekvő módban a friss hírek, a kiemelt hír és a Twitch-kártya sem óriási.
- ÚJ: ha megy a Twitch-adás, a főoldali kártyán a stream mozgóképe látszik.`;

const newFirst = `- Javítva: iPhone-on a zárképernyőn megjelenik a rádió Szüneteltetés gombja (eddig csak play és stop volt).
- Javítva: a „Most szól” panel a rádió valódi állapotát követi, és szünetnél sem tűnik el.
- Javítva: fekvő módban a friss hírek, a kiemelt hír és a Twitch-kártya sem óriási.
- ÚJ: ha megy a Twitch-adás, a főoldali kártyán a stream mozgóképe látszik.`;

swap(oldFirst, newFirst, '1. blokk + 1d (zárt teszt)', { all: true });

// 2) A fejléc-proza és a szakaszcímek a 401-re.
const headings = [
  ['# Play Console — kiadási jegyzet (másolható)', '# Play Console — kiadási jegyzet (másolható)'],
  ['> 🟡 **A 400 A FELTÖLTENDŐ** (versionCode **400**, `1.0.0`) — a **398**-hoz képest:', '> 🟡 **A 401 A FELTÖLTENDŐ** (versionCode **401**, `1.0.0`) — a **400**-hoz képest:'],
  ['a **zárt tesztre** (398 → 400) az **1. blokk** (és a\n> `tmp/play-400-zart.txt`); az **ÉLES** sávra (384 → 400) a **2b. blokk** (`tmp/play-400-eles.txt`);\n> a **bétára** (377) a **355–400** összesítő (1b-3.) való.\n> ⚠️ **A 385–399-et NE tárd fel újra** — a 400 mindegyiket tartalmazza.',
    'a **zárt tesztre** (400 → 401) az **1. blokk** (és a\n> `tmp/play-401-zart.txt`); az **ÉLES** sávra (384 → 401) a **2b. blokk** (`tmp/play-401-eles.txt`);\n> a **bétára** (377) a **355–401** összesítő (1b-3.) való.\n> ⚠️ **A 385–400-at NE tárd fel újra** — a 401 mindegyiket tartalmazza.'],
  ['**ZÁRT TESZT (alpha) = 398** (kiadva, 100%-ban kigördülve) → ide (398 → 400) **ez a néhány sor** való.',
    '**ZÁRT TESZT (alpha) = 400** (kiadva, 100%-ban kigördülve) → ide (400 → 401) **ez a néhány sor** való.'],
  ['mert az 1. blokk + a **361–400** összesítő (**1b-2.**) együtt nem férne bele az 500-as limitbe.',
    'mert az 1. blokk + a **361–401** összesítő (**1b-2.**) együtt nem férne bele az 500-as limitbe.'],
  ['**NYÍLT TESZT (beta) = 377** → a **355–400** összesítő való (**1b-3.**).',
    '**NYÍLT TESZT (beta) = 377** → a **355–401** összesítő való (**1b-3.**).'],
  ['a **blokkal** és `tmp/play-400-eles.txt` (éles sáv).', 'a **blokkal** és `tmp/play-401-eles.txt` (éles sáv).'],
  ['A **398-as AAB már fent van** a Playen (kiadva a zárt teszten), a **400 az új** — a **385–399-et ne**\n> tárd fel újra. A **kész, másolható** változatok: `tmp/play-400-zart.txt` (zárt teszt, bájtazonos ezzel\n> a blokkal) és `tmp/play-400-eles.txt` (éles sáv).',
    'A **400-as AAB már fent van** a Playen (kiadva a zárt teszten), a **401 az új** — a **385–400-at ne**\n> tárd fel újra. A **kész, másolható** változatok: `tmp/play-401-zart.txt` (zárt teszt, bájtazonos ezzel\n> a blokkal) és `tmp/play-401-eles.txt` (éles sáv).'],
  ['## 1b-2. Play Console — a **361–400** összesítő (a 384 után)', '## 1b-2. Play Console — a **361–401** összesítő (a 384 után)'],
  ['amelyek a **361–400** között készültek', 'amelyek a **361–401** között készültek'],
  ['## 1b-3. Play Console — a **BÉTA** sávhoz (**355–400** összesítő)', '## 1b-3. Play Console — a **BÉTA** sávhoz (**355–401** összesítő)'],
  ['ha a 400-at a béta (nyílt teszt) sávra teszed fel', 'ha a 401-et a béta (nyílt teszt) sávra teszed fel'],
  ['## 1d. Play Console — a **ZÁRT TESZTRE** (398 → 400: ugyanaz, mint az 1. blokk)', '## 1d. Play Console — a **ZÁRT TESZTRE** (400 → 401: ugyanaz, mint az 1. blokk)'],
  ['⚠️ A **400**-at az **éles** sávra téve nem ez a blokk való', '⚠️ A **401**-et az **éles** sávra téve nem ez a blokk való'],
  ['**355–400** összesítő (**1b-3.**).', '**355–401** összesítő (**1b-3.**).'],
  ['## 2b. Play Console — az **ÉLES** sávra (384 → 400, egyetlen blokk)', '## 2b. Play Console — az **ÉLES** sávra (384 → 401, egyetlen blokk)'],
  ['**385–400** közötti újdonságok az újak', '**385–401** közötti újdonságok az újak'],
  ['**1. blokk** és a **361–400** összesítő együtt', '**1. blokk** és a **361–401** összesítő együtt'],
  ['hanem az **1. blokk** (`tmp/play-400-zart.txt`)', 'hanem az **1. blokk** (`tmp/play-401-zart.txt`)'],
  ['A kész, másolható változat: `tmp/play-400-eles.txt`', 'A kész, másolható változat: `tmp/play-401-eles.txt`'],
];
for (const [from, to] of headings) {
  if (from === to) continue;
  swap(from, to, from.slice(0, 40));
}

// 3) Az éles (2b) blokk rádió-sora kapja meg az iPhone-javítást.
const oldElesRadio = '- Javítva: a rádió Szüneteltetés gombja megjelenik a zárképernyőn és az értesítési sávban (Android, iPhone).';
const newElesRadio = '- Javítva: a rádió Szüneteltetés gombja megjelenik a zárképernyőn (Android és iPhone is).';
swap(oldElesRadio, newElesRadio, '2b rádió-sor', { all: true });

// 4) A 401-es tételes szakasz.
const section401 = `### 401 — a rádió Szüneteltetés gombja az iPhone zárképernyőjén (mért gyökér a telefonról)
- **A tulajdonos jelzése (2026-10-04, iPhone):** *„play van meg stop és ha rányomok a playre, egy pillre pause lesz belőle aztán visszaáll … és szól a rádió”*, illetve *„Androidon működik”*.
- **A MÉRÉS (a telefonról, \\\`pymobiledevice3 syslog live\\\`):** a napló megmutatta, hogy a Stop/Play gombnyomások **megérkeznek** (\\\`Request: playerCommand:Play/Stop\\\`), a cím és a borító **kiíródik** (\\\`NPIC: setNowPlayingInfo\\\`), az \\\`AVAudioSession\\\` aktiválódik, az \\\`AVPlayer\\\` elindul (\\\`timeControlStatus=2\\\`), és a szívverés is fut (5 másodpercenként \\\`Setting identical nowPlayingInfo\\\`). A döntő sor viszont ez: **\\\`[MRNowPlaying] Ignoring setPlaybackState because application does not contain entitlement com.apple.mediaremote.set-playback-state\\\`** — az iOS a \\\`playbackState\\\`-et **eldobja** (Apple-privát jogosultság), ezért a 399/400 erre épülő javítása **nem is hathatott**. A zárképernyő gombját a \\\`playbackRate\\\` és a **live-stream jelző** dönti el.
- **A JAVÍTÁS:** (1) a \\\`MPNowPlayingInfoPropertyIsLiveStream\\\` jelző **lekerült** — az „élő adás” gombkészletben (play + stop) **nincs pause**, ezért nem is jelenhetett meg; sima elemként az iOS a megszokott play/pause gombot rajzolja; (2) \\\`MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0\\\` is kiíródik; (3) a diagnosztika **\\\`os_log\\\`** (az \\\`NSLog\\\` sorai **nem jelentek meg** a naplóban, ezért a 400 diagnosztikája használhatatlan volt).
- **A kapu mérése:** a Swift-oldal forrás-lintjei (nincs élő jelző, van alapértelmezett rate, \\\`os_log\\\` és nincs \\\`NSLog\\\`), \\\`flutter test\\\` **1561/1561**, \\\`flutter analyze lib test\\\` **0 hiba**.

### 400 — a rádió Szüneteltetés gombja tényleg megjelenik a zárképernyőn (iPhone)`;

swap('### 400 — a rádió Szüneteltetés gombja tényleg megjelenik a zárképernyőn (iPhone)', section401, '401-es tételes szakasz');

// 5) A fejléc-proza első bekezdése a 401-es mérésre.
const oldProse = `> **(1) a rádió Szüneteltetés gombja tényleg megjelenik** a zárképernyőn és az értesítési sávban`;
const newProse = `> **(1) a rádió Szüneteltetés gombja megjelenik az iPhone zárképernyőjén** (a mért gyökér: az iOS az „élő adás” gombkészletét rajzolta, amiben nincs pause; Androidon ez már a 400-ban működik)`;
if (doc.includes(oldProse)) {
  doc = doc.replace(oldProse, newProse);
  console.log('OK     fejléc-proza');
} else {
  console.log('info   fejléc-proza: a minta nem található (nem hiba)');
}

fs.writeFileSync(DOC, doc, 'utf8');
console.log(bad ? `\n${bad} HIBA` : '\nMINDEN CSERE RENDBEN');
process.exitCode = bad ? 1 : 0;
