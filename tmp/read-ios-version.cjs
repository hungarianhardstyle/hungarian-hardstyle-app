// A telepen telepitett app verziojanak kiolvasasa a `pymobiledevice3 apps list`
// kimenetebol (BOM/UTF-16 toleranciasan).
const fs = require('node:fs');

const file = process.argv[2] ?? 'tmp/apps-358.json';
let raw = fs.readFileSync(file);
// ⚠️ MERt SAJAT HIBA (2026-10-02): a PowerShell `>` atiranyitas **BOM-mal**
// kezdi a UTF-16LE fajlt (FF FE), es a regi detektalas (raw[1]===0 && raw[3]===0)
// ezen elhasalt -> a JSON.parse a 2. bajtnál elszallt. Mostantól a BOM-ot is
// felismerjuk (FF FE = UTF-16LE, FE FF = UTF-16BE).
const hasUtf16LeBom = raw.length > 2 && raw[0] === 0xff && raw[1] === 0xfe;
const hasUtf16BeBom = raw.length > 2 && raw[0] === 0xfe && raw[1] === 0xff;
if (hasUtf16BeBom) {
  // Ritka eset: a bajtparok megforditasa utan ugyanaz, mint az LE.
  raw = Buffer.from(
    raw.subarray(2).swap16().toString('utf16le'),
    'utf8',
  );
} else if (hasUtf16LeBom || (raw.length > 4 && raw[1] === 0 && raw[3] === 0)) {
  const body = hasUtf16LeBom ? raw.subarray(2) : raw;
  raw = Buffer.from(body.toString('utf16le'), 'utf8');
}
let text = raw.toString('utf8').replace(/^\uFEFF/, '');
const start = text.indexOf('{');
const parsed = JSON.parse(text.slice(start));
const bundleId = 'hu.hungarianhardstyle.app.JQPJ793V65';
const app = parsed[bundleId];
if (!app) {
  console.log('NINCS telepitve:', bundleId);
  process.exit(2);
}
console.log('CFBundleVersion            =', app.CFBundleVersion);
console.log('CFBundleShortVersionString =', app.CFBundleShortVersionString);
console.log('BundleContainer/Path       =', app.Path ?? '(nincs)');
console.log('ApplicationType            =', app.ApplicationType);
console.log('CFBundleDisplayName        =', app.CFBundleDisplayName);
