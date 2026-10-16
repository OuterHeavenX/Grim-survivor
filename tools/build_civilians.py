"""Author and render the survivor roster with Blender (no external assets).

blender --background --factory-startup --python tools/build_civilians.py -- --preview
blender --background --factory-startup --python tools/build_civilians.py -- --only rogue,reaper
blender --background --factory-startup --python tools/build_civilians.py
Assemble the final PNGs with tools/pack_civilians.py after rendering.

Every survivor is original procedural geometry: a shared weighted body and
armature, plus a per-class costume (hoods, cloaks, mantles, plate, feathers,
bone, fur, masks) built from the helpers below and skinned to the same bones,
so the shared walk cycle drives every costume piece.
"""
import bpy
import math
import json
import random
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "civilians"
RAW = OUT / "renders"
ARGS = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGS
# Re-render only the selection portraits (the title altar shows them large).
PORTRAITS = "--portraits" in ARGS
ONLY = None
if "--only" in ARGS:
    ONLY = ARGS[ARGS.index("--only")+1].split(",")
OUT.mkdir(parents=True, exist_ok=True)
RAW.mkdir(parents=True, exist_ok=True)

# Seven men and six women, as before. Each survivor has a muted, ash-dark base
# palette and exactly one accent colour so classes stay distinguishable.
#   skin/hair/style: head; tunic/sleeve/legs/boots/hands: base layers;
#   accent (+glow): the single class accent; eyes: optional glowing eyes.
ROSTER = [
    dict(id="rogue", sex="man", skin="A07A63", hair="2A211C", style="crop",
         tunic="4A3A2C", sleeve="3B3632", legs="2C2A28", boots="2A211B", hands="2E2520",
         accent="8E1D25", glow=0, eyes=None,
         outfit="deep hood, travelling cloak",
         look="Ash-brown peaked hood and long travelling cloak lined in blood red, leather jerkin, belt pouches."),
    dict(id="shadow", sex="woman", skin="9C7A68", hair="16151B", style="bob",
         tunic="1E2129", sleeve="23262F", legs="1A1C22", boots="16161A", hands="1D1E24",
         accent="5A7DAF", glow=0, eyes="8FB4FF",
         outfit="wrapped hood, face scarf",
         look="Close black wrapped hood and scarf over the lower face, cold steel-blue bindings, faintly lit eyes."),
    dict(id="pyro", sex="woman", skin="B08A74", hair="4A2219", style="bun",
         tunic="2B2522", sleeve="2B2522", legs="1F1B19", boots="221A16", hands="B08A74",
         accent="E2601A", glow=2.2, eyes=None,
         outfit="scorched robe, ember trim",
         look="Soot-black hooded robe, singed hem, cuffs and hood rim smouldering ember orange."),
    dict(id="warden", sex="man", skin="8A6450", hair="6E6862", style="crop",
         tunic="3A3633", sleeve="3A3633", legs="2D2B2A", boots="241F1B", hands="55585A",
         accent="A8843C", glow=0, eyes=None,
         outfit="iron plate, pauldrons, mantle",
         look="Tarnished iron breastplate, heavy layered pauldrons, gauntlets and greaves, brass trim, dark wool mantle, grey beard."),
    dict(id="flame", sex="man", skin="9E7560", hair="1E1714", style="quiff",
         tunic="5A2A1E", sleeve="2E2724", legs="26211F", boots="221A15", hands="F2A23A",
         accent="F2A23A", glow=2.5, eyes=None,
         outfit="burnt tabard, burning hands",
         look="Burnt-red tabard over soot leathers, high scorched collar, flame-gold glowing hands and collar trim."),
    dict(id="rime", sex="woman", skin="C4AFA4", hair="BDB6AE", style="bob",
         tunic="2C3540", sleeve="2C3540", legs="232A31", boots="2A2C2E", hands="3A4048",
         accent="9FD8E8", glow=1.2, eyes=None,
         outfit="frost furs, fur hood",
         look="Pale frosted fur hood and mantle over slate-blue leathers, ice-cyan crystal shards at clasp and shoulders."),
    dict(id="dancer", sex="woman", skin="7A5442", hair="1C1614", style="bun",
         tunic="3B3C40", sleeve="303135", legs="2A2B2E", boots="211E1C", hands="2A2524",
         accent="4E8C7E", glow=0, eyes=None,
         outfit="blade wraps, jade sash",
         look="Grey fighting wraps, faded jade sash with long tails, twin sheathed blades crossed on the back."),
    dict(id="storm", sex="man", skin="94705C", hair="15171C", style="quiff",
         tunic="2E323A", sleeve="2E323A", legs="24262B", boots="1E1E21", hands="2A2726",
         accent="6F9BFF", glow=3.0, eyes="9DBBFF",
         outfit="storm coat, lightning rods",
         look="Storm-grey long coat with a high collar, copper lightning rods on the back, crackling blue-white bracers and eyes."),
    dict(id="reaper", sex="man", skin="8E8780", hair="A6A3A0", style="crop",
         tunic="161719", sleeve="161719", legs="141517", boots="111112", hands="2A2826",
         accent="8FE0A8", glow=5.0, eyes="8FE0A8",
         outfit="black cowl, ragged robe",
         look="Deep black cowl hiding a gaunt face, ragged ankle-length robe and tattered mantle, ghost-green eyes."),
    dict(id="ravenmark", sex="woman", skin="A8887A", hair="141218", style="bob",
         tunic="25222B", sleeve="25222B", legs="1C1A20", boots="19171B", hands="1E1C21",
         accent="6A4483", glow=0, eyes=None,
         outfit="feathered mantle, raven crest",
         look="Layered black feather mantle and raven-feather crest, long open robe with a bruised plum-violet lining."),
    dict(id="bonewright", sex="man", skin="8F6A52", hair="3A2C22", style="crop",
         tunic="4A3E31", sleeve="3A332C", legs="2E2A26", boots="2A221C", hands="3A2E25",
         accent="D8CBA8", glow=0, eyes=None,
         outfit="leathers, bone crown, ribs",
         look="Stained leather apron and pauldrons studded with bone, crown of tusks, rib-bone chest guard and belt skull."),
    dict(id="plague", sex="woman", skin="9C7C68", hair="2C2420", style="bun",
         tunic="2E3027", sleeve="2E3027", legs="22241F", boots="1E1D1A", hands="1E1D1A",
         accent="A3BE3C", glow=3.0, eyes=None,
         outfit="beaked mask, long coat",
         look="Wide-brimmed hat, leather beaked mask with bile-green glass lenses, long waxed coat over dark layers."),
    dict(id="starcaller", sex="man", skin="A88570", hair="211C22", style="quiff",
         tunic="1D1C2B", sleeve="1D1C2B", legs="18171F", boots="17161A", hands="A88570",
         accent="E9C86A", glow=1.6, eyes="E9C86A",
         outfit="pointed hood, star robe",
         look="Tall pointed indigo-black hood and robe scattered with pale-gold star motes, softly lit eyes."),
]
# Cell heights (px) are unchanged from the original roster.
HEIGHTS = dict(zip([r["id"] for r in ROSTER], [78,74,76,84,76,76,74,78,80,74,84,78,76]))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for col in list(bpy.data.collections):
    if col.name != "Collection":
        bpy.data.collections.remove(col)

