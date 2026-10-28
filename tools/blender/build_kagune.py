"""Rinkaku kagune (Kaneki Ken, 4 tails) -> assets/models/kagune_rinkaku.{fbx,obj}

Run:  /home/claude/blender-venv/bin/python tools/blender/build_kagune.py [--no-render]

Objects (ROBLOX axes in the exported file; Blender Z = Roblox Y, Blender -Y = Roblox +Z):
  RinkakuSeg1..RinkakuSeg5, RinkakuTip
      Modelled along +Y.  Origin = base joint, top joint at (0, L, 0).  Both ends are
      domes centred on the joint with the joint radius, so consecutive pieces stay closed
      when bent.  Oval section (X wide, Z flatter).  The dorsal keel + jagged spines are on
      piece-local +Z ("outside"); curl the chain toward -Z, i.e. joint rotation
      CFrame.Angles(-a, 0, 0), to keep the spines on the outside of the curve.
  Kakuhou
      Fleshy root mass for the lower back, origin at its centre; visible face points
      Roblox +Z (the character's back), flat side -Z rests on the torso.  Four socket
      points (position + outward direction) are written to the manifest.
"""
import sys
import os
import math
import random
import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Vector, Matrix, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

ASSET = "kagune_rinkaku"
SIDES = 12
FLAT = 0.8                      # oval section 1.0 (X) : 0.8 (front/back)

SEG_LEN = [1.30, 1.20, 1.10, 1.00, 0.90]
TIP_LEN = 0.60
BANDS = [3, 3, 3, 2, 2, 1]      # 14 overlapping scale bands along the tentacle
TOTAL = sum(SEG_LEN) + TIP_LEN
STARTS = [sum(SEG_LEN[:i]) for i in range(6)]          # arclength at each piece's base

# brief: diameter 0.50 root, bulge at ~15%, 0.40 @25%, 0.28 @60%, 0.12 @90%, point
PROFILE = [(0.0, 0.50), (0.15, 0.52), (0.25, 0.42), (0.60, 0.28), (0.90, 0.13), (1.0, 0.09)]

RC_BRIGHT, RC_MID, RC_DARK, RC_GLOW = "#D21F2B", "#9E1220", "#4A060E", "#FF3B3B"
RC_LIP, VEIN = "#E2414B", "#2A0206"
RC_MID_DEEP = "#8A0F1B"   # Seg4-5: one step darker than RC_MID so the darkening reads in-game

# Kakuhou sockets, Blender local coords of the kakuhou (brief: upper +-0.30 @ +0.10, lower +-0.55 @ -0.10)
SOCKETS = {
    "UpperRight": (Vector((0.30, -0.10, 0.10)), Vector((0.35, -1.0, 0.60))),
    "UpperLeft": (Vector((-0.30, -0.10, 0.10)), Vector((-0.35, -1.0, 0.60))),
    "LowerRight": (Vector((0.55, -0.07, -0.10)), Vector((0.75, -1.0, -0.05))),
    "LowerLeft": (Vector((-0.55, -0.07, -0.10)), Vector((-0.75, -1.0, -0.05))),
}


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def diameter(s):
    for (s0, d0), (s1, d1) in zip(PROFILE[:-1], PROFILE[1:]):
        if s <= s1:
            t = (s - s0) / (s1 - s0)
            t = t * t * (3 - 2 * t)
            return d0 + (d1 - d0) * t
    return PROFILE[-1][1]


def section(r, theta, flat=FLAT, cy=0.0):
    return Vector((r * math.cos(theta), r * flat * math.sin(theta) + cy, 0.0))


def dome(r, z0, direction, steps=3):
    """Hemisphere rings centred on a joint; pole vertex last."""
    rings = []
    for k in range(1, steps):
        a = (math.pi / 2) * (k / steps)
        rings.append([section(r * math.cos(a), 2 * math.pi * i / SIDES) + Vector((0, 0, z0 + direction * r * math.sin(a)))
                      for i in range(SIDES)])
    rings.append([Vector((0, 0, z0 + direction * r * FLAT ** 0.0))])
    return rings


