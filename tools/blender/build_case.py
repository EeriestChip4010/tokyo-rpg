"""CCG quinque briefcase -> assets/models/quinque_case.{fbx,obj}

Run:  /home/claude/blender-venv/bin/python tools/blender/build_case.py [--no-render]

Objects (ROBLOX axes in the exported file), all with origin = grip point (centre of the
handle bar, where RightGripAttachment goes):
  CaseShellFront : front half-shell (the -Z half), rim rail, ribs, corner caps, latches,
                   tone-on-tone "CCG" plate.
  CaseShellBack  : back half-shell (the +Z half), rim rail, ribs, corner caps.
  CaseHandle     : D-shaped handle bar + mount blocks + trigger button (underside).
Width runs along X (1.6), the case hangs down -Y below the handle (shell 1.2 tall), and
thickness runs along Z (0.4, split at mid-depth with a 0.015 seam).
Blender space: Roblox -Z (front) = Blender +Y.
"""
import sys
import os
import math
import bpy  # noqa: F401  (import before bmesh)
import bmesh
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

ASSET = "quinque_case"
W, H, D = 1.6, 1.2, 0.4
TOP = -0.16                 # shell top below the grip point (bar centre 0.16 above the shell)
CZ = TOP - H / 2            # shell centre (Blender z)
SEAM = 0.0075               # half of the 0.015 seam groove
RIB_X = W / 2 - 0.35

STEEL_LIGHT, STEEL_MID, GRIP_BLACK = "#C3C8CE", "#8C939B", "#1D1E21"
RC_DARK, RC_GLOW = "#4A060E", "#FF3B3B"

P_SHELL, P_TRIM, P_GRIP, P_TRIGGER, P_PLATE, P_SEAM, P_LATCH, P_LETTER = range(8)


def add_box(bm, center, size, part, bevel=0.0, seg=1):
    n0 = len(bm.faces)
    C.box_bm(bm, center, size, bevel=bevel, segments=seg)
    C.tag_faces(bm, C.new_faces_since(bm, n0), part)


def shell(front=True):
    s = 1 if front else -1
    name = "CaseShellFront" if front else "CaseShellBack"
    bm = C.new_part_bm()
    prof = C.rrect(W, H, 0.08, 3, cz=CZ)
    n0 = len(bm.faces)
    faces = C.extrude_profile(bm, prof, s * SEAM, s * D / 2, bevel=0.03, bevel_end=True)
    C.tag_faces(bm, faces, P_SHELL)
    C.tag_faces(bm, [faces[-2]], P_SEAM)          # inner face at the seam: stored kakuhou
    # rim rail around the seam (0.04 thick, 0.05 proud)
    rim = C.rrect(W + 0.1, H + 0.1, 0.13, 3, cz=CZ)
    f = C.extrude_profile(bm, rim, s * SEAM, s * (SEAM + 0.04), bevel=0.008, bevel_end=True, bevel_start=False)
    C.tag_faces(bm, f, P_TRIM)
    C.tag_faces(bm, [f[-2]], P_SEAM)
    # two ribs per face, wrapping over the top and bottom
    for x in (-RIB_X, RIB_X):
        add_box(bm, (x, s * (D / 2 + 0.008), CZ), (0.06, 0.03, H - 0.16), P_TRIM, 0.008)
        for zz in (TOP + 0.008, TOP - H - 0.008):
            add_box(bm, (x, s * (SEAM + 0.04 + (D / 2 - 0.04 - SEAM) / 2 - 0.01), zz),
                    (0.06, D / 2 - 0.05 - SEAM, 0.03), P_TRIM, 0.008)
    # corner caps
    for x in (-1, 1):
        for zz in (TOP, TOP - H):
            c = (x * (W / 2 - 0.045), s * (D / 2 - 0.045), zz + (-0.045 if zz == TOP else 0.045))
            add_box(bm, c, (0.12, 0.12, 0.12), P_TRIM, 0.03, 1)
    if front:
        # two flush latches on the top face, either side of the handle
        for x in (-0.35, 0.35):
            add_box(bm, (x, SEAM + 0.05, TOP + 0.012), (0.18, 0.08, 0.03), P_LATCH, 0.008)
        # tone-on-tone "CCG" plate, lower right as seen from the front
        px, pz = -0.22, TOP - H + 0.16
        add_box(bm, (px, D / 2 + 0.006, pz), (0.30, 0.014, 0.10), P_PLATE, 0.006)
        M = Matrix.Translation((px, D / 2 + 0.013, pz)) @ Matrix.Rotation(math.pi, 4, 'Z') \
            @ Matrix.Rotation(math.pi / 2, 4, 'X')
        letters = C.text_bm(bm, "CCG", 0.085, M, extrude=0.004)
        C.tag_faces(bm, letters, P_LETTER)
    ob = C.obj_from_bmesh(name, bm)
    C.clean_mesh(ob, 1e-5)
    C.set_smooth(ob, 35)
    return ob