def srgb(hexcode):
    rgb = tuple(int(hexcode[i:i+2], 16) / 255 for i in (0,2,4))
    # Hex input is sRGB; Blender shader inputs are linear.
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb)

def material(name, hexcode, roughness=0.8, grime=0.35, metal=0.0, emit=0.0, sheen=0.0, bump=0.18):
    """Principled material with a soft noise 'grime' darkening for worn cloth."""
    rgb = srgb(hexcode)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = roughness
    bs.inputs["Metallic"].default_value = metal
    if sheen and "Sheen Weight" in bs.inputs:
        bs.inputs["Sheen Weight"].default_value = sheen
    if emit:
        bs.inputs["Emission Color"].default_value = (*rgb, 1)
        bs.inputs["Emission Strength"].default_value = emit
    if grime > 0:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 9.0
        noise.inputs["Detail"].default_value = 6.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = .35
        ramp.color_ramp.elements[1].position = .75
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        a = [s for s in mix.inputs if s.name == "A" and s.type == "RGBA"][0]
        b = [s for s in mix.inputs if s.name == "B" and s.type == "RGBA"][0]
        res = [s for s in mix.outputs if s.name == "Result" and s.type == "RGBA"][0]
        a.default_value = (*(v*(1-grime) for v in rgb), 1)
        b.default_value = (*rgb, 1)
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mix.inputs["Factor"])
        nt.links.new(res, bs.inputs["Base Color"])
    if bump > 0:
        # Fine weave/grit so cloth and leather stop reading as smooth clay.
        grit = nt.nodes.new("ShaderNodeTexNoise")
        grit.inputs["Scale"].default_value = 70.0
        grit.inputs["Detail"].default_value = 8.0
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        nt.links.new(grit.outputs["Fac"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
    return m

def shade(hexcode, k):
    """Scale an sRGB hex colour by k (k<1 darker)."""
    return "".join("%02X" % max(0, min(255, int(int(hexcode[i:i+2], 16)*k))) for i in (0,2,4))

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

def ellipsoid(name, pos, scale, mat, bone, segments=20, rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=12, location=pos)
    ob = bpy.context.object
    ob.scale = scale
    if rot: ob.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(ob, name, mat, bone)

def from_data(name, vs, fs, mat, bone):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vs, [], fs)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    active_col.objects.link(ob)
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
    return from_data(name, vs, fs, mat, bone)

def shell(name, profile, mat, bone, sides=40, ragged=0.0, ripple=0.0, freq=11, seed=1):
    """Open cloth surface. profile rows: (z, rx, ry, cy, a0deg, a1deg).
    Angles follow rings(): -90 is the front (-Y), +90 the back.
    ragged tears the last row into an uneven hem."""
    rnd = random.Random(seed)
    closed = all(r[5]-r[4] >= 360 for r in profile)
    n = sides if closed else sides+1
    vs, fs = [], []
    last = len(profile)-1
    for j,(z, rx, ry, cy, a0, a1) in enumerate(profile):
        for i in range(n):
            a = math.radians(a0 + (a1-a0)*i/sides)
            rip = 1 + ripple*math.cos(a*freq)*(j/last if last else 1)
            zz = z
            if j == last and ragged:
                zz += ragged*(.5 + .5*math.cos(a*17)) + ragged*.6*rnd.random()
            vs.append((rx*math.cos(a)*rip, cy+ry*math.sin(a)*rip, zz))
    for j in range(len(profile)-1):
        for i in range(sides):
            a = j*n+i
            b = j*n+(i+1)%n
            fs.append((a,b,b+n,a+n))
    return from_data(name, vs, fs, mat, bone)

def limb(name, a, b, radii, mat, bone):
    mid = (Vector(a)+Vector(b))/2
    ob = ellipsoid(name, mid, (radii[0], radii[1], (Vector(b)-Vector(a)).length*.60), mat, bone)
    ob.rotation_euler = (Vector(b)-Vector(a)).to_track_quat("Z", "Y").to_euler()
    return ob

def cone(name, a, b, r1, mat, bone, r2=0.0, verts=10):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=(b-a).length, location=(a+b)/2)
    ob = bpy.context.object
    ob.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return finish(ob, name, mat, bone)

def cloth_limb(name, a, b, radius_a, radius_b, mat, bone):
    """Tapered fabric tubes avoid the separate shoulder-pad silhouette."""
    length=(Vector(b)-Vector(a)).length
    ob=rings(name,[(-.025,radius_a*.8,radius_a*.8,0),(.015,radius_a,radius_a,0),
                   (length-.015,radius_b,radius_b,0),(length+.01,radius_b*.92,radius_b*.92,0)],mat,bone,20)
    ob.location=a
    ob.rotation_euler=(Vector(b)-Vector(a)).to_track_quat("Z","Y").to_euler()
    return ob