def keel(theta, r):
    """Raised dorsal keel on the -Y (Blender) side = piece-local Roblox +Z."""
    d = abs(((theta - (-math.pi / 2)) + math.pi) % (2 * math.pi) - math.pi)
    return 0.06 * (r / 0.25) * math.exp(-(d / 0.32) ** 2)


def add_spine(bm, z0, z1, r_surface, h, rake):
    """Jagged two-tooth spine on the dorsal ridge, raked toward +Z (tip)."""
    w = max(0.012, 0.11 * h + 0.008)
    base_y = -(r_surface * FLAT) + 0.02          # slightly sunk into the surface
    prof = [(z0, 0.0), (z0 + 0.35 * (z1 - z0), 0.5 * h), (z0 + 0.5 * (z1 - z0), 0.36 * h),
            (z1 + rake, h), (z1, 0.0)]
    left = [bm.verts.new((-w, base_y - y, z)) for z, y in prof]
    right = [bm.verts.new((w, base_y - y, z)) for z, y in prof]
    # tips of teeth are knife-thin
    for i in (1, 3):
        left[i].co.x *= 0.25
        right[i].co.x *= 0.25
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))


def piece(idx):
    is_tip = idx == 5
    L = TIP_LEN if is_tip else SEG_LEN[idx]
    s0 = STARTS[idx] / TOTAL
    s1 = (STARTS[idx] + L) / TOTAL
    r0 = diameter(s0) / 2
    r1 = diameter(s1) / 2
    nb = BANDS[idx]
    rnd = random.Random(idx * 11 + 3)
    twist = rnd.uniform(-0.4, 0.4)
    rings = []
    # proximal end: hidden spherical cap centred on the joint, then a flared collar that
    # sleeves ~0.15 over the previous piece's end (hides the kink when bent)
    Ls = min(0.15, 0.8 * r0)
    rings.append([Vector((0, 0, -r0))])
    a_l = math.asin(Ls / r0)
    for a in (a_l + (math.pi / 2 - a_l) * 0.5, a_l):
        rings.append([section(r0 * math.cos(a), 2 * math.pi * i / SIDES) + Vector((0, 0, -r0 * math.sin(a)))
                      for i in range(SIDES)])
    for z, k in ((-Ls, 1.2), (-0.4 * Ls, 1.17), (0.35 * Ls, 1.1)):
        rings.append([section(r0 * k, 2 * math.pi * i / SIDES) + Vector((0, 0, z)) for i in range(SIDES)])
    us = [0.0, 0.3, 0.6, 0.84, 0.93]
    zs = [(b + u) / nb * L for b in range(nb) for u in us]
    if is_tip:
        zs = [z * 0.45 for z in zs] + [L * t for t in (0.55, 0.68, 0.8, 0.9, 0.97)]
    else:
        zs.append(L)
    zs = [z for z in zs if z > 0.75 * Ls]
    for z in zs:
        t = z / L
        s = s0 + (s1 - s0) * t
        r = diameter(s) / 2
        cy = 0.0
        flat = FLAT
        if is_tip:
            band_t = min(t / 0.45, 1.0)
            u = (band_t * nb) % 1.0 if t < 0.45 else 0.0
            # spear point: hold radius, then taper to the point, hooked 10 deg toward ventral (+Y)
            r = r0 * (1.08 * math.sin(math.pi * 0.5 * min(t / 0.3, 1)) * 0.25 + 0.9) if t < 0.45 else \
                r0 * 1.05 * ((1 - t) / 0.55) ** 0.85
            cy = 0.09 * L * smoothstep(0.35, 1.0, t) ** 2
            flat = FLAT - 0.25 * smoothstep(0.45, 1.0, t)
            fade = smoothstep(0.0, 0.15, t) * (1 - smoothstep(0.4, 0.45, t))
        else:
            u = (t * nb) % 1.0 if t < 1 - 1e-6 else 0.0
            fade = smoothstep(0.0, 0.1, t) * smoothstep(0.0, 0.1, 1 - t)
        bulge = 0.11 * (u ** 1.6) if u < 0.95 else 0.0
        ring = []
        for i in range(SIDES):
            th = 2 * math.pi * i / SIDES
            rib = 0.03 * math.cos(4 * th + twist * z * 3)
            rr = r * (1 + fade * (bulge + rib)) + fade * keel(th, r)
            if is_tip and t > 0.45:
                rr *= 1 + 0.18 * smoothstep(0.5, 1.0, t) * abs(math.cos(th)) ** 6  # side edges
            ring.append(section(rr, th, flat, cy) + Vector((0, 0, z)))
        rings.append(ring)
    if is_tip:
        rings.append([Vector((0, 0.09 * L, L))])
    else:
        td = dome(r1, L, +1)
        rings += td
    bm = bmesh.new()
    C.loft(bm, rings, cap_start=None, cap_end=None)
    # one spine per band on the dorsal ridge, 0.10 tall at the root shrinking to 0.03
    span = L * (0.45 if is_tip else 1.0)
    for b in range(nb):
        za = (b + 0.30) / nb * span
        zb = (b + 0.86) / nb * span
        s = s0 + (s1 - s0) * ((za + zb) / 2 / L)
        h = 0.14 - 0.10 * s
        rs = diameter(s) / 2 * (1.06) + keel(-math.pi / 2, diameter(s) / 2) / FLAT
        add_spine(bm, za, zb, rs, h, rake=0.58 * h)
    name = "RinkakuTip" if is_tip else f"RinkakuSeg{idx + 1}"
    ob = C.obj_from_bmesh(name, bm)
    C.clean_mesh(ob)
    C.set_smooth(ob, 35 if is_tip else 50)
    ob["fleshy"] = 0.0
    ob["collar"] = Ls
    ob["s0"], ob["s1"], ob["L"], ob["bands"] = s0, s1, L, float(nb)
    if is_tip:
        ob["bands"] = float(nb) / 0.45   # band coordinate covers only the first 45% of the tip
    return ob, L, r0 * 2, r1 * 2


