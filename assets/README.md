# Assets (procedural, regenerated with headless Blender)

Every model and texture in this folder comes from the scripts in `tools/blender/`.
Don't edit the FBX/OBJ/PNG files by hand. Change the script and regenerate instead.

| Asset | Script | Files |
|---|---|---|
| Rinkaku kagune (Kaneki, 4 tails) | `tools/blender/build_kagune.py` | `models/kagune_rinkaku.{fbx,obj,mtl}`, `textures/kagune_rinkaku_*.png` |
| CCG quinque case | `tools/blender/build_case.py` | `models/quinque_case.{fbx,obj,mtl}`, `textures/quinque_case_*.png` |
| Starter quinque, CCG Issue Blade (Tsunagi pattern, Bikaku C-rate) | `tools/blender/build_blade.py` | `models/quinque_blade.{fbx,obj,mtl}`, `textures/quinque_blade_*.png` |

`tools/blender/common.py` holds the shared helpers: mesh building, UVs, baking, export, the R6 mannequin and rendering.
`models/manifest.json` lists every object with its file, bounding-box size, `bboxCenterFromOrigin`, pivot, triangle count and textures.
It also has kagune joint lengths and diameters, case hinge lines, and trigger positions.

## Regenerate

Run from the repo root. Blender runs headless as the `bpy` Python module (`pip install bpy==4.2.0` into a Python 3.11 environment), and Cycles bakes and renders on the CPU. The commands below use the cloud workspace's venv; substitute your own Python.

```sh
/home/claude/blender-venv/bin/python tools/blender/build_kagune.py
/home/claude/blender-venv/bin/python tools/blender/build_case.py
/home/claude/blender-venv/bin/python tools/blender/build_blade.py
```

- Each script starts from an empty scene.
- It builds the meshes, Smart-UV-unwraps all pieces of the asset into one shared atlas, and bakes 1024x1024 PNGs from the procedural node material.
- The PNGs are `_albedo` (sRGB), `_normal` (tangent space, OpenGL / +Y), `_roughness`, `_metalness` and `_emissive` (greyscale glow mask).
- It then exports FBX and OBJ, merges its entry into `models/manifest.json`, and renders review images into `renders/`.
- `tools/blender/preview_kagune_pose.py` reproduces the game's tentacle pose math (Kakuhou, root and curl chain, in Roblox CFrames) on the R6 mannequin. It renders `renders/kagune_rinkaku_pose_rest.png` and `_pose_strike.png` and prints a pose report (tip positions, height, body intersections). Pass a JSON object of overrides as the last argument to try new numbers. The defaults are the approved rest and strike values.
- Add `--no-render` to skip the renders (about 1 min per asset is mostly baking).
- To rebuild the manifest from scratch, delete it and run all three scripts.

## Axes, units and pivots (the contract game code depends on)

- **1 unit = 1 stud.** In the FBX files the vertex values are studs 1:1, objects have identity transforms, and the file unit is declared as metres. If the Roblox 3D Importer brings the model in at the wrong size, set its scale unit to Stud. OBJ files are unitless 1:1.
- **Roblox axes in the files:** +Y up, the character faces -Z. The scripts model Z-up in Blender and export with up=Y, forward=-Z. Roblox X = Blender X, Roblox Y = Blender Z, Roblox Z = Blender -Y. Use `common.rbx(x, y, z)` to write Roblox coordinates in Blender space.
- **MeshParts are centred on their bounding box** in Roblox. Each manifest entry has `bboxCenterFromOrigin`, the offset from the contract origin to the bbox centre. Use it to rebuild the pivot (`PivotOffset = CFrame.new(-offset)`).

