--!strict
-- Builds the pieces of the kagune and the quinque case/blade for the rigs in
-- WeaponVisuals. Real meshes come from ReplicatedStorage.Assets.Weapons
-- (MeshParts named as in assets/models/manifest.json, loaded by the server's
-- AssetLoader); when a mesh isn't available yet, a plain-part stand-in with
-- the same size and pivot is used so everything still works in Studio.
--
-- Pivot contract (assets/README.md): every piece is authored around a joint.
-- Kagune segments run along +Y from their base joint; case and quinque
-- pieces are authored around the grip point at the centre of the handle.
-- `center` is the offset from that joint to the mesh's bounding-box centre,
-- which is where Roblox puts a MeshPart's origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type PieceSpec = {
	name: string,
	size: Vector3, -- bounding box in studs
	center: Vector3, -- joint -> bounding-box centre
	length: number?, -- kagune: base joint to top joint
	color: Color3,
	material: Enum.Material,
	shape: ("Block" | "Cylinder" | "Ball")?, -- stand-in shape
}

local Palette = {
	RcBright = Color3.fromHex("D21F2B"),
	RcMid = Color3.fromHex("9E1220"),
	RcDark = Color3.fromHex("4A060E"),
	RcGlow = Color3.fromHex("FF3B3B"),
	SteelLight = Color3.fromHex("C3C8CE"),
	SteelMid = Color3.fromHex("8C939B"),
	Blade = Color3.fromHex("B8BDC4"),
	GripBlack = Color3.fromHex("1D1E21"),
}

local function segment(name: string, length: number, base: number, color: Color3): PieceSpec
	return {
		name = name,
		size = Vector3.new(base, length, base * 0.8),
		center = Vector3.new(0, length / 2, 0),
		length = length,
		color = color,
		material = Enum.Material.SmoothPlastic,
		shape = "Cylinder",
	}
end

local WeaponModels = {}

WeaponModels.Palette = Palette

-- Rinkaku (Kaneki's early/mid look): four tentacles, root bright to tip dark.
WeaponModels.Rinkaku = {
	kakuhou = {
		name = "Kakuhou",
		size = Vector3.new(1.4, 0.6, 0.35),
		center = Vector3.zero,
		color = Palette.RcMid,
		material = Enum.Material.SmoothPlastic,
		shape = "Ball",
	} :: PieceSpec,
	-- Mount point on the torso: the lower back, just above the hip line.
	mount = CFrame.new(0, -0.65, 0.55),
	segments = {
		segment("RinkakuSeg1", 1.3, 0.5, Palette.RcBright),
		segment("RinkakuSeg2", 1.2, 0.42, Palette.RcBright),
		segment("RinkakuSeg3", 1.1, 0.34, Palette.RcMid),
		segment("RinkakuSeg4", 1.0, 0.27, Palette.RcMid),
		segment("RinkakuSeg5", 0.9, 0.2, Palette.RcDark),
		segment("RinkakuTip", 0.6, 0.13, Palette.RcDark),
	},
	-- Sockets on the kakuhou: right upper, left upper, right lower, left lower.
	sockets = {
		{ position = Vector3.new(0.3, 0.1, 0.1), side = 1, upper = true },
		{ position = Vector3.new(-0.3, 0.1, 0.1), side = -1, upper = true },
		{ position = Vector3.new(0.55, -0.1, 0.1), side = 1, upper = false },
		{ position = Vector3.new(-0.55, -0.1, 0.1), side = -1, upper = false },
	},
}

-- CCG case (plain silver, 1.6 x 1.2 x 0.4) and the Tsunagi-pattern blade.
-- Case pieces: width along X, hanging along -Y, thickness along Z.
-- Blade pieces: blade along +Y, edge toward -Z.
WeaponModels.Quinque = {
	caseShellFront = {
		name = "CaseShellFront",
		size = Vector3.new(1.6, 1.2, 0.2),
		center = Vector3.new(0, -0.82, -0.1),
		color = Palette.SteelLight,
		material = Enum.Material.Metal,
	} :: PieceSpec,
	caseShellBack = {
		name = "CaseShellBack",
		size = Vector3.new(1.6, 1.2, 0.2),
		center = Vector3.new(0, -0.82, 0.1),
		color = Palette.SteelLight,
		material = Enum.Material.Metal,
	} :: PieceSpec,
	caseHandle = {
		name = "CaseHandle",
		size = Vector3.new(0.55, 0.22, 0.12),
		center = Vector3.new(0, -0.07, 0),
		color = Palette.GripBlack,
		material = Enum.Material.SmoothPlastic,
	} :: PieceSpec,
	-- The bottom long edge the shells hinge open around, in case space.
	hinge = Vector3.new(0, -1.42, 0),
	hilt = {
		name = "QuinqueHilt",
		size = Vector3.new(0.3, 1.1, 0.14),
		center = Vector3.new(0, 0.05, 0),
		color = Palette.GripBlack,
		material = Enum.Material.SmoothPlastic,
	} :: PieceSpec,
	blade = {
		name = "QuinqueBlade",
		size = Vector3.new(0.06, 2.8, 0.26),
		center = Vector3.new(0, 2.0, 0),
		color = Palette.Blade,
		material = Enum.Material.Metal,
	} :: PieceSpec,
}

local function findAsset(name: string): BasePart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	local asset = weapons and weapons:FindFirstChild(name)
	if asset and asset:IsA("BasePart") then
		return asset
	end
	return nil
end

local function prepare(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
end

-- Returns the part and its offset from the piece's joint, so the caller can
-- weld it with C1 = offset:Inverse().
function WeaponModels.build(spec: PieceSpec): (BasePart, CFrame)
	local asset = findAsset(spec.name)
	if asset then
		local part = asset:Clone()
		prepare(part)
		return part, CFrame.new(spec.center)
	end

	local part = Instance.new("Part")
	part.Name = spec.name
	part.Color = spec.color
	part.Material = spec.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	prepare(part)

	local offset = CFrame.new(spec.center)
	if spec.shape == "Cylinder" then
		-- Cylinders run along X; turn them to run along the piece's Y.
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.X)
		offset *= CFrame.Angles(0, 0, math.pi / 2)
	elseif spec.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * math.max(spec.size.X, spec.size.Y, spec.size.Z) * 0.6
	else
		part.Size = spec.size
	end
	return part, offset
end

return WeaponModels