def hood(name, mat, lining, center=(0,.0,1.77), radii=(.300,.295,.305), opening=46,
         droop=.30, brim=.05, peak=0.0, tall=0.0, sides=36, rows=16, lip=.92):
    """A cowl around the head with a clean oval face opening.
    The polar axis points at the face (tilted down by `droop`), so the opening
    is one ring; `brim` pulls the rim forward to shade the eyes, `peak`/`tall`
    pull the crown back/up into a point."""
    c = Vector(center)
    f = Vector((0, -1, -droop)).normalized()
    up = (Vector((0,0,1)) - f*f.z).normalized()
    rt = f.cross(up).normalized()
    pk = Vector((0, .75, .66)).normalized()
    def point(theta, psi, scale=1.0):
        d = f*math.cos(theta) + (rt*math.cos(psi) + up*math.sin(psi))*math.sin(theta)
        p = Vector((d.x*radii[0], d.y*radii[1], d.z*radii[2]))*scale
        rim = max(0.0, 1 - (math.degrees(theta)-opening)/38)
        p += f*brim*rim**1.5
        w = max(0.0, d.dot(pk))
        p += Vector((0, .14*peak, .045*peak))*w**5 + Vector((0, .03*tall, .19*tall))*w**9
        return c + p
    thetas = [math.radians(opening + (176-opening)*k/(rows-1)) for k in range(rows)]
    vs = []
    for i in range(sides):
        vs.append(point(thetas[0], 2*math.pi*i/sides, lip))
    for t in thetas:
        for i in range(sides):
            vs.append(point(t, 2*math.pi*i/sides))
    fs = []
    for j in range(len(thetas)):
        for i in range(sides):
            a = j*sides+i; b = j*sides+(i+1)%sides
            fs.append((a,b,b+sides,a+sides))
    pole = len(vs); vs.append(point(math.pi, 0))
    base = len(thetas)*sides
    for i in range(sides):
        fs.append((base+i, base+(i+1)%sides, pole))
    ob = from_data(name, [tuple(v) for v in vs], fs, mat, "head")
    # Inner lining band visible inside the face opening.
    lv = []
    lt = [math.radians(opening + 34*k/5) for k in range(6)]
    for t in lt:
        for i in range(sides):
            lv.append(point(t, 2*math.pi*i/sides, .955))
    lf = []
    for j in range(len(lt)-1):
        for i in range(sides):
            a = j*sides+i; b = j*sides+(i+1)%sides
            lf.append((a,b,b+sides,a+sides))
    from_data(name+" lining", [tuple(v) for v in lv], lf, lining, "head")
    return ob

def tuft_ring(name, z, rx, ry, cy, count, size, mat, bone, seed=3, arc=(0,360)):
    """Clumps of fur/rough trim along a ring."""
    rnd = random.Random(seed)
    for k in range(count):
        a = math.radians(arc[0] + (arc[1]-arc[0])*(k+.5)/count)
        j = .85 + .3*rnd.random()
        ellipsoid(name, (rx*math.cos(a), cy+ry*math.sin(a), z+(rnd.random()-.5)*size*.6),
                  (size*j, size*j, size*.75*j), mat, bone, 10)

def feather_ring(name, z, rx, ry, cy, count, length, out, mat, bone, seed=5, arc=(0,360), width=.05):
    rnd = random.Random(seed)
    for k in range(count):
        a = math.radians(arc[0] + (arc[1]-arc[0])*(k+.5)/count + (rnd.random()-.5)*6)
        base = Vector((rx*math.cos(a), cy+ry*math.sin(a), z))
        d = Vector((math.cos(a)*out, math.sin(a)*out*ry/rx, -1)).normalized()
        tip = base + d*length*(.85+.3*rnd.random())
        limb(name, base, tip, (width, width*.42), mat, bone)

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

# ---------------------------------------------------------------- shared body

def body(C, M, female, hooded):
    """Head, torso, limbs, boots. Faces are a little gaunter than before:
    a heavier brow ridge, sunken sockets, smaller eyes and a flat mouth."""
    width=.235 if female else .27
    rings("Tunic",[(1.01,.197 if female else .205,.139,0),(1.08,.205,.146,0),(1.23,width,.155,0),(1.40,width,.16,0),(1.48,.18,.12,0)],M["tunic"],"spine")
    rings("Collar",[(1.44,.118,.098,0),(1.52,.108,.090,0)],M["tunic"],"spine")
    ellipsoid("Neck",(0,0,1.51),(.093,.088,.12),M["skin"],"head")
    ellipsoid("Face",(0,-.015,1.75),(.225,.205,.275),M["skin"],"head")
    ellipsoid("Cheekbones",(0,-.06,1.73),(.215,.15,.07),M["skin"],"head")
    ellipsoid("Nose",(0,-.208,1.715),(.032,.048,.055),M["skin"],"head")
    ellipsoid("Brow ridge",(0,-.175,1.842),(.19,.055,.042),M["skin"],"head")
    for s in [-1,1]:
        ellipsoid("Ear",(s*.222,-.012,1.75),(.042,.036,.07),M["skin"],"head")
        ellipsoid("Sunken socket",(s*.085,-.172,1.79),(.066,.04,.042),M["socket"],"head")
        ellipsoid("Eye",(s*.085,-.193,1.792),(.040,.016,.020),M["eyewhite"],"head")
        pr = .026 if C["eyes"] else .019
        ellipsoid("Pupil",(s*.085,-.207,1.792),(pr,.008,pr),M["pupil"],"head")
        ellipsoid("Heavy brow",(s*.09,-.214,1.835),(.06,.02,.016),M["hair"],"head",rot=(0,s*.32,0))
    ellipsoid("Mouth",(0,-.198,1.632),(.046,.008,.007),M["socket"],"head")
    if not hooded:
        hair(C, M, female)
    else:
        ellipsoid("Hair under hood",(0,.01,1.80),(.235,.22,.27),M["hair"],"head")
    if female:
        rings("Hip wrap",[(.86,.215,.152,0),(1.07,.205,.15,0)],M["legs"],"hips")
    else:
        rings("Trouser seat",[(.89,.22,.144,0),(1.07,.209,.145,0)],M["legs"],"hips")
    for side,s in [("L",1),("R",-1)]:
        cloth_limb("Trouser thigh",(s*.135,0,1.0),(s*.15,0,.56),.112 if female else .116,.10,M["legs"],"thigh."+side)
        cloth_limb("Trouser calf",(s*.15,0,.58),(s*.15,0,.14),.098 if female else .105,.08,M["legs"],"shin."+side)
        # Worn leather boots with a folded cuff and a strap, no sneakers.
        ellipsoid("Boot foot",(s*.15,-.06,.105),(.098,.195,.092),M["boots"],"foot."+side)
        ellipsoid("Boot sole",(s*.15,-.062,.045),(.103,.2,.03),M["sole"],"foot."+side)
        rings("Boot shaft",[(.07,.096,.096,0),(.40,.098,.098,0)],M["boots"],"shin."+side) .location=(s*.15,0,0)
        rings("Boot cuff",[(.38,.112,.112,0),(.45,.118,.118,0)],M["boots"],"shin."+side).location=(s*.15,0,0)
        rings("Boot strap",[(.20,.103,.103,0),(.235,.103,.103,0)],M["strap"],"shin."+side).location=(s*.15,0,0)
        a=(s*.28,0,1.43); b=(s*.39,-.015,1.18); c=(s*.41,-.09,.98)
        cloth_limb("Sleeve",a,b,.12,.087,M["sleeve"],"upper_arm."+side)
        cloth_limb("Forearm sleeve",b,c,.090,.068,M["sleeve"],"forearm."+side)
        cloth_limb("Bracer",(s*.40,-.05,1.09),(s*.41,-.085,.995),.083,.075,M["bracer"],"forearm."+side)
        ellipsoid("Hand",(s*.412,-.097,.94),(.074,.055,.095),M["hands"],"forearm."+side)
        ellipsoid("Thumb",(s*.357,-.12,.955),(.028,.033,.055),M["hands"],"forearm."+side)
    rings("Belt",[(.995,.212,.152,0),(1.06,.214,.154,0)],M["belt"],"hips")
    ellipsoid("Belt buckle",(0,-.158,1.028),(.042,.014,.034),M["iron"],"hips",12)