### Kagune (v3: long, smooth, fleshy): `RinkakuSeg1`..`RinkakuSeg5`, `RinkakuTip`, `Kakuhou`
- Each piece is modelled along **+Y**. The origin is its base joint, and the top joint is at `(0, L, 0)`. Lengths are 2.0 / 1.8 / 1.7 / 1.5 / 1.3 and the tip is 0.9, for 9.2 studs along the curve.
- Diameter is 0.60 at the root (0.65 muscle belly) and tapers gradually to about 0.22 at the tip base. Every joint diameter is in the manifest.
- Each piece has a dome centred on its top joint. Its base has a soft muscle collar that sleeves about 0.15 over the previous piece, so bends of up to about 25–35° per joint stay closed.
- The section is nearly round, with smooth swelling, wet muscle-fibre striations and veins. There are no spikes, only a soft, low dorsal ridge on local **+Z**. Curl with `CFrame.Angles(-a, 0, 0)` per joint to keep that ridge on the outside of the curve.
- The only bend baked into the meshes is the tip's spear point, hooked about 10° toward -Z.
- To chain the pieces: `piece[i+1].CFrame = piece[i].CFrame * CFrame.new(0, L[i], 0) * CFrame.Angles(-a, 0, b)`.
- `Kakuhou` is the root mass. Its origin is its centre. The visible face points +Z (the character's back) and the flat side (-Z) rests on the torso. Mount it at `Torso.CFrame * CFrame.new(0, -0.65, 0.65)`, which puts its centre 2.35 studs above the feet.
- The four tail sockets (UpperRight/Left at ±0.30, LowerRight/Left at ±0.55) are listed with position and outward direction in `manifest.json`. Clone the chain 4 times.
- Colour runs deep red `#C0162A` at the root to `#7E0C18` to `#3A040B` at the tip, and the surface is glossy (roughness about 0.25).
- Emissive: the mask covers the veins and the root mass. Tint `#FF3B3B`, strength about 0.15–0.25.

### Case: `CaseShellFront`, `CaseShellBack`, `CaseHandle`
- Every object's origin is the **grip point**, the centre of the handle bar, where it attaches to `RightGripAttachment`.
- Width 1.6 runs along X, the shell hangs down -Y (top at Y=-0.16, bottom at Y=-1.36), and the 0.4 thickness runs along Z. The shell is split at mid-depth with a 0.015 seam: front is the -Z half, back is the +Z half.
- The trim, ribs, corner caps, latches (front only) and the "CCG" plate (front only) are part of the shell they sit on.
- `CaseHandle` holds the D-bar, its mounts and the trigger button. The trigger sits on the underside of the bar at (0.07, -0.06, 0).
- **Opening:** each shell hinges about the bottom long edge. The hinge point and axis are in the manifest: `(0, -1.36, ∓0.0075)`, axis X. Front opens toward -Z, back toward +Z.
- To carry the case at the side, rotate it 90° about Y so its width runs along the character's forward axis.
- Emissive: the mask covers the seam interior (RC_DARK) and the trigger. Strength is 0 at rest; ramp it up on trigger and open.

### Starter quinque: `QuinqueHilt`, `QuinqueBlade`
- Both objects share one origin, the **grip point** at the centre of the grip.
- The blade points **+Y** with the edge facing **-Z**. The spine and its 9 vertebra plates face +Z.
- Overall length is 3.8: pommel Y -0.40 to -0.30, grip up to 0.40, collar 0.40–0.60, blade 0.60–3.40.
- There is no crossguard (canon Tsunagi). The collar is where the folded case shells dock.
- The trigger sits on the -Z (index finger) side at Y 0.30.
- Baked bend: a very slight curve with the tip deflected about 0.09 toward +Z, so the edge is on the convex side.
- Emissive: the mask covers the spine vertebrae. Strength about 0.1 at rest, flaring to about 0.6 during skills.

## Review renders
`renders/` holds turnarounds, scale shots against an R6 block mannequin, and detail close-ups. The kagune also has `_rest`, `_ingame`, `_joint_detail` and `_root_detail` renders.
The mannequin is only built for renders and is never exported.
Visual references were researched separately. No reference images are stored in this repo.

## Getting the meshes into the game

The game works without the meshes: `client/WeaponModels.luau` falls back to plain-part stand-ins with the same sizes and pivots. To use the real models:

1. In Studio, **File > Import 3D** each FBX in `models/` (scale unit: Stud). Upload them to your account when asked.
2. Either drop the imported MeshParts into `ReplicatedStorage.Assets.Weapons` (keep the object names), or copy each MeshPart's `MeshId` and its texture id (upload `textures/<asset>_albedo.png` as a Decal/Image) into `src/shared/AssetIds.luau`. With ids filled in, the server's `AssetLoader` builds the MeshParts at startup.
3. Optional: add a `SurfaceAppearance` to each imported MeshPart with the `_albedo`, `_normal`, `_roughness` and `_metalness` maps; the game clones whatever is on the MeshPart.
