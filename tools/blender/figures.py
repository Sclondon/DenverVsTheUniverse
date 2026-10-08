"""Builds the action figures (the robot and every alien) in Blender and exports each as models/<name>.glb.

    blender -b --python tools/blender/figures.py -- --out=models [--preview=<dir>] [--only=robot,alien_grunt]

Figures face -Y in Blender (toward the camera in the game), stand Z up. Limbs that swing hang from
empties named arm_l / arm_r / leg_l / leg_r; the game turns those.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    for a in ARGS:
        if a.startswith("--%s=" % name):
            return a.split("=", 1)[1]
    return default


# --- Materials ------------------------------------------------------------------------------------

MATS = {}


def _linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(color, rough=0.4, metal=0.0, emit=0.0, alpha=1.0):
    key = (color, rough, metal, emit, alpha)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new("m_%s_%d" % (color, len(MATS)))
    m.use_nodes = True
    rgb = [_linear(int(color[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = 'BLENDED'
    m.diffuse_color = (*rgb, alpha)
    m["unshaded"] = emit > 0.0 or alpha < 1.0
    MATS[key] = m
    return m


# --- Solids ---------------------------------------------------------------------------------------

def _finish(bm, name, material, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), sharp=38.0, bevel=0.0, subdiv=0):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(sharp):
            e.smooth = False
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.parent = parent
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.scale = scale
    if subdiv > 0:
        ob.modifiers.new("subdiv", 'SUBSURF').levels = subdiv
    if bevel > 0.0:
        mod = ob.modifiers.new("bevel", 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(sharp)
    return ob


def pivot(name, loc, parent=None, rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(ob)
    ob.parent = parent
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


def loft(name, material, secs, n=18, **kw):
    """A skin over cross-sections stacked along local Z. Each section is (z, half x, half y[, power[, cx[, cy]]]):
    power 2 is an ellipse, higher is boxier. A zero-size section is a point (a tip)."""
    bm = bmesh.new()
    rings = []
    for s in secs:
        z, a, b = s[0], s[1], s[2]
        p = s[3] if len(s) > 3 else 2.0
        cx = s[4] if len(s) > 4 else 0.0
        cy = s[5] if len(s) > 5 else 0.0
        if a < 1e-5 or b < 1e-5:
            rings.append([bm.verts.new((cx, cy, z))])
            continue
        ring = []
        for i in range(n):
            t = 2.0 * math.pi * (i + 0.5) / n
            c, sn = math.cos(t), math.sin(t)
            ring.append(bm.verts.new((cx + a * math.copysign(abs(c) ** (2.0 / p), c), cy + b * math.copysign(abs(sn) ** (2.0 / p), sn), z)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        if len(r0) == 1 and len(r1) == 1:
            continue
        for i in range(n):
            j = (i + 1) % n
            if len(r0) == 1:
                bm.faces.new((r0[0], r1[i], r1[j]))
            elif len(r1) == 1:
                bm.faces.new((r0[i], r0[j], r1[0]))
            else:
                bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    for ring in (rings[0], rings[-1]):
        if len(ring) > 1:
            bm.faces.new(ring)
    sizes = [min(s[1], s[2]) for s in secs if s[1] > 1e-5 and s[2] > 1e-5]
    if n >= 10 and sizes and "subdiv" not in kw:
        kw.setdefault("bevel", min(0.012, min(sizes) * 0.22))
    return _finish(bm, name, material, **kw)


def lathe(name, material, profile, n=28, **kw):
    """Turns a profile of (radius, z) points around Z."""
    return loft(name, material, [(z, r, r) for r, z in profile], n=n, **kw)


def plate(name, material, pts, thick, **kw):
    """A flat sheet cut to the outline `pts` (x, z), `thick` deep in Y."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -thick * 0.5, z)) for x, z in pts]
    back = [bm.verts.new((x, thick * 0.5, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((front[j], front[i], back[i], back[j]))
    kw.setdefault("bevel", thick * 0.3)
    return _finish(bm, name, material, **kw)


def box(name, material, size, **kw):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    kw.setdefault("bevel", min(size) * 0.12)
    return _finish(bm, name, material, **kw)


def ball(name, material, radii, **kw):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
    if isinstance(radii, (int, float)):
        radii = (radii, radii, radii)
    bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
    kw.setdefault("sharp", 80.0)
    return _finish(bm, name, material, **kw)


SIDES = ((-1.0, "l"), (1.0, "r"))


def toward(d):
    """The rotation (in degrees) that turns a piece's local Z to point along `d`."""
    e = Vector((0, 0, 1)).rotation_difference(Vector(d).normalized()).to_euler()
    return tuple(math.degrees(a) for a in e)


def around(count):
    """`count` directions spread evenly over a ball."""
    out = []
    for i in range(count):
        z = 1.0 - 2.0 * (i + 0.5) / count
        r = math.sqrt(1.0 - z * z)
        out.append(Vector((math.cos(i * 2.39996) * r, math.sin(i * 2.39996) * r, z)))
    return out


def strut(name, material, a, b, r0, r1, n=8, **kw):
    """A tapering rod from `a` to `b`; a zero radius makes a point."""
    a, b = Vector(a), Vector(b)
    kw.setdefault("bevel", 0.0)
    return loft(name, material, [(0.0, r0, r0), ((b - a).length, r1, r1)], n=n, loc=a, rot=toward(b - a), **kw)


def rock(name, material, radii, seed=0, rough=0.16, **kw):
    """A flat-sided lump: a ball knocked out of true."""
    import random
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    if isinstance(radii, (int, float)):
        radii = (radii, radii, radii)
    for v in bm.verts:
        v.co *= 1.0 + rnd.uniform(-rough, rough)
    bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
    kw.setdefault("sharp", 1.0)
    return _finish(bm, name, material, **kw)


def crystal(name, material, length, r, **kw):
    """A six-sided crystal standing on its local Z, pointed at the top."""
    return loft(name, material, [(0.0, r * 0.7, r * 0.7), (length * 0.7, r, r), (length, 0.0, 0.0)], n=6, sharp=5.0, **kw)


def hoop(name, material, inner, outer, thick, n=32, **kw):
    """A flat ring lying in the XY plane."""
    bm = bmesh.new()
    rows = []
    for i in range(n):
        c, s = math.cos(2.0 * math.pi * i / n), math.sin(2.0 * math.pi * i / n)
        rows.append([bm.verts.new((c * r, s * r, z)) for r, z in ((inner, -thick * 0.5), (outer, -thick * 0.5), (outer, thick * 0.5), (inner, thick * 0.5))])
    for i in range(n):
        a, b = rows[i], rows[(i + 1) % n]
        for k in range(4):
            bm.faces.new((a[k], b[k], b[(k + 1) % 4], a[(k + 1) % 4]))
    return _finish(bm, name, material, **kw)


def banded(name, paints, r, lats, **kw):
    """A ball painted in stripes: `lats` are the latitudes (degrees) where one paint gives way to the next."""
    for i in range(len(lats) - 1):
        steps = max(2, int((lats[i + 1] - lats[i]) / 12.0) + 1)
        profile = []
        for k in range(steps + 1):
            at = math.radians(lats[i] + (lats[i + 1] - lats[i]) * k / steps)
            profile.append((max(0.0, math.cos(at)) * r, math.sin(at) * r))
        lathe(name, paints[i % len(paints)], profile, n=24, sharp=60, bevel=0.0, **kw)


def eyeball(parent, at, r, iris, white="fff6d8"):
    """An eye looking out along -Y: the white, a lit iris and a pupil."""
    at = Vector(at)
    ball("eye", mat(white, 0.15), (r, r * 0.6, r), parent=parent, loc=at)
    ball("iris", mat(iris, 0.2, 0.0, 2.0), (r * 0.56, r * 0.3, r * 0.56), parent=parent, loc=at + Vector((0, -r * 0.42, 0)))
    ball("pupil", mat("08080c", 0.1), (r * 0.26, r * 0.2, r * 0.26), parent=parent, loc=at + Vector((0, -r * 0.62, 0)))


def lettering(name, material, words, size, **kw):
    """Raised lettering, lying in the XZ plane facing -Y."""
    curve = bpy.data.curves.new(name, 'FONT')
    curve.body = words
    curve.size = size
    curve.extrude = 0.004
    curve.align_x = 'CENTER'
    ob = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob)
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.parent = kw.get("parent")
    ob.location = kw.get("loc", (0, 0, 0))
    rot = kw.get("rot", (0, 0, 0))
    ob.rotation_euler = [math.radians(rot[0] + 90.0), math.radians(rot[1]), math.radians(rot[2])]
    return ob


def finalize():
    """Turns the finished figure into plain meshes (modifiers applied) and paints soft contact
    shading into their vertex colours, so creases and joints read without any lights."""
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    meshes = [o for o in scene.objects if o.type == 'MESH']
    baked = [bpy.data.meshes.new_from_object(o.evaluated_get(deps)) for o in meshes]
    for o, me in zip(meshes, baked):
        o.modifiers.clear()
        o.data = me
    world = bpy.data.worlds.new("bake")
    world.light_settings.distance = 0.5
    scene.world = world
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 24
    scene.render.bake.target = 'VERTEX_COLORS'
    import numpy as np
    for o in meshes:
        attr = o.data.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
        o.data.color_attributes.active_color = attr
        o.data.color_attributes.render_color_index = 0
        count = len(attr.data) * 4
        if o.data.materials[0].get("unshaded"):
            attr.data.foreach_set("color", np.ones(count, dtype=np.float32))
            continue
        for other in scene.objects:
            other.select_set(other == o)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.bake(type='AO')
        shade = np.zeros(count, dtype=np.float32)
        attr.data.foreach_get("color", shade)
        shade = shade.reshape(-1, 4)
        # Keep it gentle: the lamps on the table do the real lighting
        shade[:, :3] = 0.42 + 0.58 * np.clip(shade[:, :3] * 1.15, 0.0, 1.0)
        shade[:, 3] = 1.0
        attr.data.foreach_set("color", shade.ravel())
    # Show the shading in Blender too
    for m in bpy.data.materials:
        if not m.use_nodes or m.get("unshaded"):
            continue
        tree = m.node_tree
        bsdf = tree.nodes["Principled BSDF"]
        col = tree.nodes.new("ShaderNodeVertexColor")
        col.layer_name = "Col"
        mix = tree.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
        tree.links.new(col.outputs["Color"], mix.inputs[7])
        tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])


# --- The robot ------------------------------------------------------------------------------------

