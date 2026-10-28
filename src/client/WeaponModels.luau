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

local function segment(name: string, length: number, size: Vector3, center: Vector3, color: Color3): PieceSpec
	return {
		name = name,
		size = size,
		center = center,
		length = length,
		color = color,
		material = Enum.Material.SmoothPlastic,
		shape = "Cylinder",
	}
end

local WeaponModels = {}

WeaponModels.Palette = Palette

-- Sizes and centres of every piece come from assets/models/manifest.json.

-- Rinkaku (Kaneki's early/mid look): four long, fleshy tentacles, deep red
-- at the root fading to near-black at the tip.
WeaponModels.Rinkaku = {
	kakuhou = {
		name = "Kakuhou",
		size = Vector3.new(1.347, 0.549, 0.308),
		center = Vector3.new(-0.001, 0.002, 0.08),
		color = Palette.RcMid,
		material = Enum.Material.SmoothPlastic,
		shape = "Ball",
	} :: PieceSpec,
	-- Mount point on the torso: the lower back, just above the hip line.
	mount = CFrame.new(0, -0.65, 0.65),
	segments = {
		segment("RinkakuSeg1", 2, Vector3.new(0.806, 2.723, 0.759), Vector3.new(-0.006, 1.001, 0.013), Palette.RcBright),
		segment("RinkakuSeg2", 1.8, Vector3.new(0.762, 2.48, 0.703), Vector3.new(0, 0.877, 0.01), Palette.RcBright),
		segment("RinkakuSeg3", 1.7, Vector3.new(0.666, 2.267, 0.598), Vector3.new(0, 0.816, 0), Palette.RcMid),
		segment("RinkakuSeg4", 1.5, Vector3.new(0.525, 1.943, 0.484), Vector3.new(0, 0.722, 0.007), Palette.RcMid),
		segment("RinkakuSeg5", 1.3, Vector3.new(0.406, 1.643, 0.364), Vector3.new(0, 0.628, 0), Palette.RcDark),
		segment("RinkakuTip", 0.9, Vector3.new(0.316, 1.05, 0.296), Vector3.new(0, 0.375, 0.007), Palette.RcDark),
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
		size = Vector3.new(1.7, 1.3, 0.216),
		center = Vector3.new(0, -0.76, -0.115),
		color = Palette.SteelLight,
		material = Enum.Material.Metal,
	} :: PieceSpec,
	caseShellBack = {
		name = "CaseShellBack",
		size = Vector3.new(1.7, 1.3, 0.216),
		center = Vector3.new(0, -0.76, 0.115),
		color = Palette.SteelLight,
		material = Enum.Material.Metal,
	} :: PieceSpec,
	caseHandle = {
		name = "CaseHandle",
		size = Vector3.new(0.65, 0.2, 0.12),
		center = Vector3.new(0, -0.06, 0),
		color = Palette.GripBlack,
		material = Enum.Material.SmoothPlastic,
	} :: PieceSpec,
	-- The bottom long edge the shells hinge open around, in case space.
	hinge = Vector3.new(0, -1.36, 0),
	hilt = {
		name = "QuinqueHilt",
		size = Vector3.new(0.17, 1, 0.336),
		center = Vector3.new(0, 0.1, -0.03),
		color = Palette.GripBlack,
		material = Enum.Material.SmoothPlastic,
	} :: PieceSpec,
	blade = {
		name = "QuinqueBlade",
		size = Vector3.new(0.08, 2.9, 0.365),
		center = Vector3.new(0, 1.95, 0.023),
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
