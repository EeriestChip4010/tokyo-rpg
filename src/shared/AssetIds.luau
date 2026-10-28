--!strict
-- Roblox asset ids for the weapon meshes and their albedo textures, keyed by
-- the piece names in assets/models/manifest.json. 0 means not uploaded yet:
-- the game then uses plain-part stand-ins (client/WeaponModels).
-- See assets/README.md for how to upload the meshes and fill these in.

export type AssetEntry = { mesh: number, texture: number }

local AssetIds: { [string]: AssetEntry } = {
	Kakuhou = { mesh = 0, texture = 0 },
	RinkakuSeg1 = { mesh = 0, texture = 0 },
	RinkakuSeg2 = { mesh = 0, texture = 0 },
	RinkakuSeg3 = { mesh = 0, texture = 0 },
	RinkakuSeg4 = { mesh = 0, texture = 0 },
	RinkakuSeg5 = { mesh = 0, texture = 0 },
	RinkakuTip = { mesh = 0, texture = 0 },
	CaseShellFront = { mesh = 0, texture = 0 },
	CaseShellBack = { mesh = 0, texture = 0 },
	CaseHandle = { mesh = 0, texture = 0 },
	QuinqueHilt = { mesh = 0, texture = 0 },
	QuinqueBlade = { mesh = 0, texture = 0 },
}

return AssetIds
