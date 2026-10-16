"""Pack the companion renders into game sprite sheets and a review sheet.

Run after tools/build_companions.py. Mirrors tools/pack_civilians.py: one
padded bounding square across the whole walk cycle (plus the neutral pose), so
frames never shift or resize, then six square cells in a horizontal strip.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/"art"/"companions"
RAW = ART/"renders"
DEST = ROOT/"assets"/"sprites"
FRAMES = [1, 5, 9, 13, 17, 21]
COMPANIONS = [
    ("hound", "Grave Hound", 84, "#7dffb0"),
    ("archer", "Bone Archer", 80, "#8fd8ff"),
    ("knight", "Wraith Knight", 104, "#c08cff"),
]

def font_at(size):
    for path in ["C:/Windows/Fonts/segoeui.ttf", "DejaVuSans.ttf"]:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)

title, font, small = font_at(30), font_at(20), font_at(15)
board = Image.new("RGB", (1240, 1140), "#121214")
draw = ImageDraw.Draw(board)
draw.text((28, 22), "GRIM SURVIVORS  /  SPECTRAL COMPANIONS", font=title, fill="#e8e0cd")
draw.text((30, 64), "Original Blender models · portraits · walk sheets enlarged and at in-game cell size",
          font=font, fill="#9a9a9e")
ground = (26, 27, 30)
for row, (ident, name, size, accent) in enumerate(COMPANIONS):
    raw = RAW/ident
    sources = [Image.open(raw/("walk_%02d.png" % f)).convert("RGBA") for f in FRAMES]
    idle = Image.open(raw/"idle.png").convert("RGBA")
    boxes = [img.getbbox() for img in sources+[idle]]
    assert all(boxes), ident+" has an empty source render"
    left = min(b[0] for b in boxes); top = min(b[1] for b in boxes)
    right = max(b[2] for b in boxes); bottom = max(b[3] for b in boxes)
    extent = max(right-left, bottom-top)+8
    cx = (left+right)//2; cy = (top+bottom)//2
    crop = (cx-extent//2, cy-extent//2, cx-extent//2+extent, cy-extent//2+extent)
    sheet = Image.new("RGBA", (size*6, size))
    frames = []
    for n, source in enumerate(sources):
        img = source.crop(crop).resize((size, size), Image.Resampling.LANCZOS)
        assert img.getbbox(), ident+" empty frame"
        sheet.paste(img, (n*size, 0))
        frames.append(img.tobytes())
    assert len(set(frames)) == 6, ident+" walk animation has repeated poses"
    sheet.save(DEST/("companion_%s_walk.png" % ident))
    portrait = Image.open(raw/"portrait.png").convert("RGBA").resize((384, 384), Image.Resampling.LANCZOS)
    portrait.save(DEST/("companion_%s_portrait.png" % ident))

    # Review row: portrait, name, 2x walk strip and the real-size strip on dark ground.
    y = 110 + row*340
    draw.rounded_rectangle((20, y, 1220, y+326), 12, fill="#1c1c20")
    p = portrait.resize((270, 270), Image.Resampling.LANCZOS)
    draw.rectangle((28, y+28, 298, y+298), fill="#222226")
    board.paste(p, (28, y+28), p)
    draw.text((316, y+12), name.upper(), font=font, fill="#e9d9b8")
    draw.text((316, y+40), "companion_%s  ·  %d px cells  ·  accent %s" % (ident, size, accent), font=small, fill="#9a9a9e")
    scale = min(2.0, 860/(size*6))
    big = sheet.resize((int(size*6*scale), int(size*scale)), Image.Resampling.NEAREST)
    bg = Image.new("RGBA", big.size, ground+(255,))
    bg.alpha_composite(big)
    board.paste(bg, (316, y+66))
    small_bg = Image.new("RGBA", sheet.size, ground+(255,))
    small_bg.alpha_composite(sheet)
    board.paste(small_bg, (316, y+74+big.size[1]))
board.save(ART/"companions_sheet.png")
print("Validated and packed", len(COMPANIONS), "companion walk sheets and portraits")