def hair(C, M, female):
    vs, fs=[],[]
    for j in range(10):
        for i in range(32):
            a=2*math.pi*i/32
            front=max(0,-math.sin(a))
            theta=(j/9)*(.55*math.pi-front*.20*math.pi)
            vs.append((.235*math.sin(theta)*math.cos(a), -.005+.218*math.sin(theta)*math.sin(a),1.78+.27*math.cos(theta)))
    for j in range(9):
        for i in range(32):
            a=j*32+i; b=j*32+(i+1)%32
            fs.append((a,b,b+32,a+32))
    from_data("Hair cap",vs,fs,M["hair"],"head")
    style=C["style"]
    for k in range(5 if style != "crop" else 0):
        ellipsoid("Hair lock",(-.13+k*.06,-.06,1.99),(.08,.14,.055),M["hair"],"head",rot=(.15,-.2,0))
    if style=="bob":
        for s in [-1,1]:
            ellipsoid("Long side hair",(s*.20,.03,1.70),(.075,.17,.28),M["hair"],"head")
        ellipsoid("Long back hair",(0,.15,1.66),(.22,.09,.30),M["hair"],"head")
    elif style=="bun":
        ellipsoid("Hair knot",(0,.19,1.95),(.11,.10,.11),M["hair"],"head")
        ellipsoid("Hair cord",(0,.19,1.90),(.09,.08,.022),M["strap"],"head")
    elif style=="quiff":
        for k in range(6):
            ang=math.radians(-150+k*24)
            limb("Unkempt spike",(.14*math.cos(ang)*.6,-.02+.12*math.sin(ang)*.6,1.99),(.20*math.cos(ang),-.05+.16*math.sin(ang),2.05),(.05,.035),M["hair"],"head")

# ------------------------------------------------------------------ costumes

def cloak(M, mat, lining, hem=.45, wide=1.0, ragged=.04, seed=2):
    """Travelling cloak from the shoulders down the back; open at the front so
    the arms swing clear. Lining sits just inside."""
    def prof(k, sc):
        return [(1.585, .17*sc, .13*sc, .02, -60, 240),
                (1.53, .30*sc, .20*sc, .03, -45, 225),
                (1.42, .40*wide*sc, .25*sc, .05, -20, 200),
                (1.20, .43*wide*sc, .26*sc, .10, 8, 172),
                (.85, .43*wide*sc, .27*sc, .15, 16, 164),
                (hem, .45*wide*sc, .29*sc, .20, 18, 162)]
    shell("Cloak", prof(0,1.0), mat, "spine", 44, ragged, .05, 9, seed)
    shell("Cloak lining", prof(0,.965), lining, "spine", 44, ragged, .05, 9, seed)

def mantle(M, mat, bottom=1.27, rx=.47, ry=.33, ragged=0.0, ripple=.03, seed=4, front_gap=0, lining=None):
    a0, a1 = (-90+front_gap, 270-front_gap) if front_gap else (0, 360)
    prof = [(1.58, .155, .125, 0, a0, a1), (1.535, .27, .2, .005, a0, a1),
            (1.43, .40, .28, .01, a0, a1), (bottom, rx, ry, .02, a0, a1)]
    shell("Mantle", prof, mat, "spine", 48, ragged, ripple, 13, seed)
    if lining:
        shell("Mantle lining", [(z,x*.96,y*.96,c,p,q) for z,x,y,c,p,q in prof], lining, "spine", 48, ragged, ripple, 13, seed)

def robe(M, mat, hem=.36, flare=1.0, ragged=0.0, front_gap=0, lining=None, seed=6):
    a0, a1 = (-90+front_gap, 270-front_gap) if front_gap else (0, 360)
    prof = [(1.10, .222, .158, 0, a0, a1), (.98, .245, .175, 0, a0, a1),
            (.70, .32*flare, .25*flare, -.01, a0, a1), (hem, .38*flare, .31*flare, -.01, a0, a1)]
    shell("Robe", prof, mat, "hips", 48, ragged, .035, 10, seed)
    if lining:
        shell("Robe lining", [(z,x*.965,y*.965,c,p,q) for z,x,y,c,p,q in prof], lining, "hips", 48, ragged, .035, 10, seed)
    return prof

def long_torso(M, mat, female):
    """Robe body over the tunic so robes read as one garment."""
    w = .245 if female else .28
    rings("Robe bodice",[(1.02,.215,.152,0),(1.23,w,.163,0),(1.40,w,.168,0),(1.485,.19,.128,0)],mat,"spine")

def sash_tails(mat, x=.10, length=.42, bone="hips"):
    for k,dx in enumerate([0,.05]):
        limb("Sash tail",(x+dx,-.15,1.0),(x+dx+.03,-.19,1.0-length),(.042,.012),mat,bone)

