"""Author and render the summonable companions with Blender (no external assets).

blender --background --factory-startup --python tools/build_companions.py
blender --background --factory-startup --python tools/build_companions.py -- --only hound
blender --background --factory-startup --python tools/build_companions.py -- --preview
Assemble the final PNGs with tools/pack_companions.py after rendering.

Companions are spectral allies: dark bodies with a cold emissive accent per
companion plus a faint accent-coloured Fresnel rim, so they read as ghostly but
stay solid against the dark ground. Geometry helpers, camera, lights and the
24-frame loop (frames 1, 5, 9, 13, 17, 21 exported) mirror
tools/build_civilians.py so the companions sit in the same visual family.
`--preview` renders the portrait and walk frame 5 only.
"""
import bpy
import math
import random
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "companions"
RAW = OUT / "renders"
ARGS = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGS
ONLY = ARGS[ARGS.index("--only")+1].split(",") if "--only" in ARGS else None
SAMPLES = int(ARGS[ARGS.index("--samples")+1]) if "--samples" in ARGS else 32
OUT.mkdir(parents=True, exist_ok=True)
RAW.mkdir(parents=True, exist_ok=True)

FRAMES = [1, 5, 9, 13, 17, 21]

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for col in list(bpy.data.collections):
    bpy.data.collections.remove(col)

# ------------------------------------------------------------------ helpers
# (copied from tools/build_civilians.py, plus a spectral Fresnel rim option)

def srgb(hexcode):
    rgb = tuple(int(hexcode[i:i+2], 16) / 255 for i in (0, 2, 4))
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb)

def material(name, hexcode, roughness=0.8, grime=0.35, metal=0.0, emit=0.0,
             sheen=0.0, bump=0.18, rim=None, rim_strength=0.0):
    """Principled material with noise grime. `rim` (hex) adds a cold
    accent-coloured emissive Fresnel edge: the spectral outline."""
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
        # Dim base so the key light cannot wash a glow out to white.
        bs.inputs["Base Color"].default_value = (*(v*.25 for v in rgb), 1)
    elif rim and rim_strength > 0:
        bs.inputs["Emission Color"].default_value = (*srgb(rim), 1)
        lw = nt.nodes.new("ShaderNodeLayerWeight")
        lw.inputs["Blend"].default_value = .45
        pw = nt.nodes.new("ShaderNodeMath"); pw.operation = "POWER"
        pw.inputs[1].default_value = 2.2
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = rim_strength
        nt.links.new(lw.outputs["Facing"], pw.inputs[0])
        nt.links.new(pw.outputs[0], mul.inputs[0])
        nt.links.new(mul.outputs[0], bs.inputs["Emission Strength"])
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
        grit = nt.nodes.new("ShaderNodeTexNoise")
        grit.inputs["Scale"].default_value = 70.0
        grit.inputs["Detail"].default_value = 8.0
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        nt.links.new(grit.outputs["Fac"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
    return m

active_col = None
pieces = []

def finish(ob, name, mat, bone):
    ob.name = name
    for col in list(ob.users_collection):
        col.objects.unlink(ob)
    active_col.objects.link(ob)
    ob.data.materials.append(mat)
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
    mesh.from_pydata([tuple(v) for v in vs], [], fs)
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
            b = j*sides+(i+1) % sides
            fs.append((a, b, b+sides, a+sides))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple((len(profile)-1)*sides+i for i in range(sides)))
    return from_data(name, vs, fs, mat, bone)

def shell(name, profile, mat, bone, sides=40, ragged=0.0, ripple=0.0, freq=11, seed=1):
    """Open cloth surface. rows: (z, rx, ry, cy, a0deg, a1deg); -90 is front."""
    rnd = random.Random(seed)
    closed = all(r[5]-r[4] >= 360 for r in profile)
    n = sides if closed else sides+1
    vs, fs = [], []
    last = len(profile)-1
    for j, (z, rx, ry, cy, a0, a1) in enumerate(profile):
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
            b = j*n+(i+1) % n
            fs.append((a, b, b+n, a+n))
    return from_data(name, vs, fs, mat, bone)

def limb(name, a, b, radii, mat, bone, segments=16):
    mid = (Vector(a)+Vector(b))/2
    ob = ellipsoid(name, mid, (radii[0], radii[1], (Vector(b)-Vector(a)).length*.60), mat, bone, segments)
    ob.rotation_euler = (Vector(b)-Vector(a)).to_track_quat("Z", "Y").to_euler()
    return ob

def cone(name, a, b, r1, mat, bone, r2=0.0, verts=10):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=(b-a).length, location=(a+b)/2)
    ob = bpy.context.object
    ob.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    return finish(ob, name, mat, bone)

def cloth_limb(name, a, b, radius_a, radius_b, mat, bone):
    length = (Vector(b)-Vector(a)).length
    ob = rings(name, [(-.025, radius_a*.8, radius_a*.8, 0), (.015, radius_a, radius_a, 0),
                      (length-.015, radius_b, radius_b, 0), (length+.01, radius_b*.92, radius_b*.92, 0)], mat, bone, 20)
    ob.location = a
    ob.rotation_euler = (Vector(b)-Vector(a)).to_track_quat("Z", "Y").to_euler()
    return ob