def robot():
    """An F-15 that stood up: slim and long-limbed like an Evangelion. The radome is its head, the
    intakes its shoulders with the twin tails rising from them as pylons, the wings a cape down its
    back, and the engines its calves. Three units to the top of the head, feet at the origin."""
    hull = mat("eef0f3", 0.3, 0.0)
    hull2 = mat("b4bec9", 0.34, 0.0)
    armor = mat("6a35b8", 0.3, 0.0)
    joint = mat("22252d", 0.45, 0.3)
    black = mat("08080c", 0.5)
    green = mat("86ff4a", 0.3, 0.0, 3.0)
    burn = mat("ff8a2a", 0.3, 0.0, 3.0)
    glass = mat("ffae2c", 0.08, 0.0, 0.5)
    core = mat("ff2d3d", 0.2, 0.0, 2.5)
    white = mat("f2f2f2", 0.4)
    red = mat("e0263c", 0.4)
    steel = mat("c9cfd6", 0.25, 0.4)
    # The blaster is a toy foam-dart gun: loud orange, yellow and blue plastic
    nerf = mat("ff7a1a", 0.35)
    nerf_yellow = mat("ffd21f", 0.35)
    nerf_blue = mat("2a6fe0", 0.35)

    for s, sn in SIDES:
        # Leg: slim thigh, spiked knee, and the calf is an engine standing on its nozzle
        leg = pivot("leg_" + sn, (s * 0.2, 0.0, 1.56))
        ball("hip", joint, 0.115, parent=leg)
        loft("thigh", armor, [(-0.02, 0.085, 0.1, 2.6), (-0.2, 0.125, 0.15, 2.6), (-0.48, 0.105, 0.125, 2.6), (-0.7, 0.075, 0.09, 2.4)], parent=leg)
        loft("thigh_stripe", green, [(-0.3, 0.128, 0.03, 3.0), (-0.34, 0.126, 0.03, 3.0)], parent=leg, loc=(0, -0.118, 0))
        ball("knee", joint, 0.09, parent=leg, loc=(0, 0.0, -0.75))
        # The knee bends: everything below it hangs from knee_l / knee_r (the shin pivot keeps leg coordinates)
        shin = pivot("shin", (0, 0, 0.75), parent=pivot("knee_" + sn, (0, 0, -0.75), parent=leg))
        loft("knee_spike", hull, [(-0.06, 0.075, 0.05, 3.0), (0.06, 0.07, 0.045, 3.0), (0.34, 0.0, 0.0)], parent=shin, loc=(0, -0.1, -0.78), rot=(16, 0, 0))
        loft("calf", hull, [(-0.8, 0.075, 0.085, 2.2), (-0.96, 0.115, 0.14, 2.6, 0, 0.02), (-1.2, 0.13, 0.16, 2.4, 0, 0.03), (-1.37, 0.14, 0.165, 2.0, 0, 0.03)], parent=shin)
        loft("calf_band", hull2, [(-1.3, 0.142, 0.168, 2.0, 0, 0.03), (-1.37, 0.146, 0.171, 2.0, 0, 0.03)], parent=shin)
        loft("nozzle", joint, [(-1.37, 0.135, 0.158, 2.0, 0, 0.03), (-1.5, 0.105, 0.125, 2.0, 0, 0.03), (-1.555, 0.1, 0.12, 2.0, 0, 0.03)], n=14, sharp=20, parent=shin)
        loft("burner", burn, [(-1.4, 0.09, 0.105, 2.0, 0, 0.03), (-1.41, 0.137, 0.16, 2.0, 0, 0.03)], parent=shin)
        loft("foot", armor, [(-0.1, 0.085, 0.05, 4.0), (0.12, 0.105, 0.065, 4.0), (0.3, 0.07, 0.045, 3.0), (0.46, 0.0, 0.0, 2.0, 0, -0.03)], parent=shin, loc=(0, -0.06, -1.495), rot=(90, 0, 0))

        # Arm: long, hanging nearly to the knee, a missile down the forearm
        arm = pivot("arm_" + sn, (s * 0.66, 0.0, 2.44))
        ball("shoulder", joint, 0.115, parent=arm)
        loft("upper_arm", armor, [(-0.03, 0.075, 0.085, 2.6), (-0.24, 0.092, 0.1, 2.6), (-0.6, 0.066, 0.072, 2.4)], parent=arm)
        ball("elbow", joint, 0.074, parent=arm, loc=(0, 0, -0.66))
        fore = pivot("fore_" + sn, (0, 0, 0.66), parent=pivot("elbow_" + sn, (0, 0, -0.66), parent=arm))
        loft("forearm", hull, [(-0.7, 0.064, 0.07, 2.4), (-0.92, 0.098, 0.108, 3.0), (-1.24, 0.082, 0.09, 3.0), (-1.32, 0.058, 0.064, 2.4)], parent=fore)
        loft("cuff", green, [(-1.2, 0.086, 0.094, 3.0), (-1.235, 0.085, 0.093, 3.0)], parent=fore)
        loft("hand", joint, [(-1.32, 0.048, 0.056, 3.0), (-1.42, 0.062, 0.074, 3.0), (-1.53, 0.036, 0.05, 3.0)], parent=fore)
        loft("missile", white, [(-0.8, 0.0, 0.0), (-0.82, 0.027, 0.027), (-1.28, 0.027, 0.027)], n=10, parent=fore, loc=(s * 0.128, 0, 0))
        loft("missile_tip", red, [(-1.28, 0.027, 0.027), (-1.4, 0.0, 0.0)], n=10, parent=fore, loc=(s * 0.128, 0, 0))
        for turn in (0.0, 90.0):
            plate("missile_fin", red, [(-0.07, -0.8), (0.07, -0.8), (0.03, -0.93), (-0.03, -0.93)], 0.008, parent=fore, loc=(s * 0.128, 0, 0), rot=(0, 0, turn))
        # Fingers and a thumb, and an armoured disc on the shoulder
        for i in range(3):
            box("finger", joint, (0.024, 0.036, 0.1), parent=fore, loc=((i - 1) * 0.03, -0.012, -1.56), rot=(-14, 0, 0))
        box("thumb", joint, (0.026, 0.03, 0.07), parent=fore, loc=(s * -0.058, -0.03, -1.47), rot=(-30, s * 24.0, 0))
        lathe("shoulder_cap", armor, [(0.0, 0.0), (0.105, 0.0), (0.12, 0.025), (0.09, 0.05), (0.0, 0.055)], n=20, parent=arm, loc=(s * 0.095, 0, 0.0), rot=(0, s * 90.0, 0))
        ball("shoulder_stud", green, 0.03, parent=arm, loc=(s * 0.155, 0, 0.0))
        loft("thigh_panel", hull, [(-0.1, 0.07, 0.016, 3.0), (-0.26, 0.08, 0.016, 3.0)], parent=leg, loc=(0, -0.133, 0))
        loft("shin_guard", armor, [(-0.98, 0.07, 0.02, 3.0), (-1.26, 0.085, 0.02, 3.0)], parent=shin, loc=(0, -0.132, 0))

        # Shoulder: the jet's intake, raked lip forward, with a tail fin rising from it
        loft("intake", hull, [(-0.24, 0.13, 0.13, 6.0), (0.0, 0.15, 0.16, 6.0), (0.25, 0.15, 0.17, 6.0, 0, 0.01)], loc=(s * 0.64, 0.0, 2.6), rot=(98, 0, 0))
        loft("intake_mouth", black, [(0.25, 0.125, 0.145, 6.0, 0, 0.01), (0.262, 0.12, 0.14, 6.0, 0, 0.01)], loc=(s * 0.64, 0.0, 2.6), rot=(98, 0, 0))
        loft("intake_lip", green, [(-0.02, 0.153, 0.163, 6.0), (0.02, 0.153, 0.164, 6.0)], loc=(s * 0.64, 0.0, 2.6), rot=(98, 0, 0))
        fin = pivot("fin_" + sn, (s * 0.66, 0.02, 2.72), rot=(s * 9.0, 0, 90.0 - s * 42.0))
        plate("tail", hull, [(-0.2, 0.0), (0.24, 0.0), (0.36, 0.78), (0.15, 0.78)], 0.045, parent=fin)
        lettering("tail_number", joint, "15", 0.2, parent=fin, loc=(0.13, -0.025 * s, 0.26), rot=(0, 0, 0 if s > 0 else 180))
        plate("tail_tip", armor, [(0.15, 0.78), (0.36, 0.78), (0.385, 0.95), (0.225, 0.95)], 0.05, parent=fin)
        loft("tail_pod", hull2, [(0.0, 0.0, 0.0), (0.06, 0.022, 0.022), (0.3, 0.022, 0.022), (0.36, 0.0, 0.0)], n=8, parent=fin, loc=(0.3, 0, 0.95), rot=(0, -80, 0))

        # Wings, folded down the back like a cape, and the stabilators as hip skirts
        plate("wing", hull, [(0.0, 0.34), (0.0, -0.4), (s * 1.02, -0.62), (s * 1.02, -0.36)], 0.04, loc=(s * 0.16, 0.25, 2.32), rot=(0, 0, s * 26.0))
        wing = plate("wing_roundel_base", hull2, [(s * 0.42, -0.06), (s * 0.42, -0.34), (s * 0.7, -0.4), (s * 0.7, -0.12)], 0.044, loc=(s * 0.16, 0.25, 2.32), rot=(0, 0, s * 26.0))
        for r, paint in ((0.12, mat("2a6fe0", 0.4)), (0.08, mat("f2f2f2", 0.4)), (0.04, red)):
            lathe("roundel", paint, [(0.0, 0.0), (r, 0.0), (r, 0.004 + (0.12 - r) * 0.05), (0.0, 0.004 + (0.12 - r) * 0.05)], n=20, parent=wing, loc=(s * 0.56, -0.022, -0.23), rot=(90, 0, 0))
        plate("wing_stripe", armor, [(s * 0.8, -0.235), (s * 0.8, -0.575), (s * 0.9, -0.596), (s * 0.9, -0.292)], 0.046, loc=(s * 0.16, 0.25, 2.32), rot=(0, 0, s * 26.0))
        plate("stabilator", hull2, [(0.0, 0.1), (0.0, -0.2), (s * 0.4, -0.42), (s * 0.4, -0.25)], 0.035, loc=(s * 0.22, 0.09, 1.64), rot=(0, 0, s * 38.0))
        # Engine humps down the spine
        loft("engine", hull2, [(1.72, 0.07, 0.06), (1.9, 0.105, 0.1), (2.4, 0.115, 0.11), (2.6, 0.08, 0.07)], loc=(s * 0.14, 0.17, 0))

    loft("pelvis", joint, [(1.46, 0.13, 0.11, 3.0), (1.57, 0.27, 0.15, 3.0), (1.68, 0.2, 0.13, 3.0)])
    loft("codpiece", hull, [(1.36, 0.0, 0.0, 2, 0, -0.1), (1.5, 0.07, 0.03, 3.0, 0, -0.13), (1.66, 0.11, 0.035, 3.0, 0, -0.12)])
    loft("waist", joint, [(1.66, 0.12, 0.1), (1.8, 0.095, 0.085), (1.98, 0.14, 0.11)])
    loft("abs", hull2, [(1.74, 0.1, 0.03, 3.0), (1.96, 0.13, 0.03, 3.0)], loc=(0, -0.085, 0))
    loft("chest", hull, [(1.94, 0.15, 0.12, 3.0), (2.14, 0.3, 0.2, 3.0), (2.42, 0.4, 0.235, 3.4), (2.6, 0.38, 0.21, 3.4), (2.7, 0.2, 0.15, 3.0)])
    loft("collar", armor, [(2.56, 0.385, 0.216, 3.4), (2.63, 0.345, 0.196, 3.4)])
    ball("core", core, 0.062, loc=(0, -0.155, 2.1))
    # A space ranger's chest: three big buttons one side, a badge the other, and vents under the collar
    for i, lamp in enumerate((mat("ff2d3d", 0.3, 0.0, 2.0), mat("86ff4a", 0.3, 0.0, 2.0), mat("2a8fff", 0.3, 0.0, 2.0))):
        lathe("button", lamp, [(0.0, 0.0), (0.03, 0.0), (0.03, 0.02), (0.02, 0.03), (0.0, 0.032)], n=14, loc=(0.16 + i * 0.075, -0.2 + i * 0.012, 2.3), rot=(90, 0, 0))
    plate("badge", green, [(-0.07, 0.07), (0.07, 0.07), (0.07, -0.02), (0.0, -0.09), (-0.07, -0.02)], 0.02, loc=(-0.22, -0.205, 2.32), rot=(0, 0, 8))
    lettering("badge_word", joint, "DEN", 0.05, loc=(-0.22, -0.218, 2.31), rot=(0, 0, 8))
    for s, sn in SIDES:
        for i in range(3):
            box("vent", joint, (0.11, 0.02, 0.016), loc=(s * 0.2, -0.212 + 0.004 * i, 2.5 - i * 0.035), rot=(-12, 0, 0), bevel=0.004)
        plate("ear_fin", hull, [(-0.04, 0.0), (0.06, 0.0), (0.1, 0.2), (0.04, 0.2)], 0.02, loc=(s * 0.17, -0.02, 2.9), rot=(s * 14.0, 0, 90))
    loft("core_ring", joint, [(0.0, 0.085, 0.085), (0.03, 0.08, 0.08)], n=14, loc=(0, -0.14, 2.1), rot=(90, 0, 0))
    ball("canopy", glass, (0.1, 0.085, 0.24), loc=(0, -0.2, 2.42), rot=(-8, 0, 0))
    loft("canopy_frame", joint, [(0.0, 0.112, 0.25, 2.0), (0.02, 0.105, 0.24, 2.0)], loc=(0, -0.2, 2.42), rot=(82, 0, 0))

    # Head: the radome, jutting forward under a horn
    loft("neck", joint, [(2.6, 0.075, 0.075), (2.84, 0.065, 0.065)])
    head = pivot("head", (0.0, -0.02, 2.88), rot=(104, 0, 0))
    head.scale = (1.3, 1.3, 1.3)
    loft("skull", armor, [(-0.17, 0.07, 0.08, 2.6), (-0.02, 0.125, 0.135, 2.6), (0.16, 0.11, 0.11, 2.3), (0.3, 0.065, 0.06, 2.0)], parent=head)
    loft("radome", hull2, [(0.3, 0.065, 0.06, 2.0), (0.44, 0.024, 0.022, 2.0), (0.5, 0.0, 0.0)], parent=head)
    loft("jaw", hull, [(-0.1, 0.08, 0.04, 3.0), (0.12, 0.085, 0.04, 3.0), (0.3, 0.0, 0.0)], parent=head, loc=(0, -0.1, 0))
    for s, sn in SIDES:
        loft("eye", green, [(0.06, 0.012, 0.022, 3.0), (0.2, 0.012, 0.013, 3.0)], parent=head, loc=(s * 0.108, 0.035, 0), rot=(0, s * -14.0, 0))
    loft("horn", hull, [(0.0, 0.03, 0.07, 2.0), (0.5, 0.0, 0.0, 2.0, 0, -0.1)], n=8, loc=(0, -0.16, 3.0))

    # The blaster, a rotary foam-dart gun as long as the arm, held in the right hand
    gun = pivot("gun", (0.0, -0.085, 0.0), parent=bpy.data.objects["fore_r"])
    loft("gun_body", nerf, [(-1.14, 0.03, 0.04, 4.0), (-1.2, 0.045, 0.07, 4.0), (-1.62, 0.045, 0.065, 4.0), (-1.68, 0.03, 0.04, 4.0)], parent=gun)
    loft("gun_drum", nerf_yellow, [(-1.28, 0.095, 0.095), (-1.52, 0.095, 0.095)], n=14, parent=gun, loc=(0, 0.02, 0))
    for i in range(3):
        a = math.radians(i * 120.0 + 90.0)
        loft("barrel", nerf_blue, [(-1.66, 0.022, 0.022), (-1.98, 0.022, 0.022)], n=8, parent=gun, loc=(math.cos(a) * 0.022, math.sin(a) * 0.022, 0))
    loft("muzzle", nerf, [(-1.88, 0.058, 0.058), (-1.97, 0.062, 0.062)], n=14, parent=gun)
    return 3.9, 1.85


