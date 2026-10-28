"""Preview the GAME's kagune tentacle math on the R6 mannequin (for tuning idle/strike poses).

Run:  /home/claude/blender-venv/bin/python tools/blender/preview_kagune_pose.py ['{"REST_CURL": [...], ...}']

Uses the exported assets/models/kagune_rinkaku.obj + baked textures (run build_kagune.py
first).  All pose math is done in ROBLOX space exactly as the game does it, then converted:
  Kakuhou     = Torso(0,3,0) * T(0,-0.65,0.65)
  root_i      = Kakuhou * T(socket_i) * RotY(yaw) * RotX(pitch) * RotZ(roll)
  base_1      = root_i;  base_{k+1} = base_k * T(0, L_k, 0) * RotX(REST_CURL[k] * curl)
Outputs: assets/renders/kagune_rinkaku_pose_rest.png (front | side | 3/4 back) and
         assets/renders/kagune_rinkaku_pose_strike.png (front | side | 3/4 back).
"""
import sys
import os
import json
import math
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C  # noqa: E402

PARAMS = {   # final values approved by the reference reviewer (rest v2, strike v4 + clearance pass)
    "REST_CURL": [-6, 20, 13, -30, -30],
    "REST_PITCH_UPPER": 55, "REST_PITCH_LOWER": 55,
    "REST_ROLL_UPPER": -20, "REST_ROLL_LOWER": -30,     # multiplied by side
    "REST_YAW": 0,
    "CURL_MULT_UPPER": 1.0, "CURL_MULT_LOWER": 0.75,    # per-tail curl multipliers (rest)
    # strike: per-pair root angles (yaw/roll multiplied by side) and per-pair curl lists,
    # solved so the four tips converge on (0, 3.25, -7) (chest height, 7 studs ahead): upper
    # pair over their own shoulders, lower pair round the flanks; no torso/head/arm contact
    "STRIKE_PITCH_UPPER": -49.7, "STRIKE_YAW_UPPER": 46.4, "STRIKE_ROLL_UPPER": -48.6,
    "STRIKE_CURL_UPPER": [5.4, -6.9, -39.3, -33.5, -1.0],
    "STRIKE_PITCH_LOWER": 24.4, "STRIKE_YAW_LOWER": 53.3, "STRIKE_ROLL_LOWER": -101.4,
    "STRIKE_CURL_LOWER": [-22.9, -6.9, -31.1, -25.9, 0.4],
}
SOCKETS = [((0.3, 0.1, 0.1), 1, True), ((-0.3, 0.1, 0.1), -1, True),
           ((0.55, -0.1, 0.1), 1, False), ((-0.55, -0.1, 0.1), -1, False)]
CHAIN = ["RinkakuSeg1", "RinkakuSeg2", "RinkakuSeg3", "RinkakuSeg4", "RinkakuSeg5", "RinkakuTip"]

