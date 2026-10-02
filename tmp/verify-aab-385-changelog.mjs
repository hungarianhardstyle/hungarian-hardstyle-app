// A 385-es csomag TARTALMI ellenőrzése — a `tmp/verify-aab.mjs` (a hiteles eszköz)
// kimenetének SZÁMLÁLÁSA alapján.
//
// ⚠️ MÉRT SAJÁT HIBA (ez a script első változata): a changelog-sorokat a tool
// **kiírt, rövidített** szövegében kerestem (a sor első 30 karakterét) — a tool
// viszont `…`-tal vágja a feliratokat, ezért a keresés **hamis „HIÁNYZIK"**-et
// adott mind a négy sorra, miközben a tool maga **0 HIBA**-t írt. A tanulság a
// szokásos: a rövidített kiírás nem minta — a számokat kell mérni.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

const app = process.argv[2] ?? 'build/HUHS-v1.0.0+385-release.aab';
const build = process.argv[3] ?? '385';

// A changelog sorai a FORRÁSBÓL (nem kézzel beírva).
const changelog = fs.readFileSync('lib/data/app_changelog.dart', 'utf8');
const block = new RegExp(`build: ${build},[\\s\\S]*?changes: \\[([\\s\\S]*?)\\],\\r?\\n  \\)`).exec(changelog);
if (!block) throw new Error(`nincs changelog szakasz a ${build} buildhez`);
const lines = [...block[1].matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((m) => m[1].replace(/\\'/g, "'"));

const out = execFileSync(process.execPath, ['tmp/verify-aab.mjs', app, build], {
  encoding: 'utf8',
  maxBuffer: 64 * 1024 * 1024,
});

console.log(`a ${build}-es changelog ${lines.length} sora (a forrásból):`);
for (const line of lines) console.log(`  - ${line.slice(0, 80)}${line.length > 80 ? '…' : ''}`);

// A tool minden ABI-ra kiírja a „changelog-sor bent van" sorokat; a 0 HIBA és a
// legalább 3 × sorok száma együtt bizonyítja, hogy MINDEN sor minden ABI-ban bent van.
const perAbi = [...out.matchAll(/(arm64-v8a|armeabi-v7a|x86_64): changelog-sor bent van/g)].length;
const failures = (out.match(/HIBA/g) ?? []).length;
const abis = new Set([...out.matchAll(/(arm64-v8a|armeabi-v7a|x86_64): changelog-sor bent van/g)].map((m) => m[1])).size;
const expected = lines.length * abis;

console.log(`\nABI-k: ${abis}, „changelog-sor bent van" sorok: ${perAbi} (várt: ${expected}), HIBA: ${failures}`);
const ok = failures === 0 && perAbi >= expected && abis === 3;
console.log(ok ? 'MINDEN CHANGELOG-SOR BENNE VAN MINDHÁROM ABI-BAN' : 'ELTÉRÉS — lásd a fenti számokat');
process.exitCode = ok ? 0 : 1;