# --- The aliens -----------------------------------------------------------------------------------

def grey_head(skin, loc, r, parent=None, eyes="08080c"):
    """The classic grey: a big skull narrowing to a small chin, and slanted glossy black eyes."""
    head = pivot("head", loc, parent)
    loft("skull", skin, [(-1.0 * r, 0.0, 0.0), (-0.92 * r, 0.24 * r, 0.24 * r), (-0.5 * r, 0.56 * r, 0.56 * r), (0.1 * r, 0.95 * r, 0.9 * r),
                         (0.55 * r, 0.92 * r, 0.9 * r, 2.0, 0, 0.04 * r), (0.9 * r, 0.55 * r, 0.56 * r, 2.0, 0, 0.06 * r), (1.02 * r, 0.0, 0.0, 2.0, 0, 0.06 * r)], n=16, parent=head, sharp=80, subdiv=2)
    for s, _ in SIDES:
        ball("eye", mat(eyes, 0.05), (0.36 * r, 0.14 * r, 0.21 * r), parent=head, loc=(s * 0.4 * r, -0.66 * r, 0.02 * r), rot=(0, s * 30.0, s * 24.0), subdiv=1)
    return head


def humanoid(skin, suit, trim):
    """A skinny long-limbed body, 2.3 tall and centred on the origin, without a head."""
    dark = mat("22252d", 0.45, 0.3)
    loft("neck", skin, [(0.05, 0.06, 0.06), (0.36, 0.05, 0.05)])
    loft("torso", suit, [(-0.5, 0.12, 0.09), (-0.3, 0.14, 0.1), (-0.02, 0.24, 0.13, 2.6), (0.1, 0.22, 0.12, 2.6), (0.16, 0.1, 0.08)])
    loft("belt", trim, [(-0.36, 0.142, 0.103), (-0.3, 0.146, 0.106)])
    for s, sn in SIDES:
        arm = pivot("arm_" + sn, (s * 0.26, 0.0, 0.06), rot=(0, s * -12.0, 0))
        ball("shoulder", suit, 0.085, parent=arm)
        loft("upper", skin, [(0.0, 0.05, 0.05), (-0.4, 0.04, 0.04)], n=10, parent=arm)
        ball("elbow", skin, 0.05, parent=arm, loc=(0, 0, -0.4))
        loft("lower", skin, [(-0.4, 0.04, 0.04), (-0.76, 0.032, 0.032)], n=10, parent=arm)
        loft("hand", skin, [(-0.74, 0.03, 0.035), (-0.84, 0.06, 0.03, 3.0), (-0.98, 0.0, 0.0)], n=10, parent=arm)
        leg = pivot("leg_" + sn, (s * 0.1, 0.0, -0.5))
        ball("hip", suit, 0.1, parent=leg)
        loft("thigh", suit, [(0.0, 0.085, 0.085), (-0.3, 0.06, 0.06)], n=10, parent=leg)
        loft("shin", suit, [(-0.3, 0.06, 0.06), (-0.52, 0.045, 0.045)], n=10, parent=leg)
        loft("boot", trim, [(-0.5, 0.055, 0.055), (-0.6, 0.075, 0.075), (-0.65, 0.07, 0.07)], n=12, parent=leg)
        loft("toe", trim, [(-0.06, 0.07, 0.05, 3.0), (0.1, 0.075, 0.05, 3.0), (0.24, 0.0, 0.0, 2, 0, -0.03)], n=12, parent=leg, loc=(0, 0, -0.6), rot=(90, 0, 0))
    return dark


def alien_grunt():
    """The grey in a silver jumpsuit, with a tin ray gun."""
    skin = mat("8be04e", 0.5)
    humanoid(skin, mat("c9cfd6", 0.25, 0.5), mat("ff3d7f", 0.4))
    grey_head(skin, (0, 0, 0.68), 0.45)
    arm = bpy.data.objects["arm_r"]
    gun = pivot("raygun", (0.0, -0.02, -0.84), parent=arm, rot=(90, 0, 0))
    lathe("gun_body", mat("e0263c", 0.3, 0.3), [(0.0, -0.1), (0.06, -0.06), (0.075, 0.04), (0.04, 0.14), (0.022, 0.2), (0.022, 0.34)], n=14, parent=gun)
    for i in range(3):
        lathe("gun_ring", mat("ffe14a", 0.3, 0.3), [(0.02, 0.0), (0.05 - i * 0.008, 0.012), (0.02, 0.024)], n=14, parent=gun, loc=(0, 0, 0.2 + i * 0.05))
    ball("gun_tip", mat("ff3d7f", 0.3, 0.0, 3.0), 0.04, parent=gun, loc=(0, 0, 0.37))
    return 2.6, 0.0


def alien_spitter():
    """A brain Martian: bare pink brain, bulging eyes, a villain's high-collared cape."""
    skin = mat("3fb5ae", 0.5)
    humanoid(skin, mat("2b7f7a", 0.45), mat("ffe14a", 0.4))
    cape = mat("b0122e", 0.55)
    loft("cape", cape, [(-1.02, 0.6, 0.2, 2.6), (-0.4, 0.42, 0.14, 2.6), (0.14, 0.24, 0.09, 2.6)], loc=(0, 0.17, 0))
    plate("collar", cape, [(-0.4, 0.1), (0.4, 0.1), (0.52, 0.62), (0.28, 0.44), (-0.28, 0.44), (-0.52, 0.62)], 0.04, loc=(0, 0.2, 0))
    head = pivot("head", (0, 0, 0.56))
    loft("face", mat("8be04e", 0.5), [(-0.26, 0.0, 0.0), (-0.2, 0.16, 0.16), (0.0, 0.3, 0.28), (0.2, 0.34, 0.3)], parent=head, sharp=80)
    brain = mat("f08ab0", 0.35)
    for s, _ in SIDES:
        ball("lobe", brain, (0.23, 0.36, 0.26), parent=head, loc=(s * 0.17, 0.02, 0.36))
        for i in range(4):
            ball("fold", brain, (0.1, 0.13, 0.1), parent=head, loc=(s * (0.14 + 0.2 * (i % 2)), -0.2 + i * 0.14, 0.5 - 0.06 * abs(i - 1.5)))
        ball("eye", mat("fff6d8", 0.2), 0.115, parent=head, loc=(s * 0.15, -0.27, 0.08))
        ball("pupil", mat("08080c", 0.1), 0.05, parent=head, loc=(s * 0.15, -0.37, 0.08))
    box("teeth", mat("fff6d8", 0.3), (0.2, 0.04, 0.06), parent=head, loc=(0, -0.21, -0.1), bevel=0.01)
    return 2.6, 0.0


