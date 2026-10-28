"""Starter quinque: CCG Issue Blade, Tsunagi pattern (Bikaku, C-rate)
-> assets/models/quinque_blade.{fbx,obj}

Run:  /home/claude/blender-venv/bin/python tools/blender/build_blade.py [--no-render]

Objects (ROBLOX axes in the exported file), origin of both = grip point (centre of the grip):
  QuinqueHilt  : grip (the case handle bar, GRIP_BLACK wrap) + trigger + pommel + collar
                 (the collar is where the folded case shells dock; no crossguard, canon).
  QuinqueBlade : the RC-formed blade: single edge, slight curve, clipped tip, 9 vertebra
                 spine segments (the Bikaku tell) and a fuller.
Blade points +Y; the cutting edge faces -Z, the spine/vertebrae face +Z.
Blender space: Roblox +Y = Blender +Z, Roblox -Z = Blender +Y (edge side).
"""
import sys
import os
import math
import bpy  # noqa: F401
import bmesh
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

ASSET = "quinque_blade"
GRIP0, GRIP1 = -0.30, 0.40          # grip wrap (pommel below, collar above): 0.8 incl. pommel
POMMEL0 = -0.40
COLLAR0, COLLAR1 = 0.40, 0.60
BLADE0, BLADE_L = 0.60, 2.80
WIDTH, THICK = 0.26, 0.06
SPINE_Y = -0.10                      # spine line (Blender y); edge at SPINE_Y + WIDTH
SAG = 0.09                           # tip deflection of the (very slight) curve, edge on the outside
TIP_LEN = 0.26 / math.tan(math.radians(35))   # clipped tip, ~35 deg

BLADE_COL, STEEL_EDGE, FULLER = "#B8BDC4", "#E9EDF1", "#7A8088"
STEEL_MID, GRIP_BLACK, RC_DARK, RC_GLOW = "#8C939B", "#1D1E21", "#4A060E", "#FF3B3B"
P_BLADE, P_EDGE, P_FULLER, P_SPINE, P_COLLAR, P_GRIP, P_TRIGGER = range(7)


def curve_off(t):
    """Spine-ward offset of the blade centre line at blade fraction t (edge on the outside)."""
    return -SAG * t * t


def blade_section(t, z):
    """Return list of (x, y, part_of_strip_following_this_vertex) for the cross-section."""
    zl = z - BLADE0
    # width: straight to 75%, slight narrowing, then the clipped tip cuts the edge side
    w = WIDTH
    if t > 0.75:
        w = WIDTH - 0.03 * (t - 0.75) / 0.25
    tip_start = BLADE_L - TIP_LEN
    if zl > tip_start:
        w = w * max(0.0, 1 - (zl - tip_start) / TIP_LEN)
    k = min(1.0, w / WIDTH)
    th = THICK / 2 * min(1.0, 0.35 + 0.65 * k)
    ys = SPINE_Y + curve_off(t)
    ye = ys + w
    bev = min(0.08, w * 0.45)
    groove = 0.008 if t < 0.7 else 0.008 * max(0.0, 1 - (t - 0.7) / 0.05)
    gy0, gy1 = ys + 0.03 * k, ys + 0.07 * k
    # (x, y, part of the face strip from this vertex to the next) going around +x side then -x
    pts = [
        (th, ys, P_BLADE), (th, gy0, P_FULLER), (th - groove, (gy0 + gy1) / 2, P_FULLER),
        (th, gy1, P_BLADE), (th, ye - bev, P_EDGE), (0.0, ye, P_EDGE),
        (-th, ye - bev, P_BLADE), (-th, gy1, P_FULLER), (-th + groove, (gy0 + gy1) / 2, P_FULLER),
        (-th, gy0, P_BLADE), (-th, ys, P_BLADE),
    ]
    return pts, ys, w


