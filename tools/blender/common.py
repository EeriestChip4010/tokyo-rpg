"""Shared helpers for the procedural asset builders (headless Blender / bpy 4.2).

Coordinate contract
-------------------
1 Blender unit = 1 Roblox stud.  The export contract (README / manifest) is written in
ROBLOX axes (Y up, character faces -Z).  Inside Blender we model Z-up and convert on export:

    Roblox +X  = Blender +X
    Roblox +Y  = Blender +Z      (up)
    Roblox +Z  = Blender -Y      (so Roblox -Z / "forward" = Blender +Y)

Exports use forward=-Z, up=Y, which performs exactly that mapping.  Use rbx(x, y, z) to
write Roblox-space coordinates while modelling.
"""
import bpy
import bmesh
import math
import os
import json
import numpy as np
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ASSETS = os.path.join(REPO, "assets")
MODELS = os.path.join(ASSETS, "models")
TEXTURES = os.path.join(ASSETS, "textures")
RENDERS = os.path.join(ASSETS, "renders")
for _d in (MODELS, TEXTURES, RENDERS):
    os.makedirs(_d, exist_ok=True)

TEX_SIZE = 1024


def rbx(x, y, z):
    """Roblox-space point -> Blender-space Vector."""
    return Vector((x, -z, y))


# --------------------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 1.0
    return sc


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def obj_from_bmesh(name, bm):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    return link(ob)


def loft(bm, rings, cap_start="fan", cap_end="fan"):
    """Connect a list of rings (each a list of Vectors, same length, CCW looking down +axis)
    with quads. cap: 'fan' (centre vertex), 'ngon', 'point' (ring of len 1 allowed at ends) or None.
    Returns list of BMVert rings."""
    vrings = [[bm.verts.new(p) for p in ring] for ring in rings]
    for a, b in zip(vrings[:-1], vrings[1:]):
        n = len(a)
        if len(b) == 1:
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[0]))
            continue
        if n == 1:
            for i in range(len(b)):
                bm.faces.new((a[0], b[(i + 1) % len(b)], b[i]))
            continue
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))

    def cap(ring, reverse):
        if len(ring) < 3:
            return
        if cap_mode(reverse) == "ngon":
            vs = list(reversed(ring)) if reverse else ring
            bm.faces.new(vs)
        else:
            c = sum((v.co for v in ring), Vector()) / len(ring)
            cv = bm.verts.new(c)
            n = len(ring)
            for i in range(n):
                if reverse:
                    bm.faces.new((ring[(i + 1) % n], ring[i], cv))
                else:
                    bm.faces.new((ring[i], ring[(i + 1) % n], cv))

    def cap_mode(rev):
        return cap_start if rev else cap_end

    if cap_start in ("fan", "ngon"):
        cap(vrings[0], True)
    if cap_end in ("fan", "ngon"):
        cap(vrings[-1], False)
    return vrings


def box_bm(bm, center, size, bevel=0.0, segments=1):
    """Add an axis-aligned box (Blender space) to bm, optional bevel."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    vs = res["verts"]
    bmesh.ops.scale(bm, vec=Vector(size), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(center), verts=vs)
    if bevel > 0:
        edges = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges + vs, offset=bevel, segments=segments,
                        affect='EDGES', profile=0.5)
    return vs


def set_smooth(ob, angle_deg=40.0):
    """Smooth shade with sharp edges above angle (manual auto-smooth; no modifiers)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    lim = math.radians(angle_deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0.0) <= lim
        else:
            e.smooth = False
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def recalc_normals(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def clean_mesh(ob, merge=1e-4):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=merge)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def bbox_size_rbx(ob):
    """Bounding box size in ROBLOX axes (local coords, i.e. relative to the pivot)."""
    vs = np.array([v.co[:] for v in ob.data.vertices])
    mn, mx = vs.min(0), vs.max(0)
    s = mx - mn
    c_b = (mn + mx) / 2
    return ({"x": round(float(s[0]), 3), "y": round(float(s[2]), 3), "z": round(float(s[1]), 3)},
            {"x": round(float(c_b[0]), 3), "y": round(float(c_b[2]), 3), "z": round(float(-c_b[1]), 3)})


def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