def saucer(r, tin, bulbs, pilot, glow=None):
    """A pie-tin flying saucer with a glass dome, a pilot under it and a ring of bulbs."""
    lathe("hull", mat(tin, 0.22, 0.6), [(0.0, -0.3 * r), (0.34 * r, -0.28 * r), (0.5 * r, -0.16 * r), (0.98 * r, -0.04 * r), (1.0 * r, 0.0), (0.96 * r, 0.03 * r),
                                         (0.5 * r, 0.13 * r), (0.38 * r, 0.16 * r), (0.0, 0.16 * r)], sharp=30)
    lathe("deck", mat("6d7480", 0.3, 0.5), [(0.4 * r, 0.14 * r), (0.44 * r, 0.2 * r), (0.4 * r, 0.22 * r), (0.0, 0.22 * r)], sharp=30)
    if glow:
        lathe("underglow", mat(glow, 0.3, 0.0, 3.0), [(0.0, -0.31 * r), (0.3 * r, -0.29 * r), (0.3 * r, -0.27 * r)])
    grey_head(mat(pilot, 0.5), (0, 0, 0.42 * r), 0.22 * r)
    lathe("dome", mat("b8f0e6", 0.05, 0.0, 0.0, 0.3), [(0.38 * r, 0.2 * r), (0.38 * r, 0.36 * r), (0.33 * r, 0.52 * r), (0.2 * r, 0.64 * r), (0.0, 0.69 * r)], sharp=80)
    for i in range(bulbs):
        a = 2.0 * math.pi * i / bulbs
        ball("bulb", mat("ff3d7f" if i % 2 == 0 else "ffe14a", 0.3, 0.0, 2.5), 0.065 * r, loc=(math.sin(a) * 0.78 * r, math.cos(a) * 0.78 * r, 0.085 * r))


def alien_crab():
    saucer(0.85, "c9cfd6", 6, "8be04e")
    return 2.0, 0.0


def alien_saucer():
    saucer(1.05, "d9c27a", 8, "b9bfca", "86ff4a")
    return 2.4, 0.0


def alien_diver():
    """A chrome rocket, nose down, flame out of the top."""
    chrome = mat("c9cfd6", 0.18, 0.7)
    red = mat("e0263c", 0.35)
    lathe("body", chrome, [(0.2, -0.3), (0.3, -0.05), (0.31, 0.2), (0.24, 0.44), (0.17, 0.52), (0.0, 0.52)])
    lathe("nose", red, [(0.0, -0.78), (0.07, -0.62), (0.2, -0.3)])
    lathe("band", red, [(0.305, 0.22), (0.318, 0.25), (0.305, 0.28)])
    lathe("flame", mat("ffb02e", 0.3, 0.0, 3.0), [(0.15, 0.52), (0.1, 0.68), (0.0, 0.92)], n=12)
    ball("port", mat("86ff4a", 0.1, 0.0, 1.2), (0.13, 0.05, 0.13), loc=(0, -0.28, 0.02))
    lathe("port_ring", chrome, [(0.13, 0.0), (0.16, 0.02), (0.13, 0.04)], n=16, loc=(0, -0.26, 0.02), rot=(90, 0, 0))
    for i in range(3):
        fin = pivot("fin", (0, 0, 0), rot=(0, 0, i * 120.0))
        plate("fin", red, [(0.24, 0.02), (0.72, 0.6), (0.62, 0.72), (0.2, 0.46)], 0.04, parent=fin)
    return 2.0, 0.0


def alien_brute():
    """Talos, the Titans' bronze automaton: all boxes, rivets and claws, under a centurion's crest."""
    tin = mat("c8823a", 0.28, 0.6)
    tin2 = mat("7a4a22", 0.35, 0.5)
    dark = mat("22252d", 0.45, 0.3)
    red = mat("2fb5a0", 0.4)
    box("body", tin, (1.4, 0.8, 1.1), loc=(0, 0, -0.05), bevel=0.07)
    box("head", mat("d99a4a", 0.25, 0.6), (0.9, 0.66, 0.6), loc=(0, 0, 0.8), bevel=0.06)
    box("visor", mat("08080c", 0.3), (0.7, 0.06, 0.18), loc=(0, -0.33, 0.86), bevel=0.01)
    for s, sn in SIDES:
        box("eye", mat("ffb02e", 0.3, 0.0, 3.0), (0.24, 0.06, 0.09), loc=(s * 0.17, -0.35, 0.86), bevel=0.01)
        lathe("ear", red, [(0.0, 0.0), (0.12, 0.02), (0.12, 0.08), (0.0, 0.1)], n=14, loc=(s * 0.45, 0, 0.8), rot=(0, s * 90.0, 0))
        arm = pivot("arm_" + sn, (s * 0.86, 0.0, 0.3))
        ball("shoulder", dark, 0.2, parent=arm)
        for i in range(4):
            lathe("arm_ring", tin2, [(0.14, 0.0), (0.2, 0.05), (0.2, 0.13), (0.14, 0.18)], n=14, parent=arm, loc=(s * 0.08, 0, -0.34 - i * 0.18))
        for j in (-1.0, 1.0):
            plate("claw", red, [(0.0, 0.0), (0.12, -0.1), (0.1, -0.34), (0.0, -0.4), (0.03, -0.2)], 0.24, parent=arm, loc=(s * 0.08 + j * 0.12, 0, -0.86), scale=(-j, 1, 1))
        box("leg", tin2, (0.44, 0.5, 0.5), loc=(s * 0.36, 0, -0.86), bevel=0.04)
        box("foot", dark, (0.5, 0.66, 0.14), loc=(s * 0.36, -0.08, -1.1), bevel=0.03)
        for i in range(3):
            ball("rivet", mat("f0c070", 0.2, 0.6), 0.035, loc=(s * 0.62, -0.4, -0.45 + i * 0.4))
    plate("crest", mat("ff5a1a", 0.5), [(-0.5, 1.08), (-0.42, 1.34), (0.0, 1.46), (0.42, 1.34), (0.5, 1.08)], 0.08)
    box("panel", mat("22303a", 0.3), (0.9, 0.05, 0.44), loc=(0, -0.41, 0.0), bevel=0.01)
    for i, c in enumerate(("ffe14a", "86ff4a", "ff3d7f")):
        ball("lamp", mat(c, 0.3, 0.0, 2.5), 0.09, loc=((i - 1) * 0.26, -0.44, 0.04))
    lathe("key", red, [(0.0, 0.0), (0.05, 0.0), (0.05, 0.3), (0.0, 0.3)], n=8, loc=(0, 0.4, 0.1), rot=(-90, 0, 0))
    plate("key_wings", red, [(-0.22, 0.0), (-0.3, 0.14), (-0.18, 0.26), (0.0, 0.1), (0.18, 0.26), (0.3, 0.14), (0.22, 0.0), (0.0, -0.06)], 0.05, loc=(0, 0.74, 0.0), rot=(0, 0, 90))
    return 3.0, 0.1


def alien_boss():
    """The mothership: a wide saucer with a bridge of portholes, a ring of bulbs and a ray lens beneath."""
    tin = mat("c9cfd6", 0.2, 0.6)
    tin2 = mat("8d96a3", 0.28, 0.5)
    dark = mat("3a3f4c", 0.4, 0.3)
    squash = (1.0, 0.46, 1.0)
    lathe("hull", tin, [(0.0, -0.5), (0.8, -0.46), (1.3, -0.3), (2.62, -0.14), (2.7, -0.08), (2.62, -0.02), (1.6, 0.14), (0.0, 0.2)], n=40, scale=squash, sharp=30)
    lathe("rim", dark, [(2.56, -0.11), (2.72, -0.08), (2.56, -0.05)], n=40, scale=squash)
    lathe("deck", tin2, [(1.7, 0.1), (1.78, 0.2), (1.5, 0.34), (0.0, 0.4)], n=40, scale=squash, sharp=30)
    lathe("bridge", mat("aeb6c2", 0.25, 0.5), [(1.1, 0.3), (1.14, 0.5), (0.95, 0.8), (0.55, 0.98), (0.0, 1.02)], n=32, scale=(1.0, 0.68, 1.0), sharp=50)
    for i in range(3):
        at = Vector(((i - 1) * 0.6, -0.68 if i == 1 else -0.58, 0.58))
        r = 0.22 if i == 1 else 0.18
        ball("port", mat("0f2a14", 0.1), r, loc=at)
        lathe("port_ring", dark, [(r * 0.95, 0.0), (r * 1.25, 0.03), (r * 0.95, 0.06)], n=16, loc=at + Vector((0, -0.02, 0)), rot=(90, 0, 0))
        ball("pilot_eye", mat("86ff4a", 0.3, 0.0, 2.0), (0.1, 0.05, 0.13), loc=at + Vector((0, -r * 0.82, 0)))
    for i in range(14):
        a = 2.0 * math.pi * i / 14
        ball("bulb", mat(("ff3d7f", "ffe14a", "86ff4a")[i % 3], 0.3, 0.0, 2.5), 0.11, loc=(math.sin(a) * 2.42, -math.cos(a) * 2.42 * 0.46, 0.04))
    lathe("cannon", dark, [(0.6, -0.42), (0.5, -0.7), (0.36, -0.88), (0.0, -0.88)], n=24)
    lathe("lens", mat("ff2d3d", 0.1, 0.0, 3.5), [(0.0, -0.93), (0.2, -0.91), (0.28, -0.87)], n=24)
    for s, _ in SIDES:
        loft("antenna", dark, [(0.0, 0.02, 0.02), (0.62, 0.012, 0.012)], n=8, loc=(s * 0.5, 0, 0.92), rot=(0, s * 18.0, 0))
        ball("antenna_tip", mat("ff3d7f", 0.3, 0.0, 3.0), 0.08, loc=(s * 0.7, 0, 1.52))
        lathe("pod", dark, [(0.0, -0.84), (0.16, -0.78), (0.22, -0.5), (0.18, -0.3)], n=16, loc=(s * 1.35, 0, 0))
        lathe("pod_light", mat("ffb02e", 0.3, 0.0, 3.0), [(0.0, -0.87), (0.1, -0.85), (0.14, -0.8)], n=16, loc=(s * 1.35, 0, 0))
    return 5.8, 0.1


