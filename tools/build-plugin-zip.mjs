/**
 * Build a WordPress-installable plugin ZIP from a plugin directory.
 *
 * WordPress (and every unzip tool on Linux) needs forward slashes in the entry
 * names. The .NET ZipFile helper writes backslashes, which silently produces a
 * broken plugin package, so the archive is written here entry by entry instead.
 *
 * Usage: node build-plugin-zip.mjs <plugin-dir> <out.zip> [rootFolderName]
 * The root folder name defaults to the source directory's name and is required
 * for WordPress to accept the upload as a plugin replacement.
 */

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const [, , sourceArg, outArg, rootArg] = process.argv;

if (!sourceArg || !outArg) {
  console.error('usage: node build-plugin-zip.mjs <plugin-dir> <out.zip> [rootFolderName]');
  process.exit(2);
}

const sourceDir = path.resolve(sourceArg);
if (!fs.statSync(sourceDir).isDirectory()) {
  console.error(`not a directory: ${sourceDir}`);
  process.exit(2);
}
const outPath = path.resolve(outArg);
const rootName = (rootArg || path.basename(sourceDir)).replace(/^\/+|\/+$/g, '');

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let c = i;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[i] = c;
  }
  return table;
})();

const crc32 = (buffer) => {
  let c = -1;
  for (let i = 0; i < buffer.length; i += 1) c = (c >>> 8) ^ CRC_TABLE[(c ^ buffer[i]) & 0xff];
  return (c ^ -1) >>> 0;
};

const collect = (dir, prefix = '') => {
  const files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const absolute = path.join(dir, entry.name);
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...collect(absolute, relative));
    } else if (entry.isFile()) {
      files.push({ absolute, relative });
    }
  }
  return files;
};

const dosStamp = (date) => ({
  time: ((date.getHours() & 0x1f) << 11) | ((date.getMinutes() & 0x3f) << 5) | ((date.getSeconds() >> 1) & 0x1f),
  date: (((date.getFullYear() - 1980) & 0x7f) << 9) | (((date.getMonth() + 1) & 0x0f) << 5) | (date.getDate() & 0x1f),
});

const files = collect(sourceDir);
const chunks = [];
const central = [];
let offset = 0;

for (const file of files) {
  const raw = fs.readFileSync(file.absolute);
  const deflated = zlib.deflateRawSync(raw, { level: 9 });
  // Only store uncompressed when deflate genuinely made it bigger.
  const useDeflate = deflated.length < raw.length;
  const body = useDeflate ? deflated : raw;
  const method = useDeflate ? 8 : 0;
  const name = Buffer.from(`${rootName}/${file.relative}`, 'utf8');
  const { time, date } = dosStamp(fs.statSync(file.absolute).mtime);
  const crc = crc32(raw);

  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(20, 4);
  local.writeUInt16LE(0x0800, 6); // UTF-8 file names
  local.writeUInt16LE(method, 8);
  local.writeUInt16LE(time, 10);
  local.writeUInt16LE(date, 12);
  local.writeUInt32LE(crc, 14);
  local.writeUInt32LE(body.length, 18);
  local.writeUInt32LE(raw.length, 22);
  local.writeUInt16LE(name.length, 26);
  local.writeUInt16LE(0, 28);

  const headerEntry = Buffer.alloc(46);
  headerEntry.writeUInt32LE(0x02014b50, 0);
  headerEntry.writeUInt16LE(20, 4);
  headerEntry.writeUInt16LE(20, 6);
  headerEntry.writeUInt16LE(0x0800, 8);
  headerEntry.writeUInt16LE(method, 10);
  headerEntry.writeUInt16LE(time, 12);
  headerEntry.writeUInt16LE(date, 14);
  headerEntry.writeUInt32LE(crc, 16);
  headerEntry.writeUInt32LE(body.length, 20);
  headerEntry.writeUInt32LE(raw.length, 24);
  headerEntry.writeUInt16LE(name.length, 28);
  headerEntry.writeUInt16LE(0, 30);
  headerEntry.writeUInt16LE(0, 32);
  headerEntry.writeUInt16LE(0, 34);
  headerEntry.writeUInt16LE(0, 36);
  headerEntry.writeUInt32LE(0, 38);
  headerEntry.writeUInt32LE(offset, 42);

  chunks.push(local, name, body);
  central.push(headerEntry, name);
  offset += local.length + name.length + body.length;
}

const centralBuffer = Buffer.concat(central);
const end = Buffer.alloc(22);
end.writeUInt32LE(0x06054b50, 0);
end.writeUInt16LE(0, 4);
end.writeUInt16LE(0, 6);
end.writeUInt16LE(files.length, 8);
end.writeUInt16LE(files.length, 10);
end.writeUInt32LE(centralBuffer.length, 12);
end.writeUInt32LE(offset, 16);
end.writeUInt16LE(0, 20);

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, Buffer.concat([...chunks, centralBuffer, end]));

console.log(`wrote ${outPath}`);
console.log(`entries: ${files.length}`);
console.log(`root: ${rootName}/`);