def tube(name, pts, radius, mat, bone, sides=8):
    """Swept tube along a polyline; radius is a float or one value per point."""
    pts = [Vector(p) for p in pts]
    rad = radius if isinstance(radius, (list, tuple)) else [radius]*len(pts)
    vs, fs = [], []
    for i, p in enumerate(pts):
        t = (pts[min(i+1, len(pts)-1)] - pts[max(i-1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < .9 else Vector((1, 0, 0))
        n1 = t.cross(ref).normalized(); n2 = t.cross(n1).normalized()
        for k in range(sides):
            a = 2*math.pi*k/sides
            vs.append(p + (n1*math.cos(a) + n2*math.sin(a))*rad[i])
    for i in range(len(pts)-1):
        for k in range(sides):
            a = i*sides+k; b = i*sides+(k+1) % sides
            fs.append((a, b, b+sides, a+sides))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple((len(pts)-1)*sides+k for k in range(sides)))
    return from_data(name, vs, fs, mat, bone)

def hood(name, mat, lining, center=(0, .0, 1.77), radii=(.300, .295, .305), opening=46,
         droop=.30, brim=.05, peak=0.0, tall=0.0, sides=36, rows=16, lip=.92, ragged=0.0, seed=8):
    """Cowl from tools/build_civilians.py; `ragged` tears the back/lower edge."""
    rnd = random.Random(seed)
    c = Vector(center)
    f = Vector((0, -1, -droop)).normalized()
    up = (Vector((0, 0, 1)) - f*f.z).normalized()
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
            a = j*sides+i; b = j*sides+(i+1) % sides
            fs.append((a, b, b+sides, a+sides))
    pole = len(vs); vs.append(point(math.pi, 0))
    base = len(thetas)*sides
    for i in range(sides):
        fs.append((base+i, base+(i+1) % sides, pole))
    ob = from_data(name, vs, fs, mat, "head")
    lv = []
    lt = [math.radians(opening + 34*k/5) for k in range(6)]
    for t in lt:
        for i in range(sides):
            lv.append(point(t, 2*math.pi*i/sides, .955))
    lf = []
    for j in range(len(lt)-1):
        for i in range(sides):
            a = j*sides+i; b = j*sides+(i+1) % sides
            lf.append((a, b, b+sides, a+sides))
    from_data(name+" lining", lv, lf, lining, "head")
    if ragged:
        # Torn strips hanging from the hood's lower rim onto the shoulders.
        for k in range(9):
            psi = math.radians(200 + 140*k/8 + rnd.uniform(-6, 6))
            top = point(math.radians(95), psi)
            out = Vector((top.x-c.x, top.y-c.y, 0)).normalized()
            tip = top + out*.05 + Vector((0, 0, -ragged*(.7+.6*rnd.random())))
            limb(name+" tatter", top, tip, (.05, .018), mat, "spine")
    return ob

def cloak(mat, lining, k=1.0, hem=.45, wide=1.0, ragged=.04, seed=2, ripple=.05):
    """Back cloak (from build_civilians), heights scaled by k."""
    def prof(sc):
        return [(1.585*k, .17*sc*wide, .13*sc, .02, -60, 240),
                (1.53*k, .30*sc*wide, .20*sc, .03, -45, 225),
                (1.42*k, .40*wide*sc, .25*sc, .05, -20, 200),
                (1.20*k, .43*wide*sc, .26*sc, .10, 8, 172),
                (.85*k, .43*wide*sc, .27*sc, .15, 16, 164),
                (hem, .45*wide*sc, .29*sc, .20, 18, 162)]
    shell("Cloak", prof(1.0), mat, "spine", 44, ragged, ripple, 9, seed)
    shell("Cloak lining", prof(.965), lining, "spine", 44, ragged, ripple, 9, seed)

def mantle(mat, k=1.0, bottom=1.27, rx=.47, ry=.33, ragged=0.0, ripple=.03, seed=4, front_gap=0, top=.155):
    a0, a1 = (-90+front_gap, 270-front_gap) if front_gap else (0, 360)
    prof = [(1.58*k, top, top*.8, 0, a0, a1), (1.535*k, .27*rx/.47, .2*ry/.33, .005, a0, a1),
            (1.43*k, .40*rx/.47, .28*ry/.33, .01, a0, a1), (bottom, rx, ry, .02, a0, a1)]
    shell("Mantle", prof, mat, "spine", 48, ragged, ripple, 13, seed)

# ------------------------------------------------------------------ rigs

def new_rig(name):
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
        v = eb.new(n); v.head = a; v.tail = b; v.roll = 0
        if parent: v.parent = eb[parent]
    return rig, bone

def end_rig(rig):
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    return rig

# Survivor biped joints (tools/build_civilians.py make_rig).
SURVIVOR_J = dict(hip_z=1.0, neck_z=1.49, head_top=1.99, hip_x=.135, knee=(.15, .57), ankle=.15,
                  shoulder=(.28, 0, 1.46), elbow=(.39, -.015, 1.18), wrist=(.41, -.09, .98))

def biped_rig(name, J):
    rig, bone = new_rig(name)
    hz, nz = J["hip_z"], J["neck_z"]
    bone("hips", (0, 0, hz), (0, 0, hz+.15))
    bone("spine", (0, 0, hz+.15), (0, 0, nz), "hips")
    bone("head", (0, 0, nz), (0, 0, J["head_top"]), "spine")
    kx, kz = J["knee"]; az = J["ankle"]
    sx, sy, sz = J["shoulder"]; ex, ey, ez = J["elbow"]; wx, wy, wz = J["wrist"]
    for side, s in [("L", 1), ("R", -1)]:
        bone("thigh."+side, (s*J["hip_x"], 0, hz+.01), (s*kx, 0, kz), "hips")
        bone("shin."+side, (s*kx, 0, kz), (s*kx, 0, az), "thigh."+side)
        bone("foot."+side, (s*kx, 0, az), (s*kx, -.19, .09), "shin."+side)
        bone("upper_arm."+side, (s*sx, sy, sz), (s*ex, ey, ez), "spine")
        bone("forearm."+side, (s*ex, ey, ez), (s*wx, wy, wz), "upper_arm."+side)
    return end_rig(rig)

def key_all(rig, f):
    for pb in rig.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=f)
        pb.keyframe_insert("location", frame=f)

def reset_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)

