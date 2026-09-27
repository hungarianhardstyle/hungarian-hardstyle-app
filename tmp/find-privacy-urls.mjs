import fs from 'node:fs';
import path from 'node:path';

/** Rekurzív fájllistázás (a .git és a nehéz könyvtárak kihagyásával). */
const SKIP = new Set([
  '.git', 'build', 'node_modules', '.dart_tool', 'tmp', 'newsroom', '.vendor',
  '.gradle-user', '.firebase', '.agents', 'gpt-v2', 'cloudinary-github', 'projects',
  'business', 'generated', 'ios', 'android', 'windows', 'linux', 'macos', 'web',
]);
const ROOTS = ['docs', 'tools', 'lib', 'functions', 'test', 'includes', 'admin', 'assets', '.'];
const walk = (dir, out = []) => {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (/\.(md|dart|php|json|txt|yml|yaml|html)$/.test(entry.name)) out.push(full);
  }
  return out;
};

const PATTERN = /(adatv[eé]del|adatkezel|fi[oó]kt[oö]rl|account.?deletion|deletion|privacy.?policy)/i;
const URL_PATTERN = /https?:\/\/[^\s)"'<>\]]+/g;

const rows = [];
const files = [
  ...new Set(
    ROOTS.filter((root) => fs.existsSync(root)).flatMap((root) => walk(root)),
  ),
];
for (const file of files) {
  let text;
  try {
    text = fs.readFileSync(file, 'utf8');
  } catch {
    continue;
  }
  const lines = text.split(/\r?\n/);
  lines.forEach((line, index) => {
    if (!PATTERN.test(line)) return;
    const urls = [...line.matchAll(URL_PATTERN)].map((m) => m[0].replace(/[.,;]$/, ''));
    rows.push({
      file: file.replaceAll('\\', '/'),
      line: index + 1,
      urls,
      text: line.trim().slice(0, 150),
    });
  });
}

// Csak a URL-t tartalmazó sorok, plusz a fontos fájlok rövid kivonata.
const withUrls = rows.filter((row) => row.urls.length);
console.log(`=== URL-t tartalmazó találatok: ${withUrls.length} ===`);
const seen = new Set();
for (const row of withUrls) {
  for (const url of row.urls) {
    const key = `${url}`;
    if (seen.has(key)) continue;
    seen.add(key);
    console.log(`${url}\n    ← ${row.file}:${row.line}  ${row.text.slice(0, 110)}`);
  }
}
console.log(`\n=== összes találat: ${rows.length} (fájlok szerint) ===`);
const byFile = new Map();
for (const row of rows) byFile.set(row.file, (byFile.get(row.file) ?? 0) + 1);
for (const [file, count] of [...byFile].sort((a, b) => b[1] - a[1]).slice(0, 20)) {
  console.log(`  ${count.toString().padStart(3)}  ${file}`);
}