# Roblox -> Blender basis change: (x, y, z)_rbx -> (x, -z, y)_bl
P = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def R(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def to_bl(m):
    """Roblox CFrame of a part whose mesh data is in Roblox coords -> Blender matrix_world."""
    return P @ m


def chain(root, lengths, curls, curl):
    mats = [root]
    for k in range(5):
        mats.append(mats[-1] @ T(0, lengths[k], 0) @ R('X', curls[k] * curl))
    return mats


def main():
    if len(sys.argv) > 1 and sys.argv[-1].startswith("{"):
        PARAMS.update(json.loads(sys.argv[-1]))
    with open(os.path.join(C.MODELS, "manifest.json")) as f:
        man = json.load(f)["kagune_rinkaku"]
    lengths = man["joint_lengths"]
    C.reset()
    # import WITHOUT axis conversion: mesh data stays in Roblox coordinates, and every
    # placement below is matrix_world = P @ M_roblox
    bpy.ops.wm.obj_import(filepath=os.path.join(C.MODELS, "kagune_rinkaku.obj"),
                          forward_axis='Y', up_axis='Z')
    src = {o.name: o for o in bpy.data.objects}
    for o in src.values():
        o.matrix_world = Matrix()
    paths = {ch: os.path.join(C.TEXTURES, f"kagune_rinkaku_{ch}.png")
             for ch in ("albedo", "roughness", "metalness", "normal", "emissive")}
    gm = C.game_material("kagune_rinkaku", paths, emissive_tint=C.hexlin("#FF3B3B"), emissive_strength=0.2)
    for o in src.values():
        C.assign(o, gm)
        C.set_smooth(o, 60)
        o.hide_render = True
    C.setup_render((640, 640), 24)
    mq = C.mannequin(right_arm_pitch=0)
    mqo = [o for o in mq.values() if hasattr(o, "type")]
    C.ground()
    K = T(0, 3, 0) @ T(0, -0.65, 0.65)

    def place(pose):
        objs = []
        k = src["Kakuhou"].copy()
        C.link(k)
        k.matrix_world = to_bl(K)
        k.hide_render = False
        objs.append(k)
        for pos, side, upper in SOCKETS:
            if pose == "rest":
                pitch = PARAMS["REST_PITCH_UPPER"] if upper else PARAMS["REST_PITCH_LOWER"]
                roll = side * (PARAMS["REST_ROLL_UPPER"] if upper else PARAMS["REST_ROLL_LOWER"])
                yaw, curls = PARAMS["REST_YAW"] * side, PARAMS["REST_CURL"]
                curl = PARAMS["CURL_MULT_UPPER"] if upper else PARAMS["CURL_MULT_LOWER"]
            else:
                g = "UPPER" if upper else "LOWER"
                pitch = PARAMS["STRIKE_PITCH_" + g]
                yaw, roll = side * PARAMS["STRIKE_YAW_" + g], side * PARAMS["STRIKE_ROLL_" + g]
                curls, curl = PARAMS["STRIKE_CURL_" + g], 1.0
            root = K @ T(*pos) @ R('Y', yaw) @ R('X', pitch) @ R('Z', roll)
            for name, m in zip(CHAIN, chain(root, lengths, curls, curl)):
                c = src[name].copy()
                C.link(c)
                c.matrix_world = to_bl(m)
                c.hide_render = False
                objs.append(c)
        return objs

    report = {}
    for pose in [p for p in ("rest", "strike") if p in PARAMS.get("POSES", ["rest", "strike"])]:
        objs = place(pose)
        bpy.context.view_layer.update()
        mn, mx = C.world_bbox(objs)
        # torso-intersection check: any tentacle vertex inside the torso/head box
        # (Blender coords: x, y = -Roblox Z, z = Roblox Y); Seg1 is skipped (it emerges from the back)
        boxes = {"torso": ((-1, 1), (-0.5, 0.5), (2, 4)), "head": ((-0.62, 0.62), (-0.62, 0.62), (4, 5.2)),
                 "armR": ((1, 2), (-0.5, 0.5), (2, 4)), "armL": ((-2, -1), (-0.5, 0.5), (2, 4)),
                 "legs": ((-1, 1), (-0.5, 0.5), (0, 2))}
        hits = {k: 0 for k in boxes}
        hit_parts = set()
        for o in objs[1:]:
            if "Seg1" in o.name:
                continue
            mw = o.matrix_world
            for v in o.data.vertices:
                w = mw @ v.co
                for k, ((x0, x1), (y0, y1), (z0, z1)) in boxes.items():
                    if x0 < w.x < x1 and y0 < w.y < y1 and z0 < w.z < z1:
                        hits[k] += 1
                        hit_parts.add(o.name)
        tips = [o for o in objs if o.name.startswith("RinkakuTip")]
        tip_pts = []
        for o in tips:
            vs = [o.matrix_world @ v.co for v in o.data.vertices]
            tp = max(vs, key=lambda q: (q - o.matrix_world.translation).length)
            tip_pts.append([round(tp.x, 2), round(tp.z, 2), round(-tp.y, 2)])
        report[pose] = {"top_y": round(mx.z, 2), "head_top": 5.2, "above_head": round(mx.z - 5.2, 2),
                        "span_x": round(mx.x - mn.x, 2), "reach_forward": round(mx.y, 2),
                        "behind": round(-mn.y, 2), "intersect_verts_excl_seg1": hits, "intersecting_parts": sorted(hit_parts),
                        "tips_roblox": tip_pts}
        parts = []
        views = ((0, 6), (90, 6), (215, 16)) if pose == "rest" else ((90, 6), (35, 14), (0, 89))
        for i, (az, el) in enumerate(views):
            C.camera_view(objs + mqo, az, el, margin=1.06)
            parts.append(C.render_to(os.path.join(C.RENDERS, f"_tmp_p{pose}{i}.png")))
        C.stitch(parts, os.path.join(C.RENDERS, f"kagune_rinkaku_pose_{pose}.png"))
        for o in objs:
            bpy.data.objects.remove(o)
    print("POSE_REPORT", json.dumps(report), json.dumps(PARAMS))


if __name__ == "__main__":
    main()
