import os, sys, gzip
try: import brotli
except ImportError: brotli = None
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for fn in sorted(os.listdir(src)):
    if not fn.startswith('f_'): continue
    try: data = open(os.path.join(src, fn), 'rb').read()
    except Exception as e: print(fn, 'locked'); continue
    kind = 'raw'
    if data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data); kind = 'gzip'
    elif brotli:
        try: data = brotli.decompress(data); kind = 'br'
        except Exception: pass
    head = data[:60].replace(b'\n', b' ')
    open(os.path.join(out, fn), 'wb').write(data)
    print(f'{fn} {len(data):>9} {kind:5} {head[:60]!r}')
print('brotli module:', bool(brotli))
