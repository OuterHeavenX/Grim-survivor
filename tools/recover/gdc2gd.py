"""Reconstruct GDScript source from a Godot 4.7 .gdc binary token buffer."""
import struct, sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zstandard, variant
from gdtokens import NAMES, T, TEXT

class Tok:
    __slots__ = ('type', 'name', 'val', 'line', 'col', 'unary')
    def __init__(self, t, val, line):
        self.type = t; self.name = NAMES[t] if t < len(NAMES) else f'?{t}'
        self.val = val; self.line = line; self.col = None; self.unary = False
    def __repr__(self): return f'<{self.name} {self.val!r} L{self.line}>'

def parse(path):
    raw = open(path, 'rb').read()
    magic, ver, dsize = struct.unpack_from('<4sII', raw, 0)
    assert magic == b'GDSC', magic
    buf = zstandard.ZstdDecompressor().decompress(raw[12:], max_output_size=max(dsize, 1) * 8)

    ic, cc, tlc, tc = struct.unpack_from('<IIII', buf, 0)
    p = 16
    ids = []
    for _ in range(ic):
        (l,) = struct.unpack_from('<I', buf, p); p += 4
        cs = bytes(b ^ 0xb6 for b in buf[p:p + l * 4]); p += l * 4
        ids.append(''.join(chr(struct.unpack_from('<I', cs, j * 4)[0]) for j in range(l)))
    consts = []
    for _ in range(cc):
        v, p = variant.decode(buf, p); consts.append(v)
    lines = {}
    for _ in range(tlc):
        ti, ln = struct.unpack_from('<II', buf, p); p += 8; lines[ti] = ln
    cols = {}
    for _ in range(tlc):
        ti, cl = struct.unpack_from('<II', buf, p); p += 8; cols[ti] = cl

    toks = []
    for i in range(tc):
        d, ln = struct.unpack_from('<II', buf, p); p += 8
        ttype = d & 0x7F
        idx = d >> 8
        name = NAMES[ttype] if ttype < len(NAMES) else None
        val = None
        if name in ('IDENTIFIER', 'ANNOTATION'):
            val = ids[idx]
        elif name == 'LITERAL':
            val = consts[idx]
        t = Tok(ttype, val, ln)
        t.col = cols.get(i)
        toks.append(t)
    return ver, ids, consts, toks


def esc(s):
    out = s.replace('\\', '\\\\').replace('"', '\\"')
    out = out.replace('\n', '\\n').replace('\t', '\\t').replace('\r', '\\r')
    return '"' + out + '"'

def num(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, int): return str(v)
    if math.isinf(v): return ('-' if v < 0 else '') + 'INF'
    if math.isnan(v): return 'NAN'
    if v == int(v) and abs(v) < 1e16: return f'{int(v)}.0'
    r = repr(v)
    return r

def lit(v):
    if v is None: return 'null'
    if isinstance(v, variant.SName): return '&' + esc(v)
    if isinstance(v, variant.NPath): return '^' + esc(v)
    if isinstance(v, str): return esc(v)
    return num(v)

def text_of(t):
    n = t.name
    if n == 'IDENTIFIER': return t.val
    if n == 'ANNOTATION': return '@' + t.val
    if n == 'LITERAL': return lit(t.val)
    if n in TEXT: return TEXT[n]
    return f'<{n}>'

OPEN = {'PARENTHESIS_OPEN', 'BRACKET_OPEN', 'BRACE_OPEN'}
CLOSE = {'PARENTHESIS_CLOSE', 'BRACKET_CLOSE', 'BRACE_CLOSE'}
# tokens that can end a value expression
VALUE_END = {'IDENTIFIER', 'LITERAL', 'PARENTHESIS_CLOSE', 'BRACKET_CLOSE', 'BRACE_CLOSE',
             'SELF', 'SUPER', 'CONST_PI', 'CONST_TAU', 'CONST_INF', 'CONST_NAN', 'UNDERSCORE'}
UNARY_OPS = {'MINUS', 'PLUS', 'TILDE', 'BANG', 'NOT'}
NO_SPACE_BEFORE = {'COMMA', 'SEMICOLON', 'COLON', 'PERIOD', 'PERIOD_PERIOD',
                   'PERIOD_PERIOD_PERIOD', 'PARENTHESIS_CLOSE', 'BRACKET_CLOSE', 'BRACE_CLOSE'}
NO_SPACE_AFTER = {'PERIOD', 'PERIOD_PERIOD', 'PERIOD_PERIOD_PERIOD', 'DOLLAR',
                  'PARENTHESIS_OPEN', 'BRACKET_OPEN', 'BRACE_OPEN'}

def render_line(toks, continued=False):
    out = []
    for i, t in enumerate(toks):
        prev = toks[i - 1] if i else None
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        s = text_of(t)

        # ':=' inferred type assignment
        if t.name == 'COLON' and nxt is not None and nxt.name == 'EQUAL':
            if out: out.append(' ')
            out.append(':='); nxt.name = '__SKIP__'; continue
        if t.name == '__SKIP__': continue

        space = True
        if prev is None:
            space = False
        elif prev.name in NO_SPACE_AFTER:
            space = False
        elif t.name in NO_SPACE_BEFORE:
            space = False
        elif t.name == 'PARENTHESIS_OPEN':
            space = prev.name not in (VALUE_END | {'PRELOAD'})
        elif t.name == 'BRACKET_OPEN':
            space = prev.name not in VALUE_END
        elif t.name == 'BRACE_OPEN':
            space = prev.name not in VALUE_END
        elif prev.name in UNARY_OPS and getattr(prev, 'unary', False):
            space = False
        elif t.name == 'COLON':
            space = False

        # decide unary-ness of this operator for the *next* iteration
        if t.name in UNARY_OPS:
            t.unary = (prev is None and not continued) or (prev is not None and prev.name not in VALUE_END)
            if t.name == 'NOT':
                t.unary = False  # 'not x' always keeps its space

        if space and out: out.append(' ')
        out.append(s)
    return ''.join(out)

def decompile(path):
    ver, ids, consts, toks = parse(path)
    if not toks: return ''
    by_line = {}
    for t in toks:
        if t.name in ('NEWLINE', 'INDENT', 'DEDENT', 'TK_EOF', 'EMPTY'): continue
        by_line.setdefault(t.line, []).append(t)
    if not by_line: return ''
    maxline = max(by_line)
    out = []
    last_indent = ''
    for ln in range(1, maxline + 1):
        row = by_line.get(ln)
        if not row:
            out.append('')
            continue
        # A line whose first token carries no recorded column is not a real line
        # start: the tokenizer folded it into the previous logical line via a
        # backslash continuation.
        if row[0].col is None and ln > 1 and out:
            i = len(out) - 1
            while i >= 0 and out[i] == '':
                i -= 1
            if i >= 0:
                out[i] = out[i] + ' \\'
                indent = last_indent + '\t'
                out.append(indent + render_line(row, continued=True))
                continue
        col = row[0].col or 1
        indent = '\t' * max(0, col - 1)
        last_indent = indent
        out.append(indent + render_line(row))
    return '\n'.join(out).rstrip() + '\n'

if __name__ == '__main__':
    sys.stdout.write(decompile(sys.argv[1]))
