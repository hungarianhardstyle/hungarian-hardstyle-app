#!/usr/bin/env node
/**
 * A Firebase iOS-konfiguráció (`GoogleService-Info.plist`) bekötése az
 * Xcode-projektbe és a Google Sign-In URL-séma beírása az `Info.plist`-be.
 *
 * MIÉRT ESZKÖZ ÉS NEM KÉZI SZERKESZTÉS
 * ------------------------------------
 * Az `ios/Runner.xcodeproj/project.pbxproj` kézi átírása a legkockázatosabb
 * lépés az egész iOS-útban: egy elrontott zárójel vagy egy hiányzó sor
 * **néma** build-hibát okoz, és ezen a gépen nincs Xcode, amivel ellenőrizni
 * lehetne. Ez az eszköz ezért:
 *
 *   1. **ellenőriz** a szerkesztés ELŐTT (a plist bundle ID-ja egyezik-e a
 *      projektével) — egy rossz bundle ID-jű plist csendben megölné a Firebase-t;
 *   2. **idempotens**: kétszer futtatva semmit nem dupláz;
 *   3. `--check` módban **nem ír semmit**, csak megmondja, mi hiányzik;
 *   4. `--self-test`-tel **önmagát méri** szintetikus bemeneten.
 *
 * Használat:
 *   node tools/attach-ios-firebase.mjs            # beköt (és ír)
 *   node tools/attach-ios-firebase.mjs --check    # csak jelent
 *   node tools/attach-ios-firebase.mjs --self-test
 */
import fs from 'node:fs';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const PLIST_PATH = 'ios/Runner/GoogleService-Info.plist';
const PBXPROJ_PATH = 'ios/Runner.xcodeproj/project.pbxproj';
const INFO_PLIST_PATH = 'ios/Runner/Info.plist';
const NAME = 'GoogleService-Info.plist';

// 24 hexadecimális karakter — ez az Xcode-azonosítók formátuma. A minta
// szándékosan felismerhető, hogy kézi átnézésnél kitűnjön a többi közül.
const FILE_REF_UUID = 'A11CE00000000000000000A1';
const BUILD_FILE_UUID = 'A11CE00000000000000000B2';

// --- tiszta segédfüggvények -------------------------------------------------

/** Egy kulcs értéke egy XML plist-ből (string típus). */
export function plistValue(xml, key) {
  const match = xml.match(
    new RegExp(`<key>${key}</key>\\s*<string>([^<]*)</string>`),
  );
  return match ? match[1].trim() : null;
}

/** Az Xcode-projekt fő (nem teszt) bundle ID-ja. */
export function xcodeBundleId(pbxproj) {
  const ids = [...pbxproj.matchAll(/PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g)]
    .map((match) => match[1].trim())
    .filter((id) => !id.endsWith('.RunnerTests'));
  return ids.length > 0 ? ids[0] : null;
}

function insertBeforeLine(lines, pattern, addition) {
  const index = lines.findIndex((line) => pattern.test(line));
  if (index < 0) throw new Error(`nem találom a horgonyt: ${pattern}`);
  lines.splice(index, 0, ...addition);
}

function insertAfterLine(lines, pattern, addition) {
  const index = lines.findIndex((line) => pattern.test(line));
  if (index < 0) throw new Error(`nem találom a horgonyt: ${pattern}`);
  lines.splice(index + 1, 0, ...addition);
}

/**
 * ⚠️ A sorvéget MEG KELL őrizni: az Xcode-projekt és az `Info.plist` a lemezen
 * **CRLF**-es (mérve: 644, illetve 93 sor), a `split('\n')` viszont `\r`-t
 * hagyna a sorok végén — így minden `$`-ra illeszkedő horgony elhasal, és a
 * fájl sorvégei összekeverednének. Ez a hiba a valódi fájlon derült ki, ezért
 * az önteszt külön méri a CRLF-es bemenetet is.
 */
function splitLines(text) {
  return {
    lines: text.split(/\r?\n/),
    eol: text.includes('\r\n') ? '\r\n' : '\n',
  };
}

/**
 * A plist bejegyzései az Xcode-projektbe. Négy hely kell hozzá:
 * PBXBuildFile + PBXFileReference + a Runner csoport + a Resources fázis.
 */
