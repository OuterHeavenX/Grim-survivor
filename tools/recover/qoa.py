"""Decode Godot's QOA-compressed AudioStreamWAV payload to 16-bit PCM WAV."""
import struct, sys, os

DEQUANT = [
    [1, -1, 3, -3, 5, -5, 7, -7],
    [5, -5, 18, -18, 32, -32, 49, -49],
    [16, -16, 53, -53, 95, -95, 147, -147],
    [34, -34, 113, -113, 203, -203, 315, -315],
    [63, -63, 210, -210, 378, -378, 588, -588],
    [104, -104, 345, -345, 621, -621, 966, -966],
    [158, -158, 528, -528, 950, -950, 1477, -1477],
    [228, -228, 760, -760, 1368, -1368, 2128, -2128],
    [316, -316, 1053, -1053, 1895, -1895, 2947, -2947],
    [422, -422, 1405, -1405, 2529, -2529, 3934, -3934],
    [548, -548, 1828, -1828, 3290, -3290, 5117, -5117],
    [696, -696, 2320, -2320, 4176, -4176, 6496, -6496],
    [868, -868, 2893, -2893, 5207, -5207, 8099, -8099],
    [1064, -1064, 3548, -3548, 6386, -6386, 9933, -9933],
    [1286, -1286, 4288, -4288, 7718, -7718, 12005, -12005],
    [1536, -1536, 5120, -5120, 9216, -9216, 14336, -14336],
]
M64 = (1 << 64) - 1

def _s16(v):
    return v - 0x10000 if v & 0x8000 else v

def decode(data):
    assert data[:4] == b'qoaf', data[:4]
    (total,) = struct.unpack_from('>I', data, 4)
    p = 8
    channels = 1
    rate = 44100
    out = []
    while p + 8 <= len(data) and len(out) < total:
        channels = data[p]
        rate = int.from_bytes(data[p + 1:p + 4], 'big')
        fsamples = int.from_bytes(data[p + 4:p + 6], 'big')
        fsize = int.from_bytes(data[p + 6:p + 8], 'big')
        q = p + 8
        hist = [[0] * 4 for _ in range(channels)]
        wts = [[0] * 4 for _ in range(channels)]
        for c in range(channels):
            for i in range(4):
                hist[c][i] = _s16(int.from_bytes(data[q:q + 2], 'big')); q += 2
            for i in range(4):
                wts[c][i] = _s16(int.from_bytes(data[q:q + 2], 'big')); q += 2
        frame = [[0] * fsamples for _ in range(channels)]
        for base in range(0, fsamples, 20):
            for c in range(channels):
                sl = int.from_bytes(data[q:q + 8], 'big'); q += 8
                sf = (sl >> 60) & 0xF
                sl = (sl << 4) & M64
                h, w = hist[c], wts[c]
                tab = DEQUANT[sf]
                for k in range(20):
                    idx = base + k
                    if idx >= fsamples: break
                    pred = (w[0] * h[0] + w[1] * h[1] + w[2] * h[2] + w[3] * h[3]) >> 13
                    dq = tab[(sl >> 61) & 0x7]
                    sl = (sl << 3) & M64
                    rec = pred + dq
                    if rec < -32768: rec = -32768
                    elif rec > 32767: rec = 32767
                    frame[c][idx] = rec
                    d = dq >> 4
                    w[0] += -d if h[0] < 0 else d
                    w[1] += -d if h[1] < 0 else d
                    w[2] += -d if h[2] < 0 else d
                    w[3] += -d if h[3] < 0 else d
                    h[0], h[1], h[2], h[3] = h[1], h[2], h[3], rec
        for i in range(fsamples):
            for c in range(channels):
                out.append(frame[c][i])
        p += fsize
    return channels, rate, out

def write_wav(path, channels, rate, samples):
    pcm = struct.pack('<%dh' % len(samples), *samples)
    block = channels * 2
    hdr = b'RIFF' + struct.pack('<I', 36 + len(pcm)) + b'WAVEfmt ' + \
        struct.pack('<IHHIIHH', 16, 1, channels, rate, rate * block, block, 16) + \
        b'data' + struct.pack('<I', len(pcm))
    open(path, 'wb').write(hdr + pcm)

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    ch, rate, s = decode(open(src, 'rb').read())
    write_wav(dst, ch, rate, s)
    peak = max(abs(x) for x in s) if s else 0
    rms = int((sum(x * x for x in s) / max(1, len(s))) ** 0.5)
    print(f"{os.path.basename(dst)} ch={ch} rate={rate} samples={len(s)} peak={peak} rms={rms}")
