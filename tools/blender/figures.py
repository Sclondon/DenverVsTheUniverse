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


# --- The robot ------------------------------------------------------------------------------------

def robot():
    """An F-15 that stood up: slim and long-limbed like an Evangelion. The radome is its head, the
    intakes its shoulders with the twin tails rising from them as pylons, the wings a cape down its
    back, and the engines its calves. Three units to the top of the head, feet at the origin."""
    hull = mat("aeb8c4", 0.34, 0.1)
    hull2 = mat("76828f", 0.36, 0.1)
    armor = mat("43348f", 0.3, 0.1)
    joint = mat("22252d", 0.45, 0.3)
    black = mat("08080c", 0.5)
    green = mat("86ff4a", 0.3, 0.0, 3.0)
    burn = mat("ff8a2a", 0.3, 0.0, 3.0)
    glass = mat("ffae2c", 0.08, 0.0, 0.5)
    core = mat("ff2d3d", 0.2, 0.0, 2.5)
    white = mat("f2f2f2", 0.4)
    red = mat("e0263c", 0.4)
    steel = mat("c9cfd6", 0.25, 0.4)

    for s, sn in SIDES:
        # Leg: slim thigh, spiked knee, and the calf is an engine standing on its nozzle
        leg = pivot("leg_" + sn, (s * 0.2, 0.0, 1.56))
        ball("hip", joint, 0.115, parent=leg)
        loft("thigh", armor, [(-0.02, 0.085, 0.1, 2.6), (-0.2, 0.125, 0.15, 2.6), (-0.48, 0.105, 0.125, 2.6), (-0.7, 0.075, 0.09, 2.4)], parent=leg)
        loft("thigh_stripe", green, [(-0.3, 0.128, 0.03, 3.0), (-0.34, 0.126, 0.03, 3.0)], parent=leg, loc=(0, -0.118, 0))
        ball("knee", joint, 0.09, parent=leg, loc=(0, 0.0, -0.75))
        loft("knee_spike", hull, [(-0.06, 0.075, 0.05, 3.0), (0.06, 0.07, 0.045, 3.0), (0.34, 0.0, 0.0)], parent=leg, loc=(0, -0.1, -0.78), rot=(16, 0, 0))
        loft("calf", hull, [(-0.8, 0.075, 0.085, 2.2), (-0.96, 0.115, 0.14, 2.6, 0, 0.02), (-1.2, 0.13, 0.16, 2.4, 0, 0.03), (-1.37, 0.14, 0.165, 2.0, 0, 0.03)], parent=leg)
        loft("calf_band", hull2, [(-1.3, 0.142, 0.168, 2.0, 0, 0.03), (-1.37, 0.146, 0.171, 2.0, 0, 0.03)], parent=leg)
        loft("nozzle", joint, [(-1.37, 0.135, 0.158, 2.0, 0, 0.03), (-1.5, 0.105, 0.125, 2.0, 0, 0.03), (-1.555, 0.1, 0.12, 2.0, 0, 0.03)], n=14, sharp=20, parent=leg)
        loft("burner", burn, [(-1.4, 0.09, 0.105, 2.0, 0, 0.03), (-1.41, 0.137, 0.16, 2.0, 0, 0.03)], parent=leg)
        loft("foot", armor, [(-0.1, 0.085, 0.05, 4.0), (0.12, 0.105, 0.065, 4.0), (0.3, 0.07, 0.045, 3.0), (0.46, 0.0, 0.0, 2.0, 0, -0.03)], parent=leg, loc=(0, -0.06, -1.495), rot=(90, 0, 0))

        # Arm: long, hanging nearly to the knee, a missile down the forearm
        arm = pivot("arm_" + sn, (s * 0.66, 0.0, 2.44))
        ball("shoulder", joint, 0.115, parent=arm)
        loft("upper_arm", armor, [(-0.03, 0.075, 0.085, 2.6), (-0.24, 0.092, 0.1, 2.6), (-0.6, 0.066, 0.072, 2.4)], parent=arm)
        ball("elbow", joint, 0.074, parent=arm, loc=(0, 0, -0.66))
        loft("forearm", hull, [(-0.7, 0.064, 0.07, 2.4), (-0.92, 0.098, 0.108, 3.0), (-1.24, 0.082, 0.09, 3.0), (-1.32, 0.058, 0.064, 2.4)], parent=arm)
        loft("cuff", green, [(-1.2, 0.086, 0.094, 3.0), (-1.235, 0.085, 0.093, 3.0)], parent=arm)
        loft("hand", joint, [(-1.32, 0.048, 0.056, 3.0), (-1.42, 0.062, 0.074, 3.0), (-1.53, 0.036, 0.05, 3.0)], parent=arm)
        loft("missile", white, [(-0.8, 0.0, 0.0), (-0.82, 0.027, 0.027), (-1.28, 0.027, 0.027)], n=10, parent=arm, loc=(s * 0.128, 0, 0))
        loft("missile_tip", red, [(-1.28, 0.027, 0.027), (-1.4, 0.0, 0.0)], n=10, parent=arm, loc=(s * 0.128, 0, 0))

        # Shoulder: the jet's intake, raked lip forward, with a tail fin rising from it
        loft("intake", hull, [(-0.24, 0.13, 0.13, 6.0), (0.0, 0.15, 0.16, 6.0), (0.25, 0.15, 0.17, 6.0, 0, 0.01)], loc=(s * 0.64, 0.0, 2.6), rot=(98, 0, 0))
        loft("intake_mouth", black, [(0.25, 0.125, 0.145, 6.0, 0, 0.01), (0.262, 0.12, 0.14, 6.0, 0, 0.01)], loc=(s * 0.64, 0.0, 2.6), rot=(98, 0, 0))
        loft("intake_lip", green, [(-0.02, 0.153, 0.163, 6.0), (0.02, 0.153, 0.164, 6.0)], loc=(s * 0.64, 0.0, 2.6), rot=(98, 0, 0))
        fin = pivot("fin_" + sn, (s * 0.66, 0.02, 2.72), rot=(s * 9.0, 0, 90.0 - s * 42.0))
        plate("tail", hull, [(-0.2, 0.0), (0.24, 0.0), (0.36, 0.78), (0.15, 0.78)], 0.045, parent=fin)
        plate("tail_tip", armor, [(0.15, 0.78), (0.36, 0.78), (0.385, 0.95), (0.225, 0.95)], 0.05, parent=fin)
        loft("tail_pod", hull2, [(0.0, 0.0, 0.0), (0.06, 0.022, 0.022), (0.3, 0.022, 0.022), (0.36, 0.0, 0.0)], n=8, parent=fin, loc=(0.3, 0, 0.95), rot=(0, -80, 0))

        # Wings, folded down the back like a cape, and the stabilators as hip skirts
        plate("wing", hull, [(0.0, 0.34), (0.0, -0.4), (s * 1.02, -0.62), (s * 1.02, -0.36)], 0.04, loc=(s * 0.16, 0.25, 2.32), rot=(0, 0, s * 26.0))
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

    # The gun pod, a rotary cannon as long as the arm, held in the right hand
    gun = pivot("gun", (0.0, -0.085, 0.0), parent=bpy.data.objects["arm_r"])
    loft("gun_body", joint, [(-1.14, 0.03, 0.04, 4.0), (-1.2, 0.045, 0.07, 4.0), (-1.62, 0.045, 0.065, 4.0), (-1.68, 0.03, 0.04, 4.0)], parent=gun)
    loft("gun_drum", hull2, [(-1.3, 0.075, 0.075), (-1.5, 0.075, 0.075)], n=14, parent=gun, loc=(0, 0.02, 0))
    for i in range(3):
        a = math.radians(i * 120.0 + 90.0)
        loft("barrel", steel, [(-1.66, 0.014, 0.014), (-1.98, 0.014, 0.014)], n=8, parent=gun, loc=(math.cos(a) * 0.022, math.sin(a) * 0.022, 0))
    loft("muzzle", joint, [(-1.9, 0.045, 0.045), (-1.95, 0.045, 0.045)], n=14, parent=gun)
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
    """A tin-toy robot: all boxes, rivets and claws."""
    tin = mat("aeb6c2", 0.25, 0.5)
    tin2 = mat("6d7480", 0.3, 0.5)
    dark = mat("22252d", 0.45, 0.3)
    red = mat("e0263c", 0.35)
    box("body", tin, (1.4, 0.8, 1.1), loc=(0, 0, -0.05), bevel=0.07)
    box("head", mat("c9cfd6", 0.22, 0.5), (0.9, 0.66, 0.6), loc=(0, 0, 0.8), bevel=0.06)
    box("visor", mat("08080c", 0.3), (0.7, 0.06, 0.18), loc=(0, -0.33, 0.86), bevel=0.01)
    for s, sn in SIDES:
        box("eye", mat("ff2d3d", 0.3, 0.0, 3.0), (0.24, 0.06, 0.09), loc=(s * 0.17, -0.35, 0.86), bevel=0.01)
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
            ball("rivet", mat("c9cfd6", 0.2, 0.6), 0.035, loc=(s * 0.62, -0.4, -0.45 + i * 0.4))
    lathe("antenna", dark, [(0.03, 1.08), (0.02, 1.36)], n=8)
    ball("antenna_tip", mat("ff3d7f", 0.3, 0.0, 3.0), 0.08, loc=(0, 0, 1.4))
    box("panel", mat("22303a", 0.3), (0.9, 0.05, 0.44), loc=(0, -0.41, 0.0), bevel=0.01)
    for i, c in enumerate(("ffe14a", "86ff4a", "ff3d7f")):
        ball("lamp", mat(c, 0.3, 0.0, 2.5), 0.09, loc=((i - 1) * 0.26, -0.44, 0.04))
    lathe("key", red, [(0.0, 0.0), (0.05, 0.0), (0.05, 0.3), (0.0, 0.3)], n=8, loc=(0, 0.4, 0.1), rot=(-90, 0, 0))
    plate("key_wings", red, [(-0.22, 0.0), (-0.3, 0.14), (-0.18, 0.26), (0.0, 0.1), (0.18, 0.26), (0.3, 0.14), (0.22, 0.0), (0.0, -0.06)], 0.05, loc=(0, 0.74, 0.0), rot=(0, 0, 90))
    return 3.0, 0.1


