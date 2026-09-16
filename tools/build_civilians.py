"""Author and render the civilian roster with Blender (no external assets).

blender --background --factory-startup --python tools/build_civilians.py -- --preview
blender --background --factory-startup --python tools/build_civilians.py
Assemble the final PNGs with tools/pack_civilians.py after rendering.
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "civilians"
RAW = OUT / "renders"
PREVIEW = "--preview" in sys.argv
OUT.mkdir(parents=True, exist_ok=True)
RAW.mkdir(parents=True, exist_ok=True)

# Preserve the existing seven men / six women and class colour families.
# id, body, shirt, trousers/skirt, hair, skin, hairstyle, garment
ROSTER = [
    ("rogue", "man", "69549A", "273D59", "382720", "C68D68", "crop", "shirt"),
    ("shadow", "woman", "547DA8", "263C61", "201E29", "BD8361", "bob", "cardigan"),
    ("pyro", "woman", "CB6943", "653C44", "602B21", "E7AC84", "bun", "blouse"),
    ("warden", "man", "A5B2AC", "394858", "443930", "956448", "crop", "sweater"),
    ("flame", "man", "B75536", "385472", "3B231A", "DDA278", "quiff", "shirt"),
    ("rime", "woman", "8ABFD1", "315875", "D0A66C", "EDBC98", "bob", "sweater"),
    ("dancer", "woman", "DDD0B4", "966348", "392820", "82563D", "bun", "blouse"),
    ("storm", "man", "6179AE", "364559", "171D28", "AA7253", "quiff", "sweater"),
    ("reaper", "man", "677978", "514841", "A6A3A0", "D8A181", "crop", "shirt"),
    ("ravenmark", "woman", "897297", "393748", "201923", "D6A081", "bob", "cardigan"),
    ("bonewright", "man", "C0AD87", "475D63", "5D4430", "AF7754", "quiff", "shirt"),
    ("plague", "woman", "86A064", "424E3B", "55382C", "A86E4F", "bun", "blouse"),
    ("starcaller", "man", "9380B4", "34455E", "2B2428", "E0A785", "quiff", "sweater"),
]
HEIGHTS = dict(zip([r[0] for r in ROSTER], [78,74,76,84,76,76,74,78,80,74,84,78,76]))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for col in list(bpy.data.collections):
    if col.name != "Collection":
        bpy.data.collections.remove(col)

def material(name, hexcode, roughness=0.8):
    rgb = tuple(int(hexcode[i:i+2], 16) / 255 for i in (0,2,4))
    # Hex input is sRGB; Blender shader inputs are linear.
    rgb = tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = roughness
    return m

sole = material("Warm rubber soles", "DDD5C1")
shoe = material("Everyday canvas shoes", "35333D")
eye = material("Pupils and lashes", "1B1920")
white = material("Eye whites", "F5E7D4")
button = material("Ivory buttons", "DFD0AF")

active_col = None
pieces = []

def finish(ob, name, mat, bone):
    ob.name = name
    for col in list(ob.users_collection):
        col.objects.unlink(ob)
    active_col.objects.link(ob)
    ob.data.materials.append(mat)
    if ob.type == "MESH":
        for p in ob.data.polygons:
            p.use_smooth = True
        vg = ob.vertex_groups.new(name=bone)
        vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    pieces.append(ob)
    return ob

def ellipsoid(name, pos, scale, mat, bone, segments=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=12, location=pos)
    ob = bpy.context.object
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(ob, name, mat, bone)

def rings(name, profile, mat, bone, sides=24, pleat=0):
    vs, fs = [], []
    for z, rx, ry, cy in profile:
        for i in range(sides):
            a = 2*math.pi*i/sides
            ripple = 1 + pleat*math.cos(a*12)
            vs.append((rx*math.cos(a)*ripple, cy+ry*math.sin(a)*ripple, z))
    for j in range(len(profile)-1):
        for i in range(sides):
            a = j*sides+i
            b = j*sides+(i+1)%sides
            fs.append((a,b,b+sides,a+sides))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple((len(profile)-1)*sides+i for i in range(sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vs, [], fs)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    active_col.objects.link(ob)
    return finish(ob, name, mat, bone)

def limb(name, a, b, radii, mat, bone):
    mid = (Vector(a)+Vector(b))/2
    ob = ellipsoid(name, mid, (radii[0], radii[1], (Vector(b)-Vector(a)).length*.60), mat, bone)
    ob.rotation_euler = (Vector(b)-Vector(a)).to_track_quat("Z", "Y").to_euler()
    return ob

def cloth_limb(name, a, b, radius_a, radius_b, mat, bone):
    """Tapered fabric tubes avoid the separate shoulder-pad silhouette."""
    length=(Vector(b)-Vector(a)).length
    ob=rings(name,[(-.025,radius_a*.8,radius_a*.8,0),(.015,radius_a,radius_a,0),
                   (length-.015,radius_b,radius_b,0),(length+.01,radius_b*.92,radius_b*.92,0)],mat,bone,20)
    ob.location=a
    ob.rotation_euler=(Vector(b)-Vector(a)).to_track_quat("Z","Y").to_euler()
    return ob

def make_rig(name):
    bpy.ops.object.armature_add()
    rig = bpy.context.object
    rig.name = name+"_Rig"
    for col in list(rig.users_collection):
        col.objects.unlink(rig)
    active_col.objects.link(rig)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    eb.remove(eb[0])
    def bone(n, a, b, parent=None):
        v = eb.new(n); v.head=a; v.tail=b
        if parent: v.parent=eb[parent]
    bone("hips", (0,0,1.0), (0,0,1.15))
    bone("spine", (0,0,1.15), (0,0,1.49), "hips")
    bone("head", (0,0,1.49), (0,0,1.99), "spine")
    for side, s in [("L",1),("R",-1)]:
        bone("thigh."+side,(s*.135,0,1.01),(s*.15,0,.57),"hips")
        bone("shin."+side,(s*.15,0,.57),(s*.15,0,.15),"thigh."+side)
        bone("foot."+side,(s*.15,0,.15),(s*.15,-.19,.09),"shin."+side)
        bone("upper_arm."+side,(s*.28,0,1.46),(s*.39,-.015,1.18),"spine")
        bone("forearm."+side,(s*.39,-.015,1.18),(s*.41,-.09,.98),"upper_arm."+side)
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front=True
    return rig

def author(row, idx):
    global active_col, pieces
    ident, sex, tophex, bottomhex, hairhex, skinhex, style, garment = row
    female = sex == "woman"
    active_col=bpy.data.collections.new(ident+"_civilian_"+sex)
    bpy.context.scene.collection.children.link(active_col)
    pieces=[]
    top=material(ident+" fabric",tophex)
    bottom=material(ident+(" skirt" if female else " denim"),bottomhex)
    skin=material(ident+" skin",skinhex,.65)
    hair=material(ident+" hair",hairhex,.85)
    trim=material(ident+" knit trim",tophex,.95)
    rig=make_rig(ident)
    width=.235 if female else .27
    rings("Casual "+garment,[(1.01,.197 if female else .205,.139,0),(1.08,.205,.146,0),(1.23,width,.155,0),(1.40,width,.16,0),(1.48,.18,.12,0)],top,"spine")
    rings("Neckline ribbing",[(1.45,.112,.093,0),(1.50,.104,.085,0)],trim,"spine")
    ellipsoid("Neck",(0,0,1.51),(.093,.088,.12),skin,"head")
    # Uncovered, expressive civilian head, nose and ears.
    ellipsoid("Face",(0,-.015,1.75),(.23,.208,.275),skin,"head")
    ellipsoid("Nose",(0,-.217,1.72),(.043,.060,.055),skin,"head")
    for s in [-1,1]:
        ellipsoid("Ear",(s*.227,-.012,1.75),(.047,.038,.075),skin,"head")
        ellipsoid("Eye",(s*.087,-.204,1.798),(.050,.021,.032),white,"head")
        ellipsoid("Pupil",(s*.087,-.223,1.798),(.021,.009,.026),eye,"head")
        brow=ellipsoid("Eyebrow",(s*.088,-.207,1.85),(.056,.018,.014),hair,"head")
        brow.rotation_euler.y=s*.10
    ellipsoid("Mouth",(0,-.207,1.645),(.049,.008,.010),hair,"head")
    # Hair dome, open at the face (not a second full sphere).
    vs, fs=[],[]
    for j in range(10):
        for i in range(32):
            a=2*math.pi*i/32
            front=max(0,-math.sin(a))
            theta=(j/9)*(.55*math.pi-front*.20*math.pi)
            vs.append((.24*math.sin(theta)*math.cos(a), -.005+.223*math.sin(theta)*math.sin(a),1.78+.275*math.cos(theta)))
    for j in range(9):
        for i in range(32):
            a=j*32+i; b=j*32+(i+1)%32
            fs.append((a,b,b+32,a+32))
    me=bpy.data.meshes.new("Hair cap"); me.from_pydata(vs,[],fs); me.update()
    ob=bpy.data.objects.new("Sculpted hair cap",me); active_col.objects.link(ob); finish(ob,ob.name,hair,"head")
    for k in range(5):
        lock=ellipsoid("Swept hair lock",(-.14+k*.063,-.067,1.998),(.088,.15,.064),hair,"head")
        lock.rotation_euler.y=-.20
    if style == "bob":
        for s in [-1,1]:
            ellipsoid("Bob side",(s*.207,.015,1.75),(.080,.19,.25),hair,"head")
        ellipsoid("Bob back",(0,.153,1.72),(.23,.091,.25),hair,"head")
    elif style == "bun":
        ellipsoid("Hair bun",(0,.206,1.92),(.13,.12,.13),hair,"head")
        ellipsoid("Hair tie",(0,.205,1.87),(.105,.09,.025),top,"head")
    elif style == "quiff":
        q=ellipsoid("Swept quiff",(.02,-.112,2.014),(.19,.12,.10),hair,"head")
        q.rotation_euler.y=-.2
    if female:
        rings("Knee length pleated skirt",[(.53,.355,.27,0),(.56,.353,.269,0),(.74,.305,.236,0),(.97,.235,.17,0),(1.08,.223,.169,0)],bottom,"hips",48,.028)
        rings("Skirt waistband",[(1.035,.232,.175,0),(1.085,.233,.175,0)],bottom,"hips")
        rings("Stitched skirt hem",[(.529,.356,.271,0),(.55,.356,.271,0)],bottom,"hips",48,.028)
    else:
        rings("Trouser seat",[(.89,.22,.144,0),(1.07,.209,.145,0)],bottom,"hips")
    for side,s in [("L",1),("R",-1)]:
        legmat=skin if female else bottom
        if female:
            limb("Upper leg",(s*.135,0,1.0),(s*.15,0,.57),(.105,.112),legmat,"thigh."+side)
            limb("Lower leg",(s*.15,0,.60),(s*.15,0,.15),(.079,.085),legmat,"shin."+side)
        else:
            cloth_limb("Trouser thigh",(s*.135,0,1.0),(s*.15,0,.56),.116,.102,legmat,"thigh."+side)
            cloth_limb("Trouser calf",(s*.15,0,.58),(s*.15,0,.14),.105,.080,legmat,"shin."+side)
        ellipsoid("Canvas sneaker",(s*.15,-.067,.113),(.103,.198,.096),shoe,"foot."+side)
        ellipsoid("Rubber sole",(s*.15,-.069,.056),(.108,.204,.039),sole,"foot."+side)
        ellipsoid("Toe cap",(s*.15,-.21,.104),(.094,.061,.055),sole,"foot."+side)
        for k in range(3):
            ellipsoid("Shoelace",(s*.15,-.063-k*.031,.195-k*.01),(.061,.008,.008),sole,"foot."+side,12)
        a=(s*.28,0,1.43); b=(s*.39,-.015,1.18); c=(s*.41,-.09,.98)
        cloth_limb("Shirt sleeve",a,b,.12,.087,top,"upper_arm."+side)
        long = garment in ("sweater","cardigan")
        if long:
            cloth_limb("Sleeve",b,c,.090,.068,top,"forearm."+side)
        else:
            limb("Bare forearm",b,c,(.079,.080),skin,"forearm."+side)
        ellipsoid("Hand",(s*.412,-.097,.94),(.078,.057,.10),skin,"forearm."+side)
        ellipsoid("Thumb",(s*.357,-.12,.955),(.030,.035,.06),skin,"forearm."+side)
    # Everyday garment construction: placket/buttons or a ribbed sweater hem.
    if garment != "sweater":
        ellipsoid("Button placket",(0,-.158,1.26),(.013,.012,.17),trim,"spine")
        for z in [1.12,1.23,1.34,1.43]:
            ellipsoid("Shirt button",(0,-.173,z),(.014,.008,.014),button,"spine",12)
        for s in [-1,1]:
            collar=ellipsoid("Soft collar",(s*.074,-.107,1.46),(.066,.028,.063),trim,"spine")
            collar.rotation_euler.y=s*.38
    else:
        rings("Sweater ribbed hem",[(1.012,.208,.146,0),(1.063,.214,.151,0)],trim,"spine")
    if not female and garment=="shirt":
        ellipsoid("Shirt pocket",(-.126,-.154,1.315),(.060,.015,.064),trim,"spine")
    # Join weighted pieces into one editable skin, retaining named material slots.
    bpy.ops.object.select_all(action="DESELECT")
    for ob in pieces: ob.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0]
    bpy.ops.object.join()
    mesh=bpy.context.object
    mesh.name=ident+"_Civilian_"+sex
    mod=mesh.modifiers.new("Civilian skeletal animation","ARMATURE"); mod.object=rig
    mesh.parent=rig
    rig["body"] = sex
    rig["outfit"] = garment + (" and knee-length skirt" if female else " and trousers")
    rig["class_id"] = ident
    rig["authorship"] = "Original Blender geometry; generated with tools/build_civilians.py"
    # Separate neutral frame and a seamless 24-frame action. Export six samples.
    for f in range(26):
        t=2*math.pi*(f-1)/24
        for pb in rig.pose.bones:
            pb.rotation_mode="XYZ"; pb.rotation_euler=(0,0,0); pb.location=(0,0,0)
        if f:
            rig.pose.bones["hips"].location.y=.018*(1-math.cos(2*t))
            rig.pose.bones["spine"].rotation_euler.y=.045*math.sin(t)
            for side,s in [("L",1),("R",-1)]:
                phase=math.sin(t)*s
                rig.pose.bones["thigh."+side].rotation_euler.x=.31*phase
                rig.pose.bones["shin."+side].rotation_euler.x=-.36*max(0,-math.cos(t)*s)
                rig.pose.bones["upper_arm."+side].rotation_euler.x=-.30*phase
                rig.pose.bones["forearm."+side].rotation_euler.x=-.08-.08*max(0,phase)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_euler",frame=f)
            pb.keyframe_insert("location",frame=f)
    rig.animation_data.action.name=ident+"_Idle0_Walk1to25"
    rig.location.x=idx*2.5
    return {"id":ident,"rig":rig,"mesh":mesh,"collection":active_col,"sex":sex,"outfit":rig["outfit"]}

characters=[author(r,i) for i,r in enumerate(ROSTER)]
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.view_settings.view_transform="Standard"
scene.view_settings.look="Medium High Contrast" if "Medium High Contrast" in [i.identifier for i in scene.view_settings.bl_rna.properties['look'].enum_items] else "None"
scene.view_settings.exposure=0
scene.world.color=(.30,.30,.30)
scene.render.fps=44
scene.frame_start=1; scene.frame_end=24
scene.render.resolution_percentage=100

bpy.ops.object.camera_add()
camera=bpy.context.object; camera.name="Civilian render camera"
camera.data.type="ORTHO"; scene.camera=camera
lights=[]
for name,loc,power,size in [("Softbox key",(-3,-4,7),500,4),("Softbox fill",(4,-1,5),300,3),("Hair rim",(0,4,6),600,3)]:
    bpy.ops.object.light_add(type="AREA",location=loc)
    ob=bpy.context.object; ob.name=name; ob.data.energy=power; ob.data.shape="DISK"; ob.data.size=size
    lights.append((ob,Vector(loc)))

def setup(char, portrait=False, hero=False):
    x=char["rig"].location.x
    for c in characters: c["collection"].hide_render=c is not char
    target=Vector((x,0,1.03 if not portrait else 1.47))
    camera.location=target+Vector((.0,-6,10) if not (portrait or hero) else (2.4,-7,3.2))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=2.05 if not portrait else 1.25
    if hero: camera.data.ortho_scale=2.45
    res=256 if not (portrait or hero) else (256 if portrait else 640)
    scene.render.resolution_x=res; scene.render.resolution_y=res
    for ob,loc in lights:
        ob.location=loc+Vector((x,0,0))
        ob.rotation_euler=(target-ob.location).to_track_quat("-Z","Y").to_euler()

def render(path):
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)

for i,char in enumerate(characters):
    if PREVIEW and i>1: break
    d=RAW/char["id"]; d.mkdir(exist_ok=True)
    setup(char,hero=True); scene.frame_set(0); render(d/"hero.png")
    setup(char,portrait=True); scene.frame_set(0); render(d/"portrait.png")
    setup(char); scene.frame_set(0); render(d/"idle.png")
    for frame in ([5] if PREVIEW else [1,5,9,13,17,21]):
        scene.frame_set(frame); render(d/("walk_%02d.png"%frame))
    print("CIVILIAN COMPLETE",char["id"],flush=True)

for c in characters: c["collection"].hide_render=False
scene.frame_set(0)
# Save with the full roster in the viewport, organized into named collections.
for area in bpy.context.screen.areas:
    if area.type=="VIEW_3D":
        area.spaces.active.region_3d.view_distance=18
        area.spaces.active.region_3d.view_location=(15,0,1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"civilian_roster.blend"))
manifest={"generator":"tools/build_civilians.py","blender":bpy.app.version_string,
          "frames":[1,5,9,13,17,21],"authorship":"Original procedural Blender geometry, no third-party model or texture inputs.",
          "characters":[{"id":c["id"],"body":c["sex"],"outfit":c["outfit"],"height":HEIGHTS[c["id"]]} for c in characters]}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
