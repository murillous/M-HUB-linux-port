// Extract named top-level function / const definitions from a minified bundle (inert text processing).
const fs = require('fs');
const [file, outFile, ...names] = process.argv.slice(2);
const s = fs.readFileSync(file, 'utf8');
const esc = (n) => n.replace(/[$]/g, '[$]');

function braceEnd(j) {
  let d = 0;
  for (; j < s.length; j++) {
    if (s[j] === '{') d++;
    else if (s[j] === '}') { d--; if (!d) return j; }
  }
  return j;
}

let out = '';
for (const n of names) {
  if (n.startsWith('const:')) {
    const k = n.slice(6), i = s.indexOf(k);
    out += i < 0 ? `// MISSING ${k}\n` : s.slice(i, s.indexOf(';', i) + 1) + '\n';
    continue;
  }
  const m = new RegExp('(async function|function)[ ]+' + esc(n) + '[(]').exec(s);
  if (m) {
    const open = s.indexOf('){', m.index) + 1;
    out += s.slice(m.index, braceEnd(open) + 1) + '\n';
    continue;
  }
  const m2 = new RegExp('[,;][ ]*' + esc(n) + '[ ]*=[ ]*(async[ ]*)?([(][^)]*[)]|[A-Za-z_$][A-Za-z0-9_$]*)[ ]*=>').exec(s);
  if (m2) {
    const i = m2.index + 1;
    let j = s.indexOf('=>', i) + 2;
    j = s[j] === '{' ? braceEnd(j) : s.indexOf(';', j) - 1;
    out += 'const ' + s.slice(i, j + 1) + ';\n';
    continue;
  }
  out += `// MISSING ${n}\n`;
}
fs.writeFileSync(outFile, out);