# --------------------------------------------------------------------------- UV

def smart_uv(objs, margin=0.01, angle=66.0):
    select_only(objs)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin,
                             scale_to_bounds=False, correct_aspect=True)
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.pack_islands(margin=margin, rotate=True, shape_method='CONCAVE')
    bpy.ops.object.mode_set(mode='OBJECT')


# --------------------------------------------------------------------------- materials

class MatBuilder:
    """Tiny node-graph helper."""

    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        self.mat.use_nodes = True
        self.nt = self.mat.node_tree
        self.nt.nodes.clear()
        self.N = self.nt.nodes
        self.L = self.nt.links
        self._x = 0

    def node(self, kind, **props):
        n = self.N.new(kind)
        n.location = (self._x, 0)
        self._x += 200
        for k, v in props.items():
            if k.startswith("in_"):
                key = k[3:]
                key = int(key) if key.isdigit() else key.replace("_", " ")
                n.inputs[key].default_value = v
            else:
                setattr(n, k, v)
        return n

    def link(self, a, b):
        self.L.new(a, b)

    # common building blocks ------------------------------------------------
    def coord(self, kind="Object"):
        if not hasattr(self, "_tc"):
            self._tc = self.node("ShaderNodeTexCoord")
        return self._tc.outputs[kind]

    def mapping(self, vec, scale=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0)):
        m = self.node("ShaderNodeMapping")
        m.inputs["Scale"].default_value = scale
        m.inputs["Location"].default_value = loc
        m.inputs["Rotation"].default_value = rot
        self.link(vec, m.inputs["Vector"])
        return m.outputs["Vector"]

    def noise(self, vec, scale=5.0, detail=4.0, rough=0.5, distortion=0.0, dims='3D'):
        n = self.node("ShaderNodeTexNoise", noise_dimensions=dims)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distortion
        self.link(vec, n.inputs["Vector"])
        return n

    def voronoi(self, vec, scale=5.0, feature='F1', dist='EUCLIDEAN', rand=1.0):
        n = self.node("ShaderNodeTexVoronoi", feature=feature, distance=dist)
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = rand
        self.link(vec, n.inputs["Vector"])
        return n

    def wave(self, vec, scale=5.0, distortion=0.0, detail=2.0, bands='BANDS', direction='Z', profile='SIN'):
        n = self.node("ShaderNodeTexWave", wave_type=bands, wave_profile=profile)
        if bands == 'BANDS':
            n.bands_direction = direction
        else:
            n.rings_direction = direction if direction in ('X', 'Y', 'Z', 'SPHERICAL') else 'Z'
        n.inputs["Scale"].default_value = scale
        n.inputs["Distortion"].default_value = distortion
        n.inputs["Detail"].default_value = detail
        self.link(vec, n.inputs["Vector"])
        return n

    def math(self, op, a, b=None, clamp=False, c=None):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b, c)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n.inputs[i])
        return n.outputs[0]

    def vmath(self, op, a, b=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (tuple, list)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n.inputs[i])
        return n

    def sep(self, vec):
        n = self.node("ShaderNodeSeparateXYZ")
        self.link(vec, n.inputs[0])
        return n.outputs

    def ramp(self, fac, stops, interp='LINEAR'):
        n = self.node("ShaderNodeValToRGB")
        cr = n.color_ramp
        cr.interpolation = interp
        while len(cr.elements) > 1:
            cr.elements.remove(cr.elements[-1])
        for i, (pos, col) in enumerate(stops):
            e = cr.elements[0] if i == 0 else cr.elements.new(pos)
            e.position = pos
            e.color = col if len(col) == 4 else (*col, 1.0)
        self.link(fac, n.inputs[0])
        return n

    def mix(self, fac, a, b, blend='MIX'):
        n = self.node("ShaderNodeMix", data_type='RGBA', blend_type=blend)
        for sock, v in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
            if isinstance(v, (int, float)):
                sock.default_value = v
            elif isinstance(v, (tuple, list)):
                sock.default_value = v if len(v) == 4 else (*v, 1.0)
            else:
                self.link(v, sock)
        return n.outputs[2]

    def value(self, v):
        n = self.node("ShaderNodeValue")
        n.outputs[0].default_value = v
        return n.outputs[0]

    def rgb(self, c):
        n = self.node("ShaderNodeRGB")
        n.outputs[0].default_value = c if len(c) == 4 else (*c, 1.0)
        return n.outputs[0]

    def finish(self, color, rough, metal, height=None, bump_strength=0.5, bump_distance=0.02,
               emission=None, emission_strength=1.0, extra=None):
        """Wire a Principled BSDF. Keeps the channel sockets for baking.
        extra: additional {channel: socket} to bake as Non-Color greyscale (e.g. emissive mask)."""
        bsdf = self.node("ShaderNodeBsdfPrincipled")
        for name, v in (("Base Color", color), ("Roughness", rough), ("Metallic", metal)):
            if isinstance(v, (int, float)):
                bsdf.inputs[name].default_value = v
            elif isinstance(v, (tuple, list)):
                bsdf.inputs[name].default_value = v if len(v) == 4 else (*v, 1.0)
            else:
                self.link(v, bsdf.inputs[name])
        if height is not None:
            b = self.node("ShaderNodeBump")
            b.inputs["Strength"].default_value = bump_strength
            b.inputs["Distance"].default_value = bump_distance
            self.link(height, b.inputs["Height"])
            self.link(b.outputs["Normal"], bsdf.inputs["Normal"])
        if emission is not None:
            self.link(emission, bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        out = self.node("ShaderNodeOutputMaterial")
        self.link(bsdf.outputs[0], out.inputs["Surface"])
        self.bsdf, self.out = bsdf, out
        self.channels = {"albedo": color, "roughness": rough, "metalness": metal}
        self.channels.update(extra or {})
        return self.mat


def flat_material(name, color, rough=0.6, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def assign(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


# --------------------------------------------------------------------------- baking

def _bake_target(mb, img):
    n = mb.N.new("ShaderNodeTexImage")
    n.image = img
    n.location = (mb._x, -400)
    for x in mb.N:
        x.select = False
    n.select = True
    mb.N.active = n
    return n


def bake_material(objs, mb, asset, size=TEX_SIZE, margin=8):
    """Bake albedo / roughness / metalness (via emission) and tangent normal (from bump)
    of the procedural material in MatBuilder `mb`, shared by all objs (same UV atlas).
    Returns dict channel -> png path."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 4
    sc.render.bake.margin = margin
    sc.render.bake.use_clear = True
    select_only(objs)
    paths = {}
    emit = mb.N.new("ShaderNodeEmission")
    for ch in list(mb.channels) + ["normal"]:
        img = bpy.data.images.new(f"{asset}_{ch}", size, size, alpha=False, float_buffer=False)
        img.colorspace_settings.name = 'sRGB' if ch == "albedo" else 'Non-Color'
        tgt = _bake_target(mb, img)
        if ch == "normal":
            mb.L.new(mb.bsdf.outputs[0], mb.out.inputs["Surface"])
            bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=margin)
        else:
            src = mb.channels[ch]
            if isinstance(src, (int, float)):
                emit.inputs["Color"].default_value = (src, src, src, 1.0)
                for l in list(emit.inputs["Color"].links):
                    mb.L.remove(l)
            elif isinstance(src, (tuple, list)):
                emit.inputs["Color"].default_value = src if len(src) == 4 else (*src, 1.0)
                for l in list(emit.inputs["Color"].links):
                    mb.L.remove(l)
            else:
                mb.L.new(src, emit.inputs["Color"])
            emit.inputs["Strength"].default_value = 1.0
            mb.L.new(emit.outputs[0], mb.out.inputs["Surface"])
            bpy.ops.object.bake(type='EMIT', margin=margin)
        p = os.path.join(TEXTURES, f"{asset}_{ch}.png")
        img.filepath_raw = p
        img.file_format = 'PNG'
        img.save()
        paths[ch] = p
        mb.N.remove(tgt)
    mb.L.new(mb.bsdf.outputs[0], mb.out.inputs["Surface"])
    mb.N.remove(emit)
    return paths


def hexlin(h, a=1.0):
    """'#RRGGBB' (sRGB) -> linear RGBA tuple for node sockets."""
    h = h.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, a)


def game_material(asset, paths, emission_from_albedo=0.0, emissive_tint=None, emissive_strength=1.0):
    """Material using only the baked PNGs, i.e. what a Roblox SurfaceAppearance shows."""
    m = bpy.data.materials.new(f"{asset}_game")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]

    def tex(ch, noncolor):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(paths[ch], check_existing=False)
        t.image.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
        return t
    a = tex("albedo", False)
    nt.links.new(a.outputs[0], b.inputs["Base Color"])
    r = tex("roughness", True)
    nt.links.new(r.outputs[0], b.inputs["Roughness"])
    mt = tex("metalness", True)
    nt.links.new(mt.outputs[0], b.inputs["Metallic"])
    n = tex("normal", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    if emissive_tint is not None and "emissive" in paths:
        e = tex("emissive", True)
        mixn = nt.nodes.new("ShaderNodeMix")
        mixn.data_type = 'RGBA'
        mixn.blend_type = 'MULTIPLY'
        mixn.inputs[0].default_value = 1.0
        nt.links.new(e.outputs[0], mixn.inputs[6])
        mixn.inputs[7].default_value = emissive_tint
        nt.links.new(mixn.outputs[2], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emissive_strength
    if emission_from_albedo > 0:
        nt.links.new(a.outputs[0], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emission_from_albedo
    return m


# --------------------------------------------------------------------------- export

def export(objs, basename):
    """FBX + OBJ, selected objects only, Roblox axes (Y up, -Z forward), 1 unit = 1 stud."""
    for o in objs:
        o.data.name = o.name
    select_only(objs)
    fbx = os.path.join(MODELS, basename + ".fbx")
    obj = os.path.join(MODELS, basename + ".obj")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', bake_space_transform=True,
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             global_scale=1.0, mesh_smooth_type='FACE', use_mesh_modifiers=True,
                             add_leaf_bones=False, path_mode='STRIP', use_tspace=True)
    bpy.ops.wm.obj_export(filepath=obj, export_selected_objects=True, forward_axis='NEGATIVE_Z',
                          up_axis='Y', export_materials=True, path_mode='STRIP',
                          export_normals=True, export_uv=True, export_triangulated_mesh=False,
                          global_scale=1.0, apply_modifiers=True)
    return fbx, obj


# --------------------------------------------------------------------------- R6 mannequin

def mannequin(right_arm_pitch=0.0, left_arm_pitch=0.0, right_arm_roll=0.0, prefix="R6_"):
    """R6 block mannequin in Blender space, feet at z=0, facing Roblox -Z (= Blender +Y).
    right_arm_pitch: degrees the right arm swings forward (90 = pointing forward).
    Returns dict with parts and 'right_grip' (world Matrix of the R6 RightGripAttachment:
    bottom-centre of the right arm, with the arm's local axes)."""
    skin = flat_material(prefix + "skin", (0.62, 0.62, 0.6), 0.7)
    shirt = flat_material(prefix + "shirt", (0.18, 0.2, 0.24), 0.8)
    pants = flat_material(prefix + "pants", (0.1, 0.1, 0.12), 0.8)
    face = flat_material(prefix + "face", (0.05, 0.05, 0.05), 0.5)
    parts = {}

    def part(name, size, center, mat, pivot=None, pitch=0.0, roll=0.0):
        bm = bmesh.new()
        piv = Vector(pivot) if pivot else Vector(center)
        box_bm(bm, Vector(center) - piv, size, bevel=0.04, segments=2)
        ob = obj_from_bmesh(prefix + name, bm)
        ob.location = piv
        ob.rotation_euler = Euler((math.radians(pitch), math.radians(roll), 0), 'XYZ')
        assign(ob, mat)
        parts[name] = ob
        return ob
    part("Torso", (2, 1, 2), (0, 0, 3), shirt)
    part("LeftLeg", (1, 1, 2), (-0.5, 0, 1), pants)
    part("RightLeg", (1, 1, 2), (0.5, 0, 1), pants)
    # arms pivot at shoulder (R6 shoulder joint ~0.5 below top of arm)
    ra = part("RightArm", (1, 1, 2), (1.5, 0, 3), skin, pivot=(1.5, 0, 3.5), pitch=right_arm_pitch,
              roll=right_arm_roll)
    part("LeftArm", (1, 1, 2), (-1.5, 0, 3), skin, pivot=(-1.5, 0, 3.5), pitch=left_arm_pitch)
    hd = bmesh.new()
    bmesh.ops.create_cone(hd, cap_ends=True, segments=24, radius1=0.62, radius2=0.62, depth=1.2)
    obh = obj_from_bmesh(prefix + "Head", hd)
    obh.location = (0, 0, 4.6)
    assign(obh, skin)
    set_smooth(obh, 50)
    parts["Head"] = obh
    # face marker on the front (Blender +Y) so orientation reads in renders
    fb = bmesh.new()
    box_bm(fb, (0.22, 0.6, 4.72), (0.12, 0.06, 0.25))
    box_bm(fb, (-0.22, 0.6, 4.72), (0.12, 0.06, 0.25))
    obf = obj_from_bmesh(prefix + "Face", fb)
    assign(obf, face)
    parts["Face"] = obf
    bpy.context.view_layer.update()
    # RightGripAttachment: arm-local (0,-1,0) roblox -> blender (0,0,-1) relative to arm centre
    # arm centre is 0.5 below pivot -> grip is 1.5 below pivot in arm space
    grip = ra.matrix_world @ Matrix.Translation((0, 0, -1.5))
    parts["right_grip"] = grip
    # lower back mount (Blender -Y face of torso, ~0.6 above the waist)
    parts["lower_back"] = Matrix.Translation((0, -0.5, 2.55))
    return parts


# --------------------------------------------------------------------------- rendering

def setup_render(res=(768, 768), samples=24, bg=(0.18, 0.18, 0.2), env=None):
    """env: (color, strength) of the lighting environment seen by reflections (camera still
    sees `bg`). Metals need a brighter environment to read as silver."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 4
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast'
    sc.render.image_settings.file_format = 'PNG'
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*bg, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    if env is not None:
        nt = w.node_tree
        b2 = nt.nodes.new("ShaderNodeBackground")
        b2.inputs[0].default_value = (*env[0], 1)
        b2.inputs[1].default_value = env[1]
        # vertical gradient: brighter sky above, darker floor below (studio sweep)
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sepn.inputs[0])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (0.15, 0.15, 0.16, 1)
        ramp.color_ramp.elements[1].color = (*env[0], 1)
        ramp.color_ramp.elements[0].position = 0.45
        ramp.color_ramp.elements[1].position = 0.7
        nt.links.new(sepn.outputs[2], ramp.inputs[0])
        nt.links.new(ramp.outputs[0], b2.inputs[0])
        lp = nt.nodes.new("ShaderNodeLightPath")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
        nt.links.new(b2.outputs[0], mix.inputs[1])
        nt.links.new(nt.nodes["Background"].outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs[0])
    sc.world = w
    # three point light + ground
    def light(name, kind, loc, energy, size=2.0, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = color
        if kind == 'AREA':
            ld.size = size
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        link(lo)
        c = Vector((0, 0, 1.5)) - Vector(loc)
        lo.rotation_euler = c.to_track_quat('-Z', 'Y').to_euler()
        return lo
    light("Key", 'AREA', (4, 6, 7), 900, 4)
    light("Fill", 'AREA', (-6, 3, 3), 300, 5, (0.85, 0.9, 1.0))
    light("Rim", 'AREA', (0, -7, 6), 700, 4)
    return sc


def ground(z=0.0, size=40):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size / 2)
    g = obj_from_bmesh("Ground", bm)
    g.location.z = z
    assign(g, flat_material("ground", (0.32, 0.32, 0.33), 0.9))
    return g


def world_bbox(objs):
    pts = []
    for o in objs:
        if o.type != 'MESH':
            continue
        mw = o.matrix_world
        pts += [mw @ Vector(c) for c in o.bound_box]
    a = np.array([p[:] for p in pts])
    return Vector(a.min(0)), Vector(a.max(0))


def camera_view(objs, azimuth_deg, elevation_deg=12.0, margin=1.15, ortho=True, lens=50):
    """Place (or reuse) the scene camera looking at objs from an azimuth around Blender Z.
    azimuth 0 = from the front of a character (Blender +Y side looking toward -Y)."""
    sc = bpy.context.scene
    cam = sc.camera
    if cam is None:
        cd = bpy.data.cameras.new("Cam")
        cam = link(bpy.data.objects.new("Cam", cd))
        sc.camera = cam
    mn, mx = world_bbox(objs)
    ctr = (mn + mx) / 2
    ext = (mx - mn)
    rad = ext.length / 2
    az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = ctr + d * (rad * 6 + 5)
    cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_end = 500
    if ortho:
        cam.data.type = 'ORTHO'
        # project bbox corners into the camera plane to size it
        bpy.context.view_layer.update()
        inv = cam.matrix_world.inverted()
        corners = [Vector((x, y, z)) for x in (mn.x, mx.x) for y in (mn.y, mx.y) for z in (mn.z, mx.z)]
        loc = [inv @ c for c in corners]
        w = max(p.x for p in loc) - min(p.x for p in loc)
        h = max(p.y for p in loc) - min(p.y for p in loc)
        cx = (max(p.x for p in loc) + min(p.x for p in loc)) / 2
        cy = (max(p.y for p in loc) + min(p.y for p in loc)) / 2
        cam.location = cam.matrix_world @ Vector((cx, cy, 0))
        rx, ry = sc.render.resolution_x, sc.render.resolution_y
        aspect = rx / ry
        cam.data.ortho_scale = max(w, h * aspect) * margin if aspect >= 1 else max(w / aspect, h) * margin
    else:
        cam.data.type = 'PERSP'
        cam.data.lens = lens
    return cam


def render_to(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def stitch(paths, out, delete_parts=True):
    """Horizontally concatenate PNGs (same height) into one image using bpy images."""
    arrs = []
    for p in paths:
        im = bpy.data.images.load(p, check_existing=False)
        w, h = im.size
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        arrs.append(a)
        bpy.data.images.remove(im)
    sep = np.ones((arrs[0].shape[0], 6, 4), dtype=np.float32)
    sep[..., :3] = 0.05
    parts = []
    for i, a in enumerate(arrs):
        if i:
            parts.append(sep)
        parts.append(a)
    full = np.concatenate(parts, axis=1)
    h, w = full.shape[:2]
    img = bpy.data.images.new("stitch", w, h, alpha=True)
    img.pixels = full.ravel()
    img.filepath_raw = out
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    if delete_parts:
        for p in paths:
            if p != out:
                try:
                    os.remove(p)
                except OSError:
                    pass
    return out


def hide_render(objs, hide=True):
    for o in objs:
        o.hide_render = hide


def write_manifest_entry(asset_key, data):
    """Merge one asset's data into assets/models/manifest.json."""
    p = os.path.join(MODELS, "manifest.json")
    man = {}
    if os.path.exists(p):
        with open(p) as f:
            man = json.load(f)
    man.setdefault("_contract", {
        "units": "1 unit = 1 Roblox stud",
        "axes": "Roblox axes: +Y up, -Z forward. Files exported with up=Y, forward=-Z.",
        "regenerate": "/home/claude/blender-venv/bin/python tools/blender/build_<asset>.py",
        "fbx": "vertex values are studs 1:1 (file unit declared as metres, identity object transforms); "
               "in the Roblox 3D Importer set the scale unit to Stud if the size comes in wrong",
        "bboxCenterFromOrigin": "offset from the object's origin (joint/grip point) to its bounding-box centre, "
                                "in studs; Roblox MeshParts are centred on the bbox, so pivot = bbox centre - this",
    })
    man[asset_key] = data
    with open(p, "w") as f:
        json.dump(man, f, indent=2)
    return p


# --------------------------------------------------------------------------- part-id helpers
# Hard-surface assets tag each face with a float attribute "part" (FACE domain); one shared
# material reads it (Attribute node) so a whole asset bakes into one texture atlas.

def new_part_bm():
    """bmesh with the 'part' face layer created up front (adding a layer later would
    invalidate existing BMFace references)."""
    bm = bmesh.new()
    bm.faces.layers.float.new("part")
    return bm


def tag_faces(bm, faces, part_id):
    lay = bm.faces.layers.float.get("part") or bm.faces.layers.float.new("part")
    for f in faces:
        f[lay] = float(part_id)


def new_faces_since(bm, n_before):
    bm.faces.ensure_lookup_table()
    return [bm.faces[i] for i in range(n_before, len(bm.faces))]


def part_masks(mb, ids):
    pa = mb.node("ShaderNodeAttribute", attribute_type='GEOMETRY', attribute_name="part").outputs["Fac"]
    return {i: mb.math('COMPARE', pa, float(i), c=0.5) for i in ids}


def by_part_color(mb, masks, table, default=(0.5, 0.5, 0.5, 1)):
    col = default
    for i, v in table.items():
        col = mb.mix(masks[i], col, v)
    return col


def by_part_float(mb, masks, table, default=0.0):
    acc = default
    for i, v in table.items():
        term = mb.math('MULTIPLY', masks[i], v)
        acc = term if isinstance(acc, float) and acc == 0.0 else mb.math('ADD', acc, term)
    return acc


def rrect(w, h, r, seg=3, cx=0.0, cz=0.0):
    """Rounded rectangle in the XZ plane, CCW seen from -Y; returns [(x, z)]."""
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180),
               (w / 2 - r, -h / 2 + r, 270)]
    for x, z, a0 in corners:
        for k in range(seg + 1):
            a = math.radians(a0 + 90 * k / seg)
            pts.append((cx + x + r * math.cos(a), cz + z + r * math.sin(a)))
    return pts


def extrude_profile(bm, pts, y0, y1, bevel=0.0, bevel_end=True, bevel_start=False, cap=True):
    """Extrude an XZ profile from y0 to y1 with an optional chamfer at the ends."""
    def ring(y, inset):
        cx = sum(p[0] for p in pts) / len(pts)
        cz = sum(p[1] for p in pts) / len(pts)
        out = []
        for x, z in pts:
            d = Vector((x - cx, z - cz))
            # inset toward the centre along the normalised direction (good enough for convex shapes)
            k = max(d.length - inset, 0.0) / max(d.length, 1e-6)
            out.append(Vector((cx + (x - cx) * k, y, cz + (z - cz) * k)))
        return out
    s = 1 if y1 > y0 else -1
    rings = []
    if bevel and bevel_start:
        rings.append(ring(y0, bevel))
        rings.append(ring(y0 + s * bevel, 0))
    else:
        rings.append(ring(y0, 0))
    if bevel and bevel_end:
        rings.append(ring(y1 - s * bevel, 0))
        rings.append(ring(y1, bevel))
    else:
        rings.append(ring(y1, 0))
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(pts)
    faces = []
    for a, b in zip(vr[:-1], vr[1:]):
        for i in range(n):
            faces.append(bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])))
    if cap:
        faces.append(bm.faces.new(list(reversed(vr[0]))))
        faces.append(bm.faces.new(vr[-1]))
    return faces


