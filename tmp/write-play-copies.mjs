import fs from 'node:fs';

// A Play-jegyzet blokkjait kiírjuk UTF-8 fájlokba (a PowerShell-átirányítás UTF-16-ot adna).
// ⚠️ A blokk-sorszámok a dokumentum sorrendjét követik: 0 = 1. blokk (a mostani
// buildhez), 2 = 1b-2 összesítő, 3 = 1b-3 (béta) összesítő.
//
// 🔵 A FÁJLNEVEK A DOKUMENTUM `currentBuild`-JÉBŐL SZÁRMAZNAK (2026-09-28).
// Előtte a nevek kézzel voltak beírva, és ez MÉRT HIBÁT okozott: a 378-as és a
// 379-es körben a szkript a *előző* kör fájlneveivel futott le, ezért a
// `tmp/play-377.txt` a **378** jegyzetét, a `tmp/play-378.txt` a **379** jegyzetét
// kapta — a bizonyítékfájl neve mást ígért, mint a tartalma. Mostantól a név
// **számítva** van, és a `checkNames()` (lásd `--self-test`) elutasítja az
// elavult nevet.

const CURRENT_BUILD_RE = /^currentBuild:\s*(\d+)\s*$/m;

/** A jelenlegi buildhez tartozó másolat-nevek (a sorrend a dokumentumé: 0, 2, 3). */
function expectedTargets(build) {
  return [
    [`tmp/play-${build}.txt`, 0],
    [`tmp/play-361-${build}.txt`, 2],
    [`tmp/play-355-${build}.txt`, 3],
  ];
}

/** A dokumentum build-száma, vagy hiba, ha nem olvasható. */
function currentBuildOf(doc) {
  const match = CURRENT_BUILD_RE.exec(doc);
  if (!match) {
    throw new Error('a Play-jegyzet meta fejlécében nincs `currentBuild: <szám>` sor');
  }
  return match[1];
}

/** Elutasítja az elavult (más buildhez tartozó) fájlnevet. */
function checkNames(doc, names) {
  const build = currentBuildOf(doc);
  const expected = expectedTargets(build).map(([file]) => file);
  if (names.length !== expected.length) {
    throw new Error(`a másolatok száma ${names.length}, várt ${expected.length}`);
  }
  names.forEach((name, index) => {
    if (name !== expected[index]) {
      throw new Error(
        `elavult fájlnév: ${name} — a jelenlegi build (${build}) másolatai: ${expected.join(', ')}`,
      );
    }
  });
  return build;
}

function runSelfTest() {
  const doc = 'currentBuild: 380\nlastPublishedBuild: 379\n';
  const cases = [
    ['a helyes nevek átmennek', expectedTargets('380').map(([file]) => file), true],
    ['az elavult build nevét elutasítja', ['tmp/play-379.txt', 'tmp/play-361-379.txt', 'tmp/play-355-379.txt'], false],
    ['a kevert nevet elutasítja', ['tmp/play-380.txt', 'tmp/play-361-379.txt', 'tmp/play-355-380.txt'], false],
    ['a hiányos listát elutasítja', ['tmp/play-380.txt'], false],
  ];
  let bad = 0;
  for (const [title, names, shouldPass] of cases) {
    let passed = true;
    try {
      checkNames(doc, names);
    } catch {
      passed = false;
    }
    const ok = passed === shouldPass;
    if (!ok) bad += 1;
    console.log(`${ok ? 'OK  ' : 'ELTER'} ${title}`);
  }
  console.log(`\n${cases.length - bad}/${cases.length} önteszt rendben`);
  return bad;
}

if (process.argv.includes('--self-test')) {
  process.exitCode = runSelfTest() ? 1 : 0;
} else {
  const doc = fs.readFileSync('docs/PLAY-KIADASI-JEGYZET.md', 'utf8');
  const blocks = [...doc.matchAll(/```play-notes\r?\n([\s\S]*?)```/g)].map((m) =>
    m[1].replace(/\r\n/g, '\n').trimEnd(),
  );

  const targets = expectedTargets(currentBuildOf(doc));
  // A név-ellenőrzés ugyanaz a kapu, amit az önteszt mér — itt a valódi listán fut.
  const build = checkNames(doc, targets.map(([file]) => file));
  console.log(`build-egyeztetés: currentBuild=${build}, a fájlnevek ugyanezt a buildet viselik`);

  for (const [file, index] of targets) {
    fs.writeFileSync(file, `${blocks[index]}\n`, 'utf8');
  }

  let bad = 0;
  for (const [file, index] of targets) {
    const content = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').trimEnd();
    const same = content === blocks[index];
    if (!same) bad += 1;
    console.log(`${same ? 'OK  ' : 'ELTER'} ${file} = ${index + 1}. blokk (${content.length} karakter)`);
  }
  console.log(`\n${targets.length - bad}/${targets.length} másolat egyezik a dokumentummal`);
  process.exitCode = bad ? 1 : 0;
}