def handle():
    bm = C.new_part_bm()
    path = []
    # D-shaped bar: legs down into the mounts, rounded corners, straight grip along X
    for x_sign in (-1,):
        pass
    legs = [(-0.275, -0.13), (-0.275, -0.06), (-0.268, -0.03), (-0.25, -0.01), (-0.22, 0.0)]
    pts = legs + [(x, 0.0) for x in (-0.11, 0.0, 0.11)] + [(-x, z) for x, z in reversed(legs)]
    path = [Vector((x, 0, z)) for x, z in pts]
    n0 = len(bm.faces)
    C.sweep(bm, path, 0.04, sides=8, flat=1.0)
    C.tag_faces(bm, C.new_faces_since(bm, n0), P_GRIP)
    for x in (-0.275, 0.275):
        add_box(bm, (x, 0, TOP + 0.04), (0.10, 0.12, 0.08), P_TRIM, 0.015)
    # trigger button on the underside of the bar, under the index finger
    add_box(bm, (0.07, 0, -0.06), (0.10, 0.04, 0.05), P_TRIGGER, 0.008)
    ob = C.obj_from_bmesh("CaseHandle", bm)
    C.clean_mesh(ob, 1e-5)
    C.set_smooth(ob, 40)
    return ob


def build_material():
    mb = C.MatBuilder("CaseMat")
    co = mb.coord("Object")
    m = C.part_masks(mb, range(8))
    # brushed aluminium: fine streaks along X
    br = mb.noise(mb.mapping(co, scale=(1.5, 140, 140)), scale=1.0, detail=3, rough=0.6).outputs["Fac"]
    br2 = mb.noise(mb.mapping(co, scale=(0.6, 30, 30)), scale=1.0, detail=2).outputs["Fac"]
    streak = mb.math('ADD', mb.math('MULTIPLY', br, 0.7), mb.math('MULTIPLY', br2, 0.3))
    dz = mb.math('MULTIPLY', mb.math('SUBTRACT', streak, 0.5), 0.10)
    light = mb.mix(mb.math('ADD', 0.5, dz), C.hexlin(STEEL_LIGHT), (0.0, 0.0, 0.0, 1), 'MIX')
    light = mb.mix(0.5, light, C.hexlin(STEEL_LIGHT), 'MIX')
    light = mb.mix(mb.math('MAXIMUM', mb.math('MULTIPLY', dz, -4.0), 0.0), light, (1, 1, 1, 1), 'MIX')
    mid = mb.mix(mb.math('ADD', 0.5, mb.math('MULTIPLY', dz, 0.6)), C.hexlin(STEEL_MID), (0, 0, 0, 1))
    mid = mb.mix(0.5, mid, C.hexlin(STEEL_MID))
    knurl = mb.wave(mb.mapping(co, scale=(1, 1, 1), rot=(0, 0, 0.6)), scale=60, bands='BANDS', direction='X')
    grip = mb.mix(mb.math('MULTIPLY', knurl.outputs["Fac"], 0.15), C.hexlin(GRIP_BLACK), (0.08, 0.08, 0.09, 1))
    color = by = C.by_part_color(mb, m, {
        P_SHELL: light, P_TRIM: mid, P_LATCH: mid, P_TRIGGER: mid, P_PLATE: light, P_LETTER: mid,
        P_GRIP: grip, P_SEAM: C.hexlin(RC_DARK)}, C.hexlin(STEEL_LIGHT))
    rough = C.by_part_float(mb, m, {
        P_SHELL: mb.math('ADD', 0.30, mb.math('MULTIPLY', streak, 0.1)),
        P_PLATE: 0.42, P_TRIM: 0.30, P_LATCH: 0.30, P_TRIGGER: 0.3, P_LETTER: 0.3,
        P_GRIP: 0.7, P_SEAM: 0.4})
    metal = C.by_part_float(mb, m, {P_SHELL: 0.85, P_PLATE: 0.85, P_TRIM: 0.9, P_LATCH: 0.9,
                                    P_TRIGGER: 0.9, P_LETTER: 0.9})
    height = C.by_part_float(mb, m, {P_SHELL: mb.math('MULTIPLY', streak, 0.25),
                                     P_PLATE: mb.math('MULTIPLY', streak, 0.1),
                                     P_GRIP: mb.math('MULTIPLY', knurl.outputs["Fac"], 0.6)})
    emis = C.by_part_float(mb, m, {P_SEAM: 1.0, P_TRIGGER: 1.0})
    mb.finish(color, rough, metal, height=height, bump_strength=0.2, bump_distance=0.01,
              extra={"emissive": emis})
    return mb