export function attachXcodeProject(pbxproj) {
  const { lines, eol } = splitLines(pbxproj);
  const changes = [];

  if (!pbxproj.includes(`${BUILD_FILE_UUID} /* ${NAME} in Resources */`)) {
    insertBeforeLine(lines, /\/\* End PBXBuildFile section \*\//, [
      `\t\t${BUILD_FILE_UUID} /* ${NAME} in Resources */ = {isa = PBXBuildFile; fileRef = ${FILE_REF_UUID} /* ${NAME} */; };`,
    ]);
    changes.push('PBXBuildFile');
  }

  if (!pbxproj.includes(`${FILE_REF_UUID} /* ${NAME} */ = {isa = PBXFileReference`)) {
    insertBeforeLine(lines, /\/\* End PBXFileReference section \*\//, [
      `\t\t${FILE_REF_UUID} /* ${NAME} */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = "${NAME}"; sourceTree = "<group>"; };`,
    ]);
    changes.push('PBXFileReference');
  }

  if (!pbxproj.includes(`${FILE_REF_UUID} /* ${NAME} */,`)) {
    insertAfterLine(lines, /\/\* Info\.plist \*\/,$/, [
      `\t\t\t\t${FILE_REF_UUID} /* ${NAME} */,`,
    ]);
    changes.push('Runner csoport');
  }

  if (!pbxproj.includes(`${BUILD_FILE_UUID} /* ${NAME} in Resources */,`)) {
    insertAfterLine(lines, /\/\* Main\.storyboard in Resources \*\/,$/, [
      `\t\t\t\t${BUILD_FILE_UUID} /* ${NAME} in Resources */,`,
    ]);
    changes.push('Resources fázis');
  }

  return { text: lines.join(eol), changes };
}

/**
 * A Google Sign-In OAuth-visszahívásához az iOS megköveteli, hogy a
 * `REVERSED_CLIENT_ID` szerepeljen az `Info.plist` URL-sémái között — enélkül
 * a bejelentkezés a böngészőből nem tér vissza az appba.
 */
export function attachUrlScheme(infoPlist, reversedClientId) {
  if (infoPlist.includes('<key>CFBundleURLTypes</key>')) {
    const hasScheme = infoPlist.includes(`<string>${reversedClientId}</string>`);
    return {
      text: infoPlist,
      changed: false,
      note: hasScheme
        ? 'a CFBundleURLTypes már tartalmazza ezt a sémát'
        : '⚠️ van CFBundleURLTypes, de NEM ez a séma — kézzel nézd át',
    };
  }

  const { lines, eol } = splitLines(infoPlist);
  insertBeforeLine(lines, /^\t<key>CFBundleVersion<\/key>$/, [
    '\t<!-- Google Sign-In: a GoogleService-Info.plist REVERSED_CLIENT_ID-ja. -->',
    '\t<key>CFBundleURLTypes</key>',
    '\t<array>',
    '\t\t<dict>',
    '\t\t\t<key>CFBundleTypeRole</key>',
    '\t\t\t<string>Editor</string>',
    '\t\t\t<key>CFBundleURLSchemes</key>',
    '\t\t\t<array>',
    `\t\t\t\t<string>${reversedClientId}</string>`,
    '\t\t\t</array>',
    '\t\t</dict>',
    '\t</array>',
  ]);
  return { text: lines.join(eol), changed: true, note: 'URL-séma beszúrva' };
}

// --- önteszt ----------------------------------------------------------------