def alien_splitter():
    """Two heads on one body: it comes apart into two when it dies."""
    skin = mat("b9bfca", 0.5)
    lathe("body", mat("7a4fb0", 0.4), [(0.0, -0.66), (0.2, -0.62), (0.3, -0.45), (0.44, -0.2), (0.3, -0.08), (0.0, -0.06)])
    for s, _ in SIDES:
        loft("neck", skin, [(-0.2, 0.07, 0.07), (0.0, 0.06, 0.06)], n=10, loc=(s * 0.2, 0, -0.08), rot=(0, s * 40.0, 0))
        grey_head(skin, (s * 0.42, 0, 0.2), 0.4)
    lathe("seam", mat("ff3d7f", 0.3, 0.0, 3.0), [(0.0, -0.64), (0.025, -0.6), (0.025, 0.5), (0.0, 0.54)], n=8, loc=(0, -0.3, 0))
    return 2.0, 0.0


def alien_mite():
    grey_head(mat("b9bfca", 0.5), (0, 0, 0), 0.38)
    return 1.1, 0.0


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


MODELS = {
    "robot": robot, "alien_grunt": alien_grunt, "alien_spitter": alien_spitter, "alien_crab": alien_crab,
    "alien_saucer": alien_saucer, "alien_diver": alien_diver, "alien_brute": alien_brute,
    "alien_splitter": alien_splitter, "alien_mite": alien_mite, "alien_boss": alien_boss,
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
        bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format='GLB', export_apply=True, export_yup=True)
        if shots:
            os.makedirs(shots, exist_ok=True)
            preview(os.path.join(shots, name), span, centre_z)
        print("built", name)


main()
