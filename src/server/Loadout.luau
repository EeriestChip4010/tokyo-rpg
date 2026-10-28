--!strict
-- Rolls each player's origin when they join and decides which weapon G draws.
-- Odds follow vault/02-Design/Origins and Race Paths.md. The CCG join flow
-- isn't built yet, so for the first playable every human starts as an
-- investigator with the C-rate issue quinque.
--
-- Published on the Player: Origin ("Human" | "Ghoul" | "OneEyed") and,
-- for ghouls, KaguneType. Published on the character: Loadout and WeaponId,
-- which clients read to build the kagune or quinque case.

local Players = game:GetService("Players")

export type Loadout = {
	kind: "Ghoul" | "Investigator" | "Civilian",
	weaponMoveset: string?,
	oneEyed: boolean,
}

local ORIGIN_WEIGHTS = {
	{ origin = "Human", weight = 60 },
	{ origin = "Ghoul", weight = 39 },
	{ origin = "OneEyed", weight = 1 },
}

-- Rarity from the design note. Only implemented types can be rolled; the
-- rest join the pool as their kits are built.
local KAGUNE_WEIGHTS = {
	{ kaguneType = "Bikaku", weight = 35, moveset = nil :: string? },
	{ kaguneType = "Koukaku", weight = 30, moveset = nil :: string? },
	{ kaguneType = "Ukaku", weight = 25, moveset = nil :: string? },
	{ kaguneType = "Rinkaku", weight = 10, moveset = "Rinkaku" :: string? },
}

local INVESTIGATOR_QUINQUE = "BikakuBlade"

local random = Random.new()

local Loadout = {}

local function pick<T>(entries: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, entry in entries do
		total += weightOf(entry)
	end
	local roll = random:NextNumber(0, total)
	for _, entry in entries do
		roll -= weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

local function rollKaguneType(): string
	local implemented = {}
	for _, entry in KAGUNE_WEIGHTS do
		if entry.moveset then
			table.insert(implemented, entry)
		end
	end
	return pick(implemented, function(entry)
		return entry.weight
	end).kaguneType
end

local function movesetForKagune(kaguneType: string): string?
	for _, entry in KAGUNE_WEIGHTS do
		if entry.kaguneType == kaguneType then
			return entry.moveset
		end
	end
	return nil
end

function Loadout.setOrigin(player: Player, origin: string)
	player:SetAttribute("Origin", origin)
	if origin == "Human" then
		player:SetAttribute("KaguneType", nil)
	elseif player:GetAttribute("KaguneType") == nil then
		player:SetAttribute("KaguneType", rollKaguneType())
	end
end

function Loadout.roll(player: Player)
	if player:GetAttribute("Origin") ~= nil then
		return
	end
	local entry = pick(ORIGIN_WEIGHTS, function(e)
		return e.weight
	end)
	Loadout.setOrigin(player, entry.origin)
end

function Loadout.forPlayer(player: Player): Loadout
	local origin = player:GetAttribute("Origin")
	if origin == "Ghoul" or origin == "OneEyed" then
		local kaguneType = player:GetAttribute("KaguneType")
		return {
			kind = "Ghoul",
			weaponMoveset = if typeof(kaguneType) == "string" then movesetForKagune(kaguneType) else nil,
			oneEyed = origin == "OneEyed",
		}
	elseif origin == "Human" then
		return { kind = "Investigator", weaponMoveset = INVESTIGATOR_QUINQUE, oneEyed = false }
	end
	return { kind = "Civilian", weaponMoveset = nil, oneEyed = false }
end

-- Studio only: flip between ghoul and investigator for testing both kits.
function Loadout.devSwap(player: Player)
	local origin = player:GetAttribute("Origin")
	Loadout.setOrigin(player, if origin == "Human" then "Ghoul" else "Human")
end

function Loadout.start()
	Players.PlayerAdded:Connect(Loadout.roll)
	for _, player in Players:GetPlayers() do
		Loadout.roll(player)
	end
end

return Loadout