def build_costume(C, M, female):
    i = C["id"]
    acc = M["accent"]
    if i == "rogue":
        hood("Peaked travelling hood", M["hood"], acc, peak=.8, brim=.05, droop=.30, opening=49)
        cloak(M, M["hood"], acc, hem=.42)
        mantle(M, M["hood"], bottom=1.34, rx=.40, ry=.29, ragged=.035, front_gap=34)
        rings("Leather jerkin",[(1.0,.225,.162,0),(1.12,.232,.168,0),(1.30,.286,.172,0),(1.43,.278,.17,0)],M["tunic"],"spine")
        for z in (1.16,1.26,1.36):
            ellipsoid("Jerkin lacing",(0,-.168,z),(.05,.008,.006),M["strap"],"spine",10)
        ellipsoid("Cloak clasp",(0,-.16,1.50),(.045,.02,.045),M["iron"],"spine",12)
        for s in (-1,1):
            ellipsoid("Belt pouch",(s*.17,-.11,.98),(.06,.045,.065),M["strap"],"hips",12)
        ellipsoid("Knife hilt",(-.06,-.16,.99),(.018,.018,.07),M["iron"],"hips",10,rot=(0,.5,0))
    elif i == "shadow":
        hood("Wrapped hood", M["hood"], M["hood"], radii=(.268,.262,.30), opening=46, brim=.02, droop=.18, lip=.95)
        shell("Face scarf",[(1.545,.205,.19,-.01,0,360),(1.62,.235,.235,-.02,0,360),
                            (1.70,.245,.272,-.022,0,360),(1.745,.242,.262,-.018,0,360)],M["hood"],"head",40)
        for z in (1.62,1.70):
            shell("Scarf wrap",[(z,.238,.25 if z<1.66 else .27,-.02,-150,-30),(z+.012,.24,.252 if z<1.66 else .272,-.02,-150,-30)],acc,"head",20)
        limb("Scarf tail",(.06,.21,1.58),(.12,.36,1.26),(.05,.014),M["hood"],"spine")
        limb("Scarf tail",(-.04,.21,1.58),(-.02,.38,1.20),(.045,.013),M["hood"],"spine")
        rings("Wrapped tunic",[(.96,.212,.15,0),(1.25,.24,.158,0),(1.42,.236,.162,0)],M["tunic"],"spine")
        for z in (1.06,1.30):
            shell("Binding",[(z,.243,.168,0,0,360),(z+.022,.243,.168,0,0,360)],acc,"spine",28)
        for side,s in [("L",1),("R",-1)]:
            for z in (.30,.74):
                rings("Leg binding",[(z,.106,.106,0),(z+.02,.106,.106,0)],acc,"shin."+side if z<.57 else "thigh."+side).location=(s*.15,0,0)
        mantle(M, M["hood"], bottom=1.33, rx=.42, ry=.30, ragged=.04, front_gap=30)
    elif i == "pyro":
        hood("Scorched hood", M["hood"], M["void"], opening=44, brim=.05, droop=.28, peak=.4)
        long_torso(M, M["tunic"], True)
        robe(M, M["tunic"], hem=.36, ragged=.05)
        shell("Ember hem",[(.335,.385,.315,-.01,0,360),(.40,.375,.305,-.01,0,360)],acc,"hips",48,.05,.035,10,6)
        mantle(M, M["hood"], bottom=1.30, rx=.43, ry=.31, ragged=.05, front_gap=25)
        shell("Ember mantle edge",[(1.29,.432,.312,.02,-65,245),(1.32,.428,.308,.02,-65,245)],acc,"spine",40)
        for side,s in [("L",1),("R",-1)]:
            cloth_limb("Ember cuff",(s*.405,-.075,1.02),(s*.41,-.09,.985),.078,.072,acc,"forearm."+side)
        rings("Rope belt",[(.99,.25,.18,0),(1.03,.25,.18,0)],M["strap"],"hips")
        limb("Ember charm",(.12,-.17,.98),(.13,-.18,.86),(.025,.025),acc,"hips")
    elif i == "warden":
        iron, brass = M["iron"], acc
        cloak(M, M["hood"], M["hood"], hem=.50, wide=1.08, ragged=.03)
        rings("Breastplate",[(1.06,.235,.17,0),(1.20,.292,.188,-.008),(1.36,.300,.196,-.012),(1.47,.25,.16,0)],iron,"spine",32)
        ellipsoid("Breastplate ridge",(0,-.19,1.28),(.03,.03,.17),iron,"spine",12)
        rings("Brass trim",[(1.455,.255,.165,0),(1.48,.24,.158,0)],brass,"spine",32)
        rings("Gorget",[(1.46,.165,.14,0),(1.57,.135,.125,0)],iron,"spine",28)
        shell("Tassets",[(1.06,.235,.17,0,-170,-10),(.84,.30,.22,-.02,-170,-10)],iron,"hips",24)
        shell("Tasset trim",[(.84,.302,.222,-.02,-170,-10),(.865,.30,.22,-.02,-170,-10)],brass,"hips",24)
        for side,s in [("L",1),("R",-1)]:
            rot=(0,s*.42,0)
            ellipsoid("Pauldron",(s*.33,0,1.50),(.20,.19,.12),iron,"upper_arm."+side,rot=rot)
            ellipsoid("Pauldron lame",(s*.37,0,1.41),(.17,.17,.09),iron,"upper_arm."+side,rot=rot)
            ellipsoid("Pauldron lame",(s*.39,0,1.33),(.15,.15,.07),iron,"upper_arm."+side,rot=rot)
            ellipsoid("Pauldron rim",(s*.355,0,1.455),(.205,.195,.035),brass,"upper_arm."+side,rot=rot)
            ellipsoid("Couter",(s*.39,-.01,1.18),(.08,.08,.07),iron,"forearm."+side,12)
            cloth_limb("Vambrace",(s*.395,-.04,1.13),(s*.41,-.088,.99),.088,.08,iron,"forearm."+side)
            ellipsoid("Poleyn",(s*.15,-.07,.58),(.085,.06,.08),iron,"shin."+side,12)
            rings("Greave",[(.16,.104,.104,0),(.46,.11,.11,-.005)],iron,"shin."+side).location=(s*.15,0,0)
        ellipsoid("Beard",(0,-.17,1.585),(.15,.10,.11),M["hair"],"head")
        ellipsoid("Moustache",(0,-.205,1.655),(.08,.025,.022),M["hair"],"head")
        limb("Brow scar",(.05,-.222,1.86),(.12,-.205,1.70),(.008,.006),M["scar"],"head")
    elif i == "flame":
        long_torso(M, M["sleeve"], False)
        for side_y, a0, a1 in [(-1,-130,-50),(1,50,130)]:
            shell("Tabard",[(1.47,.21,.17,0,a0,a1),(1.0,.235,.172,0,a0,a1),(.62,.255,.205,0,a0,a1)],M["tunic"],"spine" if side_y<0 else "spine",14,.05,0,1,9)
        shell("Tabard edge",[(.64,.257,.207,0,-130,-50),(.66,.256,.206,0,-130,-50)],acc,"spine",14,.05,0,1,9)
        shell("Scorched collar",[(1.47,.20,.16,.01,-60,240),(1.58,.215,.18,.02,-60,240),(1.72,.26,.23,.04,-55,235)],M["sleeve"],"spine",36,.03)
        shell("Collar ember trim",[(1.70,.262,.232,.04,-55,235),(1.73,.262,.232,.04,-55,235)],acc,"spine",36)
        for side,s in [("L",1),("R",-1)]:
            ellipsoid("Scorched pauldron",(s*.31,0,1.49),(.16,.15,.10),M["strap"],"upper_arm."+side,rot=(0,s*.4,0))
            for k in range(3):
                ellipsoid("Ember",(s*(.32+.03*k),-.04+.05*k,1.58-.03*k),(.018,.018,.018),acc,"upper_arm."+side,8)
        ellipsoid("Soot smear",(.08,-.205,1.70),(.06,.012,.035),M["socket"],"head")
    elif i == "rime":
        fur, furdark = M["fur"], M["furdark"]
        hood("Fur hood", fur, furdark, radii=(.31,.30,.33), opening=44, brim=.04, droop=.26)
        for k in range(14):
            pass
        long_torso(M, M["tunic"], True)
        robe(M, M["tunic"], hem=.44, ragged=.0)
        shell("Fur hem",[(.42,.39,.32,-.01,0,360),(.50,.37,.30,-.01,0,360)],fur,"hips",48,.03,.08,23)
        mantle(M, fur, bottom=1.26, rx=.48, ry=.34, ragged=.05, ripple=.07)
        tuft_ring("Fur tuft", 1.275, .47, .335, .02, 44, .036, furdark, "spine")
        for s in (-1,1):
            for k in range(3):
                cone("Ice shard",(s*(.30+.05*k),.02*k,1.48-.02*k),(s*(.36+.08*k),.06+.03*k,1.66-.03*k),.03,acc,"spine",verts=6)
        cone("Ice clasp",(0,-.27,1.47),(0,-.30,1.40),.04,acc,"spine",.04,6)
        ellipsoid("Ice clasp gem",(0,-.29,1.50),(.04,.025,.05),acc,"spine",10)
    elif i == "dancer":
        rings("Wrapped bodice",[(.98,.205,.145,0),(1.22,.238,.155,0),(1.42,.232,.158,0)],M["tunic"],"spine")
        for z in (1.08,1.18,1.28,1.38):
            shell("Wrap band",[(z,.242,.163,0,0,360),(z+.02,.242,.163,0,0,360)],M["sleeve"],"spine",28)
        rings("Jade sash",[(.94,.235,.17,0),(1.06,.24,.172,0)],acc,"hips")
        sash_tails(acc, x=.12, length=.46)
        shell("Short skirt panels",[(1.0,.24,.17,0,-160,-20),(.66,.31,.22,0,-160,-20)],M["sleeve"],"hips",20,.04)
        shell("Short skirt back",[(1.0,.24,.17,0,20,160),(.66,.31,.24,.02,20,160)],M["sleeve"],"hips",20,.04)
        mantle(M, M["sleeve"], bottom=1.36, rx=.37, ry=.27, ragged=.03, front_gap=0)
        for s in (-1,1):
            a=Vector((s*.30,.20,.72)); b=Vector((-s*.32,.27,1.88))
            limb("Scabbard",a,b,(.04,.025),M["strap"],"spine")
            limb("Blade hilt",b-(b-a)*.02,b+(b-a).normalized()*.18,(.022,.022),acc,"spine")
            ellipsoid("Crossguard",b,(.06,.02,.02),M["iron"],"spine",10,rot=(0,0,s*.6))
        for side,s in [("L",1),("R",-1)]:
            for z in (.62,.72,.82):
                rings("Thigh wrap",[(z,.11,.11,0),(z+.025,.11,.11,0)],M["sleeve"],"thigh."+side).location=(s*.14,0,0)
    elif i == "storm":
        long_torso(M, M["tunic"], False)
        robe(M, M["tunic"], hem=.48, front_gap=28, lining=M["strap"], ragged=.03)
        shell("High collar",[(1.48,.20,.16,.02,-50,230),(1.62,.22,.19,.03,-50,230),(1.78,.27,.25,.06,-45,225)],M["tunic"],"spine",36,.02)
        mantle(M, M["tunic"], bottom=1.30, rx=.45, ry=.32, ragged=.04, front_gap=20)
        for s in (-1,1):
            a=(s*.15,.24,1.25); b=(s*.24,.34,2.12)
            limb("Lightning rod",a,b,(.022,.022),M["copper"],"spine")
            for k in (.35,.6,.82):
                p=Vector(a)+(Vector(b)-Vector(a))*k
                ellipsoid("Copper coil",p,(.04,.04,.018),M["copper"],"spine",12)
            ellipsoid("Spark",b,(.035,.035,.035),acc,"spine",10)
        for side,s in [("L",1),("R",-1)]:
            for z in (1.07,1.03,.99):
                pass
            cloth_limb("Rune band",(s*.402,-.06,1.075),(s*.405,-.068,1.05),.088,.086,acc,"forearm."+side)
            cloth_limb("Rune band",(s*.408,-.08,1.02),(s*.41,-.085,1.00),.084,.082,acc,"forearm."+side)
        rings("Chain belt",[(.985,.255,.185,0),(1.01,.255,.185,0)],M["iron"],"hips")
    elif i == "reaper":
        hood("Deep cowl", M["hood"], M["void"], radii=(.33,.32,.325), opening=45, brim=.10, droop=.38, peak=.45, lip=.9)
        long_torso(M, M["tunic"], False)
        robe(M, M["tunic"], hem=.26, flare=1.08, ragged=.08)
        mantle(M, M["hood"], bottom=1.18, rx=.48, ry=.34, ragged=.09, ripple=.05)
        rings("Rope belt",[(.99,.258,.188,0),(1.03,.258,.188,0)],M["strap"],"hips")
        limb("Rope end",(.1,-.18,.99),(.12,-.21,.70),(.02,.02),M["strap"],"hips")
        for s in (-1,1):
            ellipsoid("Hollow cheek",(s*.12,-.16,1.69),(.05,.04,.06),M["socket"],"head")
    elif i == "ravenmark":
        feather, plum = M["feather"], acc
        long_torso(M, M["tunic"], True)
        robe(M, M["tunic"], hem=.42, front_gap=26, lining=plum, ragged=.06)
        mantle(M, feather, bottom=1.32, rx=.44, ry=.31, ripple=.06, lining=plum)
        feather_ring("Mantle feather", 1.45, .30, .21, .01, 22, .20, 1.0, feather, "spine", seed=11)
        feather_ring("Mantle feather", 1.36, .40, .28, .015, 26, .22, .8, feather, "spine", seed=12, width=.055)
        feather_ring("Mantle feather", 1.27, .45, .32, .02, 28, .18, .55, feather, "spine", seed=13, width=.05)
        for k in range(7):
            ang = math.radians(-60+20*k)
            base = Vector((.10*math.sin(ang), .05, 1.98))
            tip = base + Vector((.22*math.sin(ang), .18, .20*math.cos(ang)+.08))
            limb("Crest feather", base, tip, (.04, .016), feather, "head")
        ellipsoid("Crest band",(0,.0,1.93),(.24,.225,.03),plum,"head")
        ellipsoid("Raven skull clasp",(0,-.27,1.44),(.05,.04,.045),M["bone"],"spine",12)
        cone("Raven beak clasp",(0,-.30,1.44),(0,-.36,1.40),.025,M["socket"],"spine",verts=6)
    elif i == "bonewright":
        bone = acc
        rings("Leather apron top",[(1.0,.226,.162,0),(1.30,.284,.172,0),(1.42,.276,.17,0)],M["tunic"],"spine")
        shell("Leather apron",[(1.05,.235,.17,0,-150,-30),(.62,.27,.21,-.01,-150,-30)],M["tunic"],"hips",18,.03)
        for k,z in enumerate((1.18,1.26,1.34)):
            shell("Rib bone",[(z,.29,.18,-.006,-150,-30),(z+.028,.288,.179,-.006,-150,-30)],bone,"spine",20)
        ellipsoid("Sternum bone",(0,-.185,1.27),(.025,.02,.11),bone,"spine",10)
        for side,s in [("L",1),("R",-1)]:
            ellipsoid("Hide pauldron",(s*.31,0,1.48),(.17,.16,.10),M["strap"],"upper_arm."+side,rot=(0,s*.4,0))
            for k in range(3):
                cone("Bone spike",(s*(.30+.05*k),.03-.03*k,1.53),(s*(.40+.07*k),.05-.03*k,1.70-.02*k),.032,bone,"upper_arm."+side,verts=8)
        rings("Tusk crown band",[(1.90,.235,.218,-.005),(1.95,.23,.212,-.005)],M["strap"],"head",28)
        for k in range(9):
            a = math.radians(-90 + (k-4)*28)
            base = Vector((.235*math.cos(a), -.005+.218*math.sin(a), 1.93))
            tip = base + Vector((.06*math.cos(a), .06*math.sin(a), .13 - .02*abs(k-4)))
            cone("Crown tusk", base, tip, .028, bone, "head", verts=8)
        ellipsoid("Belt skull",(.0,-.175,.96),(.06,.05,.065),bone,"hips",14)
        for s in (-1,1):
            ellipsoid("Skull socket",(s*.022,-.222,.97),(.016,.01,.016),M["socket"],"hips",8)
        for k in range(9):
            a = math.radians(-90 + (k-4)*17)
            p = Vector((.17*math.cos(a), .14*math.sin(a), 1.47))
            cone("Tooth necklace", p, p+Vector((0,-.01,-.06)), .016, bone, "spine", verts=6)
        ellipsoid("Stubble",(0,-.16,1.59),(.14,.09,.09),M["hair"],"head")
    elif i == "plague":
        leather = M["mask"]
        long_torso(M, M["tunic"], True)
        robe(M, M["tunic"], hem=.30, flare=1.05, front_gap=24, lining=M["strap"], ragged=.03)
        mantle(M, M["tunic"], bottom=1.30, rx=.44, ry=.31, front_gap=22)
        shell("Leather mask",[(1.62,.232,.22,-.02,-175,-5),(1.75,.236,.235,-.02,-178,-2),(1.88,.226,.215,-.02,-175,-5),(1.94,.20,.19,-.02,-170,-10)],leather,"head",30)
        cone("Plague beak",(0,-.22,1.70),(0,-.55,1.54),.085,leather,"head",verts=14)
        for s in (-1,1):
            ellipsoid("Lens rim",(s*.09,-.235,1.79),(.062,.03,.062),M["iron"],"head",16)
            ellipsoid("Glass lens",(s*.09,-.252,1.79),(.048,.02,.048),acc,"head",16)
        rings("Hat crown",[(1.93,.255,.24,-.005),(2.18,.215,.20,-.005),(2.22,.20,.19,-.005)],leather,"head",32)
        rings("Hat band",[(1.95,.258,.243,-.005),(2.00,.256,.241,-.005)],M["strap"],"head",32)
        ellipsoid("Hat brim",(0,-.01,1.95),(.44,.42,.022),leather,"head",32)
        for k in range(3):
            ellipsoid("Tonic vial",(-.16+.06*k,-.165,1.0),(.022,.022,.05),acc,"hips",10)
    elif i == "starcaller":
        hood("Pointed star hood", M["tunic"], M["void"], opening=42, brim=.07, droop=.32, peak=.5, tall=.5)
        long_torso(M, M["tunic"], False)
        prof = robe(M, M["tunic"], hem=.32, ragged=.03)
        mantle(M, M["tunic"], bottom=1.27, rx=.46, ry=.33, ripple=.04)
        rnd = random.Random(7)
        for k in range(26):
            a = rnd.uniform(-170,-10) if k%3 else rnd.uniform(0,360)
            z = rnd.uniform(.40,.95)
            t = (z-.36)/(.70-.36)
            rx = .38+(.32-.38)*min(1,t); ry=.31+(.25-.31)*min(1,t)
            ar = math.radians(a)
            ellipsoid("Star mote",(rx*1.01*math.cos(ar),-.01+ry*1.01*math.sin(ar),z),(.009,.009,.009),acc,"hips",8)
        for k in range(16):
            ar = math.radians(rnd.uniform(0,360)); z = rnd.uniform(1.30,1.48)
            t=(1.43-z)/(1.43-1.27) if z<1.43 else 0
            rx=.40+(.46-.40)*t; ry=.28+(.33-.28)*t
            ellipsoid("Star mote",(rx*1.02*math.cos(ar),ry*1.02*math.sin(ar)+.01,z+.01),(.009,.009,.009),acc,"spine",8)
        ellipsoid("Star clasp",(0,-.30,1.42),(.04,.02,.04),acc,"spine",10)
        rings("Cord belt",[(.99,.25,.18,0),(1.02,.25,.18,0)],M["strap"],"hips")