function selfTest() {
  let failures = 0;
  const check = (label, ok, detail = '') => {
    if (!ok) failures++;
    console.log(`${ok ? 'OK  ' : 'FAIL'}  ${label}${ok || !detail ? '' : `  -> ${detail}`}`);
  };

  const fakePlist = `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
\t<key>BUNDLE_ID</key>
\t<string>hu.hungarianhardstyle.app</string>
\t<key>REVERSED_CLIENT_ID</key>
\t<string>1234567890-abc.apps.googleusercontent.com</string>
\t<key>PROJECT_ID</key>
\t<string>hungarian-hardstyle</string>
</dict>
</plist>`;

  check(
    'a plist BUNDLE_ID-ja kiolvasható',
    plistValue(fakePlist, 'BUNDLE_ID') === 'hu.hungarianhardstyle.app',
  );
  check(
    'a REVERSED_CLIENT_ID kiolvasható',
    plistValue(fakePlist, 'REVERSED_CLIENT_ID') ===
      '1234567890-abc.apps.googleusercontent.com',
  );

  const fakePbxproj = [
    '{',
    '\tobjects = {',
    '/* Begin PBXBuildFile section */',
    '\t\tAAAA /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = BBBB /* AppDelegate.swift */; };',
    '/* End PBXBuildFile section */',
    '/* Begin PBXFileReference section */',
    '\t\tBBBB /* AppDelegate.swift */ = {isa = PBXFileReference; path = AppDelegate.swift; sourceTree = "<group>"; };',
    '/* End PBXFileReference section */',
    '/* Begin PBXGroup section */',
    '\t\tCCCC /* Runner */ = {',
    '\t\t\tisa = PBXGroup;',
    '\t\t\tchildren = (',
    '\t\t\t\tDDDD /* Info.plist */,',
    '\t\t\t);',
    '\t\t};',
    '/* End PBXGroup section */',
    '/* Begin PBXResourcesBuildPhase section */',
    '\t\tEEEE /* Resources */ = {',
    '\t\t\tfiles = (',
    '\t\t\t\tFFFF /* Main.storyboard in Resources */,',
    '\t\t\t);',
    '\t\t};',
    '/* End PBXResourcesBuildPhase section */',
    '\t};',
    '}',
    '',
  ].join('\n');

  check(
    'a bundle ID kiolvasása a projektből',
    xcodeBundleId(
      '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = hu.hungarianhardstyle.app;\n' +
        '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = hu.hungarianhardstyle.app.RunnerTests;',
    ) === 'hu.hungarianhardstyle.app',
  );

  const first = attachXcodeProject(fakePbxproj);
  check('mind a négy helyre bekerül', first.changes.length === 4, first.changes.join(', '));
  check(
    'a fájlhivatkozás bekerült',
    first.text.includes(`/* ${NAME} */ = {isa = PBXFileReference`),
  );
  check(
    'a Resources fázisba bekerült',
    first.text.includes(`${BUILD_FILE_UUID} /* ${NAME} in Resources */,`),
  );
  check(
    'a Runner csoportba bekerült',
    first.text.includes(`${FILE_REF_UUID} /* ${NAME} */,`),
  );

  const second = attachXcodeProject(first.text);
  check('másodszorra IDEMPOTENS (nem dupláz)', second.changes.length === 0);
  check('a második futás byte-azonos', second.text === first.text);
  check(
    'a kapcsos zárójelek egyensúlya megmaradt',
    (first.text.match(/\{/g) || []).length === (first.text.match(/\}/g) || []).length,
  );

  const fakeInfo = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<plist version="1.0">',
    '<dict>',
    '\t<key>CFBundleVersion</key>',
    '\t<string>$(FLUTTER_BUILD_NUMBER)</string>',
    '</dict>',
    '</plist>',
    '',
  ].join('\n');

  const scheme = attachUrlScheme(fakeInfo, '1234567890-abc.apps.googleusercontent.com');
  check('az URL-séma bekerült', scheme.changed);
  check(
    'a séma a helyére került (CFBundleVersion előtt)',
    scheme.text.indexOf('CFBundleURLTypes') < scheme.text.indexOf('CFBundleVersion'),
  );
  const schemeAgain = attachUrlScheme(scheme.text, '1234567890-abc.apps.googleusercontent.com');
  check('a séma-beszúrás is idempotens', !schemeAgain.changed);
  const mismatch = attachUrlScheme(scheme.text, 'mas-id.apps.googleusercontent.com');
  check(
    'más séma esetén NEM ír, hanem jelez',
    !mismatch.changed && mismatch.note.includes('NEM ez a séma'),
  );

  // ⚠️ A valódi fájlok CRLF-esek (project.pbxproj: 644, Info.plist: 93 sor).
  // Az LF-es önteszt ezt a hibát NEM fogta meg, ezért külön mérjük — a sorvég
  // elvesztése miatt minden `$`-ra illeszkedő horgony elhasalt volna.
  const noBareLf = (text) => !/[^\r]\n/.test(text);
  const crlfProject = fakePbxproj.replace(/\n/g, '\r\n');
  const crlfResult = attachXcodeProject(crlfProject);
  check(
    'CRLF-es projekten is megtalálja mind a négy horgonyt',
    crlfResult.changes.length === 4,
    crlfResult.changes.join(', '),
  );
  check(
    'CRLF-es projektnél a sorvég CRLF marad',
    crlfResult.text.includes('\r\n') && noBareLf(crlfResult.text),
  );
  check(
    'CRLF-es projektnél is idempotens',
    attachXcodeProject(crlfResult.text).changes.length === 0,
  );

  const crlfInfo = fakeInfo.replace(/\n/g, '\r\n');
  const crlfScheme = attachUrlScheme(
    crlfInfo,
    '1234567890-abc.apps.googleusercontent.com',
  );
  check('CRLF-es Info.plist-be is beszúrja a sémát', crlfScheme.changed);
  check(
    'CRLF-es Info.plist-nél a sorvég CRLF marad',
    crlfScheme.text.includes('\r\n') && noBareLf(crlfScheme.text),
  );

  console.log('');
  console.log(failures === 0 ? 'ÖNTESZT: minden rendben' : `ÖNTESZT: ${failures} hiba`);
  return failures === 0;
}

