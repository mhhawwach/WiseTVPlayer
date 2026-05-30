const PORT = process.argv[2] || '53880';
const list = await (await fetch(`http://localhost:${PORT}/json/list`)).json();
const page = list.find(t => t.type === 'page') || list[0];
console.log('TARGET:', page?.url);
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));
const out = [];
ws.onopen = () => {
  send('Runtime.enable');
  send('Log.enable');
  send('Page.enable');
  setTimeout(() => send('Page.reload', { ignoreCache: true }), 400);
  setTimeout(() => send('Runtime.evaluate', {
    expression: `JSON.stringify({hasFlutter:typeof _flutter, glass:!!document.querySelector('flt-glass-pane')||!!document.querySelector('flutter-view'), canvas:document.getElementsByTagName('canvas').length, kids:document.body?document.body.children.length:-1, ck:!!window.flutterCanvasKit})`,
    returnByValue: true
  }), 8000);
  setTimeout(() => { console.log(out.join('\n') || '(no events)'); ws.close(); process.exit(0); }, 11000);
};
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.method === 'Runtime.exceptionThrown') {
    const d = m.params.exceptionDetails;
    out.push('EXCEPTION: ' + (d.exception?.description || d.text) + ' @ ' + (d.url||'').split('/').pop() + ':' + (d.lineNumber||''));
  } else if (m.method === 'Runtime.consoleAPICalled') {
    out.push('CONSOLE.' + m.params.type + ': ' + m.params.args.map(a => a.value ?? a.description ?? '').join(' '));
  } else if (m.method === 'Log.entryAdded') {
    out.push('LOG[' + m.params.entry.level + '] ' + m.params.entry.text);
  } else if (m.result?.result?.value !== undefined) {
    out.push('PROBE: ' + m.result.result.value);
  }
};
ws.onerror = (e) => { console.log('WS ERROR', e.message || String(e)); process.exit(1); };
