--!strict
-- Turns the uploaded weapon mesh ids in Shared.AssetIds into MeshParts under
-- ReplicatedStorage.Assets.Weapons, where client/WeaponModels clones them.
-- A MeshPart's mesh can't be assigned from a script, so they're created with
-- AssetService:CreateMeshPartAsync. Pieces already placed in that folder by
-- hand (for example imported with Studio's 3D Importer) are left alone.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Shared.AssetIds)

local AssetLoader = {}

local function folder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

function AssetLoader.start()
	local weapons = folder(folder(ReplicatedStorage, "Assets"), "Weapons")
	for name, ids in AssetIds do
		if ids.mesh == 0 or weapons:FindFirstChild(name) then
			continue
		end
		task.spawn(function()
			local ok, result = pcall(function()
				return AssetService:CreateMeshPartAsync(`rbxassetid://{ids.mesh}`)
			end)
			if not ok then
				warn(`AssetLoader: couldn't load mesh {name} ({ids.mesh}): {result}`)
				return
			end
			local part = result :: MeshPart
			part.Name = name
			if ids.texture ~= 0 then
				part.TextureID = `rbxassetid://{ids.texture}`
			end
			part.Anchored = true
			part.CanCollide = false
			part.Parent = weapons
		end)
	end
end

return AssetLoader
