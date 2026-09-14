"""Extract the contents of a Godot 4 .pck pack file (pack format 4)."""
import json, os, struct, sys

def read_dir(data):
    assert data[:4] == b'GDPC', 'not a Godot pack file'
    ver, vmaj, vmin, vpat, flags = struct.unpack_from('<IIIII', data, 4)
    file_base, dir_off = struct.unpack_from('<QQ', data, 24)
    p = dir_off
    (count,) = struct.unpack_from('<I', data, p); p += 4
    entries = []
    for _ in range(count):
        (plen,) = struct.unpack_from('<I', data, p); p += 4
        path = data[p:p + plen].rstrip(b'\x00').decode('utf-8'); p += plen
        off, size = struct.unpack_from('<QQ', data, p); p += 16
        p += 16  # md5
        (efl,) = struct.unpack_from('<I', data, p); p += 4
        entries.append({'path': path, 'off': off + file_base, 'size': size, 'flags': efl})
    return {'pack_version': ver, 'godot': [vmaj, vmin, vpat], 'flags': flags, 'entries': entries}

def extract(pck_path, out_dir):
    data = open(pck_path, 'rb').read()
    info = read_dir(data)
    for e in info['entries']:
        dst = os.path.join(out_dir, e['path'])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, 'wb') as f:
            f.write(data[e['off']:e['off'] + e['size']])
    return info

if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit('usage: pck_extract.py <index.pck> <out_dir>')
    info = extract(sys.argv[1], sys.argv[2])
    print(json.dumps({k: v for k, v in info.items() if k != 'entries'}))
    print(f"{len(info['entries'])} files -> {sys.argv[2]}")
