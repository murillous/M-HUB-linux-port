// Minimal CDP client for the MCHOSE HUB renderer (start it with --remote-debugging-port=9333).
// usage: node cdp.mjs <targetId> eval "<js>"        -> prints JSON value
//        node cdp.mjs <targetId> shot <out.png>     -> full window screenshot
const [, , id, cmd, arg] = process.argv;
const ws = new WebSocket(`ws://127.0.0.1:9333/devtools/page/${id}`);
let n = 0; const pending = new Map();
const send = (method, params = {}) => new Promise((res, rej) => {
  const i = ++n; pending.set(i, { res, rej }); ws.send(JSON.stringify({ id: i, method, params }));
});
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result); }
};
ws.onopen = async () => {
  try {
    if (cmd === 'eval') {
      const r = await send('Runtime.evaluate', { expression: arg, returnByValue: true, awaitPromise: true });
      console.log(r.exceptionDetails ? 'EXC ' + JSON.stringify(r.exceptionDetails.exception?.description) : JSON.stringify(r.result.value, null, 1));
    } else if (cmd === 'move') {
      const [x, y] = arg.split(',').map(Number);
      await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
      await new Promise(r => setTimeout(r, 700));
      const r = await send('Page.captureScreenshot', { format: 'png', clip: { x: x - 220, y: y - 140, width: 440, height: 280, scale: 2 } });
      (await import('node:fs')).writeFileSync(process.argv[5], Buffer.from(r.data, 'base64'));
      console.log('saved', process.argv[5]);
    } else if (cmd === 'shot') {
      const r = await send('Page.captureScreenshot', { format: 'png' });
      (await import('node:fs')).writeFileSync(arg, Buffer.from(r.data, 'base64'));
      console.log('saved', arg);
    }
  } catch (e) { console.error(e.message); }
  ws.close();
};