def blade():
    bm = C.new_part_bm()
    lay = bm.faces.layers.float["part"]
    zs = [COLLAR0 + 0.1]  # tang hidden inside the collar
    n = 26
    tip_start = BLADE0 + BLADE_L - TIP_LEN
    for i in range(n + 1):
        zs.append(BLADE0 + (tip_start - BLADE0) * i / n)
    for i in range(1, 6):
        zs.append(tip_start + TIP_LEN * i / 6 * 0.999)
    rings = []
    for z in zs:
        t = max(0.0, (z - BLADE0) / BLADE_L)
        pts, ys, w = blade_section(t, z)
        rings.append([(bm.verts.new((x, y, z)), p) for x, y, p in pts])
    tip = bm.verts.new((0, SPINE_Y + curve_off(1.0), BLADE0 + BLADE_L))
    m = len(rings[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(m):
            j = (i + 1) % m
            f = bm.faces.new((a[i][0], a[j][0], b[j][0], b[i][0]))
            f[lay] = a[i][1] if i != m - 1 else P_BLADE   # last strip = flat spine
    for i in range(m):
        j = (i + 1) % m
        f = bm.faces.new((rings[-1][i][0], rings[-1][j][0], tip))
        f[lay] = rings[-1][i][1] if i != m - 1 else P_BLADE
    f = bm.faces.new([v for v, _ in reversed(rings[0])])
    f[lay] = P_BLADE
    # vertebra spine plates: 9 x 0.25 long, 0.03 gap, ~0.04 proud, squared ends, small bevel
    L, gap = 0.25, 0.03
    z = BLADE0 + 0.08
    for i in range(9):
        sc = 1 - 0.25 * i / 8                    # slightly lower toward the tip
        hw, hp, bv = 0.04, 0.04 * sc, 0.008
        n0 = len(bm.faces)
        segs = []
        for zz, inset in ((z, bv), (z + bv, 0), (z + L / 2, 0), (z + L - bv, 0), (z + L, bv)):
            t = (zz - BLADE0) / BLADE_L
            ys = SPINE_Y + curve_off(t)
            w, h = hw - inset, hp - inset
            ring = [(w, ys + 0.01), (w, ys - h + bv), (w - bv, ys - h), (-w + bv, ys - h), (-w, ys - h + bv),
                    (-w, ys + 0.01)]
            segs.append([bm.verts.new((x, y, zz)) for x, y in ring])
        for sa, sb in zip(segs[:-1], segs[1:]):
            for k in range(len(sa)):
                kk = (k + 1) % len(sa)
                bm.faces.new((sa[k], sb[k], sb[kk], sa[kk]))
        bm.faces.new(segs[0])
        bm.faces.new(list(reversed(segs[-1])))
        C.tag_faces(bm, C.new_faces_since(bm, n0), P_SPINE)
        z += L + gap
    ob = C.obj_from_bmesh("QuinqueBlade", bm)
    C.clean_mesh(ob, 1e-5)
    C.set_smooth(ob, 30)
    return ob


def hilt():
    bm = C.new_part_bm()
    # grip: oval tube with 6 shallow wrap rings
    sides = 10
    rings = []
    nz = 24
    for i in range(nz + 1):
        z = GRIP0 + (GRIP1 - GRIP0) * i / nz
        u = (i / nz) * 6
        dip = 1 - 0.07 * (0.5 + 0.5 * math.cos(2 * math.pi * u))
        r = 0.06 * dip
        rings.append([Vector((r * math.cos(a), r * 1.15 * math.sin(a), z))
                      for a in (2 * math.pi * k / sides for k in range(sides))])
    n0 = len(bm.faces)
    C.loft(bm, rings, cap_start="ngon", cap_end="ngon")
    C.tag_faces(bm, C.new_faces_since(bm, n0), P_GRIP)
    # pommel: flat cap
    n0 = len(bm.faces)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.085, radius2=0.08, depth=0.10,
                          matrix=Matrix.Translation((0, 0, (POMMEL0 + GRIP0) / 2)))
    C.tag_faces(bm, C.new_faces_since(bm, n0), P_COLLAR)
    # collar 0.20 long, 0.30 wide (edge axis, Blender Y) x 0.12 deep (X), with two trim ribs
    n0 = len(bm.faces)
    prof = [(x, y) for x, y in C.rrect(0.12, 0.30, 0.03, 2)]
    # rrect is in XZ; use it as an XY profile extruded along Z
    cy = SPINE_Y + WIDTH / 2
    for z0, z1, grow in ((COLLAR0, COLLAR1, 0.0), (COLLAR0 + 0.04, COLLAR0 + 0.07, 0.018),
                         (COLLAR1 - 0.07, COLLAR1 - 0.04, 0.018)):
        pr = [(x * (1 + grow / 0.06), z * (1 + grow / 0.15)) for x, z in prof]
        vs0 = [bm.verts.new((x, cy + y, z0)) for x, y in pr]
        vs1 = [bm.verts.new((x, cy + y, z1)) for x, y in pr]
        k = len(pr)
        for i in range(k):
            j = (i + 1) % k
            bm.faces.new((vs0[i], vs0[j], vs1[j], vs1[i]))
        bm.faces.new(list(reversed(vs0)))
        bm.faces.new(vs1)
    C.tag_faces(bm, C.new_faces_since(bm, n0), P_COLLAR)
    # trigger: index-finger side (edge side, +Y blender), top of the grip just under the collar
    n0 = len(bm.faces)
    C.box_bm(bm, (0, 0.075, 0.30), (0.04, 0.05, 0.10), bevel=0.008)
    C.tag_faces(bm, C.new_faces_since(bm, n0), P_TRIGGER)
    ob = C.obj_from_bmesh("QuinqueHilt", bm)
    C.clean_mesh(ob, 1e-5)
    C.set_smooth(ob, 40)
    return ob


def build_material():
    mb = C.MatBuilder("BladeMat")
    co = mb.coord("Object")
    m = C.part_masks(mb, range(7))
    br = mb.noise(mb.mapping(co, scale=(120, 120, 1.2)), scale=1.0, detail=3, rough=0.6).outputs["Fac"]
    dz = mb.math('MULTIPLY', mb.math('SUBTRACT', br, 0.5), 0.12)
    body = mb.mix(mb.math('ADD', 0.5, dz), C.hexlin(BLADE_COL), (0, 0, 0, 1))
    body = mb.mix(0.5, body, C.hexlin(BLADE_COL))
    body = mb.mix(mb.math('MAXIMUM', mb.math('MULTIPLY', dz, -4.0), 0.0), body, (1, 1, 1, 1))
    # diagonal grip wrap
    wrap = mb.wave(mb.mapping(co, scale=(1, 1, 1), rot=(0, 0.0, 0.0)), scale=9, bands='BANDS',
                   direction='DIAGONAL', profile='SAW').outputs["Fac"]
    gripc = mb.mix(mb.math('MULTIPLY', wrap, 0.25), C.hexlin(GRIP_BLACK), (0.1, 0.1, 0.11, 1))
    # vertebrae: RC_DARK with slightly lighter ridge mottling
    vn = mb.noise(co, scale=30, detail=2).outputs["Fac"]
    spine = mb.mix(mb.math('MULTIPLY', vn, 0.12), C.hexlin(RC_DARK), C.hexlin("#5E0A14"))
    color = C.by_part_color(mb, m, {
        P_BLADE: body, P_EDGE: C.hexlin(STEEL_EDGE), P_FULLER: C.hexlin(FULLER), P_SPINE: spine,
        P_COLLAR: C.hexlin(STEEL_MID), P_GRIP: gripc, P_TRIGGER: C.hexlin(STEEL_MID)}, C.hexlin(BLADE_COL))
    rough = C.by_part_float(mb, m, {P_BLADE: mb.math('ADD', 0.26, mb.math('MULTIPLY', br, 0.08)),
                                    P_EDGE: 0.15, P_FULLER: 0.4, P_SPINE: 0.3, P_COLLAR: 0.3,
                                    P_GRIP: 0.7, P_TRIGGER: 0.3})
    metal = C.by_part_float(mb, m, {P_BLADE: 0.8, P_EDGE: 0.9, P_FULLER: 0.8, P_COLLAR: 0.9, P_TRIGGER: 0.9})
    height = C.by_part_float(mb, m, {P_BLADE: mb.math('MULTIPLY', br, 0.2),
                                     P_GRIP: mb.math('MULTIPLY', wrap, 0.7),
                                     P_SPINE: mb.math('MULTIPLY', vn, 0.4)})
    emis = C.by_part_float(mb, m, {P_SPINE: 1.0})
    mb.finish(color, rough, metal, height=height, bump_strength=0.25, bump_distance=0.01,
              extra={"emissive": emis})
    return mb


def main(do_render=True):
    C.reset()
    bl, ht = blade(), hilt()
    objs = [ht, bl]
    C.smart_uv(objs, margin=0.004, angle=45)
    mb = build_material()
    for o in objs:
        C.assign(o, mb.mat)
    paths = C.bake_material(objs, mb, ASSET)
    gm = C.game_material(ASSET, paths, emissive_tint=C.hexlin(RC_GLOW), emissive_strength=0.03)  # preview only; in Roblox use ~0.1
    for o in objs:
        C.assign(o, gm)
    C.export(objs, ASSET)
    tex = {k: f"textures/{os.path.basename(v)}" for k, v in paths.items()}
    entries = {}
    for o in objs:
        size, centre = C.bbox_size_rbx(o)
        entries[o.name] = {
            "file": [f"models/{ASSET}.fbx", f"models/{ASSET}.obj"],
            "bbox_size": size, "bboxCenterFromOrigin": centre, "triangles": C.tri_count(o),
            "pivot": "grip point = centre of the grip (same origin for hilt and blade)",
            "textures": tex}
    entries["QuinqueBlade"]["bakedBend"] = (f"blade curves {SAG} sagitta toward +Z (spine side); edge on the "
                                           "convex side; tip deflected about 0.09 toward +Z")
    entries["QuinqueBlade"]["blade_span_y"] = [BLADE0, round(BLADE0 + BLADE_L, 3)]
    entries["QuinqueHilt"]["bakedBend"] = "none"
    entries["QuinqueHilt"]["trigger_position"] = [0.0, 0.30, -0.075]
    entries["QuinqueHilt"]["collar_span_y"] = [COLLAR0, COLLAR1]
    C.write_manifest_entry("quinque_blade", {
        "files": [f"models/{ASSET}.fbx", f"models/{ASSET}.obj"],
        "name": "CCG Issue Blade (Tsunagi pattern), Bikaku C-rate",
        "axes": "blade points +Y, edge faces -Z, spine/vertebrae +Z; overall Y from -0.40 (pommel) to +3.40 (tip)",
        "overall_length": round(BLADE0 + BLADE_L - POMMEL0, 3),
        "emissive": "mask = spine vertebrae; tint #FF3B3B, strength 0.1 (0.6 during skills)",
        "triangles_total": sum(C.tri_count(o) for o in objs),
        "objects": entries})
    for o in objs:
        print(f"{o.name}: tris={C.tri_count(o)} size={C.bbox_size_rbx(o)}")
    print("TOTAL TRIS", sum(C.tri_count(o) for o in objs))
    if do_render:
        render(objs)


def render(objs):
    C.setup_render((640, 640), 24, env=((0.85, 0.87, 0.9), 1.6))
    R = C.RENDERS
    # turnaround laid along the view: front (edge toward camera side), side (flat), 3/4
    parts = []
    for i, (az, el) in enumerate(((90, 4), (0, 4), (50, 20))):
        C.camera_view(objs, az, el, margin=1.06)
        parts.append(C.render_to(os.path.join(R, f"_tmp_b{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_turnaround.png"))
    # flat orthographic side profile over a 1-stud grid (0.25 minor lines)
    gbm = bmesh.new()
    for k in range(-2, 17):
        zz = -0.5 + k * 0.25
        C.box_bm(gbm, (-0.3, 0.0, zz), (0.002, 2.0, 0.006 if k % 4 else 0.016))
    for k in range(-4, 5):
        yy = k * 0.25
        C.box_bm(gbm, (-0.3, yy, 1.5), (0.002, 0.006 if k % 4 else 0.016, 4.5))
    grid = C.obj_from_bmesh("Grid", gbm)
    C.assign(grid, C.flat_material("grid", (0.02, 0.02, 0.02), 0.9))
    bpy.context.scene.render.resolution_x = 360
    bpy.context.scene.render.resolution_y = 768
    C.camera_view([grid], 90, 0, margin=1.0)
    C.render_to(os.path.join(R, f"{ASSET}_profile_grid.png"))
    bpy.data.objects.remove(grid)
    bpy.context.scene.render.resolution_y = 640
    # details: hilt/collar/trigger, vertebra spine, tip
    bpy.context.scene.render.resolution_x = 640
    probes = []
    for c, sz in (((0, 0, 0.1), (0.4, 0.4, 1.1)), ((0, -0.1, 1.6), (0.3, 0.5, 0.9)), ((0, -0.2, 3.15), (0.3, 0.5, 0.55))):
        bm = bmesh.new()
        C.box_bm(bm, c, sz)
        p = C.obj_from_bmesh("probe", bm)
        p.hide_render = True
        probes.append(p)
    parts = []
    for i, (p, az) in enumerate(zip(probes, (60, 120, 70))):
        C.camera_view([p], az, 10, margin=1.05)
        parts.append(C.render_to(os.path.join(R, f"_tmp_bd{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_details.png"))
    # scale: ready stance, R6 right hand, arm 40 deg forward, blade forward-up, edge down
    man = C.mannequin(right_arm_pitch=40, left_arm_pitch=0)
    C.ground()
    M = man["right_grip"] @ Matrix.Rotation(math.radians(-90), 4, 'X')
    for o in objs:
        o.matrix_world = M
    mq = [o for k, o in man.items() if hasattr(o, "type")]
    parts = []
    for i, (az, el) in enumerate(((0, 6), (90, 6), (40, 14))):
        C.camera_view(objs + mq, az, el, margin=1.06)
        parts.append(C.render_to(os.path.join(R, f"_tmp_bs{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_scale.png"))


if __name__ == "__main__":
    main(do_render="--no-render" not in sys.argv)