def kakuhou(name="Kakuhou"):
    """1.4 W x 0.6 H x 0.35 D flattened organic lump."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=22, v_segments=12, radius=1.0)
    for v in bm.verts:
        p = v.co.copy()
        x, y, z = p.x * 0.66, p.y * 0.20, p.z * 0.27
        if y > 0.02:                       # flat side against the torso
            y = 0.02 + (y - 0.02) * 0.3
        q = Vector((x, y, z))
        outer = max(0.0, -p.y)
        q.y -= 0.05 * noise.noise(q * 3.5 + Vector((3.1, 1.7, 0.4))) * outer
        q.z += 0.03 * noise.noise(q * 4.0 + Vector((7.0, 2.0, 1.0)))
        for spos, sdir in SOCKETS.values():
            d = (q - spos).length
            q += sdir.normalized() * 0.09 * math.exp(-(d / 0.15) ** 2)
        v.co = q
    ob = C.obj_from_bmesh(name, bm)
    C.clean_mesh(ob)
    C.set_smooth(ob, 70)
    ob["fleshy"] = 1.0
    ob["s0"], ob["s1"], ob["L"], ob["bands"] = 0.0, 0.0, 1.0, 1.0
    return ob


def build_material():
    mb = C.MatBuilder("RinkakuMat")
    co = mb.coord("Object")
    attr = lambda n: mb.node("ShaderNodeAttribute", attribute_type='OBJECT', attribute_name=n).outputs["Fac"]
    fle, s0, s1, L, nb = attr("fleshy"), attr("s0"), attr("s1"), attr("L"), attr("bands")
    xyz = mb.sep(co)
    tl = mb.math('DIVIDE', xyz[2], L)
    tl = mb.math('MINIMUM', mb.math('MAXIMUM', tl, 0.0), 1.0)
    s = mb.math('ADD', s0, mb.math('MULTIPLY', tl, mb.math('SUBTRACT', s1, s0)))
    # canon gradient: bright at the root, darker toward the tips
    # Seg1-3 RC_BRIGHT, Seg4-5 RC_MID, tip RC_DARK (s: 0.59 = Seg4 start, 0.90 = tip start)
    grad = mb.ramp(s, [(0.0, C.hexlin(RC_BRIGHT)), (0.50, C.hexlin(RC_BRIGHT)),
                       (0.62, C.hexlin(RC_MID_DEEP)), (0.86, C.hexlin(RC_MID_DEEP)),
                       (0.93, C.hexlin(RC_DARK)), (1.0, C.hexlin(RC_DARK))]).outputs[0]
    # band coordinate (matches the geometric scale bands)
    u = mb.math('FRACT', mb.math('MULTIPLY', tl, nb))
    lip = mb.math('MULTIPLY', mb.math('SMOOTHSTEP' if False else 'GREATER_THAN', u, 0.62), 1.0)
    lipf = mb.node("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    mb.link(u, lipf.inputs["Value"])
    lipf.inputs["From Min"].default_value = 0.55
    lipf.inputs["From Max"].default_value = 0.92
    lip = lipf.outputs[0]
    seamf = mb.node("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    mb.link(u, seamf.inputs["Value"])
    seamf.inputs["From Min"].default_value = 0.935
    seamf.inputs["From Max"].default_value = 0.965
    seam = mb.math('MULTIPLY', seamf.outputs[0], mb.math('LESS_THAN', tl, 0.999))
    # angle around the tentacle; dorsal = -Y (Blender)
    ang = mb.math('ARCTAN2', xyz[1], xyz[0])
    dors = mb.node("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    mb.link(mb.math('SINE', ang), dors.inputs["Value"])
    dors.inputs["From Min"].default_value = -0.86
    dors.inputs["From Max"].default_value = -0.97
    dorsal = dors.outputs[0]
    # two lengthwise veins on the flanks, wobbling
    wob = mb.noise(mb.mapping(co, scale=(0.0, 0.0, 2.2)), scale=1.0, detail=1)
    wv = mb.math('MULTIPLY', mb.math('SUBTRACT', wob.outputs["Fac"], 0.5), 0.9)
    sv = mb.math('ABSOLUTE', mb.math('SINE', mb.math('ADD', ang, wv)))
    vf = mb.node("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    mb.link(sv, vf.inputs["Value"])
    vf.inputs["From Min"].default_value = 0.10
    vf.inputs["From Max"].default_value = 0.04
    vein = mb.math('MULTIPLY', vf.outputs[0], mb.math('SUBTRACT', 1.0, mb.math('GREATER_THAN', s, 0.97)))
    # subtle wet "liquid muscle" mottling (kept low: stylised look)
    mot = mb.noise(mb.mapping(co, scale=(14, 14, 3)), scale=1.0, detail=2).outputs["Fac"]
    col = mb.mix(mb.math('MULTIPLY', mb.math('SUBTRACT', mot, 0.5), 0.25), grad, (0.0, 0.0, 0.0), 'MIX')
    col = mb.mix(mb.math('MULTIPLY', lip, 0.55), col, mb.mix(0.5, col, C.hexlin(RC_LIP), 'SCREEN'), 'MIX')
    col = mb.mix(seam, col, mb.mix(0.5, col, C.hexlin(VEIN)), 'MIX')
    colf = mb.node("ShaderNodeMapRange", interpolation_type='SMOOTHSTEP')
    mb.link(xyz[2], colf.inputs["Value"])
    colf.inputs["From Min"].default_value = 0.05
    colf.inputs["From Max"].default_value = 0.0
    collar = colf.outputs[0]
    col = mb.mix(mb.math('MULTIPLY', collar, mb.math('SUBTRACT', 1.0, fle)), col, C.hexlin(RC_LIP))
    col = mb.mix(dorsal, col, C.hexlin(RC_DARK))
    col = mb.mix(mb.math('MULTIPLY', vein, 0.9), col, C.hexlin(VEIN))
    # spear tip (last 0.6 stud): plain RC_DARK, no lips/veins (avoids sparkle on the point)
    tipm = mb.math('GREATER_THAN', s0, 0.89)
    col = mb.mix(tipm, col, C.hexlin(RC_DARK))
    # kakuhou: RC_MID flesh with RC_BRIGHT veins
    kv = mb.voronoi(mb.mapping(co, scale=(5, 5, 5)), scale=1.0, feature='DISTANCE_TO_EDGE')
    kvn = mb.noise(co, scale=5.0, detail=2).outputs["Fac"]
    kvein = mb.math('SUBTRACT', 1.0, mb.math('MULTIPLY', kv.outputs["Distance"], 22.0, clamp=True))
    kvein = mb.math('MULTIPLY', kvein, mb.math('MULTIPLY', mb.math('SUBTRACT', kvn, 0.3), 3.0, clamp=True), clamp=True)
    kcol = mb.mix(mb.math('MULTIPLY', mb.math('SUBTRACT', mot, 0.5), 0.3), C.hexlin(RC_MID), (0, 0, 0))
    kcol = mb.mix(kvein, kcol, C.hexlin(RC_BRIGHT))
    color = mb.mix(fle, col, kcol)
    # roughness: wet/glossy 0.25, seams and veins a bit duller
    rough = mb.math('ADD', 0.35, mb.math('MULTIPLY', mb.math('ADD', seam, vein), 0.15))
    rough = mb.math('ADD', mb.math('MULTIPLY', rough, mb.math('SUBTRACT', 1.0, tipm)), mb.math('MULTIPLY', tipm, 0.5))
    # height: band lips, seam groove, vein grooves, fine mottling
    h = mb.math('ADD', mb.math('MULTIPLY', lip, 0.35), mb.math('MULTIPLY', seam, -0.5))
    h = mb.math('ADD', h, mb.math('MULTIPLY', vein, -0.35))
    h = mb.math('ADD', h, mb.math('MULTIPLY', mot, 0.15))
    h = mb.math('MULTIPLY', h, mb.math('SUBTRACT', 1.0, tipm))
    kh = mb.math('ADD', mb.math('MULTIPLY', kvein, 0.5), mb.math('MULTIPLY', kvn, 0.4))
    height = mb.mix(fle, h, kh)
    # emissive mask: band seams 0.6 (x0.25 strength in game ~= brief 0.15), root mass 1.0 on veins
    emis = mb.math('ADD', mb.math('MULTIPLY', mb.math('MULTIPLY', seam, 0.6), mb.math('LESS_THAN', s, 0.85)),
                   mb.math('MULTIPLY', fle, mb.math('ADD', 0.35, mb.math('MULTIPLY', kvein, 0.65))))
    emis_col = mb.mix(1.0, emis, C.hexlin(RC_GLOW), 'MULTIPLY')
    mb.finish(color, rough, 0.0, height=height, bump_strength=0.35, bump_distance=0.02,
              emission=emis_col, emission_strength=0.25, extra={"emissive": emis})
    return mb


# --------------------------------------------------------------------------- assembly for renders

def chain_mats(base, d0, bends, side=0.0, roll=0.0):
    """World matrices of Seg1..Seg5,Tip starting at `base` pointing along d0.  Each joint
    curls toward the ventral side (local +Y Blender = Roblox -Z), which faces world +Y
    (character forward) at the root, so the spines stay on the outside."""
    z = d0.normalized()
    f = Vector((0, 1, 0))
    y = f - z * f.dot(z)
    if y.length < 1e-4:
        y = Vector((0, 0, 1)) - z * z.z
    y.normalize()
    x = y.cross(z)
    M = Matrix((x, y, z)).transposed().to_4x4()
    M = M @ Matrix.Rotation(math.radians(roll), 4, 'Z')
    M.translation = base
    mats = [M.copy()]
    sides = side if isinstance(side, (list, tuple)) else [side] * 5
    for i, L in enumerate(SEG_LEN):
        M = M @ Matrix.Translation((0, 0, L)) @ Matrix.Rotation(math.radians(-bends[i]), 4, 'X') \
            @ Matrix.Rotation(math.radians(sides[i]), 4, 'Y')
        mats.append(M.copy())
    return mats


def instance_chain(pieces, mats, tag):
    out = []
    for p, M in zip(pieces, mats):
        c = p.copy()
        c.name = f"{p.name}_{tag}"
        c.matrix_world = M
        c.hide_render = False
        C.link(c)
        out.append(c)
    return out


def main(do_render=True):
    C.reset()
    pieces, info = [], {}
    for i in range(6):
        ob, L, d0, d1 = piece(i)
        pieces.append(ob)
        info[ob.name] = (L, d0, d1)
    kak = kakuhou()
    allp = pieces + [kak]
    C.smart_uv(allp, margin=0.004)
    mb = build_material()
    for o in allp:
        C.assign(o, mb.mat)
    paths = C.bake_material(allp, mb, ASSET)
    gm = C.game_material(ASSET, paths, emissive_tint=C.hexlin(RC_GLOW), emissive_strength=0.25)
    for o in allp:
        C.assign(o, gm)
    C.export(allp, ASSET)

    objs = {}
    tex = {k: f"textures/{os.path.basename(v)}" for k, v in paths.items()}
    for o in allp:
        size, centre = C.bbox_size_rbx(o)
        e = {"file": ["models/kagune_rinkaku.fbx", "models/kagune_rinkaku.obj"],
             "bbox_size": size, "bboxCenterFromOrigin": centre, "triangles": C.tri_count(o),
             "textures": tex}
        if o.name in info:
            L, d0, d1 = info[o.name]
            e["pivot"] = "base joint at (0,0,0); piece extends along +Y; spines/keel on +Z side"
            e["joint_length"] = L
            e["base_diameter"] = round(d0, 3)
            e["bakedBend"] = "none (straight along +Y)"
            if o.name == "RinkakuTip":
                e["point_at"] = [0, L, -round(0.09 * L, 3)]
                e["bakedBend"] = "point hooked ~10 deg toward -Z (ventral/inner side of the curl)"
            else:
                e["top_joint"] = [0, L, 0]
                e["top_diameter"] = round(d1, 3)
        else:
            e["bakedBend"] = "n/a"
            e["pivot"] = ("centre of the root mass; visible face +Z (character's back), flat side -Z on "
                          "the torso. Mount at Torso CFrame * (0, -0.65, 0.65) (Y=2.35 from feet)")
            e["sockets"] = {k: {"position": [round(p.x, 3), round(p.z, 3), round(-p.y, 3)],
                                "direction": [round(v.normalized().x, 3), round(v.normalized().z, 3),
                                              round(-v.normalized().y, 3)]}
                            for k, (p, v) in SOCKETS.items()}
        objs[o.name] = e
    C.write_manifest_entry("kagune_rinkaku", {
        "files": ["models/kagune_rinkaku.fbx", "models/kagune_rinkaku.obj"],
        "tentacle_count": 4,
        "chain_order": [p.name for p in pieces],
        "joint_lengths": [info[p.name][0] for p in pieces],
        "total_tentacle_length": round(TOTAL, 3),
        "curl": "rotate each joint about the piece's local X by a negative angle (CFrame.Angles(-a,0,0)) to curl with spines outside",
        "emissive": "textures/kagune_rinkaku_emissive.png is a greyscale glow mask; tint #FF3B3B, strength ~0.25",
        "triangles_total": sum(C.tri_count(o) for o in allp),
        "objects": objs,
    })
    for o in allp:
        print(f"{o.name}: tris={C.tri_count(o)} size={C.bbox_size_rbx(o)[0]}")
    print("TOTAL TRIS", sum(C.tri_count(o) for o in allp))
    if do_render:
        render(pieces, kak)


SPREAD = {   # attack spread: (base direction (Blender), bends per joint, side-bend, roll)
    # upper pair rise behind the shoulders and arc forward over them; lower pair sweep
    # out to the sides at the waist and hook forward
    "UpperRight": (Vector((0.6, -0.75, 1.0)), [16, 28, 34, 36, 30], -2, 0),
    "UpperLeft": (Vector((-0.6, -0.75, 1.0)), [14, 30, 32, 38, 28], 2, 0),
    "LowerRight": (Vector((1.0, -0.45, 0.05)), [8, 20, 26, 30, 24], 0, 0),
    "LowerLeft": (Vector((-1.0, -0.45, 0.05)), [10, 18, 28, 28, 26], 0, 0),
}
REST = {     # idle: S-curve fan rising behind the shoulders, tips ~1 above the head
    "UpperRight": (Vector((0.22, -0.35, 1.0)), [4, 5, 4, 3, 2], [-6, -4, 6, 10, 12], 0),
    "UpperLeft": (Vector((-0.22, -0.35, 1.0)), [4, 5, 4, 3, 2], [6, 4, -6, -10, -12], 0),
    "LowerRight": (Vector((0.62, -0.35, 1.0)), [3, 4, 4, 3, 2], [-8, -5, 6, 11, 14], 0),
    "LowerLeft": (Vector((-0.62, -0.35, 1.0)), [3, 4, 4, 3, 2], [8, 5, -6, -11, -14], 0),
}
SINK = 0.12   # tentacle bases sit this far inside the root mass


def render(pieces, kak):
    C.setup_render((640, 640), 24)
    R = C.RENDERS
    for p in pieces + [kak]:
        p.hide_render = True
    man = C.mannequin(right_arm_pitch=25, left_arm_pitch=-10)
    mq = [o for k, o in man.items() if hasattr(o, "type")]
    gnd = C.ground()
    kM = man["lower_back"] @ Matrix.Translation((0, -0.15, -0.2))   # centre Y=2.35, just behind the back
    k2 = kak.copy()
    C.link(k2)
    k2.matrix_world = kM
    k2.hide_render = False
    def pose(table, tag):
        out = []
        for name, (d, bends, side, roll) in table.items():
            p, sd = SOCKETS[name]
            base = kM @ (p - sd.normalized() * SINK)
            out += instance_chain(pieces, chain_mats(base, d, bends, side, roll), name + tag)
        return out
    rest = pose(REST, "_rest")
    for o in rest:
        o.hide_render = True
    tent = pose(SPREAD, "_atk")
    kag = [k2] + tent
    allv = kag + mq
    # scale sheet: front / side / 3/4-back with the R6 dummy
    parts = []
    for i, (az, el) in enumerate(((0, 6), (90, 6), (215, 16))):
        C.camera_view(allv, az, el, margin=1.06)
        parts.append(C.render_to(os.path.join(R, f"_tmp_s{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_scale.png"))
    # in-game look close-up
    C.camera_view(kag, 200, 25, margin=1.02)
    C.render_to(os.path.join(R, f"{ASSET}_ingame.png"))
    # root close-up straight from behind
    C.camera_view([k2] + [o for o in tent if "Seg1" in o.name or "Seg2" in o.name], 180, 10, margin=1.15)
    C.render_to(os.path.join(R, f"{ASSET}_root_detail.png"))
    # rest pose: back, 3/4 back, side
    for o in tent:
        o.hide_render = True
    for o in rest:
        o.hide_render = False
    parts = []
    for i, (az, el) in enumerate(((180, 6), (215, 14), (90, 6))):
        C.camera_view(rest + [k2] + mq, az, el, margin=1.06)
        parts.append(C.render_to(os.path.join(R, f"_tmp_r{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_rest.png"))
    for o in allv + [gnd] + rest:
        o.hide_render = True
    # turnaround of one straight tentacle + kakuhou (piece reference) and a 25 deg joint test
    straight = instance_chain(pieces, chain_mats(Vector((0, 0, 0)), Vector((0, 0, 1)), [0] * 5), "straight")
    bent = instance_chain(pieces, chain_mats(Vector((1.6, 0, 0)), Vector((0, 0, 1)), [25] * 5), "bent")
    k3 = kak.copy()
    C.link(k3)
    k3.matrix_world = Matrix.Translation((-1.4, 0, 0.6))
    k3.hide_render = False
    grp = straight + bent + [k3]
    parts = []
    for i, (az, el) in enumerate(((0, 4), (90, 4), (225, 20))):
        C.camera_view(grp, az, el, margin=1.06)
        parts.append(C.render_to(os.path.join(R, f"_tmp_t{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_turnaround.png"))
    for o in grp:
        o.hide_render = True
    j = instance_chain(pieces[:3], chain_mats(Vector((0, 0, 0)), Vector((0, 0, 1)), [25, 25, 0, 0, 0]), "joint")
    C.camera_view(j, 90, 5, margin=1.1)
    C.render_to(os.path.join(R, f"{ASSET}_joint_detail.png"))


if __name__ == "__main__":
    main(do_render="--no-render" not in sys.argv)