def biped_walk(rig, stride=.31, knee=.36, arm=(.30, .30), bob=.018, sway=.045, roll=0.0, forearm=.08):
    """Survivor walk cycle (frame 0 neutral, 1-25 loop), with per-arm swing."""
    for f in range(26):
        t = 2*math.pi*(f-1)/24
        reset_pose(rig)
        if f:
            rig.pose.bones["hips"].location.y = bob*(1-math.cos(2*t))
            rig.pose.bones["hips"].rotation_euler.y = roll*math.sin(t)
            rig.pose.bones["spine"].rotation_euler.y = sway*math.sin(t)
            for (side, s), amp in zip([("L", 1), ("R", -1)], arm):
                phase = math.sin(t)*s
                rig.pose.bones["thigh."+side].rotation_euler.x = stride*phase
                rig.pose.bones["shin."+side].rotation_euler.x = -knee*max(0, -math.cos(t)*s)
                rig.pose.bones["upper_arm."+side].rotation_euler.x = -amp*phase
                rig.pose.bones["forearm."+side].rotation_euler.x = -forearm*(amp/.30)*(1+max(0, phase))
        key_all(rig, f)

# ------------------------------------------------------------------ hound

def build_hound(M):
    hide, dark, rib, bone, glow, void = M["hide"], M["hidedark"], M["rib"], M["bone"], M["glow"], M["void"]
    rig, bone_ = new_rig("hound")
    bone_("root", (0, 0, 0), (0, 0, .3))
    bone_("hips", (0, .45, .82), (0, .05, .84), "root")
    bone_("chest", (0, .05, .84), (0, -.45, .90), "hips")
    bone_("neck", (0, -.45, .90), (0, -.76, 1.06), "chest")
    bone_("head", (0, -.76, 1.06), (0, -1.15, 1.0), "neck")
    bone_("tail", (0, .56, .88), (0, .95, .62), "hips")
    for side, s in [("L", 1), ("R", -1)]:
        x = s*.14
        bone_("fl_up."+side, (x, -.40, .82), (x, -.36, .46), "chest")
        bone_("fl_low."+side, (x, -.36, .46), (x, -.40, .11), "fl_up."+side)
        bone_("fl_paw."+side, (x, -.40, .11), (x, -.50, .04), "fl_low."+side)
        bone_("bl_up."+side, (x, .44, .80), (x, .30, .48), "hips")
        bone_("bl_low."+side, (x, .30, .48), (x, .50, .24), "bl_up."+side)
        bone_("bl_paw."+side, (x, .50, .24), (x, .46, .05), "bl_low."+side)
    end_rig(rig)

    # Gaunt deep chest, tucked waist, bony haunches.
    ellipsoid("Chest", (0, -.30, .80), (.150, .30, .22), dark, "chest")
    ellipsoid("Chest keel", (0, -.34, .66), (.105, .22, .15), hide, "chest")
    limb("Tucked waist", (0, -.06, .87), (0, .34, .84), (.085, .075), hide, "hips")
    ellipsoid("Pelvis", (0, .40, .84), (.125, .19, .12), hide, "hips")
    for s in (-1, 1):
        ellipsoid("Hip bone", (s*.095, .36, .935), (.04, .06, .035), rib, "hips", 12)
    # Ribs showing: thin bony arcs standing proud of the dark chest.
    for k in range(6):
        y = -.53 + k*.068
        rx = .168 - .01*abs(k-2); rz = .235 - .016*abs(k-2)
        for s in (-1, 1):
            pts = []
            for j in range(10):
                a = math.radians(80 - 130*j/9)
                pts.append((s*rx*math.cos(a)*1.02, y + .035*j/9, .80 + rz*math.sin(a)))
            tube("Rib", pts, [.012]+[.017]*8+[.009], rib, "chest", 6)
    # Spine ridge with smouldering spectral embers between the vertebrae.
    spine = [(-.62, 1.03), (-.50, 1.045), (-.38, 1.05), (-.26, 1.045), (-.14, 1.0), (-.02, .955),
             (.10, .935), (.22, .94), (.34, .955), (.46, .955), (.56, .93)]
    for n, (y, z) in enumerate(spine):
        b = "chest" if y < .04 else "hips"
        ellipsoid("Vertebra", (0, y, z), (.032, .036, .03), rib, b, 10)
        cone("Spinous process", (0, y, z+.01), (0, y+.035, z+.07), .02, rib, b, verts=6)
        if n < len(spine)-1:
            y2, z2 = spine[n+1]
            p = Vector((0, (y+y2)/2, (z+z2)/2+.005))
            ellipsoid("Spine ember", p, (.024, .03, .018), glow, b, 10)
            if n % 2 == 0:
                cone("Ember wisp", p, p+Vector((.012*(-1)**(n//2), .05, .085)), .016, glow, b, verts=6)
    # Neck with a ragged ridge of fur.
    limb("Neck", (0, -.48, .90), (0, -.80, 1.07), (.085, .10), hide, "neck")
    rnd = random.Random(21)
    for k in range(6):
        y = -.50 - k*.055; z = 1.0 + k*.02
        cone("Neck tuft", (0, y, z), (rnd.uniform(-.03, .03), y+.09, z+.10+rnd.uniform(0, .04)), .035, dark, "neck", verts=5)
    # Ragged hackles flaring over the shoulders widen the top-down silhouette.
    for k in range(5):
        for s in (-1, 1):
            p = Vector((s*.10, -.52+k*.07, 1.0-k*.012))
            cone("Hackle", p, p+Vector((s*(.10+.02*(k % 2)), .08, -.02+.03*(k % 2))), .03, dark, "chest", verts=5)
    # Skull-like head: narrow cranium, long snout, open jaw, deep sockets.
    ellipsoid("Cranium", (0, -.82, 1.11), (.112, .17, .095), hide, "head")
    ellipsoid("Skull crest", (0, -.80, 1.19), (.025, .12, .03), rib, "head", 10)
    tube("Snout", [(0, -.90, 1.10), (0, -1.02, 1.065), (0, -1.12, 1.03), (0, -1.19, 1.0)],
         [.07, .058, .045, .03], hide, "head", 10)
    ellipsoid("Snout bridge", (0, -1.03, 1.10), (.03, .12, .02), rib, "head", 10, rot=(-.3, 0, 0))
    ellipsoid("Nose", (0, -1.19, 1.01), (.03, .028, .024), void, "head", 12)
    tube("Lower jaw", [(0, -.88, 1.00), (0, -1.02, .96), (0, -1.13, .93)], [.045, .036, .022], dark, "head", 8)
    ellipsoid("Mouth", (0, -1.0, .985), (.04, .11, .02), void, "head", 12)
    for k in range(4):
        y = -.98 - k*.045
        for s in (-1, 1):
            cone("Fang", (s*.032, y, 1.02-k*.016), (s*.03, y, .955-k*.016), .012, bone, "head", verts=5)
    for s in (-1, 1):
        # Heavy angled brow over narrow slit eyes: a scowl, not a stare.
        ellipsoid("Brow", (s*.06, -.955, 1.155), (.06, .03, .018), rib, "head", 12, rot=(0, -s*.45, 0))
        ellipsoid("Socket", (s*.064, -.96, 1.122), (.045, .03, .026), void, "head", 12, rot=(0, -s*.3, 0))
        ellipsoid("Glowing eye", (s*.066, -.978, 1.124), (.034, .014, .014), glow, "head", 12, rot=(0, -s*.3, 0))
        ellipsoid("Cheek bone", (s*.085, -.90, 1.06), (.035, .07, .028), rib, "head", 10)
        # Ragged ears: torn cones with a notched second tip.
        base = Vector((s*.085, -.79, 1.19))
        cone("Ear", base, base+Vector((s*.11, .10, .16)), .05, dark, "head", verts=6)
        cone("Torn ear tip", base+Vector((s*.025, .03, .06)), base+Vector((s*.15, .05, .17)), .028, dark, "head", verts=5)
    # Legs.
    for side, s in [("L", 1), ("R", -1)]:
        x = s*.14
        ellipsoid("Shoulder blade", (s*.12, -.38, .90), (.055, .12, .13), hide, "chest", 14)
        tube("Foreleg", [(x, -.40, .86), (x, -.39, .70), (x, -.36, .47)], [.075, .06, .04], hide, "fl_up."+side, 10)
        ellipsoid("Elbow", (x, -.33, .48), (.038, .045, .04), rib, "fl_up."+side, 10)
        tube("Fore shin", [(x, -.36, .47), (x, -.385, .25), (x, -.41, .09)], [.036, .03, .033], dark, "fl_low."+side, 8)
        ellipsoid("Fore paw", (x, -.47, .045), (.05, .075, .04), dark, "fl_paw."+side, 12)
        ellipsoid("Haunch", (x, .40, .74), (.07, .15, .14), hide, "bl_up."+side, 14)
        tube("Thigh", [(x, .44, .80), (x, .37, .62), (x, .30, .48)], [.07, .065, .04], hide, "bl_up."+side, 10)
        tube("Hind shin", [(x, .30, .48), (x, .40, .36), (x, .50, .24)], [.04, .032, .03], dark, "bl_low."+side, 8)
        ellipsoid("Hock", (x, .505, .24), (.032, .04, .035), rib, "bl_low."+side, 10)
        tube("Hind foot", [(x, .50, .24), (x, .46, .06)], [.03, .028], dark, "bl_paw."+side, 8)
        ellipsoid("Hind paw", (x, .42, .04), (.048, .07, .038), dark, "bl_paw."+side, 12)
        for c in (-1, 0, 1):
            for py, b in ((-.53, "fl_paw."+side), (.36, "bl_paw."+side)):
                cone("Claw", (x+c*.025, py, .04), (x+c*.03, py-.04, .01), .011, bone, b, verts=5)
    # Ragged thin tail.
    tail = [(0, .56, .89), (0, .66, .87), (0, .74, .78), (0, .79, .66), (0, .80, .54)]
    tube("Tail", tail, [.045, .038, .03, .022, .01], dark, "tail", 8)
    for k in range(4):
        p = Vector(tail[k+1])
        cone("Tail tatter", p, p+Vector((.04*(-1)**k, .06, -.06)), .02, dark, "tail", verts=4)
    return rig

def hound_trot(rig):
    """Two-beat trot: diagonal pairs (FL+BR, FR+BL) swing together."""
    for f in range(26):
        t = 2*math.pi*(f-1)/24
        reset_pose(rig)
        if f:
            rig.pose.bones["root"].location.y = .03*(1-math.cos(2*t))*.5
            rig.pose.bones["chest"].rotation_euler.x = .03*math.sin(2*t)
            rig.pose.bones["head"].rotation_euler.x = -.07*math.sin(2*t+.6)
            rig.pose.bones["tail"].rotation_euler.z = .25*math.sin(t)
            rig.pose.bones["tail"].rotation_euler.x = .08*math.cos(2*t)
            for side, s in [("L", 1), ("R", -1)]:
                front = math.sin(t)*s          # FL with BR
                back = -math.sin(t)*s
                lift_f = max(0, math.cos(t)*s)
                lift_b = max(0, -math.cos(t)*s)
                rig.pose.bones["fl_up."+side].rotation_euler.x = .45*front
                rig.pose.bones["fl_low."+side].rotation_euler.x = -.85*lift_f
                rig.pose.bones["fl_paw."+side].rotation_euler.x = -.5*lift_f
                rig.pose.bones["bl_up."+side].rotation_euler.x = .40*back
                rig.pose.bones["bl_low."+side].rotation_euler.x = .55*lift_b
                rig.pose.bones["bl_paw."+side].rotation_euler.x = -.35*lift_b
        key_all(rig, f)

# ------------------------------------------------------------------ archer

def build_archer(M):
    J = SURVIVOR_J
    rig = biped_rig("archer", J)
    bone, dark, cloth, void, glow, wood, leather = M["bone"], M["bonedark"], M["cloth"], M["void"], M["glow"], M["wood"], M["leather"]
    # Pelvis and spine.
    ellipsoid("Pelvis", (0, .0, 1.0), (.15, .095, .07), bone, "hips")
    for s in (-1, 1):
        ellipsoid("Iliac wing", (s*.115, .01, 1.05), (.065, .065, .06), bone, "hips", 12, rot=(0, s*.4, 0))
    for z in (1.08, 1.14, 1.20, 1.26, 1.32, 1.38, 1.44):
        ellipsoid("Vertebra", (0, .07, z), (.04, .035, .026), dark, "spine" if z > 1.15 else "hips", 10)
    # Hollow ribcage around a dark core with a cold spectral heart.
    ellipsoid("Hollow", (0, .0, 1.31), (.15, .105, .15), void, "spine")
    ellipsoid("Spectral heart", (0, -.03, 1.30), (.055, .045, .065), glow, "spine", 14)
    for k, z in enumerate((1.20, 1.26, 1.32, 1.38, 1.44)):
        rx = (.18, .2, .205, .2, .175)[k]; ry = .145
        pts = []
        for j in range(15):
            a = math.radians(102 + 336*j/14)
            pts.append((rx*math.cos(a), .0+ry*math.sin(a), z + .045*math.sin(a)))
        tube("Rib", pts, .02, bone, "spine", 7)
    ellipsoid("Sternum", (0, -.16, 1.33), (.03, .02, .1), bone, "spine", 10)
    ellipsoid("Spine core", (0, .09, 1.30), (.035, .03, .2), dark, "spine", 10)
    for s in (-1, 1):
        limb("Collarbone", (s*.03, -.09, 1.47), (s*.27, -.01, 1.47), (.024, .024), bone, "spine", 10)
    # Skull: cranium, cheekbones, deep sockets with pale-blue fire.
    for z in (1.51, 1.565):
        ellipsoid("Neck vertebra", (0, .02, z), (.045, .04, .028), dark, "head", 10)
    ellipsoid("Cranium", (0, .01, 1.80), (.20, .21, .195), bone, "head")
    ellipsoid("Face", (0, -.07, 1.70), (.16, .145, .125), bone, "head")
    ellipsoid("Brow ridge", (0, -.175, 1.815), (.165, .045, .032), bone, "head")
    ellipsoid("Jaw", (0, -.09, 1.60), (.115, .10, .045), dark, "head")
    ellipsoid("Teeth", (0, -.185, 1.635), (.075, .014, .024), bone, "head", 14)
    ellipsoid("Nasal cavity", (0, -.205, 1.69), (.025, .012, .032), void, "head", 10)
    for s in (-1, 1):
        ellipsoid("Cheekbone", (s*.115, -.135, 1.695), (.05, .045, .032), bone, "head", 12)
        ellipsoid("Eye socket", (s*.075, -.17, 1.755), (.06, .04, .052), void, "head", 14)
        ellipsoid("Socket flame", (s*.075, -.205, 1.752), (.034, .012, .03), glow, "head", 12)
    hood("Tattered hood", M["hood"], void, center=(0, 0, 1.77), radii=(.29, .285, .30),
         opening=48, droop=.24, brim=.04, peak=.6, ragged=.16)
    mantle(M["hood"], bottom=1.29, rx=.43, ry=.31, ragged=.09, ripple=.06, front_gap=32)
    cloak(M["hood"], M["hood"], hem=.42, ragged=.13, seed=5)
    # Tattered loincloth and belt.
    rings("Rope belt", [(1.0, .19, .13, 0), (1.04, .19, .13, 0)], leather, "hips")
    shell("Loincloth front", [(1.04, .19, .135, 0, -140, -40), (.66, .21, .16, -.01, -140, -40)], cloth, "hips", 14, .10, 0, 1, 3)
    shell("Loincloth back", [(1.04, .19, .135, 0, 40, 140), (.62, .22, .18, .02, 40, 140)], cloth, "hips", 14, .10, 0, 1, 4)
    kx, kz = J["knee"]
    for side, s in [("L", 1), ("R", -1)]:
        limb("Femur", (s*.135, 0, 1.0), (s*kx, 0, kz), (.048, .048), bone, "thigh."+side, 12)
        ellipsoid("Knee", (s*kx, -.02, kz), (.06, .055, .055), bone, "thigh."+side, 12)
        limb("Shin bone", (s*kx, 0, kz), (s*kx, 0, .14), (.04, .04), bone, "shin."+side, 12)
        cloth_limb("Shin wrap", (s*kx, 0, .18), (s*kx, 0, .44), .07, .066, cloth, "shin."+side)
        ellipsoid("Bony foot", (s*kx, -.07, .07), (.06, .15, .045), bone, "foot."+side, 14)
        ellipsoid("Heel", (s*kx, .02, .08), (.045, .045, .045), dark, "foot."+side, 10)
        sx, sy, sz = J["shoulder"]; ex, ey, ez = J["elbow"]; wx, wy, wz = J["wrist"]
        ellipsoid("Shoulder joint", (s*sx, sy, sz-.02), (.07, .07, .065), bone, "upper_arm."+side, 12)
        limb("Humerus", (s*sx, sy, sz), (s*ex, ey, ez), (.043, .043), bone, "upper_arm."+side, 12)
        ellipsoid("Elbow", (s*ex, ey, ez), (.052, .05, .05), dark, "forearm."+side, 10)
        limb("Forearm bones", (s*ex, ey, ez), (s*wx, wy, wz), (.042, .036), bone, "forearm."+side, 12)
        ellipsoid("Bony hand", (s*.412, -.10, .93), (.05, .04, .065), bone, "forearm."+side, 12)
        for c in (-1, 0, 1):
            cone("Finger", (s*.412+c*.022, -.11, .90), (s*.412+c*.026, -.13, .83), .013, dark, "forearm."+side, verts=5)
    cloth_limb("Bracer", (.40, -.05, 1.10), (.41, -.085, .995), .06, .056, leather, "forearm.L")
    # Quiver of spectral-fletched arrows on the back.
    q0, q1 = Vector((.12, .24, 1.0)), Vector((-.10, .28, 1.60))
    limb("Quiver", q0, q1, (.072, .06), leather, "spine")
    for k in range(4):
        b = q1 + Vector((.03*k-.04, .01*k, -.02))
        tip = b + (q1-q0).normalized()*.16 + Vector((.015*k, 0, 0))
        limb("Arrow shaft", b, tip, (.012, .012), wood, "spine", 8)
        limb("Spectral fletching", tip-(q1-q0).normalized()*.05, tip, (.024, .01), M["glowsoft"], "spine", 8)
    # Longbow in the left hand, string glowing pale blue.
    grip = Vector((.43, -.11, .94))
    bow = []
    for j in range(15):
        u = -1 + 2*j/14
        bow.append(grip + Vector((.03*u*u, .17*u*u - .03*max(0, abs(u)-.8)/.2, .70*u)))
    tube("Longbow", bow, [.014+.016*(1-abs(-1+2*j/14)) for j in range(15)], wood, "forearm.L", 8)
    ellipsoid("Bow grip wrap", grip, (.034, .034, .07), leather, "forearm.L", 12)
    tube("Glowing bowstring", [bow[0], bow[-1]], .014, glow, "forearm.L", 6)
    for p in (bow[0], bow[-1]):
        ellipsoid("String nock glow", p, (.024, .024, .024), glow, "forearm.L", 10)
    return rig

# ------------------------------------------------------------------ knight

KNIGHT_J = dict(hip_z=1.10, neck_z=1.66, head_top=2.20, hip_x=.155, knee=(.175, .63), ankle=.16,
                shoulder=(.37, 0, 1.62), elbow=(.49, -.02, 1.32), wrist=(.51, -.10, 1.10))

def build_knight(M):
    J = KNIGHT_J
    rig = biped_rig("knight", J)
    iron, dark, trim, cloth, void, glow, leather = M["iron"], M["irondark"], M["trim"], M["cloth"], M["void"], M["glow"], M["leather"]
    k = J["neck_z"]/1.49
    # Torn wraith cloak and ragged mantle.
    cloak(cloth, M["lining"], k=k, hem=.22, wide=1.22, ragged=.18, seed=9, ripple=.08)
    mantle(cloth, k=k, bottom=1.42, rx=.50, ry=.36, ragged=.10, ripple=.07, front_gap=36, top=.17)
    # Torso plate.
    rings("Breastplate", [(1.12, .26, .18, 0), (1.30, .33, .20, -.01), (1.50, .345, .21, -.015), (1.64, .27, .17, 0)], iron, "spine", 32)
    ellipsoid("Breastplate ridge", (0, -.205, 1.40), (.032, .03, .2), iron, "spine", 12)
    for z in (1.20, 1.28):
        rings("Fauld", [(z, .27, .19, 0), (z+.05, .28, .195, 0)], dark, "spine", 32)
    rings("Gorget", [(1.60, .19, .16, 0), (1.74, .15, .14, 0)], dark, "spine", 28)
    # Tassets and dark mail skirt.
    rings("Mail skirt", [(1.13, .25, .175, 0), (.86, .29, .21, 0)], dark, "hips", 32, pleat=.02)
    shell("Tassets", [(1.14, .27, .19, 0, -165, -15), (.84, .33, .24, -.02, -165, -15)], iron, "hips", 24, .02)
    shell("Rear tassets", [(1.14, .27, .19, 0, 15, 165), (.86, .32, .25, .02, 15, 165)], iron, "hips", 24, .02)
    rings("Sword belt", [(1.10, .265, .185, 0), (1.15, .265, .185, 0)], leather, "hips", 32)
    ellipsoid("Belt plate", (0, -.19, 1.12), (.05, .015, .04), trim, "hips", 12)
    # Great helm: no face, a violet slit.
    rings("Great helm", [(1.68, .17, .17, -.01), (1.74, .205, .205, -.01), (1.98, .215, .22, -.01),
                         (2.10, .19, .195, -.005), (2.18, .11, .115, 0), (2.21, .04, .04, 0)], iron, "head", 32)
    ellipsoid("Helm crest", (0, .0, 2.12), (.03, .21, .09), dark, "head", 12)
    ellipsoid("Helm brow", (0, -.205, 1.98), (.19, .035, .03), dark, "head", 16)
    ellipsoid("Visor slit", (0, -.215, 1.92), (.16, .02, .032), void, "head", 16)
    ellipsoid("Slit glow", (0, -.222, 1.92), (.135, .016, .018), glow, "head", 16)
    ellipsoid("Breath slit", (0, -.218, 1.80), (.018, .015, .065), void, "head", 10)
    ellipsoid("Breath glow", (0, -.224, 1.80), (.009, .01, .045), glow, "head", 10)
    for s in (-1, 1):
        cone("Helm horn", (s*.17, 0, 2.06), (s*.32, .08, 2.26), .045, dark, "head", verts=8)
    # Arms: big layered pauldrons, plate, gauntlets.
    sx, sy, sz = J["shoulder"]; ex, ey, ez = J["elbow"]; wx, wy, wz = J["wrist"]
    for side, s in [("L", 1), ("R", -1)]:
        rot = (0, s*.42, 0)
        ellipsoid("Pauldron", (s*.39, 0, 1.68), (.23, .22, .14), iron, "upper_arm."+side, rot=rot)
        ellipsoid("Pauldron lame", (s*.43, 0, 1.58), (.20, .2, .10), dark, "upper_arm."+side, rot=rot)
        ellipsoid("Pauldron lame", (s*.455, 0, 1.49), (.17, .17, .08), iron, "upper_arm."+side, rot=rot)
        for n in range(3):
            cone("Pauldron spike", (s*(.32+.07*n), .03-.04*n, 1.76-.02*n), (s*(.38+.10*n), .07-.04*n, 1.95-.03*n), .035, dark, "upper_arm."+side, verts=6)
        cloth_limb("Rerebrace", (s*sx, sy, sz), (s*ex, ey, ez), .115, .095, dark, "upper_arm."+side)
        ellipsoid("Couter", (s*ex, ey, ez), (.09, .09, .08), iron, "forearm."+side, 12)
        cloth_limb("Vambrace", (s*(ex+.005), ey-.03, ez-.05), (s*wx, wy, wz), .098, .088, iron, "forearm."+side)
        ellipsoid("Gauntlet", (s*(wx+.005), wy-.01, wz-.06), (.085, .07, .10), dark, "forearm."+side, 14)
        # Legs.
        kx, kz = J["knee"]
        cloth_limb("Cuisse", (s*J["hip_x"], 0, J["hip_z"]), (s*kx, 0, kz), .13, .115, dark, "thigh."+side)
        ellipsoid("Poleyn", (s*kx, -.075, kz), (.095, .065, .09), iron, "shin."+side, 12)
        rings("Greave", [(.15, .115, .115, 0), (.55, .12, .12, -.005)], iron, "shin."+side, 20).location = (s*kx, 0, 0)
        ellipsoid("Sabaton", (s*kx, -.07, .085), (.11, .21, .08), iron, "foot."+side, 14)
        ellipsoid("Sabaton sole", (s*kx, -.07, .035), (.115, .215, .03), void, "foot."+side, 14)
    # Greatsword carried low in the right hand, point forward and down.
    H = Vector((-(wx+.005), wy-.02, wz-.06))
    d = (Vector((-.62, -.46, .10)) - H).normalized()
    sv = d.cross(Vector((0, 0, 1))).normalized()
    nv = sv.cross(d).normalized()
    limb("Grip", H-d*.20, H+d*.10, (.028, .028), leather, "forearm.R", 10)
    ellipsoid("Pommel", H-d*.22, (.05, .05, .05), dark, "forearm.R", 12)
    ellipsoid("Pommel soul gem", H-d*.24, (.03, .03, .03), glow, "forearm.R", 10)
    G = H + d*.13
    limb("Crossguard", G-sv*.24, G+sv*.24, (.035, .035), dark, "forearm.R", 10)
    for s in (-1, 1):
        cone("Guard quillon", G+sv*s*.22, G+sv*s*.30+d*.06, .03, dark, "forearm.R", verts=6)
    vs, fs = [], []
    L = 1.02
    rows = [(0, .075), (.12, .07), (.80, .062), (.93, .035), (1.0, .0)]
    for t, w in rows:
        c = G + d*(t*L)
        th = .018 if w else 0.0
        vs += [c-sv*w, c+nv*th, c+sv*w, c-nv*th]
    for r in range(len(rows)-1):
        for q in range(4):
            a = r*4+q; b = r*4+(q+1) % 4
            fs.append((a, b, b+4, a+4))
    fs.append((3, 2, 1, 0))
    from_data("Greatsword blade", vs, fs, M["steel"], "forearm.R")
    for side in (1, -1):
        a = G + d*(.10*L) + nv*side*.017; b = G + d*(.72*L) + nv*side*.017
        tube("Rune fuller", [a, b], .011, glow, "forearm.R", 6)
    return rig

# ------------------------------------------------------------------ roster

COMPANIONS = [
    dict(id="hound", name="Grave Hound", accent="7DFFB0", cell=84,
         walk_target=(0, -.05, .55), walk_ortho=2.15, portrait_target=(0, -.80, .95), portrait_ortho=1.25,
         look="Gaunt spectral hound: charcoal hide drawn over showing ribs, ragged ears, spectral-green eyes and spine embers."),
    dict(id="archer", name="Bone Archer", accent="8FD8FF", cell=80,
         walk_target=(0, 0, 1.03), walk_ortho=2.05, portrait_target=(0, 0, 1.47), portrait_ortho=1.25,
         look="Skeletal archer in a tattered hood and ragged cloak with a longbow; pale-blue fire in the sockets, bowstring and heart."),
    dict(id="knight", name="Wraith Knight", accent="C08CFF", cell=104,
         walk_target=(0, -.08, 1.12), walk_ortho=2.45, portrait_target=(0, 0, 1.62), portrait_ortho=1.6,
         look="Tall faceless wraith in dark plate with a torn cloak and greatsword; violet glow in the helm slit and blade runes."),
]

def author(C, idx):
    global active_col, pieces
    ident = C["id"]
    active_col = bpy.data.collections.new(ident+"_companion")
    bpy.context.scene.collection.children.link(active_col)
    pieces = []
    acc = C["accent"]
    rim = dict(rim=acc, rim_strength=.4)
    M = {"glow": material(ident+" spectral glow", acc, .4, grime=0, emit=1.3, bump=0),
         "glowsoft": material(ident+" faint glow", acc, .4, grime=0, emit=1.2, bump=0),
         "void": material(ident+" void", "050506", .95, grime=0, bump=0)}
    if ident == "hound":
        M.update(hide=material("hound grave hide", "1C201E", .88, grime=.4, **rim),
                 hidedark=material("hound dark hide", "171A19", .85, grime=.3, **rim),
                 rib=material("hound exposed bone", "5E5A50", .7, grime=.45, **rim),
                 bone=material("hound fangs", "A49C88", .5, grime=.2))
        rig = build_hound(M); hound_trot(rig)
        rig.scale = (1.25, 1, 1)  # broader frame reads better from above
    elif ident == "archer":
        M.update(bone=material("archer old bone", "8E8778", .7, grime=.45, **rim),
                 bonedark=material("archer dark bone", "5A564D", .75, grime=.4, **rim),
                 hood=material("archer hood cloth", "171A1F", .92, **rim),
                 cloth=material("archer rags", "25282D", .92, **rim),
                 wood=material("archer bow wood", "2E2520", .6, grime=.3),
                 leather=material("archer leather", "33291F", .6, grime=.3))
        rig = build_archer(M)
        biped_walk(rig, arm=(.10, .30))
    else:
        M.update(iron=material("knight blackened plate", "3E4049", .45, grime=.5, metal=.7, bump=.08, **rim),
                 irondark=material("knight dark iron", "24252B", .55, grime=.4, metal=.6, bump=.08, **rim),
                 steel=material("knight greatsword steel", "6A6C74", .35, grime=.35, metal=.85, bump=.05),
                 trim=material("knight tarnished trim", "4A4452", .5, grime=.3, metal=.6),
                 cloth=material("knight torn cloak", "17151C", .95, **rim),
                 lining=material("knight cloak lining", "221A2C", .95),
                 leather=material("knight grip leather", "2A221C", .6, grime=.3))
        rig = build_knight(M)
        biped_walk(rig, stride=.27, knee=.32, arm=(.26, .07), bob=.028, sway=.07, roll=.03)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in pieces: ob.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    mesh = bpy.context.object
    mesh.name = ident+"_Companion"
    mod = mesh.modifiers.new("Companion skeletal animation", "ARMATURE"); mod.object = rig
    mesh.parent = rig
    rig["companion_id"] = ident
    rig["authorship"] = "Original Blender geometry; generated with tools/build_companions.py"
    rig.animation_data.action.name = ident+"_Idle0_Walk1to25"
    rig.location.x = idx*3.0
    return dict(C, rig=rig, collection=active_col)

characters = [author(c, i) for i, c in enumerate(COMPANIONS)]
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast" if "Medium High Contrast" in [i.identifier for i in scene.view_settings.bl_rna.properties['look'].enum_items] else "None"
scene.view_settings.exposure = 0
if scene.world is None:
    scene.world = bpy.data.worlds.new("World")
scene.world.color = (.06, .065, .08)
scene.render.fps = 44
scene.frame_start = 1; scene.frame_end = 24
scene.render.resolution_percentage = 100

bpy.ops.object.camera_add()
camera = bpy.context.object; camera.name = "Companion render camera"
camera.data.type = "ORTHO"; scene.camera = camera
lights = []
for name, loc, power, size, color in [
        ("Warm key", (-3.2, -3.6, 6.5), 1100, 2.5, (1.0, .88, .74)),
        ("Cool fill", (4, -2, 3.5), 140, 3, (.62, .72, .95)),
        ("Cold rim left", (-3.5, 4.2, 4.2), 1500, 1.8, (.62, .76, 1.0)),
        ("Cold rim right", (3.8, 4.0, 3.6), 1100, 1.8, (.62, .76, 1.0))]:
    bpy.ops.object.light_add(type="AREA", location=loc)
    ob = bpy.context.object; ob.name = name; ob.data.energy = power; ob.data.shape = "DISK"; ob.data.size = size
    ob.data.color = color
    lights.append((ob, Vector(loc)))

def setup(char, portrait=False):
    x = char["rig"].location.x
    for c in characters: c["collection"].hide_render = c is not char
    target = Vector(char["portrait_target" if portrait else "walk_target"]) + Vector((x, 0, 0))
    camera.location = target + (Vector((2.4, -7, 3.2)) if portrait else Vector((0, -6, 10)))
    camera.rotation_euler = (target-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = char["portrait_ortho" if portrait else "walk_ortho"]
    res = 512 if portrait else 256
    scene.render.resolution_x = res; scene.render.resolution_y = res
    for ob, loc in lights:
        ob.location = loc+Vector((x, 0, 0))
        ob.rotation_euler = (Vector((x, 0, 1.2))-ob.location).to_track_quat("-Z", "Y").to_euler()

def render(path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)

for char in characters:
    if ONLY and char["id"] not in ONLY: continue
    d = RAW/char["id"]; d.mkdir(exist_ok=True)
    setup(char, portrait=True); scene.frame_set(0); render(d/"portrait.png")
    setup(char); scene.frame_set(0); render(d/"idle.png")
    for frame in ([5] if PREVIEW else FRAMES):
        scene.frame_set(frame); render(d/("walk_%02d.png" % frame))
    print("COMPANION COMPLETE", char["id"], flush=True)