def main(do_render=True):
    C.reset()
    front, back, hnd = shell(True), shell(False), handle()
    objs = [front, back, hnd]
    C.smart_uv(objs, margin=0.004, angle=50)
    mb = build_material()
    for o in objs:
        C.assign(o, mb.mat)
    paths = C.bake_material(objs, mb, ASSET)
    # in game the emissive is off at rest (seam glow only while opening, trigger when pressed)
    gm = C.game_material(ASSET, paths, emissive_tint=C.hexlin(RC_GLOW), emissive_strength=0.0)
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
            "pivot": "grip point = centre of the handle bar (same origin for all case objects)",
            "bakedBend": "n/a", "textures": tex}
    entries["CaseShellFront"]["note"] = "front = -Z half; inner seam face is RC_DARK (emissive mask 1)"
    entries["CaseShellBack"]["note"] = "back = +Z half"
    entries["CaseHandle"]["trigger_position"] = [0.07, -0.06, 0.0]
    for nm, zs in (("CaseShellFront", -1), ("CaseShellBack", 1)):
        entries[nm]["hinge"] = {"point": [0.0, round(TOP - H, 3), round(zs * SEAM, 4)], "axis": [1, 0, 0],
                                "open": "rotate about the hinge line (bottom long edge); front opens toward -Z, back toward +Z"}
    C.write_manifest_entry("quinque_case", {
        "files": [f"models/{ASSET}.fbx", f"models/{ASSET}.obj"],
        "axes": "width X (1.6), hangs along -Y below the grip (shell top at Y=-0.16, bottom at Y=-1.36), thickness Z (0.4)",
        "hold": "R6: attach origin to RightGripAttachment; rotate 90 deg about Y so the width runs along the character's forward axis (hanging at the side)",
        "emissive": "mask covers the seam interior and the trigger; tint #FF3B3B, strength 0 at rest",
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
    parts = []
    for i, (az, el) in enumerate(((0, 8), (90, 8), (35, 22))):
        C.camera_view(objs, az, el, margin=1.12)
        parts.append(C.render_to(os.path.join(R, f"_tmp_c{i}.png")))
    # exploded: shells pulled apart to show the split + seam interior
    objs[0].location.y += 0.45
    objs[1].location.y -= 0.45
    objs[2].location.z += 0.25
    C.camera_view(objs, 60, 25, margin=1.12)
    parts.append(C.render_to(os.path.join(R, "_tmp_c3.png")))
    for o in objs:
        o.location = (0, 0, 0)
    C.stitch(parts, os.path.join(R, f"{ASSET}_turnaround.png"))
    # close-ups: handle + trigger (from below-front), CCG plate
    C.camera_view([objs[2]], 30, -8, margin=1.6)
    p1 = C.render_to(os.path.join(R, "_tmp_d0.png"))
    bm = bmesh.new()
    C.box_bm(bm, (-0.22, D / 2, TOP - H + 0.16), (0.42, 0.05, 0.2))
    probe = C.obj_from_bmesh("probe", bm)
    probe.hide_render = True
    C.camera_view([probe], 0, 5, margin=1.1)
    p2 = C.render_to(os.path.join(R, "_tmp_d1.png"))
    # open pose: half-shells hinge outward about the bottom long edge (transform step 3)
    hinge = Vector((0, 0, TOP - H))
    for o, ang in ((objs[0], -70), (objs[1], 70)):
        o.matrix_world = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(ang), 4, 'X') \
            @ Matrix.Translation(-hinge)
    C.camera_view(objs, 60, 20, margin=1.12)
    p3 = C.render_to(os.path.join(R, "_tmp_d2.png"))
    for o in objs:
        o.matrix_world = Matrix()
    C.stitch([p1, p2, p3], os.path.join(R, f"{ASSET}_details.png"))
    # scale: hanging from the R6 right hand, width along the character's forward axis
    man = C.mannequin(right_arm_pitch=0, left_arm_pitch=0)
    C.ground()
    M = Matrix.Translation((0.1, 0, 0)) @ man["right_grip"] @ Matrix.Rotation(math.radians(90), 4, 'Z')
    for o in objs:
        o.matrix_world = M
    mq = [o for k, o in man.items() if hasattr(o, "type")]
    parts = []
    for i, (az, el) in enumerate(((0, 6), (90, 6), (40, 14))):
        C.camera_view(objs + mq, az, el, margin=1.08)
        parts.append(C.render_to(os.path.join(R, f"_tmp_cs{i}.png")))
    C.stitch(parts, os.path.join(R, f"{ASSET}_scale.png"))


if __name__ == "__main__":
    main(do_render="--no-render" not in sys.argv)