def sweep(bm, path, radius, sides=8, flat=1.0, cap=True):
    """Sweep a circle (radius, optional y-flattening) along a polyline of Vectors."""
    rings = []
    prev_n = None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if prev_n is None:
            up = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
            n = (up - t * up.dot(t)).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        rings.append([p + (n * math.cos(a) * flat + b * math.sin(a)) * radius
                      for a in (2 * math.pi * k / sides for k in range(sides))])
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    faces = []
    for a, c in zip(vr[:-1], vr[1:]):
        for i in range(sides):
            faces.append(bm.faces.new((a[i], a[(i + 1) % sides], c[(i + 1) % sides], c[i])))
    if cap:
        faces.append(bm.faces.new(list(reversed(vr[0]))))
        faces.append(bm.faces.new(vr[-1]))
    return faces


def text_bm(bm, text, size, matrix, extrude=0.01):
    """Add block text geometry (Blender's built-in font) transformed by matrix; returns faces."""
    cu = bpy.data.curves.new("txt", 'FONT')
    cu.body = text
    cu.size = size
    cu.extrude = extrude
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.resolution_u = 2
    ob = bpy.data.objects.new("txt", cu)
    link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    n0 = len(bm.faces)
    tmp = bmesh.new()
    tmp.from_mesh(me)
    bmesh.ops.transform(tmp, matrix=matrix, verts=tmp.verts)
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)
    return new_faces_since(bm, n0)
