import re, sys
data = open(sys.argv[1], 'rb').read()
for m in re.finditer(rb'[\x20-\x7e]{5,}', data):
    print(m.group().decode())
for m in re.finditer(rb'(?:[\x20-\x7e]\x00){5,}', data):
    print(m.group().decode('utf-16le'))
