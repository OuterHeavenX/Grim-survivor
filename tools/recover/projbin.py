import struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import variant

def parse(path):
    d = open(path, 'rb').read()
    i = d.index(b'ECFG')
    p = i + 4
    (count,) = struct.unpack_from('<I', d, p); p += 4
    out = []
    for _ in range(count):
        (kl,) = struct.unpack_from('<I', d, p); p += 4
        key = d[p:p + kl].decode('utf-8'); p += kl
        (vl,) = struct.unpack_from('<I', d, p); p += 4
        v, _ = variant.decode(d, p)
        p += vl
        out.append((key, v))
    return out

if __name__ == '__main__':
    for k, v in parse(sys.argv[1]):
        print(f'{k} = {v!r}')