HOODED = {"rogue","shadow","pyro","rime","reaper","starcaller"}

def author(C, idx):
    global active_col, pieces
    ident, sex = C["id"], C["sex"]
    female = sex == "woman"
    active_col=bpy.data.collections.new(ident+"_survivor_"+sex)
    bpy.context.scene.collection.children.link(active_col)
    pieces=[]
    acc_hex = C["accent"]
    M = {
        "skin": material(ident+" skin", C["skin"], .62, grime=.15, bump=.04),
        "socket": material(ident+" shadowed socket", shade(C["skin"], .42), .8, grime=0),
        "hair": material(ident+" hair", C["hair"], .85, grime=.2),
        "tunic": material(ident+" tunic", C["tunic"], .9),
        "sleeve": material(ident+" sleeves", C["sleeve"], .9),
        "legs": material(ident+" leggings", C["legs"], .9),
        "boots": material(ident+" worn boots", C["boots"], .62, grime=.4),
        "sole": material(ident+" boot soles", shade(C["boots"], .55), .7, grime=0),
        "strap": material(ident+" leather straps", "3A2C22", .6, grime=.3),
        "belt": material(ident+" belt", "2E241C", .6, grime=.2),
        "iron": material(ident+" tarnished iron", "6A6B6C", .55, grime=.45, metal=.6, bump=.08),
        "bracer": material(ident+" bracers", shade(C["boots"], 1.15), .6, grime=.3),
        "accent": material(ident+" accent", acc_hex, .55, grime=0 if C["glow"] else .2, emit=C["glow"]),
    }
    M["hands"] = M["skin"] if C["hands"] == C["skin"] else (M["accent"] if C["hands"] == acc_hex else material(ident+" gloves", C["hands"], .6, grime=.3))
    if C["eyes"]:
        M["eyewhite"] = material(ident+" lit sclera", shade(C["eyes"], .35), .6, grime=0, emit=.6)
        M["pupil"] = material(ident+" glowing eyes", C["eyes"], .5, grime=0, emit=2.5, bump=0)
    else:
        M["eyewhite"] = material(ident+" eye whites", "A99F92", .5, grime=0)
        M["pupil"] = material(ident+" pupils", "141217", .4, grime=0)
    hood_hex = {"rogue":"40372E","shadow":"16171C","pyro":"231E1C","reaper":"0E0F10",
                "warden":"262729","starcaller":"1D1C2B"}.get(ident, C["tunic"])
    M["hood"] = material(ident+" hood cloth", hood_hex, .92)
    M["void"] = material(ident+" hood shadow", "060607", .95, grime=0)
    M["scar"] = material(ident+" scar", "7A4A40", .6, grime=0)
    M["fur"] = material(ident+" pale fur", "9C9893", .97, grime=.3, sheen=.6)
    M["furdark"] = material(ident+" fur lining", "7C7974", .97, grime=.2)
    M["frost"] = material(ident+" frost", "C9D6DB", .5, grime=0)
    M["feather"] = material(ident+" raven feathers", "121116", .45, grime=.2, sheen=.4)
    M["bone"] = material(ident+" bone", "D8CBA8", .7, grime=.3)
    M["copper"] = material(ident+" verdigris copper", "7A5135", .45, grime=.4, metal=.8)
    M["mask"] = material(ident+" waxed leather", "3A3127", .68, grime=.4)
    if ident == "warden":
        M["iron"] = material(ident+" plate", "75777A", .55, grime=.5, metal=.6, bump=.08)
    rig=make_rig(ident)
    body(C, M, female, ident in HOODED)
    build_costume(C, M, female)
    # Join weighted pieces into one editable skin, retaining named material slots.
    bpy.ops.object.select_all(action="DESELECT")
    for ob in pieces: ob.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0]
    bpy.ops.object.join()
    mesh=bpy.context.object
    mesh.name=ident+"_Survivor_"+sex
    mod=mesh.modifiers.new("Survivor skeletal animation","ARMATURE"); mod.object=rig
    mesh.parent=rig
    rig["body"] = sex
    rig["outfit"] = C["outfit"]
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
    return {"id":ident,"rig":rig,"mesh":mesh,"collection":active_col,"sex":sex,
            "outfit":C["outfit"],"look":C["look"],"accent":"#"+acc_hex}

