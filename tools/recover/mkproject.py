import sys, os, struct, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import variant, projbin

def f32(v):
    for prec in range(1, 10):
        s = f'%.{prec}g' % v
        if struct.unpack('<f', struct.pack('<f', float(s)))[0] == struct.unpack('<f', struct.pack('<f', v))[0]:
            return s
    return repr(v)

def txt(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, variant.Col): return 'Color(' + ', '.join(f32(x) for x in v) + ')'
    if isinstance(v, variant.Vec2): return 'Vector2(' + ', '.join(f32(x) for x in v) + ')'
    if isinstance(v, variant.PStr):
        return 'PackedStringArray(' + ', '.join('"%s"' % s.rstrip('\x00') for s in v) + ')'
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return f32(v)
    if isinstance(v, str): return '"%s"' % v.rstrip('\x00').replace('\\', '\\\\').replace('"', '\\"')
    raise TypeError(type(v))

HEADER = '''; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5
'''

def build(entries):
    sections = collections.OrderedDict()
    for key, val in entries:
        sec, _, rest = key.partition('/')
        sections.setdefault(sec, []).append((rest, val))
    out = [HEADER]
    for sec, items in sections.items():
        out.append('[%s]\n' % sec)
        for k, v in items:
            out.append('%s=%s' % (k, txt(v)))
        out.append('')
    return '\n'.join(out).rstrip() + '\n'

if __name__ == '__main__':
    sys.stdout.write(build(projbin.parse(sys.argv[1])))