def alien_kaiju():
    """A rubber toy kaiju: a fat green dinosaur with a row of back plates, stubby arms, a heavy tail
    and a wind-up key. It stands on the street, so it is centred on the origin with its feet 1.5 below."""
    hide = mat("5fbf4a", 0.55)
    belly = mat("d9e88a", 0.55)
    dark = mat("2f6f2a", 0.55)
    loft("body", hide, [(-0.75, 0.3, 0.3), (-0.5, 0.62, 0.6), (0.05, 0.7, 0.62), (0.55, 0.5, 0.46), (0.85, 0.3, 0.3)], n=20, subdiv=1, sharp=80)
    loft("belly", belly, [(-0.62, 0.3, 0.1), (-0.3, 0.46, 0.14), (0.25, 0.44, 0.14), (0.6, 0.26, 0.1)], n=16, loc=(0, -0.5, 0), subdiv=1, sharp=80)
    for i in range(4):
        loft("belly_fold", dark, [(0.0, 0.34 - i * 0.03, 0.012, 3.0), (0.03, 0.34 - i * 0.03, 0.012, 3.0)], n=12, loc=(0, -0.63, -0.35 + i * 0.24))
    # Head: big jaw, teeth, angry eyes
    head = pivot("head", (0.0, -0.2, 1.0))
    loft("skull", hide, [(-0.2, 0.26, 0.26), (0.0, 0.36, 0.4, 2.6), (0.24, 0.33, 0.36, 2.6), (0.44, 0.14, 0.2)], n=18, parent=head, subdiv=1, sharp=80)
    loft("snout", hide, [(0.0, 0.26, 0.12, 3.0), (0.4, 0.2, 0.1, 3.0), (0.5, 0.1, 0.06, 3.0)], n=14, parent=head, loc=(0, -0.1, 0.12), rot=(90, 0, 0))
    loft("jaw", dark, [(0.0, 0.24, 0.07, 3.0), (0.36, 0.18, 0.06, 3.0), (0.46, 0.08, 0.04, 3.0)], n=14, parent=head, loc=(0, -0.1, -0.08), rot=(104, 0, 0))
    for i in range(5):
        loft("tooth", mat("fff6d8", 0.3), [(0.0, 0.03, 0.03), (0.09, 0.0, 0.0)], n=6, parent=head, loc=((i - 2) * 0.085, -0.5 + abs(i - 2) * 0.03, 0.06), rot=(180, 0, 0))
    for s, _ in SIDES:
        ball("eye", mat("ffe14a", 0.2, 0.0, 1.5), (0.075, 0.05, 0.085), parent=head, loc=(s * 0.2, -0.3, 0.3), rot=(0, s * 20.0, s * 14.0))
        ball("pupil", mat("08080c", 0.1), (0.03, 0.025, 0.06), parent=head, loc=(s * 0.2, -0.345, 0.3))
        plate("brow", dark, [(-0.11, 0.0), (0.11, 0.05), (0.11, 0.1), (-0.11, 0.04)], 0.05, parent=head, loc=(s * 0.2, -0.33, 0.37), scale=(-s, 1, 1))
        # Stubby arms and thick legs, on pivots so they waddle
        arm = pivot("arm_" + ("l" if s < 0 else "r"), (s * 0.58, -0.25, 0.42))
        loft("arm", hide, [(0.0, 0.12, 0.12), (-0.3, 0.1, 0.1), (-0.42, 0.07, 0.07)], n=12, parent=arm, rot=(-40, 0, 0))
        for i in range(3):
            loft("claw", mat("fff6d8", 0.3), [(0.0, 0.025, 0.025), (0.1, 0.0, 0.0)], n=6, parent=arm, loc=((i - 1) * 0.05, -0.3, -0.34), rot=(140, 0, 0))
        leg = pivot("leg_" + ("l" if s < 0 else "r"), (s * 0.42, 0.0, -0.6))
        loft("thigh", hide, [(0.1, 0.26, 0.3), (-0.4, 0.22, 0.24), (-0.82, 0.24, 0.26)], n=14, parent=leg)
        loft("foot", dark, [(-0.1, 0.24, 0.1, 3.0), (0.3, 0.26, 0.1, 3.0), (0.44, 0.16, 0.06, 3.0)], n=14, parent=leg, loc=(0, 0.0, -0.8), rot=(90, 0, 0))
    # Tail and back plates
    loft("tail", hide, [(0.0, 0.34, 0.3), (0.6, 0.22, 0.2), (1.2, 0.1, 0.1), (1.6, 0.0, 0.0)], n=14, loc=(0, 0.35, -0.55), rot=(-78, 0, 0), subdiv=1, sharp=80)
    for i in range(6):
        size = 0.34 - abs(i - 1.5) * 0.05
        plate("plate", mat("ff7a1a", 0.45), [(-size * 0.6, 0.0), (size * 0.6, 0.0), (0.0, size)], 0.05, loc=(0, 0.5 + max(0, i - 3) * 0.3, 0.8 - i * 0.36), rot=(-20 - i * 12, 0, 90))
    # The wind-up key in its back
    lathe("key_shaft", mat("c9cfd6", 0.2, 0.6), [(0.0, 0.0), (0.04, 0.0), (0.04, 0.3), (0.0, 0.3)], n=8, loc=(0.34, 0.5, 0.1), rot=(-90, 0, 0))
    plate("key", mat("c9cfd6", 0.2, 0.6), [(-0.2, 0.0), (-0.26, 0.12), (-0.16, 0.22), (0.0, 0.08), (0.16, 0.22), (0.26, 0.12), (0.2, 0.0), (0.0, -0.05)], 0.04, loc=(0.34, 0.84, 0.1), rot=(0, 0, 90))
    return 3.6, 0.0


def alien_prism():
    """The Oort Cloud Collective: a flawless blue crystal, eight faces and nothing else, hanging
    point down. It does not move so much as arrive."""
    crystal = mat("2f6bff", 0.04, 0.3, 0.35)
    loft("crystal", crystal, [(-1.0, 0.0, 0.0), (0.0, 1.0, 1.0), (1.0, 0.0, 0.0)], n=4, sharp=5.0)
    loft("seam", mat("bfe0ff", 0.1, 0.0, 2.5), [(-0.012, 1.008, 1.008), (0.012, 1.008, 1.008)], n=4, sharp=5.0)
    ball("heart", mat("ff2d3d", 0.2, 0.0, 3.0), 0.16)
    return 2.8, 0.0


def alien_seraph():
    """A deep-space harrier: a white, eyeless thing with a long skull, a wide red grin, leathery
    wings and a two-bladed spear."""
    white = mat("f2f2ee", 0.45)
    grey = mat("8a8f98", 0.4, 0.3)
    red = mat("d0182e", 0.35)
    humanoid(white, white, grey)
    head = pivot("head", (0, -0.04, 0.5))
    loft("skull", white, [(-0.3, 0.1, 0.12), (-0.05, 0.2, 0.22), (0.3, 0.19, 0.2), (0.62, 0.1, 0.12), (0.72, 0.0, 0.0)], n=16, parent=head, rot=(68, 0, 0), subdiv=1, sharp=80)
    loft("grin", red, [(0.2, 0.17, 0.035, 3.0), (0.56, 0.1, 0.03, 3.0), (0.66, 0.0, 0.0)], n=12, parent=head, loc=(0, -0.02, -0.11), rot=(68, 0, 0))
    for i in range(6):
        box("tooth", mat("fff6d8", 0.3), (0.035, 0.03, 0.05), parent=head, loc=((i - 2.5) * 0.05, -0.36 - abs(i - 2.5) * 0.02, -0.02), bevel=0.004)
    for s, sn in SIDES:
        wing = pivot("wing_" + sn, (s * 0.12, 0.16, 0.05), rot=(0, s * -18.0, s * 24.0))
        plate("wing", white, [(0.0, 0.1), (s * 0.5, 0.75), (s * 1.25, 0.95), (s * 1.05, 0.45), (s * 1.3, 0.1), (s * 0.85, -0.05), (s * 0.95, -0.5), (s * 0.45, -0.25), (0.0, -0.3)], 0.03, parent=wing)
        for i in range(3):
            loft("wing_bone", grey, [(0.0, 0.02, 0.02), (1.1 - i * 0.2, 0.008, 0.008)], n=6, parent=wing, loc=(0, -0.02, 0.0), rot=(0, s * (38.0 + i * 34.0), 0))
    spear = pivot("spear", (0.0, -0.06, -0.84), parent=bpy.data.objects["arm_r"], rot=(0, 0, 0))
    loft("shaft", grey, [(-0.9, 0.022, 0.022), (0.9, 0.022, 0.022)], n=8, parent=spear, rot=(90, 0, 0))
    for end in (-1.0, 1.0):
        plate("blade", mat("3a3f4c", 0.25, 0.5), [(-0.07, 0.0), (0.07, 0.0), (0.1, 0.3), (0.0, 0.62), (-0.1, 0.3)], 0.025, parent=spear, loc=(0, -end * 0.9, 0), rot=(90 if end > 0 else -90, 0, 0))
    return 3.2, 0.0


def alien_turtle():
    """A second toy kaiju: an upright turtle with a studded shell and tusks."""
    hide = mat("7a9a4a", 0.55)
    belly = mat("e8d88a", 0.55)
    shell = mat("6a4a2a", 0.5)
    loft("body", hide, [(-0.8, 0.3, 0.3), (-0.45, 0.6, 0.52), (0.1, 0.66, 0.54), (0.6, 0.46, 0.4), (0.82, 0.28, 0.26)], n=20, subdiv=1, sharp=80)
    loft("plastron", belly, [(-0.62, 0.3, 0.1), (-0.25, 0.48, 0.14), (0.3, 0.46, 0.14), (0.62, 0.26, 0.1)], n=16, loc=(0, -0.42, 0), subdiv=1, sharp=80)
    ball("shell", shell, (0.82, 0.5, 0.95), loc=(0, 0.34, 0.0), subdiv=1)
    for i in range(7):
        a = i * 0.9
        ball("stud", mat("c9a04a", 0.4), 0.11, loc=(math.cos(a) * 0.45, 0.78 - abs(math.cos(a)) * 0.08, math.sin(a) * 0.6))
    head = pivot("head", (0.0, -0.22, 0.95))
    loft("skull", hide, [(-0.2, 0.2, 0.2), (0.05, 0.3, 0.32), (0.3, 0.24, 0.26), (0.46, 0.1, 0.12)], n=16, parent=head, subdiv=1, sharp=80)
    loft("beak", mat("c9a04a", 0.4), [(0.0, 0.2, 0.1, 3.0), (0.3, 0.12, 0.07, 3.0), (0.4, 0.0, 0.0)], n=12, parent=head, loc=(0, -0.12, 0.06), rot=(96, 0, 0))
    for s, _ in SIDES:
        loft("tusk", mat("fff6d8", 0.3), [(0.0, 0.04, 0.04), (0.26, 0.0, 0.0)], n=8, parent=head, loc=(s * 0.13, -0.34, -0.02), rot=(20, s * 12.0, 0))
        ball("eye", mat("ff3d3d", 0.2, 0.0, 2.0), (0.06, 0.04, 0.07), parent=head, loc=(s * 0.17, -0.24, 0.24))
        arm = pivot("arm_" + ("l" if s < 0 else "r"), (s * 0.6, -0.2, 0.38))
        loft("flipper", hide, [(0.0, 0.14, 0.1), (-0.32, 0.16, 0.07), (-0.55, 0.08, 0.04)], n=12, parent=arm, rot=(-30, 0, 0))
        leg = pivot("leg_" + ("l" if s < 0 else "r"), (s * 0.4, 0.0, -0.62))
        loft("leg", hide, [(0.1, 0.24, 0.26), (-0.45, 0.22, 0.24), (-0.82, 0.26, 0.28)], n=14, parent=leg)
        loft("foot", shell, [(-0.1, 0.25, 0.1, 3.0), (0.3, 0.27, 0.1, 3.0), (0.42, 0.16, 0.06, 3.0)], n=14, parent=leg, loc=(0, 0.0, -0.8), rot=(90, 0, 0))
    loft("tail", hide, [(0.0, 0.2, 0.18), (0.5, 0.1, 0.1), (0.8, 0.0, 0.0)], n=12, loc=(0, 0.4, -0.7), rot=(-80, 0, 0))
    return 3.6, 0.0


# --- The Europans: things from the sea under the ice ----------------------------------------------