characters=[author(r,i) for i,r in enumerate(ROSTER)]
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.view_settings.view_transform="Standard"
scene.view_settings.look="Medium High Contrast" if "Medium High Contrast" in [i.identifier for i in scene.view_settings.bl_rna.properties['look'].enum_items] else "None"
scene.view_settings.exposure=0
# Low ambient so the key/rim lights carve the silhouette.
scene.world.color=(.06,.065,.08)
scene.render.fps=44
scene.frame_start=1; scene.frame_end=24
scene.render.resolution_percentage=100

bpy.ops.object.camera_add()
camera=bpy.context.object; camera.name="Survivor render camera"
camera.data.type="ORTHO"; scene.camera=camera
lights=[]
# Strong warm key from front-left above, weak cool fill, and two cold rims from
# behind that outline hoods, shoulders and cloaks against the dark ground.
for name,loc,power,size,color in [
        ("Warm key",(-3.2,-3.6,6.5),1100,2.5,(1.0,.88,.74)),
        ("Cool fill",(4,-2,3.5),140,3,(.62,.72,.95)),
        ("Cold rim left",(-3.5,4.2,4.2),1500,1.8,(.62,.76,1.0)),
        ("Cold rim right",(3.8,4.0,3.6),1100,1.8,(.62,.76,1.0))]:
    bpy.ops.object.light_add(type="AREA",location=loc)
    ob=bpy.context.object; ob.name=name; ob.data.energy=power; ob.data.shape="DISK"; ob.data.size=size
    ob.data.color=color
    lights.append((ob,Vector(loc)))