// --- fő program -------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--self-test')) process.exit(selfTest() ? 0 : 1);
  const checkOnly = args.includes('--check');

  if (!fs.existsSync(PLIST_PATH)) {
    console.error(`HIÁNYZIK: ${PLIST_PATH}`);
    console.error('');
    console.error('Ez a fájl a Firebase konzolból jön (Projekt beállítások →');
    console.error('Alkalmazás hozzáadása → iOS → bundle ID: hu.hungarianhardstyle.app).');
    console.error('Enélkül az app iOS-en indulás közben elszáll (firebase_core).');
    process.exit(2);
  }

  const plist = fs.readFileSync(PLIST_PATH, 'utf8');
  const pbxproj = fs.readFileSync(PBXPROJ_PATH, 'utf8');

  const plistBundleId = plistValue(plist, 'BUNDLE_ID');
  const projectBundleId = xcodeBundleId(pbxproj);
  const reversedClientId = plistValue(plist, 'REVERSED_CLIENT_ID');

  console.log(`plist bundle ID:   ${plistBundleId}`);
  console.log(`projekt bundle ID: ${projectBundleId}`);

  if (!plistBundleId || !projectBundleId) {
    console.error('HIBA: nem sikerült kiolvasni valamelyik bundle ID-t.');
    process.exit(1);
  }
  if (plistBundleId !== projectBundleId) {
    console.error('');
    console.error('HIBA: a plist bundle ID-ja NEM egyezik a projektével!');
    console.error('Egy rossz bundle ID-jű plist csendben megölné a Firebase-t iOS-en.');
    console.error('Töltsd le újra a helyes apphoz tartozó plistet, vagy állítsd át');
    console.error('a PRODUCT_BUNDLE_IDENTIFIER-t — de a kettőnek egyeznie KELL.');
    process.exit(1);
  }

  const project = attachXcodeProject(pbxproj);
  const info = attachUrlScheme(
    fs.readFileSync(INFO_PLIST_PATH, 'utf8'),
    reversedClientId ?? '',
  );

  console.log('');
  console.log(
    project.changes.length > 0
      ? `Xcode-projekt: bekötve (${project.changes.join(', ')})`
      : 'Xcode-projekt: már be volt kötve',
  );
  console.log(`Info.plist: ${info.note}`);

  if (checkOnly) {
    console.log('');
    console.log('--check mód: nem írtam semmit.');
    process.exit(project.changes.length === 0 && !info.changed ? 0 : 1);
  }

  if (project.changes.length > 0) {
    fs.writeFileSync(PBXPROJ_PATH, project.text);
    console.log(`írtam: ${PBXPROJ_PATH}`);
  }
  if (info.changed) {
    fs.writeFileSync(INFO_PLIST_PATH, info.text);
    console.log(`írtam: ${INFO_PLIST_PATH}`);
  }
  if (project.changes.length === 0 && !info.changed) {
    console.log('Nem volt mit tenni — minden a helyén van.');
  }
}

// Csak közvetlen futtatáskor induljon el a CLI — importálva (tesztből) NE,
// különben a `main()` mellékhatásként írna a fájlokba.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