def alien_jelly():
    """A jellyfish: a glass bell with a lit heart, trailing four tentacles that swing as it is jerked along."""
    glass = mat("9fe8ff", 0.08, 0.0, 0.0, 0.5)
    flesh = mat("e8f6ff", 0.3)
    glow = mat("ff5fd0", 0.3, 0.0, 3.0)
    lathe("bell", glass, [(0.0, 0.95), (0.34, 0.9), (0.62, 0.68), (0.74, 0.36), (0.7, 0.12)], sharp=60, bevel=0.0)
    lathe("skirt", flesh, [(0.6, 0.14), (0.76, 0.1), (0.72, 0.03), (0.5, 0.07)], sharp=60, bevel=0.0)
    ball("heart", glow, (0.2, 0.2, 0.27), loc=(0, 0, 0.5))
    for s, _ in SIDES:
        ball("eye", mat("08080c", 0.05), (0.09, 0.06, 0.12), loc=(s * 0.23, -0.66, 0.42))
    for i in range(8):
        a = 2.0 * math.pi * (i + 0.5) / 8
        ball("bulb", glow, 0.05, loc=(math.sin(a) * 0.74, math.cos(a) * 0.74, 0.09))
    for name, at in (("arm_l", (-0.4, -0.08, 0.06)), ("arm_r", (0.4, -0.08, 0.06)), ("leg_l", (-0.15, 0.12, 0.06)), ("leg_r", (0.15, 0.12, 0.06))):
        limb = pivot(name, at)
        wave = 1.0 if name.endswith("l") else -1.0
        loft("tentacle", flesh, [(-i * 0.16, 0.07 * (1.0 - i / 8.0) + 0.012, 0.07 * (1.0 - i / 8.0) + 0.012, 2.0, math.sin(i * 1.3) * 0.07 * wave, 0.0) for i in range(8)], n=8, parent=limb, sharp=80)
        ball("tip", glow, 0.045, parent=limb, loc=(math.sin(7 * 1.3) * 0.07 * wave, 0, -1.14))
    return 2.8, 0.0


def alien_squid():
    """A torpedo squid, diving point first with its arms streaming behind it."""
    hide = mat("f4e9ff", 0.25)
    dark = mat("3a2a6a", 0.4)
    spot = mat("5ff0ff", 0.3, 0.0, 3.0)
    lathe("mantle", hide, [(0.0, -0.85), (0.12, -0.66), (0.26, -0.3), (0.3, 0.0), (0.25, 0.22), (0.2, 0.26)], n=20, sharp=60, bevel=0.0)
    lathe("crown", dark, [(0.2, 0.24), (0.27, 0.34), (0.2, 0.46), (0.0, 0.48)], n=20, bevel=0.0)
    for s, _ in SIDES:
        plate("fin", dark, [(0.0, -0.8), (s * 0.44, -0.52), (s * 0.38, -0.3), (0.0, -0.36)], 0.04, loc=(s * 0.08, 0, 0))
        ball("eye", mat("fff6d8", 0.15), 0.1, loc=(s * 0.2, -0.13, 0.34))
        ball("pupil", mat("08080c", 0.1), 0.055, loc=(s * 0.22, -0.2, 0.34))
    for i, (z, y) in enumerate(((-0.08, -0.3), (-0.26, -0.27), (-0.44, -0.22))):
        ball("spot", spot, 0.045 - i * 0.006, loc=(0, y, z))
    for i in range(6):
        a = math.radians(i * 60.0 + 30.0)
        loft("arm", hide, [(0.0, 0.05, 0.05), (0.3, 0.04, 0.04, 2.0, 0.04, 0.0), (0.58, 0.022, 0.022, 2.0, -0.03, 0.0), (0.76, 0.0, 0.0)], n=8,
             loc=(math.cos(a) * 0.12, math.sin(a) * 0.12, 0.44), rot=toward((math.cos(a) * 0.34, math.sin(a) * 0.34, 1.0)), sharp=80)
    return 2.4, 0.15


def alien_angler():
    """An anglerfish from the dark under the ice: all jaw, with a lit lure hung over it."""
    hide = mat("1c2a4a", 0.45)
    belly = mat("3b5a8c", 0.45)
    tooth = mat("fff6d8", 0.3)
    lure = mat("9dff5a", 0.3, 0.0, 3.5)
    ball("body", hide, (0.72, 0.62, 0.66))
    ball("mouth", mat("5a0f1e", 0.5), (0.5, 0.2, 0.27), loc=(0, -0.48, -0.14))
    loft("jaw", belly, [(0.0, 0.52, 0.12, 3.0), (0.3, 0.44, 0.1, 3.0), (0.42, 0.2, 0.05, 3.0)], n=14, loc=(0, -0.32, -0.4), rot=(90, 0, 0))
    for i in range(7):
        loft("tooth", tooth, [(0.0, 0.04, 0.04), (0.22 - abs(i - 3) * 0.02, 0.0, 0.0)], n=6, loc=((i - 3) * 0.13, -0.7 + abs(i - 3) * 0.045, -0.34))
    for i in range(6):
        loft("fang", tooth, [(0.0, 0.035, 0.035), (0.16, 0.0, 0.0)], n=6, loc=((i - 2.5) * 0.14, -0.62 + abs(i - 2.5) * 0.03, 0.06), rot=(180, 0, 0))
    for s, sn in SIDES:
        ball("eye", mat("d8f6ff", 0.1, 0.0, 0.6), 0.12, loc=(s * 0.36, -0.47, 0.26))
        ball("pupil", mat("08080c", 0.1), 0.05, loc=(s * 0.37, -0.57, 0.26))
        fin = pivot("arm_" + sn, (s * 0.66, 0.0, -0.05))
        plate("fin", belly, [(0.0, 0.1), (s * 0.42, 0.3), (s * 0.5, -0.02), (s * 0.4, -0.3), (0.0, -0.12)], 0.04, parent=fin)
    for i in range(3):
        loft("spine", belly, [(0.0, 0.05, 0.05), (0.3 - i * 0.05, 0.0, 0.0)], n=6, loc=(0, 0.1 + i * 0.2, 0.6 - i * 0.08), rot=(-20 - i * 20, 0, 0))
    loft("stalk", hide, [(0.0, 0.035, 0.035), (0.3, 0.028, 0.028, 2.0, 0, -0.1), (0.48, 0.022, 0.022, 2.0, 0, -0.3), (0.5, 0.02, 0.02, 2.0, 0, -0.5)], n=8, loc=(0, -0.15, 0.58), sharp=80)
    ball("lure", lure, 0.11, loc=(0, -0.68, 1.06))
    return 2.4, 0.15


def _urchin(r, spikes, length):
    hide = mat("3a1f5c", 0.45)
    spike = mat("7a4fd0", 0.35)
    tip = mat("5ff0ff", 0.3, 0.0, 3.0)
    ball("body", hide, r)
    for i, d in enumerate(around(spikes)):
        if d.y < -0.72:
            continue
        loft("spike", spike, [(0.0, r * 0.11, r * 0.11), (length, 0.0, 0.0)], n=6, loc=d * r * 0.9, rot=toward(d))
        if i % 3 == 0:
            ball("tip", tip, r * 0.07, loc=d * (r * 0.9 + length))
    eyeball(pivot("head", (0, 0, 0)), (0, -r * 0.76, 0), r * 0.42, "5ff0ff")


def alien_urchin():
    """A sea urchin with one staring eye. It bursts into two little ones."""
    _urchin(0.48, 28, 0.42)
    return 2.2, 0.0


def alien_polyp():
    """What an urchin bursts into."""
    _urchin(0.26, 14, 0.2)
    return 1.2, 0.0


# --- The Titans: bronze and stone giants from under Saturn ----------------------------------------

def alien_hoplite():
    """A squat giant in bronze: a crested helmet with a glowing slit, a round shield and a spear."""
    bronze = mat("e0a040", 0.28, 0.6)
    dark = mat("7a4a22", 0.35, 0.5)
    clay = mat("6a7080", 0.6)
    black = mat("08080c", 0.4)
    glow = mat("ffb02e", 0.3, 0.0, 3.0)
    patina = mat("2fb5a0", 0.4)
    loft("cuirass", bronze, [(-0.45, 0.3, 0.24, 2.6), (-0.1, 0.4, 0.3, 2.6), (0.25, 0.46, 0.3, 2.8), (0.4, 0.3, 0.22, 2.6)])
    for i in range(5):
        box("strap", dark, (0.13, 0.05, 0.3), loc=((i - 2) * 0.15, -0.26 + abs(i - 2) * 0.035, -0.56), bevel=0.01)
    head = pivot("head", (0, 0, 0.42))
    loft("helmet", bronze, [(0.0, 0.26, 0.28, 2.4), (0.25, 0.3, 0.32, 2.4), (0.5, 0.24, 0.27), (0.62, 0.0, 0.0)], parent=head, sharp=60)
    box("slit", black, (0.36, 0.05, 0.08), parent=head, loc=(0, -0.3, 0.32), bevel=0.01)
    box("nose_slit", black, (0.08, 0.05, 0.26), parent=head, loc=(0, -0.3, 0.17), bevel=0.01)
    for s, _ in SIDES:
        box("eye", glow, (0.1, 0.04, 0.05), parent=head, loc=(s * 0.1, -0.32, 0.32), bevel=0.005)
    plate("crest", mat("ff5a1a", 0.5), [(-0.38, 0.48), (-0.32, 0.78), (0.0, 0.94), (0.32, 0.78), (0.38, 0.48), (0.0, 0.58)], 0.07, parent=head)
    for s, sn in SIDES:
        arm = pivot("arm_" + sn, (s * 0.52, 0.0, 0.25))
        ball("shoulder", bronze, 0.16, parent=arm)
        loft("upper", clay, [(0.0, 0.11, 0.11), (-0.38, 0.09, 0.09)], n=10, parent=arm)
        loft("bracer", bronze, [(-0.38, 0.1, 0.1), (-0.7, 0.085, 0.085)], n=10, parent=arm)
        ball("fist", clay, 0.105, parent=arm, loc=(0, 0, -0.76))
        leg = pivot("leg_" + sn, (s * 0.18, 0.0, -0.5))
        loft("thigh", clay, [(0.0, 0.13, 0.13), (-0.3, 0.11, 0.11)], n=10, parent=leg)
        loft("greave", bronze, [(-0.3, 0.115, 0.115), (-0.6, 0.085, 0.085)], n=10, parent=leg)
        box("sandal", dark, (0.18, 0.32, 0.08), parent=leg, loc=(0, -0.06, -0.64), bevel=0.02)
    arm = bpy.data.objects["arm_l"]
    lathe("shield", bronze, [(0.0, 0.0), (0.42, 0.0), (0.44, 0.03), (0.3, 0.08), (0.1, 0.11), (0.0, 0.12)], n=24, parent=arm, loc=(-0.06, -0.14, -0.55), rot=(90, 0, 0), sharp=30, bevel=0.0)
    hoop("shield_rim", patina, 0.36, 0.45, 0.03, n=24, parent=arm, loc=(-0.06, -0.17, -0.55), rot=(90, 0, 0))
    ball("shield_boss", glow, 0.08, parent=arm, loc=(-0.06, -0.27, -0.55))
    arm = bpy.data.objects["arm_r"]
    loft("spear", dark, [(-0.4, 0.025, 0.025), (1.3, 0.025, 0.025)], n=8, parent=arm, loc=(0.02, -0.11, -0.74))
    plate("spear_tip", bronze, [(-0.07, 1.3), (0.07, 1.3), (0.0, 1.62)], 0.03, parent=arm, loc=(0.02, -0.11, -0.74))
    return 2.8, 0.1


