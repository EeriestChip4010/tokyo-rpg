--!strict
-- Combat tuning shared by server and client. All values are placeholders
-- until playtested; see vault/02-Design/Combat System.md.

local CombatConfig = {
	M1 = {
		Damage = 4,
		SwingInterval = 0.35, -- seconds between swings
		ChainLength = 4, -- the last hit is the finisher
		ChainResetTime = 1.2, -- idle time that resets the chain
		HitboxSize = Vector3.new(5, 5, 5),
		HitboxOffset = 3.5, -- studs in front of the attacker
	},

	-- Max remote calls a player may send per second before being ignored.
	MaxActionsPerSecond = 15,
}

return CombatConfig
