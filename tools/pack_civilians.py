"""Pack Blender's transparent renders without changing the camera registration."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art"/"civilians"
DEST=ROOT/"assets"/"sprites"
manifest=json.loads((ART/"manifest.json").read_text())
rows=manifest["characters"]
def font_at(size):
    for path in ["C:/Windows/Fonts/segoeui.ttf", "DejaVuSans.ttf"]:
        try:
            return ImageFont.truetype(path,size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)
font=font_at(20)
small=font_at(15)
board=Image.new("RGB",(1400,1170),"#151e2a")
draw=ImageDraw.Draw(board)
draw.text((32,24),"GRIM SURVIVORS  /  CIVILIAN ROSTER",font=font_at(32),fill="#e8e0cd")
draw.text((34,70),"Original Blender models · everyday clothing · animated game sprites",font=font,fill="#aabac4")
for i,row in enumerate(rows):
    ident=row["id"]; raw=ART/"renders"/ident
    size=row["height"]
    sources=[Image.open(raw/("walk_%02d.png"%f)).convert("RGBA") for f in manifest["frames"]]
    idle=Image.open(raw/"idle.png").convert("RGBA")
    boxes=[img.getbbox() for img in sources+[idle]]
    assert all(boxes), ident+" has an empty source render"
    left=min(b[0] for b in boxes); top=min(b[1] for b in boxes)
    right=max(b[2] for b in boxes); bottom=max(b[3] for b in boxes)
    extent=max(right-left,bottom-top)+8
    cx=(left+right)//2; cy=(top+bottom)//2
    crop=(cx-extent//2,cy-extent//2,cx-extent//2+extent,cy-extent//2+extent)
    sheet=Image.new("RGBA",(size*6,size))
    frames=[]
    for n,source in enumerate(sources):
        img=source.crop(crop).resize((size,size),Image.Resampling.LANCZOS)
        assert img.getbbox(),ident+" empty frame"
        sheet.paste(img,(n*size,0))
        frames.append(img.tobytes())
    assert len(set(frames))==6,ident+" walk animation has repeated poses"
    sheet.save(DEST/("player_%s_walk.png"%ident))
    idle.crop(crop).resize((size,size),Image.Resampling.LANCZOS).save(DEST/("player_%s_idle.png"%ident))
    Image.open(raw/"portrait.png").resize((192,192),Image.Resampling.LANCZOS).save(DEST/("player_%s_portrait.png"%ident))
    x=24+(i%5)*276; y=122+(i//5)*340
    draw.rounded_rectangle((x,y,x+260,y+323),12,fill="#222f3d")
    hero=Image.open(raw/"hero.png").convert("RGBA").resize((252,252),Image.Resampling.LANCZOS)
    board.paste(hero,(x+4,y+3),hero)
    draw.text((x+14,y+250),ident.upper(),font=font,fill="#e9d9b8")
    draw.text((x+14,y+279),row["outfit"].replace("knee-length ",""),font=small,fill="#aabac4")
board.save(ART/"civilian_roster.png")
print("Validated and packed",len(rows),"civilian walk sheets, idle sprites and portraits")
