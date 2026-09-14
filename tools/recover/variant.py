import struct

NIL,BOOL,INT,FLOAT,STRING = 0,1,2,3,4
STRING_NAME, NODE_PATH = 21, 22
ARRAY, DICTIONARY = 28, 27

class SName(str): pass
class NPath(str): pass

def _str(buf, p):
    (l,) = struct.unpack_from('<I', buf, p); p += 4
    s = buf[p:p+l].decode('utf-8', 'replace')
    p += l
    if l % 4: p += 4 - (l % 4)
    return s, p

def decode(buf, p):
    (h,) = struct.unpack_from('<I', buf, p); p += 4
    t = h & 0xFFFF; flags = h >> 16
    if t == NIL: return None, p
    if t == BOOL:
        (v,) = struct.unpack_from('<I', buf, p); return bool(v), p+4
    if t == INT:
        if flags & 1:
            (v,) = struct.unpack_from('<q', buf, p); return v, p+8
        (v,) = struct.unpack_from('<i', buf, p); return v, p+4
    if t == FLOAT:
        if flags & 1:
            (v,) = struct.unpack_from('<d', buf, p); return v, p+8
        (v,) = struct.unpack_from('<f', buf, p); return v, p+4
    if t == STRING:
        return _str(buf, p)
    if t == STRING_NAME:
        s, p = _str(buf, p); return SName(s), p
    if t == NODE_PATH:
        s, p = _str(buf, p); return NPath(s), p
    if t == ARRAY:
        (n,) = struct.unpack_from('<I', buf, p); p += 4
        n &= 0x7fffffff
        out = []
        for _ in range(n):
            v, p = decode(buf, p); out.append(v)
        return out, p
    if t == DICTIONARY:
        (n,) = struct.unpack_from('<I', buf, p); p += 4
        n &= 0x7fffffff
        out = {}
        for _ in range(n):
            k, p = decode(buf, p); v, p = decode(buf, p); out[k] = v
        return out, p
    raise ValueError(f"unsupported variant type {t} flags {flags} at {p-4}")

VECTOR2, COLOR = 5, 20
PACKED_BYTE, PACKED_I32, PACKED_I64 = 29, 30, 31
PACKED_F32, PACKED_F64, PACKED_STRING = 32, 33, 34

class Vec2(tuple): pass
class Col(tuple): pass
class PStr(list): pass

_orig = decode
def decode(buf, p):
    (h,) = struct.unpack_from('<I', buf, p)
    t = h & 0xFFFF
    if t == VECTOR2:
        p += 4; v = struct.unpack_from('<ff', buf, p); return Vec2(v), p + 8
    if t == COLOR:
        p += 4; v = struct.unpack_from('<ffff', buf, p); return Col(v), p + 16
    if t == PACKED_STRING:
        p += 4
        (n,) = struct.unpack_from('<I', buf, p); p += 4
        out = []
        for _ in range(n):
            s, p = _str(buf, p); out.append(s)
        return PStr(out), p
    if t == PACKED_BYTE:
        p += 4
        (n,) = struct.unpack_from('<I', buf, p); p += 4
        d = buf[p:p + n]; p += n
        if n % 4: p += 4 - (n % 4)
        return d, p
    return _orig(buf, p)
