import re, sys, os, urllib.request
base, out = sys.argv[1].rstrip('/'), sys.argv[2]
os.makedirs(out, exist_ok=True)
seen, queue = set(), []
html = open(os.path.join(out, 'index.html'), encoding='utf-8').read()
pat = re.compile(r'(?:/|\./|\.\./|")(?:assets/)?([A-Za-z0-9_\-.]+\.js)(?=["\'`?])')
def enqueue(text):
    for name in set(re.findall(r'assets/([A-Za-z0-9_\-.]+\.js)', text)) | set(re.findall(r'"\./([A-Za-z0-9_\-.]+\.js)"', text)):
        if name not in seen:
            seen.add(name); queue.append(name)
enqueue(html)
while queue:
    name = queue.pop()
    try:
        req = urllib.request.Request(f'{base}/assets/{name}', headers={'User-Agent': 'Mozilla/5.0 Electron'})
        data = urllib.request.urlopen(req, timeout=30).read()
    except Exception as e:
        print('FAIL', name, e); continue
    open(os.path.join(out, name), 'wb').write(data)
    enqueue(data.decode('utf-8', 'replace'))
print('downloaded', len(seen))
