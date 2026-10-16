const fs = require('fs'), path = require('path'), zlib = require('zlib');
const [src, out] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
for (const fn of fs.readdirSync(src)) {
  let d = fs.readFileSync(path.join(src, fn));
  try { d = zlib.brotliDecompressSync(d); } catch { continue; }
  const head = d.subarray(0, 80).toString('latin1').replace(/\s+/g, ' ');
  fs.writeFileSync(path.join(out, fn + '.txt'), d);
  console.log(fn, d.length, head.slice(0, 80));
}