def alien_meteor():
    """A burning boulder with a face in it, falling on the city."""
    stone = mat("5a3a2a", 0.7)
    hot = mat("ff7a1a", 0.3, 0.0, 3.5)
    rock("rock", stone, (0.5, 0.46, 0.5), seed=3, loc=(0, 0, -0.15))
    for s, _ in SIDES:
        box("eye", hot, (0.17, 0.08, 0.07), loc=(s * 0.18, -0.41, -0.06), rot=(0, s * 22.0, 0), bevel=0.01)
        rock("pebble", stone, 0.12, seed=5, loc=(s * 0.42, 0.1, 0.5 + s * 0.12))
    plate("mouth", hot, [(-0.2, -0.3), (-0.1, -0.25), (0.0, -0.3), (0.1, -0.25), (0.2, -0.3), (0.1, -0.39), (0.0, -0.34), (-0.1, -0.39)], 0.06, loc=(0, -0.4, 0), bevel=0.0)
    for i, (x, y, tall) in enumerate(((0.0, 0.0, 1.3), (-0.24, 0.05, 0.95), (0.24, 0.05, 1.0), (-0.1, -0.2, 0.8), (0.12, 0.18, 0.85))):
        strut("flame", hot if i % 2 == 0 else mat("ffe14a", 0.3, 0.0, 3.5), (x, y, 0.1), (x * 1.5, y * 1.5, tall), 0.2, 0.0, n=6)
    return 2.2, 0.25


def alien_saturn():
    """A sour little ringed planet with one eye. It breaks up into two moons."""
    paints = (mat("e8b060", 0.45), mat("c8823a", 0.45), mat("f4d8a0", 0.45))
    banded("planet", paints, 0.5, [-90, -52, -24, -6, 20, 46, 90])
    hoop("ring", mat("d9c27a", 0.3, 0.3), 0.7, 0.98, 0.025, rot=(22, 14, 0))
    hoop("ring_inner", mat("9a6a3a", 0.3, 0.3), 0.6, 0.67, 0.025, rot=(22, 14, 0))
    head = pivot("head", (0, 0, 0))
    eyeball(head, (0, -0.4, 0.06), 0.2, "2fb5a0")
    plate("brow", mat("7a4a22", 0.5), [(-0.26, 0.12), (0.0, 0.0), (0.26, 0.12), (0.26, 0.2), (0.0, 0.09), (-0.26, 0.2)], 0.08, loc=(0, -0.45, 0.22), bevel=0.0)
    return 2.2, 0.0


def alien_moon():
    """What the ringed planet breaks up into: a cratered moon with an eye."""
    rock("moon", mat("9a9aa8", 0.7), 0.3, seed=11, rough=0.08)
    for at in ((0.18, -0.16, 0.16), (-0.2, -0.1, -0.16), (0.05, 0.1, 0.27)):
        ball("crater", mat("5a5a68", 0.7), (0.08, 0.08, 0.08), loc=at)
    eyeball(pivot("head", (0, 0, 0)), (-0.03, -0.24, 0.02), 0.12, "ffb02e")
    return 1.2, 0.0


def alien_cyclops():
    """The Titans' kaiju: a clay giant with one eye, a horn, tusks and a studded club."""
    clay = mat("a8623a", 0.65)
    dark = mat("6a3a22", 0.65)
    bronze = mat("c8823a", 0.28, 0.6)
    bone = mat("fff6d8", 0.3)
    loft("body", clay, [(-0.6, 0.42, 0.36), (-0.2, 0.5, 0.4), (0.4, 0.66, 0.44, 2.6), (0.75, 0.56, 0.38, 2.6), (0.9, 0.3, 0.26)], n=18, sharp=80)
    loft("belt", bronze, [(-0.5, 0.46, 0.39), (-0.36, 0.51, 0.42)])
    plate("loincloth", mat("b0122e", 0.6), [(-0.24, 0.0), (0.24, 0.0), (0.17, -0.5), (0.0, -0.62), (-0.17, -0.5)], 0.05, loc=(0, -0.41, -0.45))
    head = pivot("head", (0, -0.1, 0.95))
    loft("skull", clay, [(-0.1, 0.3, 0.3), (0.15, 0.4, 0.38, 2.4), (0.42, 0.34, 0.32), (0.56, 0.0, 0.0)], n=16, parent=head, sharp=80)
    eyeball(head, (0, -0.34, 0.24), 0.18, "ffb02e")
    plate("brow", dark, [(-0.32, 0.12), (0.0, 0.0), (0.32, 0.12), (0.32, 0.22), (0.0, 0.1), (-0.32, 0.22)], 0.1, parent=head, loc=(0, -0.38, 0.38), bevel=0.0)
    loft("horn", bone, [(0.0, 0.08, 0.08), (0.36, 0.0, 0.0)], n=8, parent=head, loc=(0, -0.08, 0.5), rot=(18, 0, 0))
    box("mouth", mat("3a0f14", 0.5), (0.36, 0.06, 0.07), parent=head, loc=(0, -0.36, 0.0), bevel=0.01)
    for s, sn in SIDES:
        loft("tusk", bone, [(0.0, 0.045, 0.045), (0.2, 0.0, 0.0)], n=6, parent=head, loc=(s * 0.15, -0.39, 0.0))
        arm = pivot("arm_" + sn, (s * 0.8, 0.0, 0.62))
        ball("shoulder", bronze if s < 0 else clay, 0.24, parent=arm)
        loft("upper", clay, [(0.0, 0.18, 0.18), (-0.5, 0.15, 0.15)], n=12, parent=arm)
        loft("forearm", clay, [(-0.5, 0.15, 0.15), (-0.95, 0.19, 0.19)], n=12, parent=arm)
        loft("band", bronze, [(-0.82, 0.19, 0.19), (-0.92, 0.2, 0.2)], n=12, parent=arm)
        rock("fist", clay, 0.21, seed=2, rough=0.06, parent=arm, loc=(0, 0, -1.04))
        leg = pivot("leg_" + sn, (s * 0.3, 0.0, -0.55))
        loft("thigh", clay, [(0.05, 0.26, 0.26), (-0.5, 0.2, 0.2), (-0.85, 0.24, 0.24)], n=14, parent=leg)
        loft("foot", dark, [(-0.1, 0.24, 0.1, 3.0), (0.3, 0.26, 0.1, 3.0), (0.44, 0.16, 0.06, 3.0)], n=14, parent=leg, loc=(0, 0.0, -0.85), rot=(90, 0, 0))
    club = pivot("club", (0, -0.05, -1.04), parent=bpy.data.objects["arm_r"], rot=(62, 0, 0))
    loft("club", mat("7a5a3a", 0.7), [(-0.2, 0.06, 0.06), (0.5, 0.1, 0.1), (1.0, 0.2, 0.2), (1.1, 0.12, 0.12)], n=10, parent=club)
    for i in range(5):
        a = i * 1.26
        strut("stud", bone, (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.7 + (i % 2) * 0.2), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.72 + (i % 2) * 0.2), 0.04, 0.0, n=6, parent=club)
    return 3.8, 0.1


# --- The Oort Cloud Collective: ice and crystal, all of one mind ----------------------------------

OORT_BLUE = ("2f6bff", 0.04, 0.3, 0.0, 0.45)
OORT_HEART = ("ff2d3d", 0.2, 0.0, 3.0)
OORT_ICE = ("dff4ff", 0.15, 0.2)
OORT_SEAM = ("bfe0ff", 0.1, 0.0, 2.5)


def alien_cube():
    """A cube of blue ice in a white frame, balanced on one corner around a red heart."""
    ice = mat(*OORT_ICE)
    turn = pivot("turn", (0, 0, 0), parent=pivot("tip", (0, 0, 0), rot=(54.74, 0, 0)), rot=(0, 0, 45))
    h = 0.46
    box("block", mat(*OORT_BLUE), (h * 1.9, h * 1.9, h * 1.9), parent=turn, bevel=0.0)
    for axis in range(3):
        for u in (-h, h):
            for v in (-h, h):
                at = [u, v]
                at.insert(axis, 0.0)
                size = [0.085, 0.085]
                size.insert(axis, h * 2.0 + 0.085)
                box("bar", ice, tuple(size), parent=turn, loc=tuple(at), bevel=0.01)
    ball("heart", mat(*OORT_HEART), 0.2)
    hoop("halo", mat(*OORT_SEAM), 0.9, 0.94, 0.03, n=24, rot=(78, 0, 0))
    return 2.4, 0.0


def alien_shard():
    """A long splinter of the comet, falling point first with lesser splinters round it."""
    blue = mat(*OORT_BLUE)
    loft("spike", blue, [(-1.05, 0.0, 0.0), (-0.3, 0.2, 0.2), (0.35, 0.24, 0.24), (0.6, 0.0, 0.0)], n=6, sharp=5.0)
    loft("seam", mat(*OORT_SEAM), [(0.34, 0.245, 0.245), (0.365, 0.245, 0.245)], n=6, sharp=5.0)
    ball("heart", mat(*OORT_HEART), 0.11, loc=(0, 0, 0.1))
    for i in range(3):
        a = math.radians(i * 120.0 + 90.0)
        crystal("splinter", mat(*OORT_ICE), 0.55, 0.08, loc=(math.cos(a) * 0.34, math.sin(a) * 0.34, 0.25), rot=toward((math.cos(a) * 0.25, math.sin(a) * 0.25, -1.0)))
    lathe("tail", mat(*OORT_SEAM), [(0.15, 0.5), (0.1, 0.85), (0.0, 1.15)], n=6, bevel=0.0)
    return 2.4, 0.05


def alien_cluster():
    """A geode: a lump of dark comet rock with crystals bursting out of it. It shatters into two chips."""
    rock("geode", mat("3a3f4c", 0.7), 0.42, seed=7)
    paints = (mat("8a5cff", 0.08, 0.3), mat("2f6bff", 0.08, 0.3), mat(*OORT_ICE))
    for i, d in enumerate(around(13)):
        if d.y < -0.8:
            continue
        crystal("crystal", paints[i % 3], 0.34 + 0.3 * ((i * 7) % 5) / 4.0, 0.11, loc=d * 0.28, rot=toward(d))
    ball("heart", mat(*OORT_HEART), 0.15, loc=(0, -0.36, 0.0))
    return 2.2, 0.0


def alien_chip():
    """What a geode shatters into: one small crystal."""
    loft("chip", mat("8a5cff", 0.08, 0.3), [(-0.42, 0.0, 0.0), (0.0, 0.2, 0.2), (0.42, 0.0, 0.0)], n=6, sharp=5.0)
    loft("seam", mat(*OORT_SEAM), [(-0.012, 0.204, 0.204), (0.012, 0.204, 0.204)], n=6, sharp=5.0)
    return 1.2, 0.0


def alien_strider():
    """The Collective's kaiju: the great crystal carried over the rooftops on four legs of ice."""
    ice = mat(*OORT_ICE)
    loft("crystal", mat(*OORT_BLUE), [(-0.35, 0.0, 0.0), (0.45, 0.8, 0.8), (1.25, 0.0, 0.0)], n=4, sharp=5.0)
    loft("seam", mat(*OORT_SEAM), [(0.44, 0.806, 0.806), (0.46, 0.806, 0.806)], n=4, sharp=5.0)
    ball("heart", mat(*OORT_HEART), 0.2, loc=(0, 0, 0.45))
    for name, s, y in (("leg_l", -1.0, -0.25), ("leg_r", 1.0, -0.25), ("arm_l", -1.0, 0.3), ("arm_r", 1.0, 0.3)):
        leg = pivot(name, (s * 0.3, y, 0.15))
        knee = (s * 0.55, y * 0.6, 0.55)
        strut("thigh", ice, (0, 0, 0), knee, 0.1, 0.07, n=4, parent=leg, sharp=5.0)
        ball("knee", mat(*OORT_SEAM), 0.09, parent=leg, loc=knee)
        strut("shin", ice, knee, (s * 0.85, y * 1.4, -1.65), 0.09, 0.0, n=4, parent=leg, sharp=5.0)
    return 3.8, 0.0