def setup(char, portrait=False, hero=False):
    x=char["rig"].location.x
    for c in characters: c["collection"].hide_render=c is not char
    target=Vector((x,0,1.03 if not portrait else 1.47))
    camera.location=target+Vector((.0,-6,10) if not (portrait or hero) else (2.4,-7,3.2))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=2.05 if not portrait else 1.25
    if hero: camera.data.ortho_scale=2.45
    res=256 if not (portrait or hero) else (512 if portrait else 640)
    scene.render.resolution_x=res; scene.render.resolution_y=res
    for ob,loc in lights:
        ob.location=loc+Vector((x,0,0))
        ob.rotation_euler=(Vector((x,0,1.2))-ob.location).to_track_quat("-Z","Y").to_euler()

def render(path):
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)

done=0
for i,char in enumerate(characters):
    if ONLY and char["id"] not in ONLY: continue
    if PREVIEW and not ONLY and i>1: break
    d=RAW/char["id"]; d.mkdir(exist_ok=True)
    setup(char,portrait=True); scene.frame_set(0); render(d/"portrait.png")
    if PORTRAITS:
        print("PORTRAIT COMPLETE",char["id"],flush=True)
        continue
    setup(char,hero=True); scene.frame_set(0); render(d/"hero.png")
    setup(char); scene.frame_set(0); render(d/"idle.png")
    for frame in ([5] if PREVIEW else [1,5,9,13,17,21]):
        scene.frame_set(frame); render(d/("walk_%02d.png"%frame))
    print("SURVIVOR COMPLETE",char["id"],flush=True)
    done+=1

if PREVIEW or ONLY or PORTRAITS:
    sys.exit(0)
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
          "style":"Grim dark-fantasy survivors: muted ash, leather, iron and bone palettes with one accent colour per class.",
          "characters":[{"id":c["id"],"body":c["sex"],"outfit":c["outfit"],"look":c["look"],
                         "accent":c["accent"],"height":HEIGHTS[c["id"]]} for c in characters]}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
