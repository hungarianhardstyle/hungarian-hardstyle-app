// A jelvény-katalógus KEZELT tartalék-ágának naplózását állítja át WARNING-ra.
//
// MIÉRT: a `console.warn` a Cloud Run alatt a stderr-re megy, amit a Cloud Logging
// ERROR-ként számol — így egy kezelt ág (WordPress-időtúllépés) hibaként jelent meg
// (mérve: 48 óra / 47 bejegyzés). A csere NEM változtat viselkedést: ugyanaz az
// eseménynév és üzenet megy ki, csak strukturált WARNING szinten.
//
// ⚠️ A fájl CRLF-es, ezért a mintát a fájl SAJÁT sorvégéből építjük (a `\n`-es
// horgony nulla találatot adna — ez a projekt visszatérő hibaosztálya).
import fs from 'node:fs';

const file = 'functions/index.js';
const source = fs.readFileSync(file, 'utf8');
const eol = source.includes('\r\n') ? '\r\n' : '\n';
const join = (lines) => lines.join(eol);

const before = join([
  '  } catch (error) {',
  '    console.warn(',
  '      JSON.stringify({',
  "        event: 'achievement_catalog_fallback',",
  '        message: error?.message || String(error),',
  '      }),',
  '    );',
  '  } finally {',
]);

const after = join([
  '  } catch (error) {',
  '    // Kezelt ág: a hívó a mentett (vagy alap) katalógust kapja, ezért ez',
  '    // figyelmeztetés — lásd a `log-warning.js` fejlécét (stderr = ERROR).',
  "    logWarning('achievement_catalog_fallback', error?.message || String(error));",
  '  } finally {',
]);

if (process.argv.includes('--dry')) {
  console.log(`EOL: ${eol === '\r\n' ? 'CRLF' : 'LF'}`);
  console.log(`találat a régi mintára: ${source.split(before).length - 1}`);
  process.exitCode = source.includes(before) ? 0 : 1;
} else {
  const occurrences = source.split(before).length - 1;
  if (occurrences !== 1) {
    console.error(`HIBA: a minta ${occurrences}-szor szerepel (pontosan 1 kell) — nem írok`);
    process.exit(1);
  }
  const updated = source.replace(before, after);
  fs.writeFileSync(file, updated, 'utf8');
  console.log(`kész: ${occurrences} csere, ${source.length} -> ${updated.length} bájt`);
  const line = updated
    .split(eol)
    .find((text) => text.includes("logWarning('achievement_catalog_fallback'"));
  console.log(`új sor: ${line?.trim()}`);
}