# --- From deep space: the messengers --------------------------------------------------------------

BONE = ("f2f2ee", 0.45)
CORE = ("ff2d3d", 0.2, 0.0, 3.0)


def alien_orb():
    """A perfect ball in black and white stripes under a thin halo. It has no face and makes no sound."""
    turn = pivot("turn", (0, 0, 0), rot=(24, 18, 0))
    banded("stripe", (mat("0c0c10", 0.25), mat("f2f2ee", 0.25)), 0.7, [-90, -70, -50, -30, -10, 10, 30, 50, 70, 90], parent=turn)
    hoop("halo", mat("fff6d8", 0.2, 0.0, 3.0), 0.5, 0.56, 0.03, loc=(0, 0, 0.92), rot=(12, 0, 0))
    return 2.2, 0.1


def alien_eye():
    """A great orange eye with a lesser eye on each outstretched lobe. It watches the robot."""
    flesh = mat("ff9a2a", 0.4)
    edge = mat("ffd21f", 0.4)
    ball("disc", flesh, (0.6, 0.22, 0.6))
    hoop("iris_ring", edge, 0.44, 0.52, 0.05, loc=(0, -0.17, 0), rot=(90, 0, 0))
    for s, _ in SIDES:
        loft("lobe", flesh, [(0.3, 0.4, 0.16), (0.72, 0.26, 0.12), (1.0, 0.33, 0.12), (1.25, 0.0, 0.0)], n=14, rot=(0, s * 90.0, 0), sharp=80)
        eyeball(None, (s * 0.95, -0.1, 0.0), 0.15, "2a8fff")
        for i in range(3):
            strut("lash", edge, (s * (0.62 + i * 0.17), 0, 0.3), (s * (0.66 + i * 0.2), 0, 0.5), 0.035, 0.0, n=6)
            strut("lash", edge, (s * (0.62 + i * 0.17), 0, -0.3), (s * (0.66 + i * 0.2), 0, -0.5), 0.035, 0.0, n=6)
    eyeball(pivot("head", (0, 0, 0)), (0, -0.16, 0.0), 0.36, "2a8fff")
    return 3.0, 0.0


def alien_bulwark():
    """The strongest of them: a great dark bulk with a skull for a face, a red core behind ribs and
    arms like folded paper."""
    dark = mat("22252d", 0.5)
    bone = mat(*BONE)
    loft("body", dark, [(-0.9, 0.3, 0.26), (-0.5, 0.62, 0.46), (0.2, 0.8, 0.52, 2.6), (0.7, 0.7, 0.46, 2.6), (1.0, 0.36, 0.3)], n=18, sharp=80)
    loft("belly", mat("ff7a1a", 0.5), [(-0.7, 0.3, 0.08), (-0.4, 0.42, 0.1), (-0.22, 0.3, 0.08)], n=12, loc=(0, -0.4, 0))
    head = pivot("face", (0, -0.44, 0.62))  # not "head": a flat mask must not turn to look
    plate("skull", bone, [(-0.26, 0.3), (0.26, 0.3), (0.3, 0.05), (0.16, -0.12), (0.1, -0.3), (-0.1, -0.3), (-0.16, -0.12), (-0.3, 0.05)], 0.12, parent=head)
    for s, sn in SIDES:
        ball("socket", mat("08080c", 0.3), (0.08, 0.05, 0.1), parent=head, loc=(s * 0.13, -0.05, 0.1))
        ball("glint", mat(*CORE), 0.03, parent=head, loc=(s * 0.13, -0.09, 0.1))
        for i in range(3):
            box("rib", bone, (0.34, 0.07, 0.055), loc=(s * 0.27, -0.5, 0.2 - i * 0.15), rot=(0, 0, s * (10.0 + i * 4.0)), bevel=0.015)
        arm = pivot("arm_" + sn, (s * 0.84, 0.0, 0.55))
        ball("shoulder", bone, (0.22, 0.2, 0.18), parent=arm)
        for i in range(3):
            plate("ribbon", bone, [(-0.15, 0.0), (0.15, 0.0), (0.15, -0.4), (-0.15, -0.4)], 0.03, parent=arm, loc=(0, (0.05 if i % 2 else -0.05), -0.12 - i * 0.38), rot=((14 if i % 2 else -14), 0, 0))
        leg = pivot("leg_" + sn, (s * 0.3, 0.0, -0.8))
        loft("leg", dark, [(0.0, 0.2, 0.2), (-0.3, 0.13, 0.13)], n=10, parent=leg)
        ball("foot", bone, (0.14, 0.18, 0.08), parent=leg, loc=(0, -0.04, -0.34))
    for i in range(2):
        box("tooth_row", mat("08080c", 0.3), (0.16, 0.03, 0.02), parent=head, loc=(0, -0.07, -0.18 - i * 0.06), bevel=0.0)
    ball("core", mat(*CORE), 0.2, loc=(0, -0.46, 0.05))
    return 3.0, 0.0


def alien_stalker():
    """The deep-space kaiju: tall, thin and long-armed, with no head: a bone mask on its chest over
    a red core, and bone plates for shoulders."""
    dark = mat("1f3a34", 0.5)
    bone = mat(*BONE)
    loft("torso", dark, [(-0.5, 0.2, 0.16), (0.0, 0.24, 0.18), (0.7, 0.62, 0.3, 2.6), (0.95, 0.5, 0.26, 2.6), (1.05, 0.2, 0.16)], n=18, sharp=80)
    loft("pelvis", bone, [(-0.56, 0.16, 0.14), (-0.42, 0.26, 0.2), (-0.32, 0.2, 0.17)], n=12)
    head = pivot("face", (0, -0.27, 0.9))  # not "head": a flat mask must not turn to look
    plate("mask", bone, [(-0.2, 0.2), (0.0, 0.26), (0.2, 0.2), (0.22, -0.02), (0.06, -0.14), (0.0, -0.36), (-0.06, -0.14), (-0.22, -0.02)], 0.08, parent=head)
    ball("core", mat(*CORE), 0.17, loc=(0, -0.24, 0.38))
    for s, sn in SIDES:
        ball("socket", mat("08080c", 0.3), (0.06, 0.04, 0.06), parent=head, loc=(s * 0.1, -0.04, 0.07))
        for i in range(3):
            box("rib", bone, (0.24, 0.06, 0.045), loc=(s * 0.2, -0.24 + i * 0.012, 0.56 - i * 0.13), rot=(0, 0, s * (16.0 + i * 5.0)), bevel=0.012)
        ball("pauldron", bone, (0.27, 0.22, 0.2), loc=(s * 0.64, 0, 0.98))
        arm = pivot("arm_" + sn, (s * 0.7, 0.0, 0.86))
        loft("upper", dark, [(0.0, 0.1, 0.1), (-0.75, 0.07, 0.07)], n=10, parent=arm)
        strut("elbow_spike", bone, (0, 0.02, -0.75), (0, 0.3, -0.5), 0.06, 0.0, n=6, parent=arm)
        loft("forearm", dark, [(-0.75, 0.07, 0.07), (-1.45, 0.09, 0.09)], n=10, parent=arm)
        for i in range(3):
            strut("claw", bone, ((i - 1) * 0.07, 0, -1.42), ((i - 1) * 0.11, -0.05, -1.75), 0.035, 0.0, n=6, parent=arm)
        leg = pivot("leg_" + sn, (s * 0.2, 0.0, -0.45))
        loft("thigh", dark, [(0.0, 0.14, 0.14), (-0.5, 0.1, 0.1)], n=10, parent=leg)
        ball("knee", bone, 0.11, parent=leg, loc=(0, -0.02, -0.5))
        loft("shin", dark, [(-0.5, 0.1, 0.1), (-0.95, 0.08, 0.08)], n=10, parent=leg)
        loft("foot", dark, [(-0.1, 0.14, 0.07, 3.0), (0.3, 0.16, 0.07, 3.0), (0.42, 0.08, 0.04, 3.0)], n=12, parent=leg, loc=(0, 0, -0.98), rot=(90, 0, 0))
    return 3.8, 0.0


MODELS = {
    "robot": robot, "alien_saucer": alien_saucer, "alien_boss": alien_boss,
    "alien_grunt": alien_grunt, "alien_crab": alien_crab, "alien_diver": alien_diver, "alien_spitter": alien_spitter, "alien_kaiju": alien_kaiju,
    "alien_jelly": alien_jelly, "alien_squid": alien_squid, "alien_angler": alien_angler, "alien_urchin": alien_urchin, "alien_polyp": alien_polyp, "alien_turtle": alien_turtle,
    "alien_hoplite": alien_hoplite, "alien_meteor": alien_meteor, "alien_saturn": alien_saturn, "alien_moon": alien_moon, "alien_brute": alien_brute, "alien_cyclops": alien_cyclops,
    "alien_cube": alien_cube, "alien_shard": alien_shard, "alien_prism": alien_prism, "alien_cluster": alien_cluster, "alien_chip": alien_chip, "alien_strider": alien_strider,
    "alien_orb": alien_orb, "alien_seraph": alien_seraph, "alien_eye": alien_eye, "alien_bulwark": alien_bulwark, "alien_stalker": alien_stalker,
}


# --- Export and preview ---------------------------------------------------------------------------

def preview(path, span, centre_z):
    """Front, three-quarter and back views side by side, for checking the model by eye."""
    import numpy as np
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = 560
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.15, 0.2, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    for loc, power in (((-4, -6, 8), 3.5), ((6, -3, 2), 1.2), ((0, 6, 5), 1.5)):
        sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
        sun.data.energy = power
        sun.location = loc
        sun.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = span
    scene.collection.objects.link(cam)
    scene.camera = cam
    shots = []
    for i, (yaw, pitch) in enumerate(((0, 4), (38, 14), (150, 12))):
        d = Vector((math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), -math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch))))
        target = Vector((0, 0, centre_z))
        cam.location = target + d * 20.0
        cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = "%s_%d.png" % (path, i)
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(scene.render.filepath)
        shots.append(np.array(img.pixels[:]).reshape(img.size[1], img.size[0], 4))
    sheet = np.concatenate(shots, axis=1)
    out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0])
    out.pixels = sheet.ravel()
    out.filepath_raw = path + ".png"
    out.file_format = 'PNG'
    out.save()


def main():
    out = arg("out", "models")
    shots = arg("preview")
    only = arg("only")
    os.makedirs(out, exist_ok=True)
    for name, build in MODELS.items():
        if only and name not in only.split(","):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        MATS.clear()
        span, centre_z = build()
        finalize()
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format='GLB', export_apply=True, export_yup=True,
                                  export_vertex_color='ACTIVE', export_all_vertex_colors=False)
        blends = os.path.join(os.path.dirname(os.path.abspath(__file__)), "blend")
        os.makedirs(blends, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blends, name + ".blend"), check_existing=False)
        if shots:
            os.makedirs(shots, exist_ok=True)
            preview(os.path.join(shots, name), span, centre_z)
        print("built", name)


main()
