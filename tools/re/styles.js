// Run in the page with `node tools/re/cdp.mjs <id> eval "$(cat tools/re/styles.js)"`: computed styles + boxes per class.
(() => {
  const props = ['background-color', 'background-image', 'color', 'border', 'border-radius', 'padding', 'margin',
    'font-family', 'font-size', 'font-weight', 'line-height', 'box-shadow', 'gap', 'opacity', 'transition'];
  const out = {};
  const seen = new Set();
  for (const el of document.querySelectorAll('[class]')) {
    if (!el.offsetParent && el.tagName !== 'BODY') continue;
    const cls = String(el.className.baseVal ?? el.className).split(/\s+/).find(c => /^(erp__|smp|v2-sidebar|mc-|el-slider|el-switch|eq-audition|headset|page|layout|card|common)/.test(c));
    if (!cls || seen.has(cls)) continue;
    seen.add(cls);
    const cs = getComputedStyle(el), r = el.getBoundingClientRect();
    const s = {};
    for (const p of props) {
      const v = cs.getPropertyValue(p);
      if (v && !['none', 'normal', '0px', 'rgba(0, 0, 0, 0)', 'all 0s ease 0s', '1', 'auto'].includes(v) && !(p === 'border' && v.startsWith('0px'))) s[p] = v;
    }
    s.box = [r.x, r.y, r.width, r.height].map(Math.round).join(',');
    const txt = el.children.length === 0 ? (el.textContent || '').trim().slice(0, 30) : '';
    if (txt) s.text = txt;
    out[cls] = s;
  }
  return out;
})()
