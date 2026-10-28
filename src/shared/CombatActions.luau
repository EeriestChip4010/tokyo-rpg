--!strict
-- The only action names the client may send to the server.

local CombatActions = {
	M1 = "M1",
	Feint = "Feint",
	BlockStart = "BlockStart",
	BlockEnd = "BlockEnd",
	Dash = "Dash",
	Dodge = "Dodge",
	Skill1 = "Skill1",
	Skill2 = "Skill2",
	ToggleWeapon = "ToggleWeapon",
	-- Studio only: swaps between the ghoul and investigator test loadouts.
	DevSwapOrigin = "DevSwapOrigin",
}

return CombatActions
